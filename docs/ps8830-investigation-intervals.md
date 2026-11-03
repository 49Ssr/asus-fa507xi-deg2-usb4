# Research checkpoint

Updated 3 November 2026. Scheduling is **paused**. This page preserves the resume point; the [diagnosis plan](investigation-plan.md) is the single list of current priorities.

## Resume point

The [EC host-transfer path](ec-host-transfer.md) now executes in the offline model: PMC3 accepts staged bytes but fixes the destination at update address80, not normal address98. Failed transfer retrieval can return old data. The reviewed ASUS legacy request uses the separate PMC4 route. Next identify read semantics at80 in the acquired IT8857 tool and an existing Windows route to PMC3; no hardware command is selected.

This is an access investigation. A successful version read would still not supply the missing entry/retimer/training history. The [plan](investigation-plan.md) separately ranks the hardware comparisons and the controller records needed to choose a repair.

## Completed work to reuse

| Record | Result |
| --- | --- |
| [ASUS Linux capture](linux-asus-result.md) | USB fallback reproduced; no external router or new PCIe device observed |
| [RT0 mapping](rt0-attachment-order.md) | Connector 1 maps to XHC3/NHI0/RT0; role correction precedes USB enumeration |
| [SDK 3.9.0](infineon-sdk-review.md) | AMD/PS8830 reference definitions and compiled functions acquired; no ASUS-equivalent transport established |
| [Reset command path](data-reset-command-path.md) | EC forwards the relevant bit; the actual receiving controller's interpretation is unknown |
| [IT8857 version-only path](it8857-version-path.md) | Direct host I²C initialization and address translation recovered; no Windows PD bridge established |
| [PD version cache](pd-firmware-version.md) | Getters 10/11 hex returned 00 53; a failed refresh can preserve old bytes |
| [Physical chip review](board-photo-review.md) | IT8857FN and PS8830 A3 identified; the earlier IT8853 response is a fixed string |
| [Component controls](component-behavior.md) | PS8830 mode inputs differ from link results; PS8802 reads can wake it; ITE event handling acknowledges events |
| [Boot-state readback](../evidence/boot-state-20261103.json) | Secure Boot reported off, test signing off, HVCI running; full BCD/restoration verification incomplete |

Reference-code fixtures were run offline. They are not measurements of the ASUS controller. The actual laptop PD firmware and a live state/log interface remain unidentified.

## Operating constraints

Scheduling remains paused. Physical tests, boots and changes remain owner-directed. Preserve original artifacts, failed attempts and private recovery records. Follow [AGENTS.md](../AGENTS.md), including the owner's 1% allowance stop and publication rules.

## Earlier journal

The [dated journal before cleanup](https://github.com/49Ssr/asus-fa507xi-deg2-usb4/blob/52e6e26890adf49c2846a0acc478089659808843/docs/ps8830-investigation-intervals.md) preserves the original work. Earlier “next task,” unexecuted-read and scheduling statements describe their dates.

[Findings](status.md) · [Handoff](handoff.md) · [History](history.md)
