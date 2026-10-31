# ASUS FA507XI / Minisforum DEG2 USB4 investigation

**Status: unresolved. Updated 31 October 2026.** This repository documents an ASUS TUF A15 FA507XI that operates a Minisforum DEG2 as a USB hub but never enumerates its external USB4 router or attached GPU. The same assembled dock, GPU, PSU, and supplied cable work on a Dell Intel Thunderbolt 4 laptop.

**A separate full Windows installation has now reproduced the failure.** Windows 11 Pro 26200.8037 booted natively from the VHDX with the scoped baseline drivers. Its USB4 host/root, UCSI, I2C and eight Parade peripherals were healthy, but the DEG2 still appeared only through ordinary USB fallback. No external USB4 router or GPU enumerated. This makes a problem specific to the original Windows installation a weaker explanation; it does not identify a proven firmware defect or rule out every Windows/driver interaction. See the [fresh-Windows result](docs/fresh-windows.md) and [validation audit](docs/validation-audit.md).

The aim is to turn a difficult troubleshooting session into reproducible evidence, useful negative results, and a practical knowledge base for other owners. This is not a claim that every FA507XI or every AMD host is affected, or that a particular firmware fix exists for this model.

## What the evidence currently establishes

| Observation | Implication |
| --- | --- |
| RTX 4080 SUPER, DEG2 and supplied cable work on the Dell | A dead GPU or fundamentally nonfunctional assembly is not supported by the evidence. Host-specific cable/firmware interoperability remains possible. |
| ASUS has a Microsoft USB4 host router and initializes its root router | The laptop exposes a real USB4 controller; ordinary USB operation alone would not prove this. |
| Firmware grants `_OSC` USB4 controls `0xf` | Firmware is granting the four requested USB controls, including PCIe tunneling control. This is not an end-to-end link test. |
| No external USB4 router enumerates on ASUS; a Billboard device appears | The observed failure precedes enumeration of the GPU. Reinstalling NVIDIA drivers does not address the missing link stage. |
| Reinstalls, retimer restarts, EC reset and a newer related-model Parade driver did not change the symptom | Those specific attempts were ineffective; they do not rule out all Windows or firmware causes. |
| `EnableUSB4v2Support=1` was ignored because test-signing is disabled | The registry experiment never activated the intended path. It is not a valid negative test of that path. |
| An all-vendor Windows Update driver search succeeded with zero packages | No applicable packages were offered by that search at that time. This does not prove that every vendor has published every possible fix. |
| Separate Windows build 26200.8037 with USB4 driver 10.0.26100.7920 reproduces fallback | The failure is not confined to the owner's main Windows installation or its newest USB4 binary. Cable/host/dock interoperability remains to be isolated. |

## Read the knowledge base

- [Hardware and working comparison](docs/hardware.md)
- [Detailed troubleshooting timeline](docs/timeline.md)
- [Trace interpretation and evidence limits](docs/findings.md)
- [Experiment ledger](docs/experiments.md)
- [Correction: the private USB4 policy override](docs/policy-audit.md)
- [Research and primary sources](docs/research.md)
- [Temporary full-Windows test](docs/test-windows.md)
- [Fresh-Windows results](docs/fresh-windows.md)
- [Current state and handoff](docs/handoff.md)
- [Publishing evidence without exposing private device information](docs/privacy.md)

## Tools

`tools/Prepare-USB4Test.ps1` builds a separate native-boot Windows installation in a new VHDX file. It defaults to a read-only preview. Creation of the image and addition/removal of its boot entry are separate explicit modes. `tools/Collect-USB4Test.ps1` records a before/after device inventory and ETW connection trace inside that installation.

The temporary image is a diagnostic experiment. Preparation, native boot, and one connection capture have now completed on the owner's machine; removing the boot entry has not yet been exercised. The initial real preparation failure and correction remain documented. Parser/guard tests are separate from hardware validation. The original troubleshooting scripts and raw captures are retained privately rather than presented here as a universally applicable repair utility.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Prepare-USB4Test.ps1 -Mode Preview
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-Toolkit.ps1
```

The scripts require Windows PowerShell 5.1 or later. Mutating setup modes require a 64-bit Administrator console on the exact FA507XI model. Signed driver binaries and Windows media are not redistributed. They belong in the ignored `local/` directory on the owner's machine.

## Contributions

Reports from the same model or another USB4 host are welcome. Include the exact host, BIOS, OS build, dock/router firmware, cable type, whether an external USB4 router appears, and whether the identical assembly works on another host. A working mouse on the dock is a USB fallback result, not proof of PCIe tunneling. See [CONTRIBUTING.md](CONTRIBUTING.md).

This investigation used AI-assisted code and analysis. Important mistakes are recorded explicitly so that other people do not repeat invalid tests or mistake hypotheses for fixes.
