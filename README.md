# ASUS FA507XI / Minisforum DEG2 USB4 investigation

**Unresolved, 31 October 2026.** The ASUS TUF A15 FA507XI detects ordinary USB functions on the DEG2 but does not enumerate its external USB4 router or RTX 4080 SUPER. The identical assembled dock, GPU, PSU and supplied cable work on a Dell Intel Thunderbolt 4 laptop. A separate full Windows installation on the ASUS reproduces the failure.

**New control: [ASUS-Dell USB4 peer link passed at a reported 40 Gbps](docs/peer-test.md).** Both P2P adapters are Up, and ASUS port telemetry confirms Gen 3 with two bonded lanes using the supplied DEG2 cable. This demonstrates host-to-host link establishment at the ASUS port's advertised negotiated rate; GPU PCIe tunnelling and payload throughput remain untested. The failing condition is still the ASUS-DEG2 pairing.

**New result: [deeper negotiation comparison completed](docs/handoff.md#n5-existing-hardware-partner-handoff-proposed).** The 20:08-20:10 UTC run contains 3,097,071 events, zero reported loss and 4,735 decoded UCSI lines. All 84 diagnostic GET requests completed without a CCI error. The peer reconnected; neither DEG2 attachment produced its router/GPU. Both failures show completed PD/data-role negotiation followed by alternate-mode-only partner reporting. Root cause remains unresolved. The successful direct Dell-DEG2 control below supplies the next comparison. Earlier reset/policy scripts and the standalone memory probe remain retired; their source is available at the [revision before cleanup](https://github.com/49Ssr/asus-fa507xi-deg2-usb4/tree/90ad1d612df03fef1875bcefebe554b1afab42a3).

**[Direct Dell control completed](docs/dell-control.md).** The corrected collector recorded 1,096,876 events with zero reported loss, native USB4 at a reported 40 Gbps, the DEG2 router, NVIDIA binding and working display output. All 41 diagnostic GETs completed; original setting and network snapshots were preserved. All 14 copied Windows images match the current ASUS files by SHA-256. Dell needs no OS `SET_UOR` correction; both ASUS failures perform that correction before alternate-mode-only reporting. This is a targeted negotiation lead, not a proven cause or fix.

## Measured comparison

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
