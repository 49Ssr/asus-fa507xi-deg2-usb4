"""Extract the exact BIOS314 EC package image offline; never access hardware.

Outputs contain vendor firmware and must remain private. This is not a flash
backup: the running machine's physical EC contents have not been read back.
"""
import argparse
import hashlib
import json
from pathlib import Path

CAPSULE_SHA256 = "a72291441a378a38a1aa7d5198c4aeb91aed07f787a3025435393719351f4ed1"
EC_SHA256 = "103721578b66daed81dcf7a0bed06709c072f9da1dc75a6d7887321e6e32b060"
EC_OFFSET = 0x81800
EC_LENGTH = 0x40000


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("capsule", type=Path)
    parser.add_argument("private_output", type=Path, help="new directory; existing directories are refused")
    args = parser.parse_args()
    capsule = args.capsule.read_bytes()
    if len(capsule) != 33556480 or hashlib.sha256(capsule).hexdigest() != CAPSULE_SHA256:
        parser.error("exact ASUS BIOS314 capsule pin mismatch")
    ec = capsule[EC_OFFSET:EC_OFFSET + EC_LENGTH]
    if len(ec) != EC_LENGTH or hashlib.sha256(ec).hexdigest() != EC_SHA256:
        parser.error("EC extraction pin mismatch")
    outputs = {"ec-main-full.bin": ec}
    for bank in range(1, 8):
        outputs[f"ec-full-bank{bank}.bin"] = ec[:0x8000] + ec[bank * 0x8000:(bank + 1) * 0x8000]
    manifest = {
        "scope": "Offline BIOS package extraction; not live EC flash readback or a qualified rollback image",
        "capsuleSha256": CAPSULE_SHA256,
        "capsuleOffset": EC_OFFSET,
        "files": [{"file": name, "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}
                  for name, data in outputs.items()],
    }
    try:
        args.private_output.mkdir(parents=True, exist_ok=False)
    except FileExistsError:
        parser.error("output directory already exists; originals will not be overwritten")
    for name, data in outputs.items():
        with (args.private_output / name).open("xb") as stream:
            stream.write(data)
    with (args.private_output / "extraction.private.json").open("x", encoding="utf-8") as stream:
        json.dump(manifest, stream, indent=2)
        stream.write("\n")
    print(json.dumps({"result": "ExtractedOffline", "files": len(outputs), "ecSha256": EC_SHA256}))


if __name__ == "__main__":
    main()
