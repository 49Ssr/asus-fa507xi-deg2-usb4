"""Execute pinned original WPP serializers offline and check decoder layouts.

Requires Unicorn. The only external call is replaced by a RAM recorder sink.
No logging session, Windows device access, driver loading or hardware model.
"""
import argparse
import importlib.util
import json
import struct
from pathlib import Path

from unicorn import UC_HOOK_CODE
from unicorn.x86_const import UC_X86_REG_RCX, UC_X86_REG_RDX, UC_X86_REG_R8, UC_X86_REG_R9, UC_X86_REG_RSP


def module(name, file):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).with_name(file))
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('host_image', type=Path)
    parser.add_argument('host_pdb', type=Path)
    parser.add_argument('xhci_image', type=Path)
    parser.add_argument('xhci_pdb', type=Path)
    args = parser.parse_args()
    pdb = module('publics', 'Read-PdbPublics.py')
    gaps = module('gaps', 'Decode-USB4TraceGaps.py')
    core = module('machine', 'Test-OemPdCapability.py')
    pairs = {'host': (args.host_image, args.host_pdb), 'xhci': (args.xhci_image, args.xhci_pdb)}
    mapped = {}
    for name, (image, symbols) in pairs.items():
        info = pdb.read_pair(image, symbols)
        if info['imageSha256'] != (gaps.HOST_SHA if name == 'host' else gaps.XHCI_SHA):
            raise ValueError('Driver input pin mismatch')
        raw = image.read_bytes()
        data = bytearray(max(s['rva'] + max(s['virtualBytes'], s['fileBytes']) for s in info['sections']))
        for section in info['sections']:
            start, count, source = section['rva'], section['fileBytes'], section['fileOffset']
            data[start:start + count] = raw[source:source + count]
        mapped[name] = info['imageBase'], data
    cases = []
    definitions = [
        ('host', 0x27c8, 0x6f078, 2, 22, '<IQ', [4, 8]),
        ('xhci', 0x7c04, 0x75098, 0, 12, '<QIII', [8, 4, 4, 4]),
        ('xhci', 0x3418c, 0x75098, 1, 11, '<QIQ', [8, 4, 8]),
        ('xhci', 0x2e6a8, 0x75098, 3, 25, '<Q', [8]),
    ]
    for name, entry, iat, group, message, fmt, lengths in definitions:
        for seed in (0, 0x12345678, 0xffffffff):
            base, data = mapped[name]
            machine = core.Machine(base, data)
            machine.w64(base + iat, core.STUB)
            machine.w64(base + 0x6f350 if name == 'xhci' else core.DATA + 0x80, core.DATA + 0x100)
            sp = machine.uc.reg_read(UC_X86_REG_RSP)
            values = [seed if n == 4 else (seed << 32) | seed for n in lengths]
            captures = []
            if name == 'host':
                machine.uc.reg_write(UC_X86_REG_RDX, 0)  # ETW disabled.
                machine.uc.reg_write(UC_X86_REG_R8, 1)   # RAM recorder enabled.
                for offset, value in ((0x28, 5), (0x30, 10), (0x38, message), (0x40, base + 0x61818)):
                    machine.w64(sp + offset, value)
                first = 0x48
            else:
                machine.uc.reg_write(UC_X86_REG_RCX, core.DATA + 0x800)
                machine.uc.reg_write(UC_X86_REG_RDX, 4)
                machine.uc.reg_write(UC_X86_REG_R8, 17 if group == 0 else 8)
                machine.uc.reg_write(UC_X86_REG_R9, message)
                machine.w64(sp + 0x28, base + {0: 0x5e5b8, 1: 0x5ebf8, 3: 0x5ea78}[group])
                first = 0x30
            for i, value in enumerate(values):
                machine.w64(sp + first + 8 * i, value)

            def hook(uc, address, size, _):
                if address == core.STUB:
                    stack = uc.reg_read(UC_X86_REG_RSP)
                    payload, sizes = b'', []
                    assert machine.r64(stack + 0x28) & 0xffff == message
                    for i in range(10):
                        pointer = machine.r64(stack + 0x30 + 16 * i)
                        if not pointer:
                            break
                        length = machine.r64(stack + 0x38 + 16 * i)
                        assert length in (4, 8)
                        sizes.append(length)
                        payload += bytes(uc.mem_read(pointer, length))
                    assert sizes == lengths
                    captures.append(payload)
                    machine.ret(0)
            machine.uc.hook_add(UC_HOOK_CODE, hook)
            machine.uc.emu_start(base + entry, core.STOP, count=10000)
            expected = struct.pack(fmt, *values)
            assert captures == [expected]
            row = gaps.decode({'group': group, 'id': message, 'bytes': len(expected), 'payload': expected.hex()})
            assert list(row['fields'].values()) == values
            cases.append({'driver': name, 'entryRva': hex(entry), 'group': group, 'message': message,
                          'seed': seed, 'fieldBytes': lengths, 'payloadBytes': len(expected)})
    rejected = 0
    for (group, message), (fmt, _, _) in gaps.LAYOUTS.items():
        for delta in (-1, 1):
            length = struct.calcsize(fmt) + delta
            try:
                gaps.decode({'group': group, 'id': message, 'bytes': length, 'payload': '00' * length})
            except ValueError:
                rejected += 1
            else:
                raise AssertionError('Malformed payload was accepted')
    try:
        gaps.decode({'group': 9, 'id': 9, 'bytes': 0, 'payload': ''})
    except ValueError:
        pass
    else:
        raise AssertionError('Unreviewed type was accepted')
    print(json.dumps({'scope': 'Original serialization instructions; external logging sink doubled in RAM',
                      'passed': len(cases), 'malformedPayloadsRejected': rejected,
                      'unreviewedTypeRejected': True, 'cases': cases}, indent=2))


if __name__ == '__main__':
    main()
