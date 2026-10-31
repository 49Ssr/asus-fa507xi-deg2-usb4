# ASUS FA507XI / Minisforum DEG2 USB4 investigation

**Unresolved, 31 October 2026.** The ASUS TUF A15 FA507XI detects ordinary USB functions on the DEG2 but does not enumerate its external USB4 router or RTX 4080 SUPER. The identical assembled dock, GPU, PSU and supplied cable work on a Dell Intel Thunderbolt 4 laptop. A separate full Windows installation on the ASUS reproduces the failure.

## Measured comparison

| Environment | Windows build | Microsoft USB4 host driver | External DEG2 router | External GPU |
| --- | --- | --- | --- | --- |
| Dell Intel TB4 | 26200.9711 | Not recorded | Present; 40/40 Gbps | Driver installed; HDMI output works |
| ASUS, original installation after rollback | 26200.9818 | 10.0.26100.9818 | Absent | Absent |
| ASUS, separate native-boot Windows | 26200.8037 | 10.0.26100.7920 | Absent | Absent |

The separate Windows capture passed its required USB4 host/root, UCSI, I2C and Parade checks: **0 essential preflight issues, 0 external routers, 0 new display adapters**. It contains 7,720 events with 0 reported lost events; 2,441 events lacked matching WPP formats. It was a scoped driver baseline, not an ASUS factory recovery image. [Full result and limits](docs/fresh-windows.md).

A [live kernel snapshot inspected with USB4KD](docs/kernel-snapshot.md) also shows **0 external routers, 0 tunnels and `PcieTunnelsDisabledInBios = 0`**, with the fallback hub/Billboard still present. Offline inspection succeeded; it identified no repair or root cause.

Expanded inspection recovered 12 recorder buffers and decoded the USB4/UCSI histories. Successful register reads are followed by negative USB4 plugged/router-detected checks. The firmware shared-memory pages are absent from this dump. A newly identified [USB4 peer comparison using the existing Dell and cable](docs/handoff.md#n0-existing-hardware-usb4-peer-test) is available without another peripheral; it remains unperformed and does not test GPU PCIe tunnelling.

A [scripted UCSI/EC memory probe](docs/ucsi-memory-probe.md) completed a live capture at 12:35 UTC after two launcher corrections. Current-session mapping discovery succeeded, but LiveKD could read neither the 48-byte UCSI block nor the 64-byte EC shadow. No firmware contents or actionable repair were obtained. Offline replay and 40 checks also pass; those software checks do not establish hardware compatibility.

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
