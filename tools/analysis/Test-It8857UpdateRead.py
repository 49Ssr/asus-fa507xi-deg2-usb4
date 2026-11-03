"""Execute the pinned updater's parameter reader in RAM, with no device access.

Requires Unicorn 2.1.4 and the original privately held PDUTC101.efi.
Only the original function at RVA 3778 executes. Its I2C and print callees
are simulated; any other execution address fails closed. This tests the
program's error handling and conditional write, not controller semantics.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import sys

PIN = "ea3531946ef9f0aabdb94e7ef69d79d60beb466a16c6a5d1602ae609382970d3"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("image", type=Path)
    parser.add_argument("--deps", type=Path)
    args = parser.parse_args()
    if args.deps:
        sys.path.insert(0, str(args.deps))
    from unicorn import Uc, UC_ARCH_X86, UC_MODE_64, UC_HOOK_CODE
    from unicorn.x86_const import (UC_X86_REG_RIP, UC_X86_REG_RSP,
        UC_X86_REG_RCX, UC_X86_REG_RDX, UC_X86_REG_R8,
        UC_X86_REG_R9, UC_X86_REG_RAX)

    raw = args.image.read_bytes()
    if hashlib.sha256(raw).hexdigest() != PIN:
        raise ValueError("Original image hash does not match")
    pe = struct.unpack_from("<I", raw, 60)[0]
    opt = pe + 24
    count = struct.unpack_from("<H", raw, pe + 6)[0]
    optlen = struct.unpack_from("<H", raw, pe + 20)[0]
    if struct.unpack_from("<Q", raw, opt + 24)[0] != 0:
        raise ValueError("Unexpected image base")
    sections = [struct.unpack_from("<IIII", raw, opt + optlen + 40*i + 8)
                for i in range(count)]
    rows = []
    cases = [
        ("zero first byte", bytes.fromhex("001122334455"), 0, False, 0),
        ("nonzero first byte", bytes.fromhex("011122334455"), 0, False, 1),
        ("failed read leaves zero buffer", None, 1, False, 0),
        ("failed read with partial data", bytes.fromhex("011122334455"), 1, False, 1),
        ("poll remains nonzero", bytes.fromhex("011122334455"), 0, True, 1),
    ]
    for name, supplied, status, busy, expected_writes in cases:
        uc = Uc(UC_ARCH_X86, UC_MODE_64)
        uc.mem_map(0, 0x20000)
        for _, va, size, offset in sections:
            uc.mem_write(va, raw[offset:offset+size])
        uc.mem_map(0x100000, 0x10000)
        uc.mem_write(0x169c0, b"\x80")
        sp = 0x108008
        uc.mem_write(sp, struct.pack("<Q", 0x1f000))
        uc.reg_write(UC_X86_REG_RSP, sp)
        calls, writes = [], []

        def hook(em, address, size, _):
            if address == 0x1f000:
                em.emu_stop()
                return
            if 0x3778 <= address < 0x387c:
                return
            if address not in (0x30e0, 0x3298, 0x1558):
                raise RuntimeError("Unexpected callee: " + hex(address))
            rsp = em.reg_read(UC_X86_REG_RSP)
            if address == 0x30e0:
                target = em.reg_read(UC_X86_REG_RCX) & 255
                selector_len = em.reg_read(UC_X86_REG_R8) & 255
                selector = bytes(em.mem_read(em.reg_read(UC_X86_REG_RDX), selector_len))
                length = struct.unpack("<H", em.mem_read(rsp+0x28, 2))[0]
                destination = em.reg_read(UC_X86_REG_R9)
                calls.append((target, selector.hex(), length))
                if selector == b"\xa0":
                    assert target == 0x80 and length == 6 and len(calls) == 1
                    if supplied is not None:
                        em.mem_write(destination, supplied)
                    em.reg_write(UC_X86_REG_RAX, status)
                else:
                    assert target == 0x80 and selector == b"\x1e" and length == 1
                    em.mem_write(destination, b"\x01" if busy else b"\x00")
                    em.reg_write(UC_X86_REG_RAX, 0)
            elif address == 0x3298:
                n = em.reg_read(UC_X86_REG_RDX) & 255
                writes.append(bytes(em.mem_read(em.reg_read(UC_X86_REG_R8), n)).hex())
                em.reg_write(UC_X86_REG_RAX, 0)
            else:
                em.reg_write(UC_X86_REG_RAX, 0)
            ret = struct.unpack("<Q", em.mem_read(rsp, 8))[0]
            em.reg_write(UC_X86_REG_RSP, rsp+8)
            em.reg_write(UC_X86_REG_RIP, ret)

        uc.hook_add(UC_HOOK_CODE, hook)
        uc.emu_start(0x3778, 0x1ffff, count=10000)
        assert uc.reg_read(UC_X86_REG_RIP) == 0x1f000, "Function did not return"
        saved = bytes(uc.mem_read(0x165a0, 6))
        assert saved == (supplied if supplied is not None else bytes(6))
        assert writes == ["1e01"] * expected_writes
        assert len(calls) == (7 if busy else 2 if expected_writes else 1)
        rows.append(dict(case=name, initial_status=status, saved=saved.hex(),
                         simulated_reads=len(calls), simulated_writes=writes))
    print(json.dumps(dict(scope="Original updater instructions with RAM-only I2C fixtures",
        cases=rows, actual_device_requests=0, actual_pd_state_obtained=False), indent=2))


if __name__ == "__main__":
    main()
