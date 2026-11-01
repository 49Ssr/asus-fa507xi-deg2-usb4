# ASUS FA507XI / Minisforum DEG2 USB4 investigation

**New firmware lead:** Microsoft Catalog PS8830 CFU packages contain offer words consistent with 1.3.0.4/1.3.0.5, versus this machine's reported 1.3.0.2. Signatures, catalog membership and generic hardware IDs check out; ASUS-specific qualification and recovery do not. Configured Windows Update currently offers no pending drivers. Nothing was installed or flashed. [Candidate analysis](docs/parade-cfu-candidates.md).

**Preconnected startup completed, 1 November:** powered DEG2 was connected to the same ASUS USB4 port before power-on and left connected, as confirmed by the owner. Both post-sign-in snapshots still show Billboard, no external USB4 router and no RTX 4080 SUPER; display N. The 20-second trace has 471,428 events, zero loss/format errors and 14 unknown formats. This sequence did not enable USB4. Initial BIOS/PD negotiation is outside the capture. [Measured observation](docs/cold-start-observation.md), [structured evidence](evidence/cold-start-result.json).

The installed retimer CFU payload has also been reconstructed and verified offline for further analysis. [Firmware findings and limits](docs/firmware-entry-followup.md).

**Firmware investigation continues:** exact-model BIOS 314 contains AMD pre-OS USB4-manager code. Existing ASUS memory also retains raw-client UCSI version `0xffff`; forcing a protocol version is not justified. The Parade driver exposes firmware operations, but its get-feature path returns cached fields. No vendor command was sent. [Evidence and limits](docs/firmware-entry-followup.md). The [preconnected cold start](docs/cold-start-observation.md) has now completed without enabling USB4.

**Policy-only trial completed, 1 November:** Windows accepted policy **1** and automatic role-correction sends fell from **1 to 0**, but DEG2 still produced Billboard fallback, no USB4 router/GPU and no display. The exact driver rollback and owned test-entry/certificate cleanup are verified; manual Secure Boot/original-boot verification is pending. This policy alone is insufficient for this pairing. [Measured result, limits and recovery](docs/role-policy-test-result.md).

<details>
<summary>Earlier policy-test preparation and load stages (superseded)</summary>

**Filter loaded and policy override accepted, 1 November at 12:18 UTC:** Microsoft now reports mask `0x1f`, forced disable-correction and cached/configured policy **1**, compared with the same-boot powered baseline **0**. The filter is Running; startup tracing has zero loss/format errors. This verifies the intervention reached its intended Windows consumer. **USB4/GPU success is not established; one attachment and exact rollback are pending.** [Actual load and current stages](docs/local-test-signing.md).

**Powered fallback baseline completed, 1 November at 12:16 UTC:** original policy 0 in the actual test boot reproduces Billboard fallback, with no external USB4 router/GPU. Startup tracing has zero loss/format errors; enabled ICS is preserved. This qualifies the same-boot control for the reviewed filter. The approved disconnected installation stage is open; no installation result yet. Earlier no-device attachment was owner-confirmed dock power off and is retained separately. [Current stages and evidence](docs/local-test-signing.md).

**Baseline checker corrected, 1 November:** the first baseline stopped before attachment because our parser expected literal `false`, while the real Windows trace reports `0x00000000(false)`. The retained stock-policy startup now validates with zero loss/format errors; 79 workflow checks pass, including that real trace. The guarded continuation reuses it without another UCSI restart. **Driver remains uninstalled; attachment is pending.** [Correction and current stages](docs/local-test-signing.md).

**Actual test boot verified, 1 November at 12:06 UTC:** the owned copied loader is active with TESTSIGNING on, Secure Boot off and Memory Integrity/HVCI running. Full [LocalTest preflight](docs/local-test-signing.md) passed. DEG2 is disconnected and the interactive stock-policy baseline has been opened; no completed baseline result yet. **No experimental driver is installed or loaded.** A fresh same-boot fallback baseline must precede installation; boot acceptance alone is not evidence of a USB4 fix.

**Test boot prepared, 1 November at 11:57 UTC:** the owner approved the [local test-signing route](docs/local-test-signing.md), disabled Secure Boot and returned to the original Windows loader. One owned copied loader now has TESTSIGNING enabled, and only the exact test certificate was trusted. Actual readback verifies the original default, other boot-manager fields and running HVCI are preserved. **No driver is installed or loaded.** The owner must manually select the new test entry; actual test-boot checks and a same-boot fallback baseline precede installation. The [driver review](docs/driver-readiness-review.md) retains 4,631 parser, 36 callback/DDI, 64 workflow and 41 signing/boot checks, with zero project static-analysis results. Native USB4 entry and the original failure remain unresolved.

