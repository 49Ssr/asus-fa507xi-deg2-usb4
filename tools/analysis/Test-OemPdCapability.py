"""Execute pinned OEM code offline with explicit EC and kernel test doubles.

No device APIs. Private vendor binaries are inputs and are never modified.
This qualifies the capability request's framing, not its hardware behaviour.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path

from unicorn import Uc, UC_ARCH_X86, UC_MODE_64, UC_HOOK_CODE
from unicorn.x86_const import (
    UC_X86_REG_RAX, UC_X86_REG_RCX, UC_X86_REG_RDX, UC_X86_REG_R8,
    UC_X86_REG_R9, UC_X86_REG_R12, UC_X86_REG_R13, UC_X86_REG_RBX,
    UC_X86_REG_RSP, UC_X86_REG_RBP, UC_X86_REG_RIP,
)

PINS = {
    'AsusSAIO.sys': 'eef750c7fb515d162a76423531f4f6773bcf837d9607069e797a26d198edd892',
    'AsusWinIO64.dll': 'a07802f565b9b1ec527b2d1eec69debfb92f90022953b63f1122edb50d2d5b54',
}
STACK, DATA, STUB, STOP = 0x200000000, 0x300000000, 0x400000000, 0x400000100


def image(path):
    raw = path.read_bytes()
    if hashlib.sha256(raw).hexdigest() != PINS[path.name]:
        raise ValueError('Unreviewed binary: ' + path.name)
    nt = struct.unpack_from('<I', raw, 0x3c)[0]
    if raw[nt:nt+4] != b'PE\0\0':
        raise ValueError('Not PE')
    optional = nt+24
    if struct.unpack_from('<H', raw, optional)[0] != 0x20b:
        raise ValueError('Not PE64')
    base = struct.unpack_from('<Q', raw, optional+24)[0]
    length, headers = struct.unpack_from('<II', raw, optional+56)
    data = bytearray(length)
    data[:headers] = raw[:headers]
    sections = optional+struct.unpack_from('<H', raw, nt+20)[0]
    for i in range(struct.unpack_from('<H', raw, nt+6)[0]):
        _, rva, size, offset = struct.unpack_from('<IIII', raw, sections+i*40+8)
        data[rva:rva+size] = raw[offset:offset+size]
    return base, data


class Machine:
    def __init__(self, base, data):
        self.base = base
        self.uc = Uc(UC_ARCH_X86, UC_MODE_64)
        for start, size in [(base, (len(data)+4095)&~4095), (STACK, 0x20000), (DATA, 0x10000), (STUB, 0x1000)]:
            self.uc.mem_map(start, size)
        self.uc.mem_write(base, bytes(data))
        self.uc.mem_write(STUB, b'\xc3'*0x1000)
        self.uc.reg_write(UC_X86_REG_RSP, STACK+0x10008)
        self.w64(STACK+0x10008, STOP)
        self.calls = []

    def w64(self, at, value):
        self.uc.mem_write(at, struct.pack('<Q', value))

    def r64(self, at):
        return struct.unpack('<Q', self.uc.mem_read(at, 8))[0]

    def ret(self, value=0):
        sp = self.uc.reg_read(UC_X86_REG_RSP)
        self.uc.reg_write(UC_X86_REG_RAX, value & 0xffffffffffffffff)
        self.uc.reg_write(UC_X86_REG_RIP, self.r64(sp))
        self.uc.reg_write(UC_X86_REG_RSP, sp+8)

    def run(self, rva, hook):
        self.uc.hook_add(UC_HOOK_CODE, hook)
        self.uc.emu_start(self.base+rva, STOP, count=5000)
        assert self.uc.reg_read(UC_X86_REG_RIP) == STOP, 'Instruction budget exhausted'
        return self.uc.reg_read(UC_X86_REG_RAX) & 0xffffffff


def getter(binary, reply, status):
    m = Machine(*binary)
    m.uc.mem_write(m.base+0x26af41, b'\x01')  # Select the reviewed legacy x64 route.
    def hook(uc, address, size, context):
        if address == m.base+0x47870:
            cl = uc.reg_read(UC_X86_REG_RCX)&255
            dl = uc.reg_read(UC_X86_REG_RDX)&255
            r8 = uc.reg_read(UC_X86_REG_R8)
            mode = uc.reg_read(UC_X86_REG_R9)&255
            params = bytes(uc.mem_read(r8, cl)).hex()
            m.calls.append((dl, cl, params, mode))
            uc.mem_write(m.r64(uc.reg_read(UC_X86_REG_RSP)+0x28), struct.pack('<I', status))
            m.ret(reply)
    result = m.run(0x55470, hook)
    assert m.calls == [(0xbb, 1, '50', 1)], m.calls
    assert result == (reply if status == 0 else 0x7fffffff), hex(result)
    return {'response': reply, 'ecStatus': status, 'return': result, 'calls': m.calls}


def driver_wrapper(binary, reply, status, supplied_packet=None):
    m = Machine(*binary)
    packet = bytearray(16)
    packet[0:3] = bytes.fromhex('bb0150')
    packet[10] = 1
    if supplied_packet is not None:
        packet = bytearray(supplied_packet)
    m.uc.mem_write(DATA, bytes(packet))
    m.uc.reg_write(UC_X86_REG_RCX, DATA+0x100)
    m.uc.reg_write(UC_X86_REG_RDX, DATA)
    m.w64(m.base+0x40c0, STUB+0x10)  # KeWaitForSingleObject
    m.w64(m.base+0x40b8, STUB+0x20)  # KeReleaseMutex
    def hook(uc, address, size, context):
        if address in (STUB+0x10, STUB+0x20):
            m.calls.append('wait' if address == STUB+0x10 else 'release')
            m.ret()
        elif address == m.base+0x1828:
            assert uc.reg_read(UC_X86_REG_RCX)&255 == packet[1]
            assert uc.reg_read(UC_X86_REG_RDX)&255 == packet[0]
            assert uc.reg_read(UC_X86_REG_R8) == DATA+2
            assert uc.reg_read(UC_X86_REG_R9)&255 == 1
            at = m.r64(uc.reg_read(UC_X86_REG_RSP)+0x28)
            assert at == DATA+12
            uc.mem_write(at, struct.pack('<I', status))
            m.calls.append('ec')
            m.ret(reply)
    assert m.run(0x1aa0, hook) == 0
    output = bytes(m.uc.mem_read(DATA, 16))
    assert m.calls == ['wait', 'ec', 'release'], m.calls
    assert output[11] == reply and struct.unpack_from('<I', output, 12)[0] == status
    assert output[:11] == packet[:11]
    return {'response': reply, 'ecStatus': status, 'output': output.hex(), 'calls': m.calls}


def pd_identity_loop(binary, payload, fail_at=None):
    assert len(payload) == 12
    m = Machine(*binary)
    frame = STACK+0x11000
    m.uc.reg_write(UC_X86_REG_RBP, frame)
    outcome = []
    def hook(uc, address, size, context):
        if address in (m.base+0x21d5e, m.base+0x21da0):
            outcome.append(address == m.base+0x21d5e)
            uc.reg_write(UC_X86_REG_RIP, STOP)
        elif address == m.base+0x47870:
            count = uc.reg_read(UC_X86_REG_RCX)&255
            command = uc.reg_read(UC_X86_REG_RDX)&255
            params = bytes(uc.mem_read(uc.reg_read(UC_X86_REG_R8), count))
            mode = uc.reg_read(UC_X86_REG_R9)&255
            index = len(m.calls)
            assert (command, count, params, mode) == (0xdd, 3, bytes([5, index+2, 1]), 1)
            status = 5 if index == fail_at else 0
            uc.mem_write(m.r64(uc.reg_read(UC_X86_REG_RSP)+0x28), struct.pack('<I', status))
            m.calls.append({'command': command, 'params': params.hex(), 'status': status})
            m.ret(payload[index])
    m.run(0x21d14, hook)
    assert len(m.calls) == (12 if fail_at is None else fail_at+1)
    assert outcome == [fail_at is None]
    if fail_at is None:
        assert bytes(m.uc.mem_read(frame-0x19, 12)) == payload
    return {'kind': 'original-pd-identity-loop', 'payload': payload.hex(), 'failureAt': fail_at, 'completed': outcome[0], 'calls': m.calls}


def pd_identity_gate(binary, version):
    m = Machine(*binary)
    m.uc.reg_write(UC_X86_REG_R13, version)
    outcome = []
    def hook(uc, address, size, context):
        if address in (m.base+0x21d14, m.base+0x21da0):
            outcome.append(address == m.base+0x21d14)
            uc.reg_write(UC_X86_REG_RIP, STOP)
    m.run(0x21d05, hook)
    assert outcome == [14 <= version <= 255], (version, outcome)
    return {'kind': 'original-pd-identity-gate', 'tableVersion': version, 'allowsPdIdentity': outcome[0]}


def pdo_loop(binary, kind, index, value, fail_at=None, failure_status=5):
    m = Machine(*binary)
    m.uc.reg_write(UC_X86_REG_RBP, STACK+0x11000)
    m.uc.reg_write(UC_X86_REG_R12, index)
    payload = struct.pack('<I', value)
    if kind == 'contract':
        entry, good, bad, end, low = 0x1fe14, 0x1fe8d, 0x1fe98, 0x1fea4, 0x1e
    else:
        entry, good, bad, end, low = 0x200ba, 0x20130, 0x2013b, 0x20147, 2+4*index
    outcome = []
    def hook(uc, address, size, context):
        if address in (m.base+good, m.base+bad):
            outcome.append(address == m.base+good)
        elif address == m.base+end:
            uc.reg_write(UC_X86_REG_RIP, STOP)
        elif address == m.base+0x47870:
            count = uc.reg_read(UC_X86_REG_RCX)&255
            command = uc.reg_read(UC_X86_REG_RDX)&255
            params = bytes(uc.mem_read(uc.reg_read(UC_X86_REG_R8), count))
            step = len(m.calls)
            offset = low+3-step
            assert (command, count, params, uc.reg_read(UC_X86_REG_R9)&255) == (0xdd, 3, bytes([6, offset, 0]), 1)
            status = failure_status if step == fail_at else 0
            uc.mem_write(m.r64(uc.reg_read(UC_X86_REG_RSP)+0x28), struct.pack('<I', status))
            m.calls.append({'params': params.hex(), 'status': status})
            m.ret(payload[offset-low])
    returned = m.run(entry, hook)
    assert len(m.calls) == (4 if fail_at is None else fail_at+1)
    assert outcome == [fail_at is None]
    if fail_at is None:
        assert m.uc.reg_read(UC_X86_REG_RBX)&0xffffffff == value
    assert returned == (value if fail_at is None else 0x7fffffff)
    return {'kind': 'original-'+kind+'-loop', 'index': index, 'word': f'{value:08x}', 'failureAt': fail_at, 'failureStatus': failure_status if fail_at is not None else None, 'completed': outcome[0], 'returned': returned, 'calls': m.calls}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path, help='Private copies of the two pinned binaries')
    parser.add_argument('--output', type=Path, required=True, help='Private new result file')
    args = parser.parse_args()
    binaries = {name: image(args.directory/name) for name in PINS}
    results = []
    for response, status in [(0, 0), (1, 0), (255, 0), (0, 1), (2, 5), (0, 0x102)]:
        results.append({'kind': 'original-client', **getter(binaries['AsusWinIO64.dll'], response, status)})
        results.append({'kind': 'original-driver-wrapper', **driver_wrapper(binaries['AsusSAIO.sys'], response, status)})
    for version in [0, 13, 14, 15, 255, 0x7fffffff]:
        results.append(pd_identity_gate(binaries['AsusWinIO64.dll'], version))
    for fail_at in [None, 0, 5, 11]:
        results.append(pd_identity_loop(binaries['AsusWinIO64.dll'], b'TEST-CTRL123', fail_at))
    results.append(pd_identity_loop(binaries['AsusWinIO64.dll'], b'\xff'*12))
    for offset in [2, 7, 13]:
        packet = bytearray(16)
        packet[:5] = bytes([0xdd, 3, 5, offset, 1])
        packet[10] = 1
        for status in [0, 5]:
            results.append({'kind': 'original-driver-identity-wrapper', **driver_wrapper(binaries['AsusSAIO.sys'], 0x41, status, packet)})
    for index, value in enumerate([0x2f81912c, 0x0002d12c, 0x0004b12c, 0x000641e0]):
        results.append(pdo_loop(binaries['AsusWinIO64.dll'], 'source-pdo', index, value))
    results.append(pdo_loop(binaries['AsusWinIO64.dll'], 'contract', 0, 0x2f81912c))
    results.append(pdo_loop(binaries['AsusWinIO64.dll'], 'source-pdo', 0, 0))
    for kind in ['source-pdo', 'contract']:
        for failure in [0, 3]:
            results.append(pdo_loop(binaries['AsusWinIO64.dll'], kind, 0, 0x2f81912c, failure))
        results.append(pdo_loop(binaries['AsusWinIO64.dll'], kind, 0, 0x2f81912c, 0, 0x102))
    report = {'qualification': 'Offline framing and wrapper only; EC/kernel calls are test doubles; no hardware', 'cases': results}
    with args.output.open('x', encoding='utf-8') as stream:
        json.dump(report, stream, indent=2)
    print(f'{len(results)} offline cases passed; no hardware access')


if __name__ == '__main__':
    main()
