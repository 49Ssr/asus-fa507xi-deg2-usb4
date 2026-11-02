"""Build a local overlay for the pinned stock ISO. Never writes a USB device.

Run from any directory. The only destination is this repository's private local/
LinuxCaptureBundle directory. The stock ISO remains byte-for-byte unchanged.
"""

import hashlib
import json
from pathlib import Path
import posixpath
import re
from urllib.parse import urlsplit, urlunsplit

ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path(__file__).resolve().parent
ISO_NAME = "systemrescue-13.02-amd64.iso"
ISO_SHA256 = "ad4d670b72859d887c7960142a9a9d36a3e50446694a035e254442f65d6e7572"


def sha(path):
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(4 * 1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def portable_guide(text):
    """Keep guide links usable outside a repository checkout."""

    def replace(match):
        url = urlsplit(match[2])
        if url.scheme or url.netloc:
            return match[0]
        path = posixpath.normpath(
            posixpath.join("docs", url.path or "linux-capture.md")
        )
        if path.startswith("../") or path.startswith("local/"):
            raise RuntimeError("Guide link escapes public repository content.")
        target = urlunsplit(
            (
                "https",
                "github.com",
                "/49Ssr/asus-fa507xi-deg2-usb4/blob/main/" + path,
                url.query,
                url.fragment,
            )
        )
        return "[" + match[1] + "](" + target + ")"

    return re.sub(r"\[([^\]\n]+)\]\(([^\s)]+)\)", replace, text)


def main():
    kit = (ROOT / "local/LinuxCaptureBundle").resolve()
    if not kit.is_relative_to((ROOT / "local").resolve()):
        raise RuntimeError("Bundle destination escaped private local directory.")
    iso = kit / ISO_NAME
    if not iso.is_file() or sha(iso) != ISO_SHA256:
        raise RuntimeError("Pinned official ISO is missing or its checksum differs.")
    overlay = kit / "USB-OVERLAY"
    if not overlay.resolve().is_relative_to(kit):
        raise RuntimeError("Overlay destination escaped the prepared kit.")

    def destination(rel):
        p = overlay / rel
        if not p.resolve().is_relative_to(kit):
            raise RuntimeError("Payload destination escaped the prepared kit.")
        p.parent.mkdir(parents=True, exist_ok=True)
        return p

    files = {}
    for source, rel in [
        ("capture_usb4.py", "usb4/capture_usb4.py"),
        ("start-capture.sh", "usb4/start-capture.sh"),
        ("900-usb4-capture.yaml", "sysrescue.d/900-usb4-capture.yaml"),
    ]:
        p = destination(rel)
        p.write_bytes((SOURCE / source).read_text(encoding="utf-8").encode("utf-8"))
        files[rel] = sha(p)
    marker = destination("USB4-CAPTURE-MEDIA.txt")
    marker.write_bytes(b"USB4 research capture media v1\n")
    files[marker.name] = sha(marker)
    manifest = {
        "schema": 1,
        "iso_name": ISO_NAME,
        "iso_sha256": ISO_SHA256,
        "files": files,
    }
    destination("usb4/payload-manifest.json").write_bytes(
        (json.dumps(manifest, indent=2) + "\n").encode()
    )
    for name in ["START-HERE.md", "bundle-manifest.private.json"]:
        if not (kit / name).resolve().is_relative_to(kit):
            raise RuntimeError("Bundle output escaped the prepared kit.")
    guide = portable_guide((ROOT / "docs/linux-capture.md").read_text(encoding="utf-8"))
    (kit / "START-HERE.md").write_bytes(guide.encode("utf-8"))
    (kit / "bundle-manifest.private.json").write_bytes(
        (json.dumps(manifest, indent=2) + "\n").encode()
    )
    print(
        json.dumps(
            {
                "iso_verified": True,
                "payload_files": len(files),
                "overlay": str(overlay),
                "usb_device_writes": 0,
            }
        )
    )


if __name__ == "__main__":
    main()
