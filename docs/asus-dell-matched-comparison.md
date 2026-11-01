# Fresh ASUS versus Dell: matched evidence comparison

**1 November 2026: comparison completed; no working repair established.** The fresh ASUS passive trace and full native kernel dump reproduce the failure and independently confirm its current policy against the [working Dell baseline](dell-dump-recovery.md). We have enough for this software-state comparison. No repeat capture on either laptop is queued. [Structured observations and exact milestones](../evidence/asus-dell-matched-comparison.json).

## Acquisition and validation

The local ASUS workflow completed with no capture/evidence errors. Pre-dump and after-dump inventory both show USB/Billboard fallback, no external DEG2 router and no NVIDIA-bound external GPU. The owner answered **N** for display output. All **35 capture files** and the separate **3,172,020,224-byte** dump were copied privately with source/copy SHA-256 verification and source stability checks. The original files remain in place. The dump opens offline with snapshot time **00:53:54.969 UTC**; SHA-256 is `FA979A86E3A586CF17A9C04C41564526A1CC748B8F8182DF431EAF6A5773928C`.

The **239,206,400-byte ETL** spans **00:52:05.8475366-00:53:16.8845896 UTC**, 71.0370530 seconds. Decode reports **1,114,490 events, zero lost events/buffers, zero format errors and 342 unknown records**. Matching WPP formats decode 464 UcmUcsiCx, 26 UcmCx, 902 USB4 host and 1,230 USB4 device-router lines. This is actual hardware/artifact validation, separate from the earlier 183 collector and 28 local-entry-point software checks.

The collector injected no UCSI requests. **Windows itself automatically sent 10 normal commands and 10 acknowledgements**, including one SET_UOR. All 10 terminal command/ACK completions are present, without reported CCI error, unsupported or busy completion. The dump was accepted using a valid pasted path; automatic discovery/Browse were not exercised by this owner run. No USB return transfer was needed.

## What the new comparison establishes

DFP/UFP below describe the **partner**. A partner DFP implies the laptop is the USB device side; partner UFP implies the laptop is the USB host side. These are firmware/Windows reports, not physical packet capture.

| Observation | Fresh ASUS failure | Working Dell |
| --- | --- | --- |
| Initial Type-C role | Partner DFP; USB flag 1; laptop power consumer | Same initial report |
| First PD report | Partner still DFP at 00:52:17.0075650 | Partner already UFP at 00:17:44.9977521 |
| Windows correction | Yes at 00:52:17.1299775; SET_UOR(DFP) at .1464315 | No; no recorded OS SET_UOR |
| Correction result | Completed at .1631249 with CCI Error=0; Windows reports local DFP success | Not requested |
| Later partner report | UFP at .2060961; **USB flag 1** | UFP / USB flag 1 |
| Cached OPM device-controller policy | **0**, client PPM configuration also 0 | **1** |
| UCSI ACPI supported mask | `0x0f`; function 4 absent | `0x1f`; function 4 returns `UDRS` |
| USB4 result | No external router/tunnels | Operational external DEG2 router; PCIe and USB3 tunnels |
| Installed Windows images | All 14 captured images match Dell by SHA-256 | Same files |

ASUS is still BIOS 314 on build 26200.9818. Loaded module metadata and exact-symbol inspection support the comparison of key USB4/UCSI objects. Current ASUS USB4 capabilities granted are `0x0f`; `PcieTunnelsDisabledInBios = 0`. This is not a newly discovered BIOS PCIe-disable setting or a missing NVIDIA-installation explanation.

ASUS's selected PD RDO is `0x1384b12c`, versus Dell's `0x438781e0`; the contract reports differ and their causal relevance has not been tested. ASUS also retains the earlier diagnostic-interface value 1, while the new Dell passive capture records it absent. No value was changed to make these conditions artificially equal.

## Two useful refinements

**The USB4 controller detects no router before and after the OS correction.** Root DFP port 2 successfully reads its plug state at 00:52:17.0829942 and router-detected state at .0830516; both decisions are No, before SET_UOR. The corresponding checks at 00:52:27.8953049/.8953782 are also No, after correction. This places the observed failure before external-router enumeration and shows a completed data-role request did not bring that router into view. The early No readings are not proof that Windows caused the failure, nor do they expose whether Enter_USB was sent or rejected.

**The earlier alternate-mode-only report is not a required marker of the failure.** Earlier ASUS captures reported flags `0x2` after correction. This fresh failure instead reports `0x1` (USB), and the external router still never appears. Preserve both observations. A physical mux/firmware issue is not ruled out, but the PPM's alternate-mode-only flag alone cannot explain every retained failure. Repeating the rejected mode exit or guessing an alternate-mode index is not justified by this comparison.

The report ordering is more informative than a simple elapsed-time argument: the later UFP report appears about 274 ms after ASUS's initial partner report, versus about 279 ms on Dell. This does not establish that ASUS merely needs a longer wait. The recorded trace runs for over a minute.

## What this means for a Windows fix

Microsoft describes firmware-handled role switching for the [UCSI/embedded-controller design](https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/ucsi). It also documents that the [USB4 connection manager has no software dependency on UCM/UCSI](https://learn.microsoft.com/en-us/windows-hardware/design/component-guidelines/usb4-design-details-and-general-requirements#usb-type-c-requirements). Therefore a completed SET_UOR is not a software guarantee of native USB4 discovery/entry.

The [ACPI function-4 policy](https://learn.microsoft.com/en-us/windows-hardware/design/component-guidelines/usb4-acpi-requirements#device-specific-method-to-prevent-data-role-swap-for-host-to-host-connections) explains an available platform control over correction; it is not a demonstrated ASUS registry repair. Dell's underlying XDCE/UDRS field values remain absent from its dump, so its cached 1 cannot be attributed uniquely to function 4. Simply forcing ASUS's flag to 1 could suppress the step that currently obtains its host data role. That hypothetical change has not been qualified or performed.

The remaining target is **ASUS's firmware/controller path for native USB4 discovery and entry across the PD/data-role transition**, including what it does after Windows requests DFP. The captures do not identify a faulty instruction, accepted update image or supported Windows control for that path. Continue static component/call-path analysis using these artifacts; another generic dump, repeated correction, mode exit, device reset or unverified register write does not close that gap. No new state-changing test or flash is prepared.

## Coverage and preservation

The dump contains only the root USB4 router and no tunnels. Its later idle D3/RouterPoweredDown state is a snapshot observation, not an established cause; the working Dell snapshot also contains idle D3 states. USB4KD relation-helper errors occur while topology is supplied. Missing WDFLDR input and unavailable ACPI-client Fdo type queries are debugger/input limits; the required OPM and PPM-config values were recovered directly through the typed PPM object. No AML was executed and the retired missing-firmware-buffer reads were not repeated.

Enabled ICS bindings and every pre-existing adapter record match before/after; one dock network adapter appears with attachment. The collector made no network, firmware, driver, registry, boot or security setting writes, and no live kernel helper was used. Raw traces, dump, identity-bearing logs and source/copy receipts remain private. The selected public evidence contains no machine addresses, serials, accounts or private paths.
