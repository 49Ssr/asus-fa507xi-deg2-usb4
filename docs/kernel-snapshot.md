# Live kernel snapshot: 31 October 2026

**Result: the offline inspection worked; no repair or root cause was identified.** The captured USB4 policy permits PCIe tunnels, but the ASUS has no external USB4 router or tunnel while the DEG2's ordinary USB fallback devices remain present. This corroborates the earlier failure boundary with driver objects retained in memory.

## Capture and method

| Item | Recorded value |
| --- | --- |
| Snapshot time | 2026-10-31 04:27:38.513 UTC |
| System uptime | 00:16:04.448 |
| Installation | Original ASUS Windows, build 26200.9818 |
| USB4 host/device-router binaries | 10.0.26100.9818; matching public symbols loaded |
| File | Task Manager live kernel dump, 2,300,018,688 bytes; hash in [observations](../evidence/observations.json) |
| Dump form | x64 kernel bitmap dump; kernel address space available, not a complete record of user memory |
| Debugger and USB4KD version | Microsoft 10.0.29661.1004 |

Microsoft's signed debugger binaries were extracted locally and used with an offline `-z` target. The debugger, engine and USB4KD extension signatures validated as Microsoft. Matching kernel, WDF, USB4 and UCSI public symbols were used. Native symbol-server HTTP failed in this environment; downloading the matching public PDBs separately and using a local symbol path resolved that tooling problem.

The inspection used `!usb4kd.usb4treeall`, host/router/port/adapter commands, `!usb4kd.usb4tunnels`, PnP/WDF state, typed driver objects and decoded in-flight recorder buffers. Driver code was inspected only to distinguish a constructor's initial value from a recorded failure. No driver, registry, boot-debugging, firmware or power setting was changed by this analysis. Live-system dump code `0x161` is present; this was a deliberate Task Manager snapshot, not evidence of a blue-screen crash.

## Observed state

| Object / property | Value | What it establishes |
| --- | --- | --- |
| USB4 topology | 1 AMD host, 1 root router, 0 external routers | DEG2 has not become a USB4 device in this snapshot |
| Host | PCI 1022:1668, D0 | Host object present and powered |
| Root router | `RouterOperational (177)`; D3 | Initialized root, idle at capture; D3 alone does not establish a power-management defect |
| Host granted capabilities | `m_usb4CapabilitiesGranted = 0xf` | Consistent with the earlier captured `_OSC` grant |
| Host tunnel policy | `PcieTunnelsDisabledInBios = 0` | This specific cached BIOS-disable flag is clear; it does not prove a working end-to-end PCIe path |
| Downstream USB4 port 2 | `WaitForEventsInDisconnected (457)` | No established USB4 connection on the port |
| Plug-state manager | `Unplugged (50)` | USB4 state-machine state, not a claim that the physical Type-C cable was absent |
| Lane bonding | `IdleDFP (34)` | No active bonded USB4 link shown |
| PCIe and USB3 downstream adapters | `WaitForTunnelRequestFromChild (83)`; not tunneled | Waiting for a child, not evidence that one exists |
| Tunnels | Total 0; USB3, PCIe, DP and host-to-host each 0 | No USB4 tunnel exists at capture |
| Fallback devices | USB 8087:5787 / USBHUB3 and 041F:D002 / WINUSB, both PnP Started | Dock fallback was still present; this is not merely a snapshot of the whole dock disconnected |
| UCSI | PnP Started, WDF D0; no pending PnP/power/wake IRPs reported | No stopped UCSI device or pending request of those classes was identified |

The two logical UCSI/UCM connectors both report an attached partner, local data role `UcmDataRoleDfp`, and `UcmPdConnStateNegotiationSucceeded`. Connector 1 is a power sink; connector 2 is a power source. Their physical-port/device mapping has not been independently established here. These cached states do not identify a failed Enter_USB exchange or prove that USB4 mode negotiation succeeded. They also do not show either local connector still stuck in the UFP data role at capture.

## Retained recorder evidence

- The host buffer contains 38 formatted messages saying `Config space request sent successfully`, from 04:27:31.698 to 04:27:32.206 UTC. These are host configuration-request observations, not successful USB4 attachment or GPU transactions.
- The port buffer reports `USBPortIsConfigured: 0`, `USBPortIsInterDomain: 0`, and wake-on-connect enabled at 04:12:04.503 and 04:27:31.629 UTC.
- These are finite retained recorder buffers, not a continuous boot history or USB-PD wire capture. Absence of an earlier error in them does not establish that no earlier error occurred.

## Values that must not become diagnoses

`m_PortConfiguredStatus = 0xc0000001` initially looked like a useful failure status. The matching driver constructor explicitly writes that value to the field before a connection attempt. Its presence in the disconnected object therefore cannot establish a failed configuration operation. The same object reports `m_CurrentFailureIsFatal = 0` and `m_LastTransferStatus = StatusSuccess`; neither proves that physical negotiation succeeded.

Likewise, a retained retimer-count field of zero is not a measured inventory of the laptop's physical retimers when discovery never established an external link. Raw UCSI version/cache values without verified interpretation or port correlation are not firmware diagnoses.

The UCM cable-property caches do not establish the supplied cable's USB4 rating: one reports a structure size of 8 with zero mode-support flags, while the other has size zero. Neither is a substitute for a verified cable descriptor or a direct comparison with another suitable cable.

