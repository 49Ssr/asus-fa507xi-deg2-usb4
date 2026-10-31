# What the traces say

## Failure stage

On the ASUS, the host and root router initialize. The root's downstream adapter remains disconnected; no external router is enumerated. Ordinary USB hubs and the dock's Billboard interface appear through the native xHCI path instead.

The useful sequence is:

1. USB-C attachment and power/data-role handling occur.
2. The host/root USB4 stack is present and firmware grants USB controls.
3. The trace does not show an established external USB4 router.
4. Billboard/USB fallback reports the unsuccessful advanced connection.
5. There is consequently no external PCIe GPU to hand to NVIDIA's display driver.

This locates a boundary. It does not identify which cable, mux/retimer, PD controller, host firmware, dock firmware, or Windows interaction caused it.

## `_OSC` result `0xf`

The host restart trace records `_OSC USB4 capabilities granted: 0xf`. The four low control bits are granted, including PCIe tunneling control. This rules out the specific claim that firmware is withholding that `_OSC` permission in the captured initialization.

It does not establish signal integrity, successful USB4 mode entry, a downstream router, PCIe link training, or GPU operation. A root PCIe downstream adapter reaching `WaitForTunnelRequestFromChild` means the state machine is ready for a child request; it is not proof that a child exists.

The 31 October 04:27 live kernel snapshot independently retains `m_usb4CapabilitiesGranted = 0xf` and the direct policy field `PcieTunnelsDisabledInBios = 0`. USB4KD finds one host/root, no external router and zero tunnels, while the ordinary fallback devices remain PnP Started. It also finds both logical UCM connectors in the local DFP data role. No new causal error or repair was identified. See [the snapshot report](kernel-snapshot.md), including the constructor-default status and debugger-helper caveats.

The expanded pass decoded the port's retained transition history: register reads complete successfully, while `IsUSB4PortPlugged` and `IsRouterDetectedSet` return No. The plug-state manager is Enabled. UCSI's retained SET_UOR command completes and is acknowledged. These are stronger observations of the no-connection boundary, but do not expose the missing PD/firmware exchange. The UCSI/EC shared-memory pages are not included in the dump. [Selected state and command excerpts](../evidence/kernel-state-excerpts.txt).

## Router versions

The ASUS trace reports root router USB4 version `0x20` and connection manager version `0x10`. These fields must not be converted into a claim that the laptop provides an 80 Gbps physical port. The model's documented port is 40 Gbps.

The working Dell reports a host USB4 version of 1.0 while the external DEG2 router reports 2.0 and runs a 40/40 Gbps link. Therefore a device's v2 descriptor does not, by itself, establish that Windows must enable its v2 connection-manager path for any backward-compatible connection.

## Billboard status nuance

The fallback Billboard data includes SVIDs `FF00` (USB4) and `8087` (Thunderbolt), each with status 1, and DisplayPort SVID `FF01` with status 3.

For the relevant Windows notification interpretation, status 1 means the mode was not attempted or was exited. It is **not** evidence that a particular Enter_USB/Enter Mode request was sent and explicitly rejected. The log's event title `Alternate Mode Failed` is less precise than the underlying status. DisplayPort mode success also does not prove USB4 mode success.

The notification "Use different USB port" is a symptom reported from this fallback path; it is not an instruction that proves the owner used the wrong physical port.

## UCSI and power roles

UCSI commands complete. The trace includes a `SET_UOR(Dfp)` operation and a subsequent partner-role change. Such a correction can be normal when a powered dock initially advertises a different data role. Completion of the command does not prove that the whole negotiation completed, nor does its presence prove the command is the defect.

USB Power Delivery values describe the Type-C power relationship, not the desktop GPU's separately wired PSU power. Host/router idle after failure is also a consequence of no connected USB4 device, rather than proof that a power-saving timer caused the failure.

## Trace provenance

