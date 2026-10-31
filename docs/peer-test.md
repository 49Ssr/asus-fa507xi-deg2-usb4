# N0: ASUS-Dell USB4 peer link

**31 October 2026: passed for adapter enumeration and link status on both machines.** The owner followed the direct ASUS-Dell comparison using the supplied DEG2 cable. ASUS PowerShell text and a Dell PowerShell photograph both show `USB4(TM) P2P Network Adapter` with status `Up` (aliases Ethernet 4 and Ethernet 9 respectively).

**Subsequent ETW rundown confirms a reported negotiated 40 Gbps USB4 link: Gen 3, two bonded lanes, both Up.** This is derived from physical lane-register fields, not the virtual network adapter's advertised speed. Payload throughput and GPU PCIe tunnelling remain untested.

| Pairing with the supplied cable | Observation | Scope |
| --- | --- | --- |
| DEG2 and Dell Intel TB4 | External router at 40/40 Gbps; NVIDIA driver and HDMI output work | Existing eGPU control |
| ASUS and Dell directly | USB4 P2P Up on both; root port reports Gen 3 with two bonded lanes, 40 Gbps | Host-to-host control at the ASUS port's advertised negotiated rate |
| DEG2 and ASUS | USB fallback/Billboard; no external router or GPU | Unresolved failing pairing |

The ASUS has established a USB4 interdomain link with a different peer at a reported 40 Gbps. This weakens a blanket explanation that its USB4 path or supplied cable cannot negotiate that rate and strengthens pairing-dependent interoperability as a lead. It does not establish GPU PCIe tunnelling, signal margins under other conditions, sustained data transfer or workload stability. A supplied cable that works in two pairings can still participate in a failure with the third pairing; it is not universally exonerated.

No ping, file transfer or throughput measurement was reported. The Dell photograph's background USB4 settings contain DEG2 metadata; that display was not used to establish the peer rate. The subsequent ASUS ETW capture supplies the physical lane fields independently. No identifying raw photograph or full adapter inventory is published here.

## Working-link rundown, completed

[Capture-USB4Peer.ps1](https://github.com/49Ssr/asus-fa507xi-deg2-usb4/blob/90ad1d612df03fef1875bcefebe554b1afab42a3/tools/Capture-USB4Peer.ps1) completed its live run on ASUS from 13:37:49.185 to 13:37:52.305 UTC, about 3.12 seconds. Both adapter inventories stayed Up. Xperf and TraceFmt processed 1,666 events, zero lost events/buffers, zero formatting errors and zero unknown records. An `InterDomainPeerInformation` record corroborates the peer connection.

The root port's rundown at 13:37:49.187 UTC reports:

Its lane adapters are 2 and 3. The failed DEG2 trace's post-attachment checks concern the root's DFP 2, providing a comparison at that logical port; physical connector identity follows the owner's requested test setup.

| Field | Raw value | Interpretation |
| --- | --- | --- |
| CurrentLinkSpeed | `0x4` | Gen 3: 20 Gbps per lane |
| NegotiatedLinkWidth | `0x2` | Dual-lane symmetric link |
| LaneBonded | `1` | Two lanes bonded: reported aggregate 40 Gbps |
| AdapterState / Lane1AdapterState | `0x2` / `0x2` | Both lane adapters Up |
| HECError / FlowControlError / HECErrors | `0` / `0` / `0` | No reported error flags/count in this observation |
| Lane0 / Lane1 logical-layer errors | `0x0` / `0x0` | No reported logical-layer error bits in this observation |

The P2P virtual NIC reports **20 Gbps** before and after; this is a different attribute and was not substituted for the physical lane-register interpretation. It is not a measured payload throughput either. The capture wrapper's original `PhysicalRateMeasured: false` means it did not derive a rate while recording; this analysis supplies the decoded negotiated-rate observation without modifying the original status file.

Microsoft documents that these speed/width fields come from `LANE_ADP_CS_1`. Their encoding was cross-checked against the Linux v6.12 driver sources: `0x4` is Gen 3, decoded as 20 Gbps per lane, and width `BIT(1)` is dual-lane symmetric. The lane state `2` is Up. These sources decode the register fields; Linux was not booted for this test.

For comparison, the failed DEG2 recording's post-attachment WPP reads yield USB4 plugged No and router-detected No. Its zero-valued initial port rundown was collected while the cable was disconnected and must not be relabelled as a post-failure speed measurement.

The raw peer ETL is 524,288 bytes; SHA-256 `9A77EEFACB155F79585B536000347500133A61D5FD907AC28A4C4A5EA6BF6D77`. Raw identifiers, peer UUIDs and device paths remain private.

The completed run used the historical collector's `-Mode Capture`. That collector was retired during the owner's subsequent cleanup; its source link above identifies the revision used for reproduction. Current `tools/` no longer includes it, and another capture is not requested.

The script reuses ETW helpers that completed the guided DEG2 recording. It requires exactly one Up USB4 P2P adapter, checks its state again after capture, stops only its own uniquely named trace, and keeps output under ignored `local/`. It does not load LiveKD, restart a controller, flash firmware or configure networking. Windows PowerShell 5.1 parsing, Preview and this live capture completed. A three-second snapshot is not a sustained stability test.

## Firmware/support consequence

Minisforum's [official DEG2 support section](https://www.minisforum.com/pages/product-info) was rechecked on 31 October: headings for downloads are present, but no verified applicable DEG2 firmware image was obtained. That does not exclude an unpublished support package. The ASUS UK BIOS page could not be re-read through the research tool during this check; the previously verified BIOS listing is not presented as a fresh complete search.

For vendor escalation, report the three pairings above and ask which exact host PD/retimer or DEG2 firmware component addresses this negotiation failure. The observed DEG2 router firmware is 62.62; that number does not independently identify its PD-controller firmware. Another model's updater is not a verified fix for FA507XI or this dock revision.

Method source: [Microsoft USB4 interdomain connections](https://learn.microsoft.com/en-us/windows-hardware/design/component-guidelines/usb4-interdomain-connections). Remaining hardware comparisons and their limits are in the [handoff](handoff.md#deg2-cable-and-peripheral-comparisons).

Register provenance: [Microsoft rundown field definitions](https://learn.microsoft.com/en-us/windows-hardware/design/component-guidelines/usb4-tracelogging-rundown-events); Linux v6.12 [lane-register constants and port states](https://github.com/torvalds/linux/blob/v6.12/drivers/thunderbolt/tb_regs.h), [speed decoding](https://github.com/torvalds/linux/blob/v6.12/drivers/thunderbolt/switch.c) and [link-width enumeration](https://github.com/torvalds/linux/blob/v6.12/include/linux/thunderbolt.h).
