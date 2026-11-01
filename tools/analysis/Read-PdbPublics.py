"""Read public symbol addresses from a matching local PE/PDB pair, offline.

No driver loading, device access or symbol downloading. Output from private
inputs stays private. Layout references: LLVM MSFCommon.h and PDB RawTypes.h.
"""
import argparse
import hashlib
import json
import re
import struct
import uuid
from pathlib import Path


def u16(data, offset):
    return struct.unpack_from('<H', data, offset)[0]


def u32(data, offset):
    return struct.unpack_from('<I', data, offset)[0]


def pdb_streams(data):
    if not data.startswith(b'Microsoft C/C++ MSF 7.00\r\n\x1aDS\0\0\0'):
        raise ValueError('Expected MSF7 PDB')
    page_size, _, page_count, directory_size, _, block_map = struct.unpack_from('<6I', data, 32)
    if page_size not in (512, 1024, 2048, 4096, 8192, 16384, 32768) or page_count * page_size != len(data):
        raise ValueError('Invalid PDB page geometry')
    count = (directory_size + page_size - 1) // page_size
    if count * 4 > page_size:
        raise ValueError('Multi-page directory block map is outside this reader')

    def pages(indices, size):
        if any(i >= page_count for i in indices):
            raise ValueError('PDB page outside input')
        return b''.join(data[i * page_size:(i + 1) * page_size] for i in indices)[:size]

    indices = struct.unpack_from('<' + 'I' * count, data, block_map * page_size)
    directory = pages(indices, directory_size)
    streams = u32(directory, 0)
    if streams > 100000:
        raise ValueError('Too many PDB streams')
    sizes = struct.unpack_from('<' + 'I' * streams, directory, 4)
    cursor, result = 4 + streams * 4, []
    for size in sizes:
        if size == 0xffffffff:
            result.append(None)
            continue
        if size > len(data):
            raise ValueError('PDB stream larger than input')
        count = (size + page_size - 1) // page_size
        indices = struct.unpack_from('<' + 'I' * count, directory, cursor)
        cursor += count * 4
        result.append(pages(indices, size))
    if cursor != len(directory):
        raise ValueError('Unconsumed PDB directory bytes')
    return result


def read_pair(image, pdb):
    raw, debug = image.read_bytes(), pdb.read_bytes()
    nt = u32(raw, 0x3c)
    if raw[:2] != b'MZ' or raw[nt:nt + 4] != b'PE\0\0' or u16(raw, nt + 24) != 0x20b:
        raise ValueError('Expected PE64')
    optional = nt + 24
    section_table = optional + u16(raw, nt + 20)
    sections = []
    for i in range(u16(raw, nt + 6)):
        offset = section_table + 40 * i
        size, rva, raw_size, file_offset = struct.unpack_from('<4I', raw, offset + 8)
        sections.append((rva, size, file_offset, raw_size))

    def file_offset(rva):
        for start, size, offset, raw_size in sections:
            if start <= rva < start + max(size, raw_size):
                if rva - start >= raw_size:
                    raise ValueError('RVA has no file backing')
                return offset + rva - start
        raise ValueError('Unmapped RVA')

    debug_rva, debug_size = struct.unpack_from('<II', raw, optional + 112 + 6 * 8)
    offset, rsds = file_offset(debug_rva), []
    if debug_size % 28:
        raise ValueError('Invalid PE debug directory')
    for i in range(debug_size // 28):
        entry = offset + 28 * i
        if u32(raw, entry + 12) == 2:
            start, length = u32(raw, entry + 24), u32(raw, entry + 16)
            record = raw[start:start + length]
            if record.startswith(b'RSDS'):
                rsds.append((record[4:20], u32(record, 20)))
    if len(rsds) != 1:
        raise ValueError('Expected one RSDS identity')
    streams = pdb_streams(debug)
    info, dbi = streams[1], streams[3]
    info_age, dbi_age = u32(info, 8), u32(dbi, 8)
    stripped = bool(u16(dbi, 56) & 2)
    # These Microsoft public PDBs have Info age4, DBI age1 and PE age1.
    # Preserve that distinction; allow the higher Info age only for a stripped
    # PDB with the exact GUID and DBI age. Reports must not call all ages equal.
    if info[12:28] != rsds[0][0] or dbi_age != rsds[0][1] or (info_age != dbi_age and not (stripped and info_age > dbi_age)):
        raise ValueError('PDB GUID/age does not match PE')
    records = streams[u16(dbi, 20)]
    symbols, cursor = [], 0
    while cursor < len(records):
        length, kind = struct.unpack_from('<HH', records, cursor)
        end = cursor + length + 2
        if length < 2 or end > len(records):
            raise ValueError('Invalid symbol record length')
        if kind == 0x110e:  # S_PUB32: flags, offset, section, NUL-terminated name.
            flags, address, section = struct.unpack_from('<IIH', records, cursor + 4)
            name = records[cursor + 14:end].split(b'\0', 1)[0].decode('utf-8')
            if section and section <= len(sections):
                symbols.append({'name': name, 'rva': sections[section - 1][0] + address, 'flags': flags})
        cursor = end
    return {
        'imageSha256': hashlib.sha256(raw).hexdigest(),
        'pdbSha256': hashlib.sha256(debug).hexdigest(),
        'pdbGuid': str(uuid.UUID(bytes_le=rsds[0][0])), 'pdbAge': rsds[0][1],
        'peGuidAndDbiAgeMatched': True, 'infoAge': info_age,
        'dbiAge': dbi_age, 'stripped': stripped,
        'allAgesEqual': info_age == dbi_age, 'symbols': symbols,
        'imageBase': struct.unpack_from('<Q', raw, optional + 24)[0],
        'sections': [{'rva': r, 'virtualBytes': v, 'fileOffset': f, 'fileBytes': n}
                     for r, v, f, n in sections],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('image', type=Path)
    parser.add_argument('pdb', type=Path)
    parser.add_argument('--match', default='.')
    args = parser.parse_args()
    result = read_pair(args.image, args.pdb)
    pattern = re.compile(args.match)
    result['symbols'] = [s for s in result['symbols'] if pattern.search(s['name'])]
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