[Trace excerpts](../evidence/trace-excerpts.txt) retain timestamps and message payloads tied to captures T4, T5 and T6. Identifying instance, process/thread and address prefixes are removed. Selection is deliberate: these are not a continuous USB-PD transaction log. In particular, the T4 `_OSC` observation occurs during a host restart after the earlier Billboard events; it must not be rearranged into one proven attachment sequence.

[Structured observations](../evidence/observations.json) record capture hashes, sizes, counts and comparison provenance. Raw traces and inventories remain private, so an external reviewer can audit the stated reasoning but cannot independently re-decode those files from this repository alone.

## Capture quality

| ID / UTC run label | Events | Reported lost | Duration, seconds | Notes |
| --- | ---: | ---: | ---: | --- |
| T0: 30 Oct, initial WPR around 20:01 | 253 | 0 | 55 | Metadata-only; inadequate for the connection question |
| T1: 30 Oct, direct 20:08:03 | 8,403 | 0 | 28 | Useful direct trace |
| T2: 30 Oct, direct 20:47:54 | 6,500 | 0 | 30 | Valid capture despite later wrapper error |
| T3: 30 Oct, direct 21:06:31 | 9,876 | 0 | 25 | Connection capture |
| T4: 30 Oct, direct 21:07:44 | 12,787 | 0 | 37 | Includes host restart and `_OSC` grant |
| T5: 30 Oct, direct 22:12:23 | 9,229 | 0 | 33 | Includes host restart; zero WPP formatting errors; policy remains default |
| T6: 31 Oct, fresh Windows 03:16:25-03:17:19 | 7,720 | 0 | About 54 | 2,441 unknown-format events; independent PnP snapshots show fallback only |

T0-T5 counts/durations come from tracerpt summaries. Matching Microsoft public PDBs supplied WPP formats for the original-installation analysis. T6 counts come from TraceFmt, with only partial decoding; see the [fresh-Windows result](fresh-windows.md). Counts from different capture windows/tools are recording metadata, not performance measurements or a repeatability percentage.

Zero reported loss does not show every physical-layer transaction was observable. Neither the original WPP analysis nor T6 supplies a USB-PD wire capture proving which endpoint failed to send or accept an Enter_USB transaction.

## Remaining hypotheses

| Hypothesis | Evidence affecting it | What is still needed |
| --- | --- | --- |
| Cause confined to original Windows cleanup/registry | Same failure on separate full Windows with an older USB4 driver | Weaker explanation; shared OEM drivers, firmware and baseline omissions still matter |
| Dead GPU / NVIDIA display driver is the initial cause | Identical assembly produces output on Dell; ASUS lacks the earlier external router | No evidence to prioritize replacing the GPU; revisit GPU/driver diagnosis if enumeration advances |
| Firmware denies USB `_OSC` PCIe control / cached BIOS-disable policy | Captured grant is `0xf`; kernel snapshot has `PcieTunnelsDisabledInBios = 0` | Those specific denial indicators are absent in the captured states, not all firmware/security interactions |
| Cable-dependent negotiation or signal margins | Supplied cable works on Dell; no second suitable cable tested | N1/N2 in the [next-test matrix](handoff.md); a Dell pass does not measure ASUS signal margins |
| ASUS host/PD/retimer hardware or firmware issue | Both Windows installations fail before external-router enumeration | N3; no known-good separate USB4 peripheral has exercised this ASUS path |
| DEG2-specific host/dock firmware interaction | ASUS/Dell difference and other-model precedents fit this possibility | N1-N3 and exact-model vendor evidence; no applicable firmware fix verified |
| Common Windows/OEM driver interaction | Fresh Windows shares selected OEM drivers and physical firmware | A specific mechanism and targeted test; neither total exclusion nor another blanket reinstall is justified |

These are qualitative evidence assessments, not numeric probabilities. [Next tests](handoff.md) specify observable outcomes and the limits of each inference.
