# Fresh ASUS comparison against the recovered Dell

**Completed and analysed, 1 November:** the [fresh ASUS-Dell comparison](asus-dell-matched-comparison.md) supersedes the preparation status below. The native Task Manager dump and valid-path selection completed; all 35 capture files and the full dump verify. The procedure below is retained for reproducibility, not an instruction to repeat this acquisition.

**Preparation record, superseded by the measured result above.** The [recovered Dell dump and passive trace](dell-dump-recovery.md) supply a working external router/PCIe baseline, loaded UCSI policy and ACPI methods. An identical Dell recollection is not justified by the remaining missing firmware page. The next acquisition targets the ASUS's current normal USB/Billboard fallback using the same DEG2, GPU, PSU and supplied cable.

## Why another ASUS capture

The earlier ASUS dump predates the detailed role traces and the completed temporary Rp-only test. That test's saved record says default DRP was restored and no restoration is pending; the exact original policy was never readable. A current snapshot alongside a new passive trace will distinguish persistent driver policy from handshake ordering without injecting a firmware request.

| Question | Dell baseline | New ASUS evidence to inspect |
| --- | --- | --- |
| When does the partner role change? | Initial partner DFP, then UFP during PD, before a Windows correction request | Align initial attachment, PD contract, role correction, partner flags and USB4 port/router milestones |
| What policy is cached? | `m_IsUsbDeviceControllerEnabled = 1` | Re-extract the same field from current UCSI objects; compare with the earlier ASUS value 0 |
| What does loaded firmware describe? | UCSI `_DSM` mask `0x1f`, function 4 present | Current loaded namespace, supported functions and cached client configuration; disassemble without executing AML |
| Where is USB4 absent? | External router plus PCIe/USB3 tunnels | Root/external router state, tunnels, relevant USB4 histories and policy flags |
| Are inputs comparable? | Build 26200.9818; 14 retained images | Current installed hashes, loaded identities, firmware version and diagnostic-interface state |

ASUS's diagnostic interface remains enabled from the earlier investigation, whereas the new passive Dell capture records it absent. Preserve and record that difference; this collector neither uses the interface nor changes its setting. The two snapshots occur after their traces and cannot supply a wire-level PD recording. A policy difference alone is not a proven repair mechanism.

## Local procedure

The [local entry point](../tools/Capture-ASUSLocalCompare.ps1) imports the verified [deep-comparison kit](deep-compare-capture.md) and invokes its existing passive workflow. Its separate local path avoids the portable entry point's USB-return requirement. Build the source kit into a new local NTFS folder named `USB4-Deep-Compare-resumable`; place the local script and local START/FINISH launchers beside that folder. Leave existing kits/results intact.

1. Run **START-ASUS-LOCAL.cmd** as Administrator on FA507XI, with normal barrel power and DEG2/PSU powered. The collector checks the ASUS model, healthy AMD USB4 host, UCSI binding, kit hashes and internal NTFS free space.
2. At the first prompt, leave DEG2's upstream cable disconnected from ASUS and press Enter. Reconnect to the same tested ASUS USB4 port only at **GREEN**. Keep it connected afterward.
3. After passive recording and endpoint inventory, Task Manager opens. In Details, right-click System (PID 4), choose Create live kernel memory dump file, then **Full live kernel memory dump**. Wait until complete.
4. Return to the capture window and press Enter to find the completed dump automatically, or B to Browse. No pasted path is required. P/cancel preserves a pending run; use **FINISH-ASUS-LOCAL.cmd** on this ASUS to complete it without recapturing. The portable kit's generic FINISH-DUMP launcher is not this local entry point.
5. Leave the dump at its original path. Evidence remains under LocalAppData/USB4-Deep-Compare/Runs, with a machine-bound local latest-run link and copied acquisition source/manifest. No USB compression/transfer is invoked. Preserve these private originals for offline analysis.

The same entry point's `StopTrace` mode addresses only its saved owned session if interrupted. Pending completion verifies the Windows identity, source bundle, owned run path, ASUS target and local-only record. It cannot silently turn a Dell/USB-bound run into a local ASUS run. No network/ICS, firmware, device, driver, boot or security setting is changed; no UCSI requests or live kernel helpers are used.

## Qualification and next analysis

The local entry point passes **28 PS5.1 checks**, including actual manifest verification/file receipts and mocked capture/resume/cleanup, source/machine/target/storage refusal, separate run preservation and failed completion status. The reused collector's existing **183 checks** remain separate. The owner subsequently completed the hardware trace, native Full Task Manager snapshot and valid pasted-path selection. Their measured coverage and limits are in the comparison linked above; automatic/Browse UI paths remain separately software-tested.

Afterward, validate the new trace's loss and decoding coverage, open the new ASUS dump with matching symbols, discover its object addresses afresh, and compare the table above against the recovered Dell. Record missing pages explicitly. Do not repeat the old missing-memory reads, role/mode commands or generic resets unchanged. Any proposed Windows fix still needs an identified applicable control and a result that changes external-router enumeration.
