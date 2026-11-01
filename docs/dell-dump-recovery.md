# Dell dump recovery and platform-policy comparison

**Subsequent matched comparison completed:** the [fresh ASUS trace/dump](asus-dell-matched-comparison.md) independently confirms current ASUS policy 0, failed external-router detection before/after correction, and a post-swap USB-capable report. The earlier outstanding ASUS acquisition is now complete; generic recollection is not queued.

**1 November 2026: the Dell capture is recovered; do not repeat it for the failed handoff.** The separate dump placed in the USB root opens in Microsoft's offline debugger. The returned trace, firmware tables, driver images and metadata also verify. ASUS USB4 failure remains unresolved. [Structured evidence](../evidence/deep-compare-recovery.json).

## What was preserved and recovered

The second Dell run recorded a healthy external DEG2 router and NVIDIA-bound GPU before its dump selection failed. Its original status remains `NotCompleted`, phase `DumpValidation`; the completed return manifest correctly says no full dump was included. That original record has not been rewritten as a successful end-to-end collection.

All **33 returned files** passed part, compressed-stream and raw SHA-256 verification and were copied to a private recovery directory. The separate **2,248,310,784-byte** dump was copied from the USB root, read back and matched against source SHA-256 **A7112995C96CF9E6F3ECBB15407AA6643AD5C252957A4994289319726ACBD789**. USB originals were left unchanged. Debugger snapshot time is **00:20:19.337 UTC**. The dump contains the Intel host, operational external DEG2 router, PCIe tunnel and USB3 tunnel. The original capture has no after-dump inventory or owner display-output answer; the recovered topology supplements that gap without inventing either observation.

The retained files identify Dell Latitude 5540, BIOS 1.32.0, Windows build 26200.9818. All 14 copied Windows images match the earlier Dell/current ASUS comparison by SHA-256. Matching symbols were used for offline object and namespace inspection. The standalone dump is associated with this run by owner provenance, timing, UCSI identity and the matching Intel/DEG2 topology; a separate debugger SMBIOS query failed and is not claimed as an independent model check.

## Why the handoff rejected a valid dump

V2 printed the full-dump instructions, then waited for a separate Enter press before recording its freshness cutoff. The recovered dump's source modification time is **00:20:22 UTC**, while the recorded cutoff is **00:20:55.527 UTC**. The dump therefore predates that cutoff even though it follows the recorded passive observation. This collector ordering defect can independently reject a valid file created after the displayed instructions. The exact entered path was not retained, so a malformed path is not established as the sole cause.

The revised collector uses the timestamp of the saved post-observation inventory, before displaying instructions. After completion, Enter searches Task Manager's standard dump directory; Browse selects a file. A quoted file path, a folder containing one eligible dump, or a mistakenly repeated filename is also accepted. Invalid input can be retried. Pending/cancel preserves the trace and records `TraceCaptured_DumpPending`; **FINISH-DUMP.cmd resumes that same saved run on the same laptop without another attachment trace**. The launcher remains open at completion. This resume facility applies to new runs with the revised kit; the existing V2 run was recovered offline and needs no migration or repeat.

Microsoft documents the standard dump directory, full-kernel selection and possible omitted memory in the [Task Manager live-dump procedure](https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/task-manager-live-dump). Header/freshness checks alone do not certify useful memory coverage.

## Passive handshake was captured

| Measurement | Recovered result |
| --- | --- |
| ETL | 188,874,752 bytes; 00:17:32.4648255-00:19:16.6873458 UTC; **104.2225203 seconds** |
| Decode | 654,212 events; zero reported event/buffer loss; zero format errors; **257 unknown records** |
| Initial reported attachment | 00:17:44.7184187: connected, power consumer; partner DFP / USB flag 1 |
| PD-time report | 00:17:44.9977510: power consumer with PD contract; partner UFP / USB flag 1 |
| Windows decision | PD negotiation succeeded at 00:17:45.1652218; role correction **No** at 00:17:45.3105086; no recorded OS SET_UOR |
| Final evidence | Pre-dump inventory: healthy external router and NVIDIA binding. Later snapshot: operational external router and PCIe/USB3 tunnels. |

The nominal 45-second sleep is not the actual trace duration: inventory and workflow time extended the retained interval. The trace stops before the interactive dump step. The later dump cannot reconstruct every earlier transient flag or supply physical PD packets. This second passive Dell run corroborates the previous host-role ordering without diagnostic UCSI GET/SET injection by this collector.

## A persistent policy difference is now recovered

| Same-image comparison | ASUS earlier dump | Dell recovered dump |
| --- | --- | --- |
| OPM `m_IsUsbDeviceControllerEnabled` | **0** | **1** |
| UCSI UUID `_DSM` supported-function mask | `0x0f` | `0x1f` |
| Documented function 4 exposed | No | Yes; returns `UDRS` |
| Function 3 | Present | Present; returns `XDCE` |
| Recorded role-correction path | Yes on DEG2 failure | No on working DEG2 control |

Dell's loaded UCSI namespace exposes the standard UCSI UUID and function 4 that ASUS's inspected method omits. Microsoft documents [function 4 as a platform policy for disabling UCSI data-role correction](https://learn.microsoft.com/en-us/windows-hardware/design/component-guidelines/usb4-acpi-requirements#device-specific-method-to-prevent-data-role-swap-for-host-to-host-connections). The cached Dell value supplies the persistent-policy comparison that the earlier trace alone could not.

**Limit:** Dell's `UDRS` and `XDCE` are fields in a firmware operation region. The mapped page is absent from this dump; two bounded offline byte reads explicitly failed. Neither field's value was recovered, no AML was executed, and the cached flag cannot be attributed uniquely to function 4. USB4KD also emits helper relation errors while producing topology; these are debugger limitations, not recorded controller failures. Routers' D3 power state in this idle snapshot does not by itself indicate negotiation failure.

This strengthens the platform-policy hypothesis but does not establish that suppressing ASUS's correction would repair USB4. Dell already reports partner UFP during PD, before its No decision; ASUS does not. The earlier working ASUS-Dell peer link also survived a rejected correction. **No supported registry fix, applicable firmware patch or new state-changing experiment is established.** The next acquisition, if needed, is a fresh normal-fallback ASUS snapshot/passive trace against this recovered Dell baseline, not a repeat Dell run. Analysis must continue separating the policy decision from the missing native USB4 entry.

## Qualification and Ethernet handoff

The revised software passes **183 Windows PowerShell 5.1 assertions**. New cases cover early valid timestamps, quoted/file/folder/repeated-filename inputs, automatic selection, mocked Browse/cancel/retry, JSON pending-run resume, no second trace and preserving an already-qualified snapshot. Native read-only inventory/static-input checks remain included. New hardware attachment, Task Manager UI and Browse UI were not exercised by these tests. Historical large-file compression/reconstruction checks remain separate.

The existing direct Ethernet link is up at **1 Gbps**. Dell's SMB port answers, but a usable authenticated share was not established from this session; SSH and WinRM endpoints did not answer the bounded probes. This is evidence that Ethernet transfer is feasible, not a completed replacement transport. No sharing, firewall, network, device, firmware or boot setting was changed. Do not disturb the existing Internet-sharing arrangement to recover data that is already safely copied.
