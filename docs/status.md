# Findings

Updated 3 November 2026. **No working Windows fix or firmware patch has been demonstrated.**

ASUS detects DEG2's ordinary USB devices but does not discover its external USB4 router at the recorded checks. The GPU is downstream of that missing connection. Changing the NVIDIA driver is therefore not the next diagnostic step.

## The comparisons that matter

| Observation | What it tells us | What it does not tell us |
| --- | --- | --- |
| The same DEG2, GPU, PSU and supplied cable work on Dell Latitude 5540 | The assembled dock can operate on another host | That it negotiates identically with ASUS, or has equal signal margins |
| ASUS fails in two Windows installations and SystemRescue Linux | The failure is not confined to the original Windows installation | Whether firmware, physical signalling or an interaction between components is responsible |
| ASUS–Dell peer connection reaches Gen 3, two lanes, 40 Gbps | The tested ASUS port and cable can establish this USB4 peer link | That PCIe tunnelling or DEG2 compatibility works |
| ASUS completes the data-role correction, then enumerates DEG2's SuperSpeed hub | The connection is not stuck in the wrong USB host/device role | That USB4 entry or retimer configuration succeeded |
| The dock's cached Billboard report says USB4 successful on Dell, not attempted or exited on ASUS | The dock reports different outcomes | Whether ASUS omitted entry, DEG2 rejected it, or entry was followed by an exit |

Records: [matched comparison](asus-dell-matched-comparison.md), [separate Windows installation](fresh-windows.md), [Linux result](linux-asus-result.md), [peer link](peer-test.md), [attachment order](rt0-attachment-order.md), [dock report](billboard-comparison.md).

The Linux recording saw a 10 Gbps USB hub, no external router and no new PCIe device in its 45-second observation. The host router was present and ACPI granted OS control of PCIe tunnelling. Its ERROR 0x7 packets were plug-event acknowledgements, not rejection messages from DEG2. It did not record the physical PD exchange or a new RouterDetected bit-13 sample.

## Hardware and settings

- Photographs identify **IT8857FN** and **PS8830 A3**. The earlier `IT8853` response is a fixed string in ASUS EC firmware, not the fitted chip identity. [Photo review](board-photo-review.md).
- The captured failing port maps to **connector 1 → XHC3 → NHI0 → RT0**. RT1 is a separate host-router instance, not the retimer. [Mapping and correction to the earlier XHC4 description](rt0-attachment-order.md).
- Stored PD USB4 and Thunderbolt 3 settings are enabled. RT0 and its PCIe tunnel are Auto; RT1 is Disabled. Stored values do not reveal the final controller decision. [Settings](../evidence/firmware-settings-read.json).
- The Windows getter returned cached PD firmware bytes **00 53**. A failed refresh can leave old bytes in that cache. Their freshness, display encoding and matching laptop firmware image remain unknown. [Version read](pd-firmware-version.md).

The first retained ASUS RouterDetected sample has bit 13 clear; Dell's is set. A sampled value is not proof that a link never appeared between observations. [Detection evidence](../evidence/router-detection-branch.json).

## Explanations weakened by the tests

The policy-filter trial changed Windows' role-correction behaviour without restoring USB4. Also, a working ASUS–Dell peer phase included a rejected Windows SET_UOR request. The existence of that request alone cannot explain failure. [Policy result](role-policy-test-result.md) · [Peer role sequence](negotiation-followup.md).

The retimer updater's target-lifetime bug coexisted with a working peer link, so it is not sufficient to explain all USB4 failure. The OEM diagnostic timeout led to a stubbed firmware getter; it is not a measurement of a timed-out PD handshake. [Updater](parade-updater-failure.md) · [EC getter](ec-firmware-decision.md).

All four plug orientations and a powered preconnected startup have already been tried. The Rp-only experiment never established attachment and therefore did not test its intended condition. See [all experiment results](experiments.md).

## What remains unknown

We have not distinguished these outcomes:

1. USB4 entry is never requested.
2. Entry is requested but rejected.
3. Entry is accepted, but routing or link training fails.
4. A link forms briefly and is lost.

The Infineon SDK and component drivers describe reference implementations. They have not supplied the actual ASUS controller decision or a working Windows transport for reading it. PS8830 mode flags describe requested configuration, not independent proof of a trained link. [Access routes](windows-repair-route.md) · [Component controls](component-behavior.md).

**The next work is ranked in the [diagnosis plan](investigation-plan.md).** Another generic dump or unchanged boot would repeat the same blind spot.

## Latest access finding

The EC has a host-requested transfer path through PMC3, but it fixes the destination at update address80 rather than normal PD address98. Offline execution also shows that retrieval after a failed transfer can return old buffer contents. The reviewed ASUS Windows request uses the separate PMC4 route. The remaining access questions are the update interface's read protocol and an existing Windows route to PMC3. [Code and limits](ec-host-transfer.md).

## Recovery status

The experimental filter was removed and stock policy verified. On 3 November, Windows reported Secure Boot off, test signing off and HVCI running. The exact test certificate was absent from both machine trust stores. Fresh BCD enumeration and complete boot-restoration verification remain incomplete. ASUS System Control Interface 3.1.73.0 is installed. [Readback and limits](../evidence/boot-state-20261103.json).

[Documentation index](README.md) · [Research handoff](handoff.md)
