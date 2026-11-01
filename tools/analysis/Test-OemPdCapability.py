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
    UC_X86_REG_R9, UC_X86_REG_R13, UC_X86_REG_RSP, UC_X86_REG_RIP,
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


def driver_wrapper(binary, reply, status):
    m = Machine(*binary)
    packet = bytearray(16)
    packet[0:3] = bytes.fromhex('bb0150')
    packet[10] = 1
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
            assert uc.reg_read(UC_X86_REG_RCX)&255 == 1
            assert uc.reg_read(UC_X86_REG_RDX)&255 == 0xbb
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path, help='Private copies of the two pinned binaries')
    parser.add_argument('--output', type=Path, required=True, help='Private new result file')
    args = parser.parse_args()
    binaries = {name: image(args.directory/name) for name in PINS}
    results = []
    for response, status in [(0, 0), (1, 0), (255, 0), (0, 1), (2, 5)]:
        results.append({'kind': 'original-client', **getter(binaries['AsusWinIO64.dll'], response, status)})
        results.append({'kind': 'original-driver-wrapper', **driver_wrapper(binaries['AsusSAIO.sys'], response, status)})
    for version in [0, 13, 14, 15, 255, 0x7fffffff]:
        results.append(pd_identity_gate(binaries['AsusWinIO64.dll'], version))
    report = {'qualification': 'Offline framing and wrapper only; EC/kernel calls are test doubles; no hardware', 'cases': results}
    with args.output.open('x', encoding='utf-8') as stream:
        json.dump(report, stream, indent=2)
    print(f'{len(results)} offline cases passed; no hardware access')


if __name__ == '__main__':
    main()