**Pre-attachment experiment prepared, 1 November:** [role-policy source, controlled test and rollback](docs/role-policy-experiment.md). The unsigned KMDF filter supplies the documented disable-correction policy at UCSI startup; it has **not been installed or loaded**. Native core: 4,631 assertions; PS5.1 workflow: 57 checks with device operations mocked. The real Microsoft client must confirm policy acceptance before a single attachment is allowed. Windows-accepted signing is unresolved; Secure Boot, firmware, drivers and ICS were not changed. This is a causal test, not a verified USB4 fix.

</details>

**[Fresh ASUS-Dell comparison completed](docs/asus-dell-matched-comparison.md).** New 3.17 GB ASUS dump and 35 capture files verify. Current policy remains ASUS **0** versus Dell **1**; all 14 installed Windows images match. ASUS completes its normal data-role correction but still has no external USB4 router. This failure reports USB flag 1 rather than the earlier alternate-mode-only flag 2. No repeat generic capture is queued; native USB4 entry remains unresolved and no Windows fix is established.

**Unresolved, 1 November 2026.** The ASUS TUF A15 FA507XI detects ordinary USB functions on the DEG2 but does not enumerate its external USB4 router or RTX 4080 SUPER. The identical assembled dock, GPU, PSU and supplied cable work on a Dell Intel Thunderbolt 4 laptop. A separate full Windows installation on the ASUS reproduces the failure.

**[Dell dump recovered; policy difference identified](docs/dell-dump-recovery.md).** All 33 returned files and the separate 2.25 GB kernel dump verify. Offline inspection recovers Dell policy flag **1** versus ASUS **0**, plus Dell's additional UCSI ACPI function 4. The new passive trace repeats the successful role ordering. A late freshness cutoff could reject a valid dump; the revised handoff adds automatic/Browse selection, retry and saved-run completion (**183 PS5.1 assertions**). No repeat Dell capture is needed for this failure. ASUS root cause and an applicable Windows fix remain unresolved.

