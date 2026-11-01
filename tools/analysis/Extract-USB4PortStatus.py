"""Replay two pinned, already-decoded captures; no tracing or device access.

Associate scalar read responses by provider/controller/buffer tag, then require
one matching root-adapter read inside the corresponding state-machine read phase.
Opaque tags and controller identifiers are not emitted in the result.
"""
import argparse
from datetime import datetime
from decimal import Decimal
import hashlib
import importlib.util
import json
from pathlib import Path
import re

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("investigation_reader", HERE / "Read-Investigation.py")
reader = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reader)
PROFILES = {
    "ASUS-DEEP": dict(sha256="75ea73f7f2eb11ce37ea11b6bc027b15b932b18e75ff0ca03cc8ce8a8bdd3158", controller="A06801", adapter=2, router_offset=0xd2),
    "DELL-DEEP": dict(sha256="6081a1c438433e96eed6b505a430e7d7677dda72ab5897416dd00be978fa3cd5", controller="4D0001", adapter=1, router_offset=0xa2),
}
TIME = re.compile(r"::(\d{2}/\d{2}/\d{4}-\d{2}:\d{2}:\d{2}\.\d+)")
HRD = re.compile(r"\[usb4hrd\]\[([^\]]+)\]\[([^\]]+)\](.*)")
RESPONSE = re.compile(r"Read Response - RS: ([0-9 ]+) , (USB4\w+ConfigurationSpace), Adapter: (\d+), DW offset: 0x([0-9A-Fa-f]+), DW length: (\d+), SN: (\d+)")
WORD = re.compile(r"DWORD\[(\d+)\]: 0x([0-9A-Fa-f]+)")
CALL = re.compile(r"Transition \(Call\): (ReadingPluggedStateForUSB4|ReadingRouterDetected) ---\(_noevent_\)---> WaitingForCompletion")
BRANCH = re.compile(r"Transition \(External\): (IsUSB4PortPlugged|IsRouterDetectedSet) ---\((Yes|No)\)---> (\w+)")


def utc(text):
    head, fraction = text.split(".")
    return datetime.strptime(head, "%m/%d/%Y-%H:%M:%S").strftime("%Y-%m-%dT%H:%M:%S") + "." + fraction + "Z"


def parse(lines, profile):
    pending, samples, phases, branches = {}, [], {}, []
    for line_number, line in enumerate(lines, 1):
        tm = TIME.search(line)
        if not tm:
            continue
        time = utc(tm[1])
        clock = reader.timestamp(time)
        hrd = HRD.search(line)
        if hrd:
            key = (hrd[1], hrd[2])
            response = RESPONSE.search(hrd[3])
            if response:
                if key in pending:
                    raise ValueError("Incomplete response replaced before its payload")
                route = tuple(int(x) for x in response[1].split())
                space, adapter, offset, length, sequence = response[2], int(response[3]), int(response[4], 16), int(response[5]), int(response[6])
                if hrd[1] == profile["controller"] and route == (0, 0, 0, 0, 0, 0) and space == "USB4AdapterConfigurationSpace" and adapter == profile["adapter"] and offset in (4, profile["router_offset"]):
                    if length != 1:
                        raise ValueError("Selected status response is not exactly one DWORD")
                    pending[key] = dict(header_line=line_number, read_response_utc=time, adapter=adapter,
                                        dword_offset=offset, sequence=sequence)
                continue
            word = WORD.search(hrd[3])
            if word and key in pending:
                if int(word[1]) != 0:
                    raise ValueError("Selected scalar response has wrong payload index")
                sample = pending.pop(key)
                sample.update(payload_line=line_number, payload_utc=time, value=int(word[2], 16))
                if sample["value"] > 0xffffffff:
                    raise ValueError("Payload is larger than a DWORD")
                samples.append(sample)
        context = f"([{profile['controller']}]::0:0:0:0:0:0::DFP_{profile['adapter']})"
        if "[usb4drd]" not in line or context not in line:
            continue
        call = CALL.search(line)
        if call:
            kind = "plugged" if call[1] == "ReadingPluggedStateForUSB4" else "router_detected"
            phases[kind] = (clock, time, line_number)
        branch = BRANCH.search(line)
        if not branch:
            continue
        kind = "plugged" if branch[1] == "IsUSB4PortPlugged" else "router_detected"
        if kind not in phases:
            raise ValueError("Selected branch has no preceding matched read phase")
        start, start_utc, start_line = phases.pop(kind)
        offset = 4 if kind == "plugged" else profile["router_offset"]
        selected = [s for s in samples if s["dword_offset"] == offset and start <= reader.timestamp(s["read_response_utc"]) <= reader.timestamp(s["payload_utc"]) <= clock]
        if len(selected) != 1:
            raise ValueError("Branch does not have exactly one matching scalar response in its read phase")
        sample = selected[0]
        mask = 0x40000000 if kind == "plugged" else 0x2000
        predicted = "Yes" if sample["value"] & mask else "No"
        if predicted != branch[2]:
            raise ValueError("Original-code mask and recorded branch disagree")
        branches.append(dict(kind=kind, read_phase_start_utc=start_utc, read_phase_line=start_line,
                             decision_utc=time, decision_line=line_number, result=branch[2], next_state=branch[3],
                             mask_hex=f"0x{mask:08x}", sample=sample,
                             response_to_decision_seconds=str(clock-reader.timestamp(sample["payload_utc"]))))
    if pending:
        raise ValueError("Incomplete selected read response")
    if not branches:
        raise ValueError("No selected branch observations")
    return dict(samples=samples, branches=branches)


def extract(path, case):
    raw = Path(path).read_bytes()
    profile = PROFILES[case]
    if hashlib.sha256(raw).hexdigest() != profile["sha256"]:
        raise ValueError("Decoded-input hash mismatch; this replay has no unpinned-input mode")
    result = parse(raw.decode("utf-8-sig").splitlines(), profile)
    return dict(case=case, input_sha256=profile["sha256"], logical_root_adapter=profile["adapter"],
                router_capability_base_dword_derived=profile["router_offset"]-0x12, **result)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("case", choices=PROFILES)
    p.add_argument("decoded_log", type=Path)
    args = p.parse_args()
    try:
        result = extract(args.decoded_log, args.case)
        print(json.dumps(result, indent=2))
    except (OSError, ValueError, KeyError) as exc:
        p.exit(2, "Port-status replay stopped: " + str(exc) + "\n")


if __name__ == "__main__":
    main()
