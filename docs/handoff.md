# Independent review and next tests

**31 October 2026: unresolved.** This page is the entry point for a second opinion, including Claude. The goal is to identify the shortest discriminating test or a verified applicable fix. No root cause has been established.

## Evidence to read first

1. [Findings](findings.md), including the `_OSC`, Billboard and USB4-version caveats.
2. [Separate full-Windows result](fresh-windows.md), including its missing drivers and partial WPP decoding.
   [Live kernel snapshot](kernel-snapshot.md) adds offline USB4KD topology, direct PCIe policy and retained recorder results.
3. [Experiment ledger](experiments.md), [exact hardware](hardware.md), [structured observations](../evidence/observations.json) and [trace excerpts](../evidence/trace-excerpts.txt).
4. [Research](research.md) and [private policy audit](policy-audit.md) before proposing a registry or firmware change.

## Current state

- ASUS FA507XI, Ryzen 9 7940HS, internal RTX 4070 Laptop; BIOS 314. Its documented USB4 port is 40 Gbps; the laptop is not being described as TB4-certified.
- DEG2 / JHL9480, Gigabyte RTX 4080 SUPER WINDFORCE V2, Cooler Master 1000 W PSU, original supplied DEG2 cable. Identical assembly works on the Intel Dell: external TBGAA router, firmware 62.62, 40/40 Gbps, NVIDIA driver and HDMI output.
- Original Windows: 25H2 26200.9818, USB4 driver 10.0.26100.9818. Original Parade SPB 1.0.8 / HID 1.0.11 restored. Related-model trial packages removed. Private v2 override absent; Secure Boot retained and test-signing disabled.
- Separate native-boot Windows: 26200.8037, USB4 driver 10.0.26100.7920. Required host/root/UCSI/I2C/Parade devices healthy before and after connection; no external router or new GPU. The shared firmware and selected OEM drivers remain common variables.
- ASUS host/root initialize and firmware grants USB `_OSC` controls `0xf`; only ordinary USB hub/Billboard fallback appears. This is earlier than the missing NVIDIA adapter, PCIe authorization of an enumerated external router, or GPU workload performance.
- Offline USB4KD inspection completed on the 04:27 live kernel snapshot: one host/root, zero external routers, zero tunnels, cached `PcieTunnelsDisabledInBios = 0`; fallback devices still Started. Both logical UCM connectors report local DFP data roles. No root cause or repair emerged; the snapshot is not a PD wire capture.
- Expanded inspection recovered all 12 available WPP buffers and decoded three USB4 histories plus both UCSI rings. Register reads succeed but USB4 plugged/router-detected checks return No. The BIOS's UCSI and EC shared-memory pages are absent from the dump; that gap cannot be repaired by another decoder. [Detailed result](kernel-snapshot.md#expanded-recorder-state-machine-and-acpi-inspection).
- All four plug orientations, EC reset, graphics mode changes, OS file repair, scoped controller reinstall and retimer restarts were ineffective. The v2 override was ignored and is an invalid negative test of its intended path.
- No second suitable cable or known-working separate USB4 peripheral is available at last report. The spare UGREEN cable was reported unsuitable. The existing UGREEN 3121 is a 10 Gbps USB-C hub; its USB/Ethernet/display operation would not validate USB4/PCIe.
- The owner prefers Windows diagnosis using the hardware already available. There is no spare suitable cable or USB4 hub; do not make obtaining another hub the required next step. A detailed ASUS report has already been sent. No verified applicable FA507XI PD/USB-C or DEG2 firmware image was found in the inspected sources.
- Support update, 31 October: the owner reports that an ASUS US support agent promised handover through an escalated ticket to the relevant ASUS department. Completed internal handover, engineering review, a diagnosed cause and an applicable firmware release remain unconfirmed. Case and agent identifiers remain private.
- N0 is complete: the ASUS-Dell direct USB4 peer link shows P2P adapters Up on both machines with the supplied DEG2 cable. A completed 13:37 rundown confirms a reported 40 Gbps physical link, Gen 3 with two bonded lanes, both Up. The P2P virtual NIC's 20 Gbps value is not the physical-rate observation. Payload transfer and GPU PCIe tunnelling remain untested. [Evidence, register fields and limits](peer-test.md).

