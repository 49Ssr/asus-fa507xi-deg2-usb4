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

## Consequence for the next test

The dump adds a direct check of the cached BIOS PCIe-disable flag and confirms disconnected USB4 state despite USB fallback. It supplies no demonstrated software switch or firmware repair. Cable-dependent negotiation, the ASUS host/PD/retimer path, DEG2 interoperability and shared driver/firmware interactions remain unresolved.

The shortest missing comparisons remain a suitable alternate cable and a separate known-working USB4/PCIe peripheral on the ASUS. See [N1-N4 and their outcome limits](handoff.md#missing-comparisons-in-priority-order). Repeating this same snapshot without a changed condition is unlikely to separate those hypotheses.

Raw memory, debugger transcripts, symbols and kernel addresses remain private. Only the reviewed findings and artifact hash are published. Method references: [Microsoft USB4KD](https://learn.microsoft.com/en-us/windows-hardware/design/component-guidelines/usb4-kernel-debugger-extension) and [Task Manager live kernel dumps](https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/task-manager-live-dump).
