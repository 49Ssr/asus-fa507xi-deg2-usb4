# ASUS FA507XI + Minisforum DEG2: USB4 failure investigation

The DEG2 and RTX 4080 SUPER work on a Dell Latitude 5540. On the ASUS TUF A15 FA507XI, the dock's ordinary USB devices appear, but its external USB4 router and GPU do not.

**As of 3 November 2026, there is no confirmed fix.** The failure also occurs in a separate Windows installation and a live Linux session. The same ASUS port can establish a 40 Gbps host-to-host USB4 link with Dell. Those comparisons narrow the problem, but do not identify a defective chip or prove that ASUS can tunnel PCIe to this dock.

## Read the investigation

| Question | Page |
| --- | --- |
| What do we know, and what is still uncertain? | [Findings](docs/status.md) |
| What should we do next, and why? | [Diagnosis plan](docs/investigation-plan.md) |
| How do the controller, retimer and GPU fit together? | [Connection explained](docs/connection.md) |
| What has already been tried? | [Experiment results](docs/experiments.md) |
| Where are the detailed records? | [Documentation index](docs/README.md) |
| What can I run? | [Tool guide](tools/README.md) |

## The unresolved part

ASUS corrects the USB data role and enumerates the dock's USB hub. The missing record is what happens during USB4 entry and link establishment: whether entry is requested, rejected, accepted but followed by failed training, or followed by a brief link that is lost.

Board photographs identify **ITE IT8857FN** and **Parade PS8830 A3**. Knowing the parts helps us read the right reference code; it does not tell us which operation failed. The [diagnosis plan](docs/investigation-plan.md) ranks the remaining hardware comparisons and software-access work.

## Using or contributing to this repository

This is a case study, not a driver or patch to install. The Linux collector records a connection; older device-control scripts preserve specific experiments. Read their status in the [tool guide](tools/README.md) before using them.

[Compatibility reports and contributions](CONTRIBUTING.md) are welcome. Report external-router detection separately from USB devices, GPU detection and display output. A USB hub working does not establish a working USB4 link.

Public evidence includes decoded records, source references and offline checks. Raw dumps, traces, firmware and identifying inventories remain private, so the public repository alone cannot reproduce every decode. [Evidence policy](docs/privacy.md) · [History](docs/history.md)
