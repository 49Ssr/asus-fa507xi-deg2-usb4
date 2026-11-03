# Tools

There is no working repair tool. This repository contains a Linux observer, Windows readers already used in the investigation, offline analysis, and older experiments.

## Linux observer

The [ASUS run](../docs/linux-asus-result.md) booted and saved a capture to USB. It reproduced ordinary USB fallback without an external router. A matching Dell Linux capture is unavailable. Repeating the same ASUS run would not expose the missing PD exchange.

| File | Purpose |
| --- | --- |
| [capture_usb4.py](linux/capture_usb4.py) | Previews by default; explicit capture records topology, roles and logs on the prepared USB |
| [build_bundle.py](linux/build_bundle.py) | Verifies the pinned ISO and builds the local overlay; does not write a physical USB |
| [start-capture.sh](linux/start-capture.sh), [console configuration](linux/900-usb4-capture.yaml) | Launch the collector on the live console |
| [test_capture_usb4.py](linux/test_capture_usb4.py) | Offline checks using fixtures; no real device or mount operations |

Read the [capture guide](../docs/linux-capture.md) before preparing media. The ISO and overlay are not distributed in the repository. The collector does not authorize PCIe devices, change roles, scan retimers, flash firmware or reboot.

## Windows readers

| Tool | Result already obtained |
| --- | --- |
| [Read-USB4FirmwareSettings.ps1](Read-USB4FirmwareSettings.ps1) | Read two BIOS 314 variables; stored USB4/TBT3 settings are enabled. [Evidence](../evidence/firmware-settings-read.json) |
| [Read-DEG2BillboardStrings.ps1](Read-DEG2BillboardStrings.ps1) | Read standard descriptors on the identified device. [Evidence](../evidence/billboard-strings-result.json) |

Neither reader exposes the physical PD exchange or applied retimer state. The private [PD version read](../docs/pd-firmware-version.md) returned cached bytes 00 53 through the existing ASUS driver. Its hardware runner is not distributed as a general-purpose tool.

## Offline checks

Run from the repository root with Python 3.12 or later:

```text
python tools/analysis/Run-Investigation.py --check
python tools/analysis/Test-Investigation.py
python tools/analysis/Test-InvestigationAutomation.py
python tools/linux/test_capture_usb4.py
python tools/analysis/Check-Docs.py
```

These check public evidence relationships, generated reports, fixtures and links. They do not access hardware, independently decode unpublished captures or demonstrate a fix. The runner regenerates reports when used without `--check`.

Additional reference-code checks need separately acquired, pinned inputs:

- [Test-PdVersionCache.c](analysis/Test-PdVersionCache.c) executes the original EC cache behaviour using private BIOS data and the [EC harness](analysis/Test-EcPmcFirmware.c) build inputs.
- [Test-Ps8802ReadBehavior.py](analysis/Test-Ps8802ReadBehavior.py) compiles pinned Chromium EC reader functions against a simulated bus. Use `source.c source.h --compiler cc`, or `--compiler cl` from a Visual Studio compiler environment. [Scope](../docs/component-behavior.md).
- [Test-It8857UpdateRead.py](analysis/Test-It8857UpdateRead.py) executes the pinned updater parameter reader in Unicorn2.1.4 with RAM-only I2C substitutes. Pass the original `PDUTC101.efi` path and optionally `--deps` for an existing Unicorn installation. [Scope and results](../docs/update-interface-reads.md).

- [Test-It8857Dispatch.c](analysis/Test-It8857Dispatch.c) runs the pinned IT8857 card receiver, reset-state branch and per-port reader against RAM fixtures. Build with the pinned emu8051 sources and `bcrypt.lib`; pass the original card firmware as the only argument. [Scope and results](../docs/it8857-runtime-commands.md).

- [Test-It8857StateRecord.c](analysis/Test-It8857StateRecord.c) adds original record-producer and receiver-initialization checks, reusing the dispatch fixture above. The send helper returns supplied results; no packet is transmitted. It emits two JSON Lines. [Evidence](../evidence/it8857-state-producers.json).

- [Test-LaptopPdStatus.c](analysis/Test-LaptopPdStatus.c) executes BIOS314 status projection, power parsing and PMC4 getters with RAM bus replies. Build with the same EC harness inputs; pass the pinned full EC image. [Evidence](../evidence/laptop-pd-status-consumers.json).

Passing these checks verifies the tested code behaviour, not an ASUS hardware-access route.

## Historical experiments

Windows VHDX setup, role/mode commands, test signing and the policy filter belong to completed or inconclusive work. Their sources remain available for review. Read [results](../docs/experiments.md) and [history](../docs/history.md); those pages are not a new installation or test-boot request.

[Diagnosis plan](../docs/investigation-plan.md) · [Documentation](../docs/README.md)
