"""Offline execution of pinned driver code in Unicorn. No Windows device APIs.

Driver bytes remain private. WDF, CFU transport, registry and I2C are explicit
test doubles; results qualify control flow only, never real bus behaviour.
The candidate injects a call to the existing cleanup routine inside the emulator.
It neither modifies the driver file nor prepares an installable driver patch.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path

from unicorn import Uc, UC_ARCH_X86, UC_MODE_64, UC_HOOK_CODE
from unicorn.x86_const import (
    UC_X86_REG_RAX, UC_X86_REG_RCX, UC_X86_REG_RDX, UC_X86_REG_R8,
    UC_X86_REG_R9, UC_X86_REG_R13, UC_X86_REG_RSI, UC_X86_REG_RSP, UC_X86_REG_RBP,
    UC_X86_REG_RIP,
)

PIN = '9b701e2bef6411ac2ecb01cf9819ddeedefd0975a77863726e77009d89d4296c'
BASE, STACK, HEAP, STUB = 0x140000000, 0x200000000, 0x300000000, 0x400000000
CTX, PACKET, OFFER, RESPONSE = HEAP, HEAP+0x24000, HEAP+0x25000, HEAP+0x26000
TABLE, DISPATCH, STOP = STUB+0x10000, STUB+0x20000, STUB+0x20010
REGS = [UC_X86_REG_RCX, UC_X86_REG_RDX, UC_X86_REG_R8, UC_X86_REG_R9]


def pe_image(data):
    nt = struct.unpack_from('<I', data, 0x3c)[0]
    assert data[nt:nt+4] == b'PE\0\0'
    count, optional = struct.unpack_from('<H', data, nt+6)[0], nt+24
    assert struct.unpack_from('<H', data, optional)[0] == 0x20b
    assert struct.unpack_from('<Q', data, optional+24)[0] == BASE
    size, headers = struct.unpack_from('<II', data, optional+56)
    image = bytearray(size)
    image[:headers] = data[:headers]
    sections = optional + struct.unpack_from('<H', data, nt+20)[0]
    for i in range(count):
        _, rva, rawsize, raw = struct.unpack_from('<IIII', data, sections+i*40+8)
        image[rva:rva+rawsize] = data[raw:raw+rawsize]
    return image


class Trial:
    def __init__(self, image, reads, candidate=False, cached=None):
        self.uc = Uc(UC_ARCH_X86, UC_MODE_64)
        for start, size in [(BASE, 0x40000), (STACK, 0x20000), (HEAP, 0x40000), (STUB, 0x30000)]:
            self.uc.mem_map(start, size)
        self.uc.mem_write(BASE, bytes(image))
        self.reads, self.candidate, self.cached = list(reads), candidate, cached
        self.targets, self.inner, self.events = {}, {}, []
        self.responses, self.cleanups, self.injections = [], 0, 0
        self.resume = False
        self.w64(BASE+0x15ab8, TABLE)
        self.w64(BASE+0x15ac0, 0x1234)
        self.w64(BASE+0x12238, DISPATCH)
        self.w64(BASE+0x12198, STUB+0x1000)
        self.w64(BASE+0x121a0, STUB+0x1010)
        self.w64(BASE+0x15080, BASE+0x15080)  # trace disabled
        self.uc.mem_write(CTX+0x18, b'\x30')
        self.uc.mem_write(CTX+0x22, 'ACPI\\VEN_PS88&DEV_3018\0'.encode('utf-16le'))
        for offset in [0x538, 0x540, 0x550, 0x5d0, 0x650]:
            self.w64(TABLE+offset, STUB+offset)
        self.uc.hook_add(UC_HOOK_CODE, self.hook)

    def r64(self, p): return struct.unpack('<Q', self.uc.mem_read(p, 8))[0]
    def w64(self, p, n): self.uc.mem_write(p, struct.pack('<Q', n))
    def w32(self, p, n): self.uc.mem_write(p, struct.pack('<I', n & 0xffffffff))
    def text(self, p):
        out = bytearray()
        for i in range(512):
            c = bytes(self.uc.mem_read(p+i*2, 2))
            if c == b'\0\0': return out.decode('utf-16le')
            out.extend(c)
        raise AssertionError('Unterminated emulated string')

    def ret(self, value=0):
        sp = self.uc.reg_read(UC_X86_REG_RSP)
        dest = self.r64(sp)
        self.uc.reg_write(UC_X86_REG_RAX, value & 0xffffffffffffffff)
        self.uc.reg_write(UC_X86_REG_RSP, sp+8)
        self.uc.reg_write(UC_X86_REG_RIP, dest)

    def hook(self, uc, address, size, _):
        a, b, c, d = (uc.reg_read(r) for r in REGS)
        sp = uc.reg_read(UC_X86_REG_RSP)
        rva = address-BASE
        if address == STOP:
            uc.emu_stop(); return
        if address == DISPATCH:
            uc.reg_write(UC_X86_REG_RIP, uc.reg_read(UC_X86_REG_RAX)); return
        if rva == 0x1668 and self.candidate:
            if self.resume:
                self.resume = False
            elif (uc.reg_read(UC_X86_REG_RAX) & 0xff == 0 and
                  self.r64(uc.reg_read(UC_X86_REG_RBP)-0x70) & 0xffffffff == 0):
                # Existing cleanup in the emulated CPU, preserving SKIP response.
                self.injections += 1
                self.resume = True
                self.w64(sp-8, address)
                uc.reg_write(UC_X86_REG_RSP, sp-8)
                uc.reg_write(UC_X86_REG_RCX, uc.reg_read(UC_X86_REG_R13))
                uc.reg_write(UC_X86_REG_RIP, BASE+0x19438)
                return
        if rva == 0x19438:
            self.cleanups += 1
        if rva == 0x179d:
            raise AssertionError('Payload/flash path is forbidden')
        if address == STUB+0x650:
            self.ret(CTX)
        elif address == STUB+0x538:
            handle = 0x10000 + len(self.targets)*0x100
            self.targets[handle] = {'state': 'Created', 'alias': None}
            self.w64(d, handle); self.ret()
        elif address == STUB+0x540:
            # WDF_IO_TARGET_OPEN_PARAMS.TargetDeviceName is offset 0x30.
            name = self.text(self.r64(c+0x38))
            self.targets[b].update(state='Started', alias=name)
            self.events.append({'outer_open': name}); self.ret()
        elif address == STUB+0x550:
            item = self.targets[b]
            item['state'] = 'Closed'
            self.inner[item['alias']] = False
            self.events.append({'outer_close': item['alias']}); self.ret()
        elif address == STUB+0x5d0:
            item = self.targets[b]
            if d == 0x04001c00:
                if self.inner.get(item['alias']):
                    self.events.append({'already_open': item['alias']})
                    self.ret(0xc0000184)
                else:
                    self.inner[item['alias']] = True
                    self.ret()
            elif d == 0x04001c10:
                assert self.reads, 'Unexpected extra version read'
                success, version = self.reads.pop(0)
                inp, out = self.r64(sp+0x28), self.r64(sp+0x30)
                assert self.r64(inp) & 0xffffffff == 1
                reg = bytes(uc.mem_read(self.r64(inp+8), 1))[0]
                assert reg == 1 and self.r64(out+16) & 0xffffffff == 4
                self.events.append({'version_read': {'register': reg, 'success': success, 'version': version}})
                if success: uc.mem_write(self.r64(out+8), struct.pack('>I', version))
                self.ret(0 if success else 0xc0000185)
            else:
                raise AssertionError(f'Forbidden emulated IOCTL {d:x}')
        elif rva == 0x10dc0:
            uc.mem_write(a, bytes([b & 0xff])*c); self.ret(a)
        elif rva == 0x4868:
            self.w64(b, RESPONSE); self.w64(c, RESPONSE+0x100); self.ret()
        elif rva in [0x475c, 0x4f20, 0x4c40, 0x3d96]:
            self.ret()
        elif rva == 0x3d50:
            # The real security-cookie helper preserves the caller's RAX.
            self.ret(uc.reg_read(UC_X86_REG_RAX))
        elif rva == 0x3e38:
            # __chkstk: stack is already committed in emulated memory.
            self.ret(uc.reg_read(UC_X86_REG_RAX))
        elif rva == 0x3d90:
            hay, needle = self.text(a), self.text(b)
            self.ret(a+2*hay.index(needle))
        elif rva == 0x3d9c:
            fmt, arg = self.text(c), self.text(d)
            value = fmt.replace('%s', arg).replace('%ws', arg)
            uc.mem_write(a, (value+'\0').encode('utf-16le')); self.ret(len(value))
        elif rva == 0x1c20:
            fmt = self.text(b)
            value = self.text(c) if fmt == '%ws' else fmt.replace('%02X', f'{c:02X}')
            dest = self.r64(a+8)
            raw = value.encode('utf-16le')
            uc.mem_write(dest, raw+b'\0\0'); uc.mem_write(a, struct.pack('<H', len(raw))); self.ret()
        elif address == STUB+0x1000:
            raw = self.text(b).encode('utf-16le')
            uc.mem_write(a, struct.pack('<HHIQ', len(raw), len(raw)+2, 0, b)); self.ret()
        elif address == STUB+0x1010:
            self.w32(c, int(self.text(self.r64(a+8)), b)); self.ret()
        elif rva == 0x1cb4:
            if self.cached is None: self.ret(0xc0000034)
            else: self.w32(b, self.cached); self.ret()
        elif rva == 0x1e70:
            self.events.append({'registry_version_test_double': b}); self.ret()
        elif rva == 0x201c:
            self.events.append({'registry_status_test_double': self.text(self.r64(b+8))}); self.ret()
        elif STUB <= address < STUB+0x30000:
            raise AssertionError(f'Unexpected test-double address {address:x}')

    def offer(self):
        raw = b'\x25'+bytes.fromhex('00003000020003010000000000000000')
        self.uc.mem_write(OFFER, raw)
        self.uc.mem_write(PACKET, struct.pack('<QIB3x', OFFER, len(raw), 0x25))
        self.uc.mem_write(RESPONSE, bytes(64))
        sp = STACK+0x1f008
        self.w64(sp, STOP)
        for reg, val in zip(REGS, [0xabcdef, 0x876543, 0, PACKET]): self.uc.reg_write(reg, val)
        self.uc.reg_write(UC_X86_REG_RSP, sp)
        self.uc.emu_start(BASE+0x12b0, STOP+1, count=40000)
        assert self.uc.reg_read(UC_X86_REG_RIP) == STOP, 'Instruction budget exhausted'
        reply = bytes(self.uc.mem_read(RESPONSE+4, 17))
        assert reply[0] == 0x25
        result = {'status': reply[13], 'reason': reply[9],
                  'started_outer_targets': sum(t['state']=='Started' for t in self.targets.values()),
                  'open_inner_targets': sum(self.inner.values()), 'cleanup_calls': self.cleanups}
        self.responses.append(result)
        return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--driver', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    data = args.driver.read_bytes()
    assert hashlib.sha256(data).hexdigest() == PIN, 'Unreviewed driver version'
    assert not args.output.exists(), 'Preserve existing evidence'
    image = pe_image(data)
    results = {}
    for candidate in [False, True]:
        name = 'candidate_emulated_cleanup' if candidate else 'original'
        trial = Trial(image, [(False, 0), (True, 0x01030002)], candidate)
        first, second = trial.offer(), trial.offer()
        assert first['status'] == 0, first  # CFU SKIP
        assert second['status'] == 2, second  # CFU REJECT
        assert first['started_outer_targets'] == (0 if candidate else 3), first
        assert second['started_outer_targets'] == (0 if candidate else 3), second
        assert len([e for e in trial.events if 'version_read' in e]) == (2 if candidate else 1)
        results[name] = {'responses': trial.responses, 'events': trial.events, 'cleanup_injections': trial.injections}
    for version in [0, 0xffffffff, 0x01030002, 0x01030004]:
        for candidate in [False, True]:
            trial = Trial(image, [(True, version)], candidate)
            reply = trial.offer()
            assert reply['status'] == (1 if version == 0x01030004 else 2), reply
            assert reply['started_outer_targets'] == (3 if version == 0x01030004 else 0), reply
            results[f'control_read_{version:08x}_candidate_{candidate}'] = reply
    cached = Trial(image, [], cached=0x01030002)
    assert cached.offer()['started_outer_targets'] == 0
    results['control_cached_equal'] = cached.responses
    restored = Trial(image, [(False, 0)])
    assert restored.offer() == results['original']['responses'][0]
    assert hashlib.sha256(args.driver.read_bytes()).hexdigest() == PIN
    report = {'schema': 1, 'boundary': 'Offline emulation, OS and I2C test doubles only',
              'driver_sha256': PIN, 'driver_file_changed': False, 'live_device_calls': 0,
              'candidate_is_installable_patch': False, 'original_recreated_after_candidate': True,
              'results': results}
    args.output.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'result':'Passed', 'scenarios':len(results), 'live_device_calls':0}))


if __name__ == '__main__': main()
