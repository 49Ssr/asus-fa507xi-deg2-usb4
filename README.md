# ASUS FA507XI + Minisforum DEG2 USB4 investigation

The DEG2's ordinary USB functions work on this ASUS TUF A15, but its external USB4 router and RTX 4080 SUPER do not appear. The same assembled dock, GPU, power supply and supplied cable work on a Dell Latitude 5540.

**Status — 2 November 2026: no confirmed fix.** The first ASUS Linux capture also reproduced USB fallback: a 10 Gbps USB hub appeared, but no external USB4 router or new PCIe device was observed. The capture saved successfully to the boot USB. [Linux result](docs/linux-asus-result.md).

## Start here

| What you need | Read |
| --- | --- |
| The result, what has been ruled out, and what remains unknown | [Current findings](docs/status.md) |
| A plain explanation of the components and connection sequence | [How the connection works](docs/connection.md) |
| The proposed Linux comparison and its instructions | [Linux capture guide](docs/linux-capture.md) |
| What has already been tried | [Experiment results](docs/experiments.md) |
| Which scripts are useful now | [Tool guide](tools/README.md) |
| Every research note, grouped by subject | [Documentation index](docs/README.md) |

## What the evidence establishes

- Two Windows installations and a live Linux session on ASUS reproduce the missing-router failure.
- ASUS completes the Windows-requested data-role change and then enumerates DEG2's SuperSpeed USB hub and downstream USB devices.
- The failed connection maps to **connector 1 → XHC3 → NHI0 → RT0**. RT1 is a different host-router instance.
- Stored USB4 and Thunderbolt 3 enable settings are already enabled. Their presence does not prove how the controller applies them.
- A working ASUS–Dell peer connection demonstrates a 40 Gbps negotiated USB4 link on the tested ASUS port/cable. It does not establish eGPU PCIe tunnelling.

The missing evidence is the actual USB4-entry request/response and the retimer/link state during failure. We have not yet separated an omitted request, rejection, failed link training or a brief connection followed by loss. [Details and sources](docs/status.md).

## For other owners and contributors

This repository is a case study and diagnostic work in progress. The scripts that touch devices are restricted to the documented hardware and conditions. There is no universal driver, BIOS patch or registry fix to install.

[Report a comparison or contribute evidence](CONTRIBUTING.md). Useful reports separate ordinary USB operation, external-router detection, PCIe-device detection, GPU output and workload stability. Keep raw dumps, serial numbers and unreviewed logs private.

## Evidence and reproducibility

Public JSON records, reviewed excerpts and pinned code references support the findings. Original memory dumps, ETL files, firmware and device inventories remain private. An outside reviewer can inspect the reasoning and run the public-file checks, but cannot independently re-decode unpublished captures. [Publication policy](docs/privacy.md).

```text
python tools/analysis/Run-Investigation.py --check
python tools/analysis/Test-Investigation.py
python tools/analysis/Test-InvestigationAutomation.py
python tools/linux/test_capture_usb4.py
python tools/analysis/Check-Docs.py
```

[Earlier investigation record](docs/history.md) · [Technical evidence map](docs/investigation-map.md)
