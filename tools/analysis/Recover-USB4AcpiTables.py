"""Recover cached AML tables from saved offline WinDbg text, without device access.

Plan: turn saved !acpicache output into db commands for an already existing dump.
Extract: validate the saved db output and write private table copies.
Raw tables, command plans and indexes must remain private.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re


ENTRY = re.compile(r"^\s+(SSDT|DSDT) @\(([0-9a-fA-F]{16})\) Rev: 0x[0-9a-fA-F]+ Len: 0x([0-9a-fA-F]+) TableID: ([\w ]+)\r?$", re.M)
PROMPT = r"\d+:\s*kd>\s*"


def inventory(text):
    # Ignore subsequent debugger commands rather than accepting a second list.
    start = re.search(PROMPT + r"!acpicache(?:\s+[01])?\s*\r?\n", text)
    if start:
        text = re.split(PROMPT, text[start.end():], maxsplit=1)[0]
    tables = []
    for signature, address, length, name in ENTRY.findall(text):
        size = int(length, 16)
        if not address.lower().startswith("ffff") or not 36 <= size <= 1024 * 1024:
            raise ValueError("Invalid cached table address or size")
        name = name.strip()
        if not re.fullmatch(r"[A-Za-z0-9_ ]{1,8}", name):
            raise ValueError("Unsafe table identifier")
        if any(t["address"] == address.lower() for t in tables):
            raise ValueError("Duplicate cached address")
        tables.append({"signature": signature, "address": address.lower(), "bytes": size,
                       "table_id": name, "file": f"{len(tables):02d}-{signature}-{name}.bin"})
    if not tables or len(tables) > 128 or sum(t["bytes"] for t in tables) > 16 * 1024 * 1024:
        raise ValueError("Missing or excessive cached table inventory")
    return tables


def plan(tables):
    return "\n".join([f'db {t["address"]} L{t["bytes"]:x}' for t in tables] + ["q"]) + "\n"


def extract(tables, text):
    commands = list(re.finditer(PROMPT + r"db ([0-9a-fA-F]+) L([0-9a-fA-F]+)\s*\r?\n", text))
    if len(commands) != len(tables):
        raise ValueError("Readout command count does not match inventory")
    recovered = []
    for i, (table, command) in enumerate(zip(tables, commands)):
        if int(command[1], 16) != int(table["address"], 16) or int(command[2], 16) != table["bytes"]:
            raise ValueError("Readout command does not match the planned range")
        section = text[command.end():commands[i + 1].start() if i + 1 < len(commands) else len(text)]
        section = re.split(PROMPT, section, maxsplit=1)[0]
        data = bytearray()
        for line in section.splitlines():
            row = re.match(r"^([0-9a-fA-F]{8})`([0-9a-fA-F]{8})  (.{1,48})", line)
            if not row:
                continue
            if int(row[1] + row[2], 16) != int(table["address"], 16) + len(data):
                raise ValueError("Discontinuous memory readout")
            for token in row[3].replace("-", " ").split():
                if not re.fullmatch(r"[0-9a-fA-F]{2}", token):
                    raise ValueError("Unreadable byte; no zero substitution is allowed")
                data.append(int(token, 16))
            if len(data) > table["bytes"]:
                raise ValueError("Extra bytes outside the planned range")
        if len(data) != table["bytes"]:
            raise ValueError("Incomplete cached table")
        if data[:4] != table["signature"].encode() or int.from_bytes(data[4:8], "little") != len(data):
            raise ValueError("Table header differs from cache inventory")
        if sum(data) % 256:
            raise ValueError("ACPI checksum failed; preserve the original readout for review")
        recovered.append(({**table, "sha256": hashlib.sha256(data).hexdigest(), "checksum_valid": True}, bytes(data)))
    return recovered


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("plan", "extract"))
    parser.add_argument("--cache", type=Path, required=True)
    parser.add_argument("--readout", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        tables = inventory(args.cache.read_text(encoding="utf-8-sig", errors="replace"))
        if args.mode == "plan":
            with args.output.open("x", encoding="ascii") as stream:
                stream.write(plan(tables))
        else:
            if args.readout is None:
                raise ValueError("Extract requires --readout")
            recovered = extract(tables, args.readout.read_text(encoding="utf-8-sig", errors="replace"))
            args.output.mkdir(parents=True, exist_ok=False)
            for meta, data in recovered:
                (args.output / meta["file"]).write_bytes(data)
            index = {"schema": 1, "cache_log_sha256": hashlib.sha256(args.cache.read_bytes()).hexdigest(),
                     "readout_sha256": hashlib.sha256(args.readout.read_bytes()).hexdigest(),
                     "tables": [meta for meta, _ in recovered]}
            (args.output / "index.private.json").write_text(json.dumps(index, indent=2) + "\n", encoding="utf-8")
    except (OSError, ValueError) as error:
        parser.exit(2, f"Refused: {error}\n")
    print(json.dumps({"mode": args.mode, "tables": len(tables), "bytes": sum(t["bytes"] for t in tables), "device_access": False}))


if __name__ == "__main__":
    main()
