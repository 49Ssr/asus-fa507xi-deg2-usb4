"""Execute a pinned AMD I2C abort-status branch offline, with seeded RAM only.

No controller registers, driver loads, device handles or live kernel interfaces.
This qualifies a status-code mapping, not the cause of a real I2C failure.
"""
import argparse
import ctypes
import hashlib
import importlib.util
import json
import struct
from pathlib import Path

from unicorn import Uc, UC_ARCH_X86, UC_MODE_64
from unicorn.x86_const import UC_X86_REG_RDI, UC_X86_REG_RBX, UC_X86_REG_RBP, UC_X86_REG_RIP

PIN = 'd12c0ef69b3c3a7284ade336404cecaaacc7029b8cdeb1891c873ee5f919fe82'
BASE, RAM = 0x140000000, 0x300000000
BEGIN, END = BASE+0x22a9, BASE+0x2395


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--driver', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    binary = args.driver.read_bytes()
    if hashlib.sha256(binary).hexdigest() != PIN:
        raise ValueError('Unreviewed AMD I2C binary')
    if args.output.exists():
        raise ValueError('Preserve existing evidence')
    spec = importlib.util.spec_from_file_location('parade_pe_loader', Path(__file__).with_name('Test-ParadeLifecycle.py'))
    loader = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(loader)
    image = loader.pe_image(binary)
    results = []
    for abort in [0, 1, 2, 4, 3, 5, 6, 7, 8, 0x1000, 0x8000]:
        for clear in [0, 1]:
            cpu = Uc(UC_ARCH_X86, UC_MODE_64)
            cpu.mem_map(BASE, (len(image)+0xfff)&~0xfff)
            cpu.mem_map(RAM, 0x10000)
            cpu.mem_write(BASE, bytes(image))
            cpu.mem_write(BASE+0xf080, struct.pack('<Q', BASE+0xf080))  # tracing disabled
            cpu.mem_write(RAM+0xa4, struct.pack('<II', abort, clear))
            cpu.reg_write(UC_X86_REG_RDI, RAM)
            cpu.reg_write(UC_X86_REG_RBX, RAM+0x1000)
            cpu.reg_write(UC_X86_REG_RBP, BASE+0xf080)
            cpu.emu_start(BEGIN, END, count=1000)
            if cpu.reg_read(UC_X86_REG_RIP) != END:
                raise AssertionError('Instruction limit exceeded or unexpected control flow')
            status = struct.unpack('<I', cpu.mem_read(RAM+0x1018,4))[0]
            expected = 0xc000000e if abort & 7 else 0 if abort & 8 else 0xc0000001
            if status != expected:
                raise AssertionError((abort, clear, hex(status), hex(expected)))
            cached = struct.unpack('<I', cpu.mem_read(RAM+0xa4,4))[0]
            if cached != (0 if clear else abort):
                raise AssertionError('Unexpected abort-cache clearing')
            results.append({'abort_mask':hex(abort),'clear_flag':clear,'native_status':f'0x{status:08X}',
                            'cached_abort_after':hex(cached)})
    status_map = ctypes.WinDLL('ntdll').RtlNtStatusToDosError
    status_map.argtypes = [ctypes.c_uint32]
    status_map.restype = ctypes.c_uint32
    translated = status_map(0xc000000e)
    if translated != 433:
        raise AssertionError('Unexpected Windows status translation')
    if hashlib.sha256(args.driver.read_bytes()).hexdigest() != PIN:
        raise AssertionError('Driver source changed')
    report = {'schema':1,'scope':'Offline original AMD driver branch with seeded abort bits',
              'driver_sha256':PIN,'entry_rva':'0x22A9','stop_rva':'0x2395',
              'hardware_register_read_into_cache_rva':'0x5EF2','cached_abort_field':'0xA4',
              'address_nack_mask':'0x7','no_such_device_status':'0xC000000E',
              'actual_windows_status_translation':translated,'cases':results,
              'device_calls':0,'driver_file_changed':False,'real_probe_raw_abort_bits_recovered':False}
    args.output.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'result':'Passed','native_branch_cases':len(results),'translated_win32':translated,'device_calls':0}))


if __name__ == '__main__':
    main()