USB4KD emitted `Couldn't find FX Relation Type` while trying to describe framework power relations. That helper lookup failed; it is not a controller error. The findings above use the topology, direct state fields and corroborating PnP/WDF results rather than treating that helper output as evidence of missing hardware.

## Expanded recorder, state-machine and ACPI inspection

The initial two targeted recorder reads were followed by enumeration of **all 12 available WPP recorder buffers**: seven in Usb4HostRouter, three in Usb4DeviceRouter, one in UcmUcsiCx and one in UcmCx. This recovered **334 timestamped formatted records**, including 74 UcmUcsiCx records. The retained timestamps range from 04:11:39.347 to 04:27:34.233 UTC, with gaps; this is not a continuous recording of that interval. The ACPI client has no compatible WPP autolog header; its separate WDF recorder was also read.

Microsoft's signed `SmFxDbg.dll` decoded the USB4 port, plug-state manager and root-router engines. Each retained 64 transitions, an empty event queue and zero recorded exceptions. Their current states are respectively `WaitForEventsInDisconnected`, `Unplugged` under `Enabled`, and `RouterOperational`. An engine labelled `Stopped` here is idle between events, not evidence that the driver crashed.

The port history supplies a more specific boundary than topology alone:

1. `ReadingPluggedStateForUSB4` completes with `Success`.
2. `IsUSB4PortPlugged` returns `No`.
3. `ReadingRouterDetected` completes with `Success`.
4. `IsRouterDetectedSet` returns `No`; the path ultimately reports nothing attached and waits disconnected.

These are retained state-machine outcomes, not a time-stamped USB-PD transaction sequence. They show successful register-access handling without a reported USB4 connection. They do not distinguish an Enter_USB exchange that never occurred from failed physical/link training or another firmware interaction.

SmFxDbg could not obtain the UcmUcsiCx engine implementation type from that module's public symbols. The two UCSI rings were instead read using the shared record layout, checked against direct memory reads, and decoded with UcmUcsiCx's own public `StateIndex` and `EventId` enumerations. All **128 retained source-state/event records** mapped to known enums. None contains the enumerated failure, command-timeout, unrecoverable-failure or exhausted-retry indicators checked. The current OPM and command-handler stacks end in `WaitingForCommandOrNotification` and `WaitingForCommand`. Ring records describe a transition's source; destination states must not be guessed from an adjacent record across submachine calls.

The formatted UCSI recorder independently supplies this short sequence:

| UTC time | Retained observation |
| --- | --- |
| 04:27:20.963 | GET_ALTERNATE_MODES command 0x13 completes with data length 0; Error and NotSupported flags clear |
| 04:27:20.984 | Its acknowledgement completes; SET_UOR for logical connector 1 requests DFP, command 0x14 |
| 04:27:21.000 | SET_UOR completes; UCM reports a successful change to DFP |
| 04:27:21.037 | Command/connector-change acknowledgement completes |

The empty alternate-mode result is not a recorded Enter_USB rejection. UCSI and USB4 mode entry must not be treated as the same protocol; Microsoft's [design requirements](https://learn.microsoft.com/en-us/windows-hardware/design/component-guidelines/usb4-design-details-and-general-requirements) explicitly describe the USB4 connection manager as independent of the UCSI software stack. Earlier failures may have been overwritten from these finite buffers.

Matching ACPI symbols also allowed namespace and AML disassembly from the dump. The UCSI device is `\_SB_.UBTC`, with two connector children. Its USB `_DSM` query returns mask `0x0f`; it does not advertise optional function 4, the [data-role-correction override](https://learn.microsoft.com/en-us/windows-hardware/design/component-guidelines/usb4-acpi-requirements#device-specific-method-to-prevent-data-role-swap-for-host-to-host-connections). Absence of that optional function is not itself a demonstrated defect.

The firmware describes a 48-byte UCSI shared-memory region and a 64-byte EC shadow region. **The pages backing both regions are absent from this kernel bitmap dump.** Reads of the mapped regions report missing dump pages; a physical read of the UCSI region also fails. This is a limitation of the artifact, not evidence that those memory reads fail on the running laptop. A different decoder cannot recover those uncaptured bytes. AML was disassembled only; no firmware method was executed and no live MMIO access was performed.

Selected reviewed lines are in [kernel-state excerpts](../evidence/kernel-state-excerpts.txt). They omit addresses and identifying prefixes. No newly established root cause or software repair emerged from the expanded inspection.

## Consequence for the next test

The dump adds a direct check of the cached BIOS PCIe-disable flag and confirms disconnected USB4 state despite USB fallback. It supplies no demonstrated software switch or firmware repair. Cable-dependent negotiation, the ASUS host/PD/retimer path, DEG2 interoperability and shared driver/firmware interactions remain unresolved.

An additional comparison uses hardware already available: connect the ASUS directly to the working Dell using the supplied DEG2 cable and check for a live USB4 P2P network adapter. This tests host-to-host USB4 negotiation, not GPU PCIe tunnelling; see [N0 and its limits](handoff.md#n0-existing-hardware-usb4-peer-test). Suitable alternate-cable and separate USB4/PCIe-peripheral comparisons remain unperformed. Repeating the same snapshot without a changed condition cannot recover the omitted firmware-region pages.

Raw memory, debugger transcripts, symbols and kernel addresses remain private. Only the reviewed findings and artifact hash are published. Method references: [Microsoft USB4KD](https://learn.microsoft.com/en-us/windows-hardware/design/component-guidelines/usb4-kernel-debugger-extension) and [Task Manager live kernel dumps](https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/task-manager-live-dump).
