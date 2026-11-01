"""Offline qualification of the pinned ASUS WPP callback. No device APIs."""
import argparse
import importlib.util
import json
import struct
from pathlib import Path

spec = importlib.util.spec_from_file_location('oem_model', Path(__file__).with_name('Test-OemPdCapability.py'))
model = importlib.util.module_from_spec(spec)
spec.loader.exec_module(model)


def trial(binary, control, flags):
    m = model.Machine(*binary)
    cb, info = model.DATA, model.DATA+0x100
    original = b'\x5a'*0x80
    m.uc.mem_write(cb, original)
    # The callback receives the native packed WMI trace context.
    trace = struct.pack('<HBBI', 0x5432, 5, 0, flags)
    m.uc.mem_write(info, trace)
    m.w64(m.base+0x5000, cb)
    m.w64(m.base+0x4018, model.STUB+0x10)  # imp_WppRecorderReplay
    for register, value in [(model.UC_X86_REG_RDX, control), (model.UC_X86_REG_R8, info), (model.UC_X86_REG_R9, cb)]:
        m.uc.reg_write(register, value)
    def hook(uc, address, size, context):
        if address == model.STUB+0x10:
            args = [uc.reg_read(r) for r in [model.UC_X86_REG_RCX, model.UC_X86_REG_RDX, model.UC_X86_REG_R8, model.UC_X86_REG_R9]]
            assert args[:3] == [cb, int.from_bytes(trace, 'little'), flags]
            assert args[3]&255 == 5
            m.calls.append('WppRecorderReplay')
            m.ret()
    m.run(0x1660, hook)
    actual = bytes(m.uc.mem_read(cb, 0x80))
    expected = bytearray(original)
    if control in (0, 1):
        expected[0x18:0x20] = trace if control else bytes(8)
        expected[0x29] = 5 if control else 0
        expected[0x2c:0x30] = struct.pack('<I', flags) if control else bytes(4)
    assert actual == bytes(expected)
    assert m.calls == (['WppRecorderReplay'] if control == 1 else [])
    return {'kind': 'oem-callback', 'control': control, 'flags': flags, 'calls': m.calls, 'firmware_protocol_function_called': False, 'changed_offsets': [i for i in range(0x80) if actual[i] != original[i]]}


def replay_gate(binary, flags):
    m = model.Machine(*binary)
    m.uc.reg_write(model.UC_X86_REG_R8, flags)
    outcome = []
    def hook(uc, address, size, context):
        if address in (m.base+0x19cd, m.base+0x1c85):
            outcome.append(address == m.base+0x19cd)
            uc.reg_write(model.UC_X86_REG_RIP, model.STOP)
    m.run(0x19c0, hook)
    assert outcome == [flags == 0x40000000]
    return {'kind': 'installed-recorder-entry-gate', 'flags': flags, 'entersReplay': outcome[0], 'boundary': 'Stops immediately after flags check; replay internals not executed'}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('driver', type=Path)
    p.add_argument('recorder', type=Path)
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    binary = model.image(args.driver)
    results = [trial(binary, control, flags) for flags in [0xffffffff, 0x40000000] for control in [0, 1, 2]]
    model.PINS['WppRecorder.sys'] = '8a9b253d4d45200b1f9362d3769aa63a1e01d12351f243524ff212f595a1ced4'
    recorder = model.image(args.recorder)
    results += [replay_gate(recorder, flags) for flags in [0, 2, 0x40000000, 0x40000002, 0xffffffff]]
    with args.output.open('x', encoding='utf-8') as f:
        json.dump({'scope': 'Original OEM callback with recorder test double, plus installed recorder entry gate; no hardware or full replay emulation', 'cases': results}, f, indent=2)
    print('11 original-code cases passed; recorder replay requires flags exactly 0x40000000')


if __name__ == '__main__':
    main()
