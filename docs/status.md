# Current findings

Updated 2 November 2026. **The ASUS–DEG2 connection remains unresolved. No working Windows fix or firmware patch has been demonstrated.**

The observed failure occurs before Windows discovers DEG2's external USB4 router. Its USB hub, storage/network functions and Billboard interface can still enumerate. GPU-driver changes cannot explain that earlier missing-router observation by themselves.

## The strongest comparisons

| Comparison | Result | What it establishes |
| --- | --- | --- |
| DEG2 + RTX 4080 SUPER + supplied cable on Dell Latitude 5540 | External router, GPU and display work | The assembled dock can operate on another host |
| Same dock on ASUS FA507XI | Ordinary USB works; external router/GPU absent | The failure is reproducible in this pairing |
| Separate Windows installation on ASUS | Same failure | Weakens an explanation confined to the original Windows installation |
| ASUS–Dell host-to-host connection through the tested ASUS port/cable | Negotiated Gen 3, two lanes, 40 Gbps | The ASUS path can establish a USB4 peer link; eGPU PCIe tunnelling remains a separate question |

Sources: [matched ASUS/Dell comparison](asus-dell-matched-comparison.md), [Dell control](dell-control.md), [separate Windows installation](fresh-windows.md), [peer connection](peer-test.md).

## The role change succeeds; USB4 detection still fails

Both hosts initially report the partner in the host-facing data role. Dell reports the partner in the device-facing role by its first PD report and then detects the external router. ASUS reports that role later, after Windows requests the change.

The saved ASUS trace independently confirms successful enumeration of DEG2's SuperSpeed hub after that correction. This rules out a permanently wrong USB host/device role in that attachment. It does not reveal the physical PD exchange or how PS8830 was configured.

The first ASUS router-detection sample has bit 13 clear; Dell's is set. These are recorded samples, not a complete history proving that ASUS never formed a brief link. [Port mapping and exact timestamps](rt0-attachment-order.md), [native detection branch](../evidence/router-detection-branch.json).

## Settings already checked

The Windows read of BIOS 314 stored variables found:

| Setting | Stored value |
| --- | --- |
| PD USB4 Control | Enabled |
| PD Thunderbolt 3 Alt Mode | Enabled |
| RT0 router / PCIe tunnel | Auto / Auto |
| RT1 router | Disabled |

RT0 is the host instance associated with the failed connection. RT1 is the second instance, not the PS8830 retimer. Enabling RT1 is unsupported as a repair for this captured path. Stored Auto values are not a measurement of final applied policy. [Settings read](../evidence/firmware-settings-read.json), [router mapping](rt1-router-mapping.md).

One earlier description of XHC4's ACPI association was too strong: the inspected scope contains a conditional dependency on NHI1, rather than the explicit USB4 property present for XHC3. The tested RT0 mapping remains supported. [Correction](rt0-attachment-order.md).

## Previous tests and their limits

The policy-only driver trial changed Windows' role-correction behavior but did not restore USB4. The driver was removed and stock policy verified. A powered preconnected startup also failed to produce the router/GPU. An Rp-only test did not establish attachment, so it did not test the intended changed condition. One alternate-mode exit request was rejected. [Complete results](experiments.md).

The OEM EC-response timeout was traced to a stubbed diagnostic getter in the inspected firmware. It is not a measured timeout of the PD handshake. The updater's retimer-target lifetime issue is real, but the working ASUS peer connection weakens it as a universal blocker. [EC timeout](ec-firmware-decision.md), [Parade updater analysis](parade-updater-failure.md).

## The remaining question

We need to distinguish:

1. ASUS never requests USB4 entry.
2. DEG2 rejects the request.
3. Entry is accepted but routing or link training fails.
4. A usable link briefly appears and is then lost.

The captures have not exposed the decisive controller record. A hidden menu, enabled setting, successful UCSI command or final missing router does not answer those questions on its own. No source-qualified Windows operation that repairs the missing transition has been found. [Windows repair research](windows-repair-route.md).

## The next comparison

The prepared [Linux kit](linux-capture.md) asks whether another OS can discover an external router and PCIe endpoint with the existing hardware. It keeps pending PCIe authorization separate from entry failure and records transient routers. Its real USB persistence and ASUS capture are not yet tested.

Linux success would narrow the OS/firmware interaction, with boot and power history still a confound. Linux failure would leave the PD/retimer ambiguity open. The kit does not force a mode, authorize devices, scan retimers or change firmware.

No vendor-confirmed root cause or applicable fix is recorded. [All documentation](README.md) · [Research handoff](handoff.md)
