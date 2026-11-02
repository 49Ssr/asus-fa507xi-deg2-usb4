# Tool guide

There is no working repair tool. The current kit observes a connection and preserves evidence. Most older scripts are specific experiments retained for review.

## Current Linux observation

Read [the capture guide](../docs/linux-capture.md) before preparing media. The signed stock ISO and generated overlay remain local; binaries are not distributed through this repository.

| File | Purpose |
| --- | --- |
| [capture_usb4.py](linux/capture_usb4.py) | Preview by default; explicit capture records topology/roles/logs on the prepared live USB |
| [build_bundle.py](linux/build_bundle.py) | Verifies the pinned ISO and builds the private overlay; never writes a physical USB |
| [start-capture.sh](linux/start-capture.sh), [console configuration](linux/900-usb4-capture.yaml) | Start the collector on the live console |
| [test_capture_usb4.py](linux/test_capture_usb4.py) | Offline boundary and capture-flow checks; no real device/mount operations |

Startup/model rejection was checked in a VM. The later [ASUS hardware run](../docs/linux-asus-result.md) booted and saved its capture to USB, reproducing USB fallback without an observed external router. A matching Dell Linux capture remains uncollected. The collector does not authorize PCIe devices, change roles/modes, scan retimers, flash firmware or reboot.

## Windows readers already used

| Tool | What it reads | Status |
| --- | --- | --- |
| [Read-USB4FirmwareSettings.ps1](Read-USB4FirmwareSettings.ps1) | Two exact BIOS314 variables | Read completed; stored USB4/TBT3 fields enabled. [Result](../evidence/firmware-settings-read.json) |
| [Read-DEG2BillboardStrings.ps1](Read-DEG2BillboardStrings.ps1) | Standard descriptors through the existing USB hub driver | Read completed on one verified binding. [Result](../evidence/billboard-strings-result.json) |

These readers do not expose the physical PD exchange or applied retimer state. Repeating them unchanged is not the next test.

## Offline evidence checks

Run these from the repository root using Python 3.12 or later. They read public files and run fixtures; they do not install drivers or access hardware.

```text
python tools/analysis/Run-Investigation.py --check
python tools/analysis/Test-Investigation.py
python tools/analysis/Test-InvestigationAutomation.py
python tools/linux/test_capture_usb4.py
python tools/analysis/Check-Docs.py
```

The runner validates source/case relationships and regenerates reports when invoked without `--check`. A successful check means the public record is internally consistent, not that a fix works or private captures were independently decoded.

## Earlier experiments

Windows VHDX preparation, UCSI role/mode experiments, test signing and the policy filter belong to completed or inconclusive investigations. Their source is preserved. Use [experiment results](../docs/experiments.md) and the [dated procedures](../docs/history.md) to understand them; no new driver installation or test boot is selected from those pages.

[Current findings](../docs/status.md) · [Documentation index](../docs/README.md)