**[Initial CC-role test completed](docs/initial-role-test.md#measured-result-2303-2304-utc):** Rp-only was accepted, but the 30.886-second trace contains no reported attachment or PD negotiation. No external router/GPU appeared. All nine requests completed; default DRP restoration completed and no recovery remains pending. The 238,588-event capture reports zero loss, zero format errors and 118 unknown records. This did not establish the intended initial-role comparison or a fix; do not repeat it unchanged. The [existing-capture follow-up](docs/negotiation-followup.md) remains the role-order and correction-flag audit.

**New control: [ASUS-Dell USB4 peer link passed at a reported 40 Gbps](docs/peer-test.md).** Both P2P adapters are Up, and ASUS port telemetry confirms Gen 3 with two bonded lanes using the supplied DEG2 cable. This demonstrates host-to-host link establishment at the ASUS port's advertised negotiated rate; GPU PCIe tunnelling and payload throughput remain untested. The failing condition is still the ASUS-DEG2 pairing.

**New result: [deeper negotiation comparison completed](docs/handoff.md#n5-existing-hardware-partner-handoff-proposed).** The 20:08-20:10 UTC run contains 3,097,071 events, zero reported loss and 4,735 decoded UCSI lines. All 84 diagnostic GET requests completed without a CCI error. The peer reconnected; neither DEG2 attachment produced its router/GPU. Both failures show completed PD/data-role negotiation followed by alternate-mode-only partner reporting. Root cause remains unresolved. The successful direct Dell-DEG2 control below supplies the next comparison. Earlier reset/policy scripts and the standalone memory probe remain retired; their source is available at the [revision before cleanup](https://github.com/49Ssr/asus-fa507xi-deg2-usb4/tree/90ad1d612df03fef1875bcefebe554b1afab42a3).

**[Direct Dell control completed](docs/dell-control.md).** The corrected collector recorded 1,096,876 events with zero reported loss, native USB4 at a reported 40 Gbps, the DEG2 router, NVIDIA binding and working display output. All 41 diagnostic GETs completed; original setting and network snapshots were preserved. All 14 copied Windows images match the current ASUS files by SHA-256. Dell needs no OS `SET_UOR` correction; both ASUS failures perform that correction before alternate-mode-only reporting. This is a targeted negotiation lead, not a proven cause or fix.

## Measured comparison

ASUS mode inspection completed: 37/37 GETs; current index 1 lacks a readable local entry despite advertised override support. At 22:12 firmware rejected one guarded exit request. The single 22:21 error-status read returned `0x0004`, invalid command parameters. This is consistent with rejection of that diagnostic request; it does not identify the original USB4 negotiation failure or a specific bad field. No software repair is established. [Inspection and exit/error results](docs/handoff.md#next-owner-action-read-retained-error-status-once) and [remaining cable/peripheral comparisons](docs/handoff.md#deg2-cable-and-peripheral-comparisons).

| Environment | Windows build | Microsoft USB4 host driver | External DEG2 router | External GPU |
| --- | --- | --- | --- | --- |
| Dell Intel TB4, initial owner test | 26200.9711 | Not recorded | Present; 40/40 Gbps | Driver installed; HDMI output works |
| Dell Latitude 5540, recorded control | 26200.9818 | 10.0.26100.9818 | Present; native USB4, reported 40 Gbps | NVIDIA bound; image confirmed |
| ASUS, original installation after rollback | 26200.9818 | 10.0.26100.9818 | Absent | Absent |
| ASUS, separate native-boot Windows | 26200.8037 | 10.0.26100.7920 | Absent | Absent |

The separate Windows capture passed its required USB4 host/root, UCSI, I2C and Parade checks: **0 essential preflight issues, 0 external routers, 0 new display adapters**. It contains 7,720 events with 0 reported lost events; 2,441 events lacked matching WPP formats. It was a scoped driver baseline, not an ASUS factory recovery image. [Full result and limits](docs/fresh-windows.md).

A [live kernel snapshot inspected with USB4KD](docs/kernel-snapshot.md) also shows **0 external routers, 0 tunnels and `PcieTunnelsDisabledInBios = 0`**, with the fallback hub/Billboard still present. Offline inspection succeeded; it identified no repair or root cause.

Expanded inspection recovered 12 recorder buffers and decoded the USB4/UCSI histories. Successful register reads are followed by negative USB4 plugged/router-detected checks. The firmware shared-memory pages are absent from this dump. The subsequently completed [USB4 peer comparison](docs/peer-test.md) adds a working host-to-host control, not a GPU PCIe-tunnelling result.

A [guided live connection window](docs/hotplug-window.md) completed at 12:52-12:53 UTC: **80 validated samples, 0 readable firmware buffers, 8,221 ETW events and 0 reported lost events**. Normal kernel memory was readable throughout. Successful root-port register reads still reported USB4 plugged No and router-detected No; Billboard fallback followed. The connection was recorded, but no targeted repair was identified. The [tool](docs/ucsi-memory-probe.md) also passes 64 offline checks; those checks do not establish hardware compatibility.

## Read in this order

0. **[Continuation record](docs/continuation.md)** - recovered context after the previous chat reached its limit, decisions to retain, and the [future diagnostic-tool scope](docs/tool-scope.md).
1. **[Independent review and next tests](docs/handoff.md)** - current state, remaining hypotheses, feasible comparisons and what each outcome would mean. Start here when consulting another engineer or AI.
2. **[Findings](docs/findings.md)** - the failure boundary, `_OSC` grant, Billboard interpretation, evidence limits and hypothesis table.
3. **[Experiment ledger](docs/experiments.md)** and **[hardware](docs/hardware.md)** - completed attempts, invalid tests, exact versions and working comparison.
4. **[Research](docs/research.md)** - primary documentation and separately labelled other-model reports; no verified FA507XI firmware fix has been found.

For the underlying record: [timeline](docs/timeline.md), [private-policy correction](docs/policy-audit.md), [fresh-Windows result](docs/fresh-windows.md), [preparation failure/correction](docs/validation-audit.md), and [test procedure](docs/test-windows.md).

## Evidence available for review

- [Structured observations](evidence/observations.json): capture IDs, event counts, durations where recorded, SHA-256 hashes, comparison outcomes and their provenance.
- [Trace excerpts](evidence/trace-excerpts.txt): timestamps and messages tied to specific captures; identifying prefixes removed.
- Raw ETL/XML/PnP inventories and kernel memory remain private because they contain device/account identifiers and memory contents. The public record permits review of the reasoning; it does not let an outside reviewer independently re-decode the unpublished artifacts. [Publication rules](docs/privacy.md).

The observed failure is before external-router/GPU enumeration. The fresh Windows result weakens a cause confined to the original installation, but leaves common driver/firmware interactions open. A suitable second cable and a separate known-working USB4 peripheral on this ASUS remain untested. The existing UGREEN Revodok Pro 3121 is a conventional 10 Gbps hub and cannot fill that comparison.

## Diagnostic toolkit

The toolkit prepares a separate full Windows installation in a new VHDX and records a connection test. Preparation, native boot and one capture have completed on this machine. Boot-entry removal has not been exercised. Mocked guard tests are documented separately from actual execution.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Prepare-USB4Test.ps1 -Mode Preview
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-Toolkit.ps1
```

Setup uses Windows PowerShell 5.1+, with an Administrator console for mutating modes on the exact FA507XI. Driver binaries and Windows media are not redistributed. See the [procedure](docs/test-windows.md), [audit](docs/validation-audit.md) and [contribution guide](CONTRIBUTING.md). The existing test image can be reused when a new comparison is available; another Windows deployment is not the default next step.
