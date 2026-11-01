"""Decode four missing WPP record types from the pinned captured Windows drivers.

Labels are analyst interpretations, not recovered Microsoft message strings.
Input/output contain private pointers. Never publish the decoded record list.
"""
import argparse
import collections
import datetime
import hashlib
import importlib.util
import json
import struct
from pathlib import Path

HOST_SHA = '912efbfca273c62484db952632eeb0d2b061bd7a1c830970fda23cdb50beeb1f'
XHCI_SHA = '689af40dff3f9ae809e459100a697cdd6c45264baadc1ec255b0a53e27021cec'
XHCI_PDB_SHA = 'd1d6eec43e6b383c86962bd28485a1c8abc63c7b66fcdeed5e704b9f76cb6309'
LAYOUTS = {
    (0, 12): ('<QIII', 'USB endpoint state transition', ['endpoint_context', 'state_before', 'trigger_id', 'state_after']),
    (1, 11): ('<QIQ', 'USB device-slot context installed', ['slot_context', 'slot_id', 'device_context_address']),
    (2, 22): ('<IQ', 'Timing-policy branch without a policy change', ['logging_prefix', 'policy_context']),
    (2, 15): ('<IQQI', 'Known control: router minimum timing requirement', ['logging_prefix', 'policy_context', 'router_handle', 'minimum_mode']),
    (3, 25): ('<Q', 'USB common-buffer unused-resource cleanup', ['buffer_address']),
}


def decode(row):
    key = row['group'], row['id']
    if key not in LAYOUTS:
        raise ValueError('Unreviewed message type')
    fmt, label, names = LAYOUTS[key]
    data = bytes.fromhex(row['payload'])
    if row['bytes'] != len(data) or len(data) != struct.calcsize(fmt):
        raise ValueError('Payload length does not match original serializer')
    return {**row, 'label_source': 'Analyst; original text unavailable for missing types',
            'interpretation': label, 'fields': dict(zip(names, struct.unpack(fmt, data)))}


def state_handlers(image, pdb):
    spec = importlib.util.spec_from_file_location('pdb_publics', Path(__file__).with_name('Read-PdbPublics.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    info = module.read_pair(image, pdb)
    if info['imageSha256'] != XHCI_SHA or info['pdbSha256'] != XHCI_PDB_SHA:
        raise ValueError('Unreviewed state-table input')
    raw = image.read_bytes()
    mapped = bytearray(max(s['rva'] + max(s['virtualBytes'], s['fileBytes']) for s in info['sections']))
    for section in info['sections']:
        start, count, source = section['rva'], section['fileBytes'], section['fileOffset']
        mapped[start:start + count] = raw[source:source + count]
    symbols = collections.defaultdict(list)
    for symbol in info['symbols']:
        symbols[symbol['rva']].append(symbol['name'])
    table = next(s['rva'] for s in info['symbols'] if s['name'] == 'ESMStateTable')

    def lookup(state):
        # Base2000 and descriptor entry-function offset8 are taken from the
        # original ESM dispatcher. Only observed IDs in this pinned table are used.
        if not 2000 <= state <= 2059:
            return []
        descriptor = struct.unpack_from('<Q', mapped, table + 8 * (state - 2000))[0] - info['imageBase']
        handler = struct.unpack_from('<Q', mapped, descriptor + 8)[0] - info['imageBase']
        # Several state names share one compiled function. Preserve ALL aliases.
        return symbols[handler]
    return lookup


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('raw_jsonl', type=Path)
    parser.add_argument('host_image', type=Path)
    parser.add_argument('xhci_image', type=Path)
    parser.add_argument('xhci_pdb', type=Path)
    args = parser.parse_args()
    for path, pin in ((args.host_image, HOST_SHA), (args.xhci_image, XHCI_SHA)):
        if hashlib.sha256(path.read_bytes()).hexdigest() != pin:
            parser.error('Driver input pin mismatch')
    lookup = state_handlers(args.xhci_image, args.xhci_pdb)
    rows = [decode(json.loads(line)) for line in args.raw_jsonl.read_text().splitlines() if line.strip()]
    counts = collections.Counter((r['group'], r['id']) for r in rows)
    if dict(counts) != {(0, 12): 331, (1, 11): 7, (2, 22): 2, (2, 15): 2, (3, 25): 2}:
        parser.error('This decoder requires the complete saved ASUS gap extraction, including two known controls')
    contexts = {}
    for row in rows:
        seconds, fraction = divmod(row['timestamp100ns'], 10000000)
        time = datetime.datetime(1601, 1, 1, tzinfo=datetime.timezone.utc) + datetime.timedelta(seconds=seconds)
        row['utc'] = time.strftime('%Y-%m-%dT%H:%M:%S') + f'.{fraction:07d}Z'
        if row['group'] == 0:
            value = row['fields']['endpoint_context']
            row['local_context_alias'] = contexts.setdefault(value, f'endpoint-{len(contexts) + 1}')
            for field in ('state_before', 'state_after'):
                row[field + '_handler_aliases'] = lookup(row['fields'][field])
    print(json.dumps({'scope': 'Offline decoding of saved payloads; labels inferred from pinned original instructions',
                      'unknown_records_decoded': 342, 'known_control_records': 2,
                      'endpoint_contexts': len(contexts), 'records': rows}, indent=2))


if __name__ == '__main__':
    main()
