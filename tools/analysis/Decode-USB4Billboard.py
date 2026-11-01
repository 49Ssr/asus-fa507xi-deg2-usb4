"""Decode saved BOS bytes; no device access or settings changes.

USB-IF Billboard 1.2.2 tables 3-7 and 3-9 define the fields. AUM VDOs
are device reports, not a recording of PD traffic. Unknown capability
types are retained only by type/length; identity fields are not printed.
"""
import argparse
import hashlib
import json
from pathlib import Path


STATES = (
    "UnspecifiedError",
    "NotAttemptedOrExited",
    "AttemptedUnsuccessfulNotEntered",
    "Successful",
)


def decode_bos(data):
    if len(data) < 5 or data[:2] != b"\x05\x0f":
        raise ValueError("Expected a five-byte BOS header")
    total = int.from_bytes(data[2:4], "little")
    if total != len(data):
        raise ValueError("BOS total length must exactly match the input")
    caps, pos = [], 5
    while pos < total:
        size = data[pos]
        if size < 3 or pos + size > total or data[pos + 1] != 0x10:
            raise ValueError("Invalid device-capability boundary")
        caps.append(data[pos:pos + size])
        pos += size
    if len(caps) != data[4]:
        raise ValueError("BOS capability count mismatch")
    billboards = [cap for cap in caps if cap[2] == 0x0d]
    if len(billboards) != 1:
        raise ValueError("Expected exactly one Billboard capability")
    bb = billboards[0]
    if len(bb) < 44:
        raise ValueError("Truncated Billboard capability")
    count, preferred = bb[4], bb[5]
    if not 1 <= count <= 52 or len(bb) != 44 + count * 4:
        raise ValueError("Invalid Billboard mode count or size")
    if preferred != 255 and preferred >= count:
        raise ValueError("Preferred mode index is out of range")
    version = int.from_bytes(bb[40:42], "little")
    if version != 0x0122:
        raise ValueError("This decoder is qualified for Billboard revision 1.2.2")
    if bb[42] & 0xfc or bb[43]:
        raise ValueError("Reserved Billboard failure bits are nonzero")
    modes = []
    for index in range(count):
        start = 44 + index * 4
        state = (bb[8 + index // 4] >> ((index % 4) * 2)) & 3
        modes.append({
            "index": index,
            "svid": f"0x{int.from_bytes(bb[start:start + 2], 'little'):04x}",
            "mode": bb[start + 2],
            "configuration_code": state,
            "configuration": STATES[state],
        })
    seen = set()
    for cap in caps:
        if cap[2] != 0x0f:
            continue
        if len(cap) != 8 or cap[3] >= count or cap[3] in seen:
            raise ValueError("Invalid or duplicate AUM capability index")
        index = cap[3]
        seen.add(index)
        word = int.from_bytes(cap[4:8], "little")
        modes[index]["reported_vdo"] = f"0x{word:08x}"
        if modes[index]["svid"] == "0xff00" and modes[index]["mode"] == 0:
            modes[index]["reported_eudo"] = {
                "usb_mode_code": (word >> 28) & 7,
                "cable_speed_code": (word >> 21) & 7,
                "cable_type_code": (word >> 19) & 3,
                "cable_current_code": (word >> 17) & 3,
                "pcie_supported": bool(word & (1 << 16)),
                "dp_supported": bool(word & (1 << 15)),
                "tbt_supported": bool(word & (1 << 14)),
                "host_present": bool(word & (1 << 13)),
            }
    # Preserve absent extensions as absent; never manufacture zero EUDOs.
    failure_valid = preferred != 255 and modes[preferred]["configuration_code"] != 3
    return {
        "schema": 1,
        "input_sha256": hashlib.sha256(data).hexdigest(),
        "bos_bytes": total,
        "capability_count": len(caps),
        "billboard_revision": "1.2.2",
        "preferred_index": preferred,
        "vconn_power_raw": f"0x{int.from_bytes(bb[6:8], 'little'):04x}",
        "additional_failure": {
            "raw": bb[42],
            "valid_for_preferred_mode": failure_valid,
            "insufficient_power_reported": bool(bb[42] & 1) if failure_valid else None,
            "no_pd_communication_reported": bool(bb[42] & 2) if failure_valid else None,
        },
        "modes": modes,
        "limits": [
            "Device-reported state; not raw PD packets or proof of freshness",
            "NotAttemptedOrExited does not distinguish those two outcomes",
            "Successful reports entry; subsequent operation can still fail",
            "Zero failure flags do not prove adequate power or fault-free PD",
            "Cable-speed code is not the host rate or measured throughput",
        ],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("inputs", nargs="+", type=Path)
    parser.add_argument("--hex", action="store_true", help="Inputs contain whitespace-separated hex bytes")
    args = parser.parse_args()
    try:
        results = []
        for path in args.inputs:
            data = bytes.fromhex(path.read_text(encoding="utf-8")) if args.hex else path.read_bytes()
            results.append(decode_bos(data))
    except (OSError, ValueError) as error:
        parser.exit(2, f"Refused: {error}\n")
    print(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
