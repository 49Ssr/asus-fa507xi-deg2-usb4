"""Run the pinned EC transaction code in RAM; EC I/O and delays are test doubles."""
import argparse
import importlib.util
import json
from pathlib import Path

spec = importlib.util.spec_from_file_location('oem_model', Path(__file__).with_name('Test-OemPdCapability.py'))
model = importlib.util.module_from_spec(spec)
spec.loader.exec_module(model)


def trial(binary, failure):
    m = model.Machine(*binary)
    params, status, cb = model.DATA, model.DATA+0x100, model.DATA+0x200
    m.uc.mem_write(params, bytes.fromhex('060500'))
    m.w64(m.base+0x5000, cb)
    m.w64(m.base+0x5008, cb)
    m.w64(cb+0x40, model.DATA+0x300)
    m.w64(m.uc.reg_read(model.UC_X86_REG_RSP)+0x28, status)
    for register, value in [(model.UC_X86_REG_RCX, 3), (model.UC_X86_REG_RDX, 0xdd), (model.UC_X86_REG_R8, params), (model.UC_X86_REG_R9, 1)]:
        m.uc.reg_write(register, value)
    messages, transfers = [], []
    response_polls = 0
    def hook(uc, address, size, context):
        nonlocal response_polls
        if address == m.base+0x1734:
            transfers.append('drain')
            m.ret(0x102 if failure == 'drain' else 0)
        elif address in (m.base+0x1bcc, m.base+0x1c4c):
            value = uc.reg_read(model.UC_X86_REG_RCX)&255
            key = ('send-' if address == m.base+0x1bcc else 'parameter-')+f'{value:02x}'
            transfers.append(key)
            m.ret(0x102 if failure == key else 0)
        elif address == m.base+0x16a4:
            transfers.append('post-command-ready')
            m.ret(0x102 if failure == 'post-command-ready' else 0)
        elif address == m.base+0x1c84:
            port = uc.reg_read(model.UC_X86_REG_RCX)&65535
            assert port in (0x25c, 0x25d), hex(port)
            if port == 0x25d:
                response_polls += 1
                m.ret(0 if failure == 'response' else 1)
            else:
                transfers.append('response-byte')
                m.ret(0x2f)
        elif address == m.base+0x1000:
            assert uc.reg_read(model.UC_X86_REG_RCX) == 100
            m.ret()  # No real wait and no timing claim.
        elif address == m.base+0x1b08:
            messages.append(uc.reg_read(model.UC_X86_REG_R9)&65535)
            m.ret()
        elif address in (m.base+0x1ccc, m.base+0x1d70):
            raise AssertionError('Unexpected access below EC test-double boundary')
    returned = m.run(0x1828, hook)&255
    actual_status = int.from_bytes(m.uc.mem_read(status, 4), 'little')
    stages = {'drain':14, 'send-ff':15, 'send-dd':16, 'parameter-06':17, 'parameter-05':17, 'parameter-00':17, 'post-command-ready':18, 'response':19}
    complete = ['drain', 'send-ff', 'send-dd', 'parameter-06', 'parameter-05', 'parameter-00', 'post-command-ready']
    if failure is None:
        assert transfers == complete+['response-byte']
        assert (returned, actual_status, messages, response_polls) == (0x2f, 0, [], 1)
    elif failure == 'response':
        assert transfers == complete*2
        assert (returned, actual_status, messages, response_polls) == (0, 0x102, [19, 19], 104)
    else:
        assert actual_status == 0x102 and returned == 0
        assert messages == [stages[failure]] and response_polls == 0
        assert transfers[-1] == failure
    return {'failure':failure, 'returnedByte':returned, 'driverTransportStatus':actual_status, 'messages':messages, 'responseStatusReads':response_polls, 'transfers':transfers}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('driver', type=Path)
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    binary = model.image(args.driver)
    cases = [trial(binary, failure) for failure in [None, 'drain', 'send-ff', 'send-dd', 'parameter-06', 'parameter-05', 'parameter-00', 'post-command-ready', 'response']]
    with args.output.open('x', encoding='utf-8') as f:
        json.dump({'scope':'Original transaction, response helper and polling code; I/O, logging and delay test doubles; no hardware or timing qualification', 'cases':cases}, f, indent=2)
    print('9 pinned EC transaction cases passed')


if __name__ == '__main__':
    main()
