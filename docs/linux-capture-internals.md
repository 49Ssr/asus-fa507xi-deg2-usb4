# Linux collector: design and validation

Use the [short capture guide](linux-capture.md) for the actual procedure. This page describes the implementation and its verification limits.

## Pinned live environment

| Item | Verified value |
| --- | --- |
| Image | SystemRescue 13.02 amd64, released 1 August 2026 |
| Bytes | 1,381,629,952 |
| SHA256 | `ad4d670b72859d887c7960142a9a9d36a3e50446694a035e254442f65d6e7572` |
| Published signing key | `0FF11AF081E98345594812037091115F8320B897` |
| Kernel package | linux-lts 6.18.41-1 |
| Python package | Python 3.14.6-1 |

The SHA256 and detached signature match the publisher's files/key. Verification used an isolated local keyring; no Windows trust store changed. The stock ISO remains unchanged. A modified DVD copy was used only for the VM startup test. [Official image](https://www.system-rescue.org/Download/).

The configuration extracted from that ISO's kernel has `CONFIG_USB4=m`, `CONFIG_TYPEC_UCSI=m`, `CONFIG_UCSI_ACPI=m`, and tracing/dynamic-debug support enabled. This establishes compiled support, not successful module binding on ASUS. [Original preparation record](../evidence/linux-capture-preparation.json), [current audit](../evidence/linux-kit-audit.json).

## Capture behavior

- Default Preview performs no device access. Explicit capture requires Linux, root and the supported laptop model.
- Output requires a direct FAT boot mount, USB-storage ancestry, the marker, exact script location and matching payload hashes. Internal and read-only ISO destinations are rejected.
- Kernel logs, uevents and available USB4/UCSI/Type-C tracepoints start before the connection prompt. A private trace instance uses a monotonic clock where supported and retains per-CPU statistics.
- Snapshots preserve driver-exposed roles, identity, USB devices, router/authorization/link attributes and PCIe devices. Missing values remain unknown. Serial numbers and router keys are not deliberately collected, but raw logs can still contain private data.
- Already-connected and early-connected cases keep their timing labels. Interrupted captures retain their partial observations. A failed preparation releases its own unused lock so a corrected setup need not force another boot.
- A 45-second sampling window is followed by logger shutdown and output hashing. Each file is limited to 32 MiB. Kernel operations may add time; the window is not a hard limit on every driver read.

The collector does not authorize a router, switch a data/power role, force a mode, access raw registers, enumerate retimers, flash firmware or reboot. The operating system's normal driver/policy behavior remains part of the comparison.

## What was checked

The audit covers offline boundary tests and complete-flow simulations using fixture observations and temporary files. They include pending authorization, no host router, early attachment, interrupted preconnected history, logger-start failure, mount restoration, output manifests and source-record freshness. A harmless real child process verifies logger termination.

A headless QEMU UEFI guest booted the live environment, started the console launcher and reached the unsupported-model guard. The VM had no network, host-disk access, hardware passthrough or emulated USB4 controller. That VM trial checks startup and scope rejection only. The later [physical ASUS run](linux-asus-result.md) separately verified boot-USB saving and observed USB fallback; it did not expose the missing PD/retimer decision. A matching Dell Linux run remains uncollected.

Source hashes, test results and the VM receipt are recorded in [the audit](../evidence/linux-kit-audit.json). The older preparation record remains intact as history.

## Rebuilding the local files

`tools/linux/build_bundle.py` verifies the pinned ISO and writes only the private local bundle. It normalizes payloads to LF and generates hashes. It never selects or writes a physical USB. Copying the overlay after the stock image has been written is a separate owner-directed action.

No runtime package download is required. The first kit does not include tbtools. Its sysfs and trace records may still leave the PD/retimer decision unresolved; a successful public-file check is not hardware certification.

[Tool guide](../tools/README.md) · [Documentation index](README.md)
