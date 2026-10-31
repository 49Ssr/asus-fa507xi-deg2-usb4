# N0: ASUS-Dell USB4 peer link

**31 October 2026: passed for adapter enumeration and link status on both machines.** The owner followed the direct ASUS-Dell comparison using the supplied DEG2 cable. ASUS PowerShell text and a Dell PowerShell photograph both show `USB4(TM) P2P Network Adapter` with status `Up` (aliases Ethernet 4 and Ethernet 9 respectively).

| Pairing with the supplied cable | Observation | Scope |
| --- | --- | --- |
| DEG2 and Dell Intel TB4 | External router at 40/40 Gbps; NVIDIA driver and HDMI output work | Existing eGPU control |
| ASUS and Dell directly | USB4 P2P adapter Up on both | New host-to-host link control |
| DEG2 and ASUS | USB fallback/Billboard; no external router or GPU | Unresolved failing pairing |

The ASUS has now established a USB4 interdomain link with a different peer. This weakens a blanket explanation that its USB4 path cannot operate at all and strengthens pairing-dependent interoperability as a lead. The observation does not establish GPU PCIe tunnelling, physical link rate, error margins, sustained data transfer or workload stability. A supplied cable that works in two pairings can still participate in a failure with the third pairing; it is not universally exonerated.

No ping, file transfer or throughput measurement was reported. The Dell photograph's background USB4 settings contain DEG2 metadata; its displayed 40 Gbps must not be reassigned to the ASUS-Dell peer link. No physical peer rate has been recorded yet. The pasted/screen evidence is owner-supplied; no identifying raw photograph or full adapter inventory is published here.

## Working-link rundown, prepared but not run

[Capture-USB4Peer.ps1](../tools/Capture-USB4Peer.ps1) records three seconds of USB4 ETW while the direct peer link stays connected. Enabling the existing provider set requests rundown records, which may expose the root port's reported link speed, width and state for comparison with the failed DEG2 recording. Availability and interpretation of those fields require analysis after capture; recording alone does not measure throughput.

```powershell
# Safe default: print the plan.
powershell.exe -NoProfile -File .\tools\Capture-USB4Peer.ps1

# Administrator on ASUS; keep both peer-link ends connected and Up.
powershell.exe -NoProfile -File .\tools\Capture-USB4Peer.ps1 -Mode Capture
```

The script reuses ETW helpers that completed the guided DEG2 recording. It requires exactly one Up USB4 P2P adapter, checks its state again after capture, stops only its own uniquely named trace, and keeps output under ignored `local/`. It does not load LiveKD, restart a controller, flash firmware or configure networking. The saved adapter `LinkSpeed` is a virtual-NIC value, not a physical USB4 measurement. Windows PowerShell 5.1 parsing and Preview passed; actual execution of this new rundown wrapper remains unperformed.

## Firmware/support consequence

Minisforum's [official DEG2 support section](https://www.minisforum.com/pages/product-info) was rechecked on 31 October: headings for downloads are present, but no verified applicable DEG2 firmware image was obtained. That does not exclude an unpublished support package. The ASUS UK BIOS page could not be re-read through the research tool during this check; the previously verified BIOS listing is not presented as a fresh complete search.

For vendor escalation, report the three pairings above and ask which exact host PD/retimer or DEG2 firmware component addresses this negotiation failure. The observed DEG2 router firmware is 62.62; that number does not independently identify its PD-controller firmware. Another model's updater is not a verified fix for FA507XI or this dock revision.

Method source: [Microsoft USB4 interdomain connections](https://learn.microsoft.com/en-us/windows-hardware/design/component-guidelines/usb4-interdomain-connections). Remaining hardware comparisons and their limits are in the [handoff](handoff.md#deg2-cable-and-peripheral-comparisons).
