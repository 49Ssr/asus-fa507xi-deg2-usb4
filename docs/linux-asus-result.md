# ASUS Linux result: USB fallback reproduced

On 2 November 2026, SystemRescue 13.02 / Linux 6.18.41-1-lts booted on the ASUS FA507XI and recorded a fresh DEG2 attachment. The collector saved its files on the boot USB. All 12 returned files were copied privately and verified; all 11 capture-manifest entries match.

**Result: DEG2's ordinary USB functions appeared, including its 10 Gbps USB hub. No external USB4 router or new PCIe device appeared in the recorded observations.**

## What the run establishes

| Observation | Meaning |
| --- | --- |
| Host USB4 router and domain present before and after attachment | The Linux USB4 subsystem was present; this was not a run without a host router |
| ACPI `_OSC` grants Linux USB3, DisplayPort, PCIe and XDomain control | Firmware did not withhold OS PCIe control at this interface |
| Connector maps to `CR01`; dock USB functions map to `XHC3` | Consistent with the previously captured ASUS path |
| Partner type changes from DFP to UFP; host finishes in the host data role and sink power role | The role change occurs under Linux too; it does not restore router discovery |
| Intel `8087:5787` USB hub reports 10,000 Mb/s; DEG2 `041f:d002` interface and downstream USB devices appear | Ordinary USB fallback is real; 10 Gbps USB is not a measured USB4 link |
| 45 topology samples span 45.000246 seconds, with no snapshot-read errors | No external router or PCIe-device change was found in those samples |
| Available Thunderbolt/UCSI tracepoints recorded 72 events with zero reported drops/overruns | The saved attachment trace can be inspected; it is not a complete PD-wire recording |

The final domain security mode is `user`, but no external router appears to authorize. A pending PCIe-authorization result would have been different: the router would be visible while access remained restricted.

## What the extra trace says

The three UCSI connector reports occur at 82.921329, 83.018129 and 83.211345 seconds since boot. They report attachment, a PD power mode and then a partner-role change. A DisplayPort alternate mode is registered later. Registration alone does not establish that it became active; it also does not establish USB4 entry or an applied PS8830 mode.

The host exchanges local configuration packets and receives plug notifications for root-route ports 6 and 7. Its two transmitted `TB_CFG_PKG_ERROR` packets carry code `0x7`. In the matching Linux source this is `TB_CFG_ERROR_ACK_PLUG_EVENT`; `tb_cfg_ack_plug()` sends it to acknowledge a notification. **These packets are not dock rejection replies.** [Packet definitions](https://github.com/gregkh/linux/blob/2fe596715f840d053aed5cee5455f701bdcd2b50/drivers/thunderbolt/tb_msgs.h), [acknowledgement implementation](https://github.com/gregkh/linux/blob/2fe596715f840d053aed5cee5455f701bdcd2b50/drivers/thunderbolt/ctl.c).

The trace does not sample the previously studied RouterDetected bit 13. It therefore adds no new clear/set measurement of that bit. Local host traffic is not a recovered exchange with DEG2's external router.

The JMicron USB-storage bridge separately reports not-ready/capacity errors. They are preserved as a downstream symptom; their relationship to USB4 entry is not established.

## What changes in the diagnosis

The failure now reproduces under Linux as well as two Windows installations. A cause confined to the installed Windows, its automatic role-correction policy or the NVIDIA driver is insufficient to explain all recorded cases.

This strengthens a shared firmware/controller/cable interaction as a direction to investigate. It does not identify a defective chip, prove permanent hardware damage or distinguish an omitted/rejected USB4-entry request from routing/training failure. Sampling and the enabled tracepoints cannot exclude a shorter unreported transient link.

No new firmware command, experimental driver, mode override or flash was used by the collector. Normal Linux driver and policy activity remains part of the comparison, including the host configuration writes visible in the trace.

## Next useful evidence

A matching successful Linux capture on Dell would provide an OS-matched trace, but that route is currently unavailable. The [successful Dell Windows capture](asus-dell-matched-comparison.md) remains the control and already contains native router-detection and device-status records. Neither another boot-menu attempt nor an unchanged Windows capture is selected.

Offline work can continue against the original policy/controller implementation. A Windows repair still needs a specific failing operation and a supported intervention; this result does not supply one.

[Reviewed evidence and source hashes](../evidence/linux-asus-result.json) · [Current findings](status.md) · [Capture guide](linux-capture.md)