## Current action

The deeper ASUS comparison completed on 31 October, 20:08:08-20:10:47 UTC; peer negotiation worked, both DEG2 attempts failed. The [direct Dell control](dell-control.md#measured-result) subsequently succeeded at 21:25-21:27 UTC: native USB4 at a reported 40 Gbps, external router, NVIDIA-bound GPU and display output. All 14 copied Windows images match current ASUS files. Dell performs no OS `SET_UOR` correction, whereas both ASUS DEG2 failures send one successfully before alternate-mode-only reporting. Role-policy origin and later ASUS mode entries have now been inspected. The 21:58 inspection confirms advertised override support and prepares the guarded one-exit experiment below. Hardware effect and the causal role of data-role correction remain unproven.

### Next owner action: inspect the ASUS mode tables

**Completed at 21:58:02-21:58:09 UTC:** 37/37 GET requests completed, with no transport failure, busy result or expired budget. The powered DEG2 remained connected; no external router or new GPU appeared. This fills the earlier index-0-only gap.

| ASUS connector 1 observation | Exact result / interpretation |
| --- | --- |
| Partner mode 0 | `01 ff 45 00 1c 00`: SVID `0xff01`, VDO `0x001c0045`; repeated replies agree |
| Partner mode 1 | Empty; no later Intel SVID appears before the returned list terminates |
| Local mode table | Reported count 1; index 0 is OEM SVID `0x0b05`, VDO zero; index 1 empty |
| Current / supported modes | Current index `1`; supported bitmap `0000`. The current index lacks a readable local entry under the UCSI 1.22 interpretation. |
| Advertised optional features | `0xbd`: alternate-mode details and alternate-mode override support both set |
| Error status | Zero before and after |
| Network / interface | Diagnostic DWORD unchanged. Adapters, DHCP/interface settings, DNS, default routes and ICS match; one link-local IPv4 address appeared on unused DEG2 Ethernet. No network setting was written. |

These are PPM reports, not raw PD discovery or proof of physical mux selection. The inconsistent mode table and reported UCSI version `ff.f.f` still require interpretation. The absence of Intel SVID in this returned list does not prove native USB4 is unavailable. A previous comparison transcribed the ASUS VDO as `0x00001c45`; the six retained bytes establish `0x001c0045` instead.

The GET engine is shared with the successful Dell implementation. Its 43 query/workflow checks and the existing 60 toolkit checks pass in Windows PowerShell 5.1 with system/native calls mocked. ASUS host/preparation/native-tool guard bodies remain unchanged; the successful private Dell bundle remains frozen.

### Next owner action: one current-mode exit

**Prepared; hardware execution pending.** `TestModeExit` tests whether leaving the PPM-reported alternate mode allows USB4 negotiation to recover. This changes protocol state once. Its rationale is the current-mode report plus advertised override support, not a demonstrated cause or repair. The current index is absent from the reported local table, so firmware may reject it; this does not select or enter a guessed Thunderbolt mode.

Keep powered DEG2 connected to the ASUS USB4 port and run from Administrator Windows PowerShell in the prepared checkout:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Capture-USB4PartnerSwap.ps1 -Mode TestModeExit
```

The collector requires the exact healthy ASUS UCSI device, existing native-tool hashes and already-prepared interface. It checks for DEG2 Billboard fallback and refuses an already-present DEG2 router. Fresh capability, connector status, current-mode and exact DEG2 partner-PDO replies must match the captured state. It starts the existing bounded ETW profile, waits five seconds, repeats target checks and preserves a spontaneously recovered router.

Only then can it send `SET_NEW_CAM` once: connector 1, current index 1, EXIT, mode-specific data zero; CONTROL high `00000000`, low `0101000F`. [UCSI 1.22 tables 4-31/4-32 and section 4.6.4](https://www.intel.com/content/dam/www/public/us/en/documents/technical-specifications/usb-type-c-ucsi-spec.pdf) define the current index, enter/exit request and advertised override feature. No ENTER, data-role swap, reset, registry write, device restart or firmware-image write is requested.

Keep the cable connected until completion. A completed request is followed by 20 seconds of passive observation, device milestones and GET status/current-mode replies. A rejection, busy/transport result or failed GET stops further firmware commands; intent, raw replies, trace and snapshots remain private under `Runs/*-ASUS-mode-exit-*`. The dock connection may drop. After completion, ordinary disconnection/reconnection restarts normal attachment negotiation if needed; no automatic mode re-entry is attempted. A completed command alone is not a repaired link: check for the external router, new GPU and display output.

`Test-ModeExit.ps1` passes 100 PS5.1 checks covering packet encoding, target/refusal guards, stopping on errors, one-request limits, spontaneous recovery and trace cleanup. All hardware operations in these tests are mocked. Actual ASUS response and effect remain unmeasured.

Microsoft's [sample ACPI client](https://github.com/microsoft/Windows-driver-samples/blob/main/usb/UcmUcsiAcpiSample/UcmUcsiAcpiSample/Acpi.cpp) maps firmware role-correction policy/device-controller status into `UsbDeviceControllerEnabled`. The existing ASUS dump has that configuration and the OPM's cached value false. This explains why the correction policy is enabled; it does not establish that suppressing a necessary host-role change would repair the link. No supported registry replacement for this policy has been established.

### N5: existing-hardware partner handoff, proposed

**Executed, unresolved.** The earlier attempt stopped before trace creation because the peer adapter was not Up. The revised [collector](../tools/Capture-USB4PartnerSwap.ps1) and [shared library](../tools/Usb4Capture.Common.ps1) subsequently completed all three phases. Their instrumentation is described below the measured result.

| Measurement | Observed result |
| --- | --- |
| ETL interval and retained size | 20:08:08.754-20:10:47.787 UTC; 159.033 seconds; 590,479,360 bytes, below the cap |
| Trace decoding | 3,097,071 events; zero reported lost events/buffers; zero formatting errors; 726 unknown records remain |
| Decoded driver messages | 4,735 UcmUcsiCx; 62 UcmCx; 5,285 USB4 host; 3,048 USB4 device-router lines |
| Live recorder snapshots | All three debugger transcripts reached their start/end markers; ACPI client WDF logs supplement its unavailable WPP log header |
| Firmware GET batches | 28 per phase, 84 total; every native request returned a completed response with CCI ErrorIndicator zero |
| Working peer | Reconnected; peer adapter Up and interdomain tunnel created |
| DEG2 handoff and fresh attachment | No external router/new display adapter before or after active queries |
| Existing Internet sharing | Upstream/downstream ICS bindings preserved. Expected device change was P2P removal and appearance of unshared DEG2 Ethernet. |

Both failed attachments have the same recorded order. For the handoff, firmware reports the connector at 20:09:25.659, PD state succeeds, then `SET_UOR(Dfp)` completes at 20:09:25.903. At 20:09:25.955 a connector-status reply reports partner UFP with `PartnerFlags:0x2[AltMode]`; Windows reports operating modes `0x40 -> 0x20`. The fresh attachment repeats this order at 20:10:24.108, .360 and .421. These reports precede our active query batches. No USB4 router follows. This identifies a useful comparison boundary; the mode change is not established as the cause or a confirmed DisplayPort-only mux selection.

The trace contains 108 UCSI command sends: 107 successful completion indications and one error completion, with all 108 ACK completions accounted for. The error is `SET_UOR` during the **working peer** connection, not either failed DEG2 attachment. No UCSI timeout was observed. The first peer GET_ERROR_STATUS returns `0x0010` (CC communication error); both DEG2 batches return zero. This weighs against a command-mailbox stall as the recorded failure mechanism, while not excluding a lost unsolicited firmware notification.

There are also firmware-interface consistency questions. Connector 1 reports supported CAM mask `0000`, current CAM `01`, and total PPM mode count one; its repeated partner-mode replies are stable. Cable speed bytes `0002` are the same in working-peer and DEG2 phases and decode implausibly under the published UCSI speed field. The CLI displays UCSI version `ff.f.f`. These values need validation against firmware/tool interpretation and further mode-list offsets. They do not establish a slow cable, the identity of mode 1, or an actionable register patch. [UCSI specification, tables 4-24, 4-29, 4-31 and 4-39](https://www.intel.com/content/dam/www/public/us/en/documents/technical-specifications/usb-type-c-ucsi-spec.pdf).

The procedure did not preserve every power-state condition: the root router FDO exits D0 at 20:09:19.619 after peer removal, before DEG2 attachment. Parent host and child-router state must be distinguished. This is not a controlled proof that holding the whole domain awake does or does not help.

ETL SHA-256: `9DD59171EF0D8164652EDE617D7CC5813D1E36A62F986A83F9D42C44AEDBA114`. Raw trace, per-phase firmware replies, snapshots and networking inventories remain private. The public observations record counts and conclusions, not a full independently decodable trace.

### Instrumentation and recorded procedure

| Layer | Requested evidence | Limits to check during analysis |
| --- | --- | --- |
| Windows bus trace | 27 USB4/UCM/UCSI, USB-stack, SPB, ACPI, power and PnP/PCI providers; USB transfer/header/payload flags included | Requested providers can emit no events. FullDataBusTrace includes at most 4 KiB from a supported transfer, not arbitrary firmware traffic. Check actual provider coverage, event loss and time bounds. |
| Driver flight recorders | All available buffers for five USB4/UCM/UCSI modules, WDF logs and USB4 topology, collected through signed LiveKD/KD after each passive observation | Finite circular histories; formatter availability differs by module. Transcript completion does not establish successful decoding of every buffer. |
| Supported firmware interface | Up to 28 GET requests per phase: error status first, capabilities, connector/cable/CAM status, local/partner PDOs and repeated partner alternate-mode reads | Queries actively exercise the firmware. They follow the passive window and its recorder snapshot, with separate timestamps and a second PnP inventory. Unsupported commands or raw CLI exit codes require interpretation. |

The earlier USB keyword mask `0xF861B` omitted transfer headers and payload. A policy-manager WPP GUID present in the matching UCM symbols was also missing from the request list; it is not currently registered, so adding it is not evidence it will emit. Five additional matching PDBs were verified and processed for available formatting. USBHUB3 private WPP formats may remain unavailable.

**Comparison sequence:** verify the ASUS-Dell peer link, start ETW, disconnect/reconnect only the Dell end to capture a fresh working peer negotiation, then leave the ASUS end attached and move the Dell end into powered DEG2 upstream. If no new display adapter or DEG2 router appears, record a second DEG2 attachment by disconnecting/reconnecting the ASUS end. ETW remains active across these transitions. Green prompts mark requested insertion times; actual physical timing must be correlated with events. A newly appearing router/display adapter stops the comparison from deliberately disconnecting that potentially useful connection.

The already-awake peer domain is a hypothesis to test, not an established idle-power cause. Peer negotiation is a successful physical-link control, not a test of GPU PCIe tunnelling. The second DEG2 attachment also changes connection history and is not a full hardware cold reset.

**Preparation:** Microsoft documents `TestInterfaceEnabled` for the existing UCSI driver. Read-only examination of this machine's matching `UcmUcsiCx.sys` confirms that its enable function reads the per-device DWORD without the private USB4 test-signing gate. `PrepareUcsi` is restricted to the FA507XI, exact healthy UCSI instance and audited driver hash. It saves the original DWORD state and private Ethernet/IP/DNS/route/ICS configuration before changing that single value, then restarts only the UCSI device. A USB-C link can reconnect during that restart. Network configuration is not edited.

On the owner's already-prepared checkout, from Administrator Windows PowerShell:

```powershell
$test = Join-Path $PWD 'tools\Capture-USB4PartnerSwap.ps1'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $test -Mode PrepareUcsi
```

After preparation succeeds, connect ASUS directly to Dell with the supplied cable, keep both awake and DEG2 powered, then follow the collector's prompts:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $test -Mode Capture -Scenario Compare
```

After examination, restore the exact original setting and restart the same UCSI device:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $test -Mode UndoUcsi
```

The collector defaults to Preview. It uses a unique sequential ETL capped at 1 GiB, closes only its own session, and records file-cap risk. Each recorder call is limited to 60 seconds; firmware probes have a 60-second phase budget and five-second command limits. Native child processes use an owned job. Kernel-helper unloading is not independently verified. Raw results remain private in `local/`. No firmware flash, driver-package installation, boot-security change or private USB4 policy override is performed.

**Tool provenance:** UcsiControl 10.0.26572.1000 was extracted without executing/installing Microsoft's MUTT 3.0.1 MSI. The native EXE is unsigned; it is a user-mode program from the official package, pinned by SHA-256 `22AC51EF4503E4FF3344B7C33FFB7509F43D26F5F4942A2C382DD91F4FB7B9A7`. The package hash is `093BD7FB8DBC4A3B8EED909657CA58701235B328C101BDE0AB63099FD4EB95A1`. Debugger executables have valid Microsoft signatures. Binaries, symbols and machine-specific state are not redistributed; this public source is not a standalone install bundle.

**Candidate mechanism, unproven:** the extracted FA507XI `UBTC.M318` AML copies firmware status into the OS mailbox and then clears parts of the firmware shadow. An upstream ASUS UM325 UCSI fix avoids an extra status read because a similar destructive copy can lose a pending notification. The new trace accounts for all observed command/ACK completions, including successful role correction on both DEG2 attachments; it does not demonstrate that mailbox quirk. Unsolicited notifications and physical mode entry remain separate questions. Comparing direct successful Dell-DEG2 enumeration is more discriminating than patching a completed command path on speculation.

Windows UCSI exposes firmware commands/status rather than every packet on the USB-C CC wires. This capture does not supply a complete USB-PD wire transcript. If the failure remains entirely inside firmware, vendor firmware logging or a suitable physical PD analyzer is the next instrumentation layer. [Primary sources and exact precedent](research.md#deeper-negotiation-capture-and-ucsi-workaround-precedent).

## Additional hardware comparisons, currently unavailable

**N0 passed its adapter/link-status check; N1-N4 remain unperformed and need unavailable additional hardware.** These are optional comparisons for future access, not instructions to buy or obtain another hub now. For DEG2 comparisons, keep the same assembled GPU/dock/PSU, correct upstream port/mode and laptop barrel power. Change one named variable per comparison. Record the protocol/device milestone, not just fan activity or the Windows warning.

### N0: existing-hardware USB4 peer test

Microsoft documents [USB4NET between two Windows PCs](https://learn.microsoft.com/en-us/windows-hardware/design/component-guidelines/usb4-interdomain-connections). This is a separate test of USB4 host-to-host negotiation; it does not route the GPU through the Dell or test a PCIe device tunnel.

1. Keep both laptops awake and signed into Windows, with their normal chargers. Disconnect the DEG2 upstream cable from the dock and ASUS.
2. Connect that supplied cable directly between the ASUS USB4 port and the same Dell Thunderbolt port that successfully ran DEG2.
3. Check for a newly present USB4 P2P network adapter on both laptops and whether its interface is Up. The initial test is only adapter enumeration/link state; no sharing, bridge, IP or firewall configuration is required.

Read-only PowerShell check on each laptop:

```powershell
Get-NetAdapter -IncludeHidden |
    Where-Object { $_.InterfaceDescription -match 'USB4|Thunderbolt' } |
    Select-Object Name, InterfaceDescription, Status
```

**Observed:** ASUS Ethernet 4 and Dell Ethernet 9 both report `USB4(TM) P2P Network Adapter`, status `Up`, in owner-supplied output. The later [working-link rundown](peer-test.md#working-link-rundown-completed) confirms Gen 3, two bonded lanes and both lane adapters Up: reported aggregate 40 Gbps. It contains 1,666 events with no reported loss, formatting errors or unknown records. The ASUS also has the signed in-box USB4P2PNetAdapter 10.0.26100.9818 package. Payload transfer and GPU PCIe tunnelling remain untested.

**Pass:** a newly connected, working P2P adapter provides evidence that ASUS can establish a USB4 host-to-host path with this cable and peer. It strengthens the case for pairing-dependent DEG2 interoperability, while leaving PCIe tunnelling, rate margins and GPU operation untested. Do not treat a virtual NIC's reported speed alone as measured physical USB4 bandwidth.

**Failure:** record the warning and any new/problem PnP device on both machines. This does not prove a damaged ASUS port: peer-role negotiation, host interoperability or the work laptop's device-installation policy can also block this test. Microsoft documents compatible-ID policy blocking for `USB4\USB4NET` and an optional firmware workaround for host-to-host data-role correction. Do not bypass work-device policy. Disconnect the cable after the observation.

### DEG2 cable and peripheral comparisons

| ID / comparison | Method and result to record | What the result would change |
| --- | --- | --- |
| N1: suitable alternate 40 Gbps cable | Verify the cable is rated for USB4/TB4 data, then connect DEG2 directly to the same ASUS port. Check Windows USB4 settings for the external router; if present, record bandwidth and GPU enumeration. Use the Dell as a control for the replacement cable if available. | ASUS success makes cable-dependent interoperability a useful lead. It does not prove the original cable is universally faulty. Failure leaves host/dock/firmware and cable interactions open. |
| N2: documented lower-speed USB4 cable | Separately try a cable documented for 20 Gbps USB4 operation. Record the actual negotiated rate if a router appears; the printed rating alone is not the measurement. | Other-model DEG2 reports motivate this test. Success suggests rate/cable-dependent negotiation; it does not identify a specific PD or signal-integrity defect. Failure does not rule out firmware. |
| N3: another known-working USB4/Thunderbolt peripheral | Prefer a device with a PCIe function, such as a genuine USB4 NVMe enclosure or another eGPU. Verify it on a working host first. On ASUS, separately record external router presence and its PCIe function; avoid interpreting USB 3 fallback as success. | Another router plus functioning PCIe device demonstrates that ASUS can negotiate and tunnel in that tested pairing. DEG2-specific interoperability becomes more likely. Another failure broadens suspicion to the ASUS/host path, but does not by itself prove physical port damage. |
| N4: borrowed TB4 hub between ASUS and DEG2 | Secondary workaround test only. First verify the hub's external router on ASUS, then connect DEG2 downstream and record both routers and GPU. | A working chain is a practical workaround and constrains the failing pairing. It changes topology and cable segments, so it cannot isolate a single firmware component. Do not buy a hub on an assurance that this works. |

For N1-N4, report these milestones separately: **USB fallback -> external router -> PCIe GPU/device -> working driver/output -> stable workload**. Router enumeration alone does not prove PCIe tunneling, and GPU appearance alone does not prove workload stability. If a router appears but the GPU does not, the failure stage has changed and a new PCIe/device investigation becomes justified. N0 uses its separate P2P milestone; a peer host is not a managed external dock router.

## Questions for an independent reviewer

1. Which causal conclusions in this repository are too strong? In particular, challenge the inference from no external router to a pre-enumeration problem, and the limits of the fresh Windows baseline.
2. Is there a documented FA507XI/JHL9480 interaction or overlooked host/PD/retimer requirement that fits both Windows failures and the working Dell? Separate exact-model evidence from other ASUS/AMD reports.
3. Choose one next feasible test. State the hypothesis, prerequisites, exact observations to collect, what both outcomes mean and any rollback. If suggesting another Windows command or driver change, explain what new information it obtains beyond the completed tests.
4. If proposing firmware, identify the exact product/revision, official source, applicability evidence and recovery path. A compatible chip family or another model's success is insufficient.

Raw traces are not public. The excerpts and manifest are curated observations, not a substitute for independently decoding the originals. Request a specific sanitized event/property extraction if a conclusion depends on omitted detail. Do not assume the public repository contains undisclosed raw evidence or that the current interpretation is correct merely because it is detailed.

## State to retain

The separate Windows image, boot entry and private results remain available. Native boot and capture completed; boot-entry removal is untested. Recreating the image, repeating blanket driver resets or revisiting the inactive registry override has low value without a new mechanism to test. Do not discard evidence or flash another model's firmware as a routine next step.

## Completed additional Windows investigation

A full Task Manager live kernel snapshot was inspected offline using Microsoft's signed debugger and matching public symbols. USB4KD topology/port/tunnel queries worked. The [report](kernel-snapshot.md) records the direct policy result, retained recorder messages, UCSI state and decoder limits. An error-looking port status was checked against the matching constructor and proved to be an initial value, not a demonstrated failed operation.

The follow-up expanded recorder/state-machine/ACPI inspection is also complete. Its missing firmware-region pages and finite histories limit retrospective diagnosis. Another identical snapshot cannot recover those absent pages. N0 subsequently supplied a working USB4 peer control using the existing hardware; the other [reviewed tools](research.md#further-windows-diagnostic-tools-reviewed-31-october-2026) remain untested and have no verified applicable repair.

The owner subsequently requested a scripted firmware-buffer examination. A [LiveKD-backed probe](ucsi-memory-probe.md) discovers current mappings and attempts only the identified 48/64-byte reads. The first Administrator run at 12:18:59 UTC failed during debugger launch; the second at 12:26:17 UTC opened the live view but missed its relative command file after a directory change. Absolute script/log paths corrected that automation issue. Twenty PowerShell and twenty actual WinDbg JavaScript checks pass, including a deliberate directory change; full offline replay also passes.

The third live capture at 12:35:05 UTC completed normally in about 1.57 seconds. Discovery was Validated; both PM08 (48 bytes) and EURM (64 bytes) reads were Unavailable. No firmware bytes were obtained. This is a completed examination with a view-access limitation, not another launcher failure or evidence of a firmware/GPU defect. The cause of the unavailable reads and helper unloading remain unverified. No patch is justified from this result; N0 subsequently supplied a working host-to-host control. An unchanged memory-probe rerun has no identified diagnostic benefit.

The owner then requested capture during insertion. The [guided live window](hotplug-window.md) completed at 12:52-12:53 UTC. All 80 mapping discoveries and normal-kernel controls succeeded; all 160 firmware-buffer read attempts failed. First/last PTEs were valid and KD's cache was disabled. ETW start/stop succeeded; Xperf/TraceFmt recovered 8,221 events, zero lost events/buffers, zero formatting errors and two unknown records. Root-port reads succeeded but plugged/router-detected remained No, followed by Billboard fallback. No UCSI-labelled formatted records were observed. No external router/GPU or actionable patch resulted. This tested insertion during recording; repeated unchanged windows have no identified new variable. N0 subsequently passed adapter/link checks. The tool's 37 PowerShell and 27 WinDbg offline checks are separate software validation.
