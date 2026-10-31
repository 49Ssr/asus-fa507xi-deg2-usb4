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
- The owner prefers Windows diagnosis and existing/borrowed hardware. A detailed ASUS report has already been sent. No verified applicable FA507XI PD/USB-C or DEG2 firmware image was found in the inspected sources.

## Missing comparisons, in priority order

All rows below are **unperformed**. N0 uses the existing Dell and supplied cable; the other rows need a suitable additional cable/peripheral. No purchase or successful fix is assumed. For DEG2 comparisons, keep the same assembled GPU/dock/PSU, correct upstream port/mode and laptop barrel power. Change one named variable per comparison. Record the protocol/device milestone, not just fan activity or the Windows warning.

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

Alternatively inspect Device Manager, Network adapters. Compare before/after presence and current link status; an old disconnected adapter is not a pass. The ASUS already has the signed in-box USB4P2PNetAdapter 10.0.26100.9818 package in its driver store. The connection itself remains untested.

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

The follow-up expanded recorder/state-machine/ACPI inspection is also complete. Its missing firmware-region pages and finite histories limit retrospective diagnosis. Another identical snapshot cannot recover those absent pages. N0 supplies a new Windows comparison using the existing hardware; the other [reviewed tools](research.md#further-windows-diagnostic-tools-reviewed-31-october-2026) remain untested and have no verified applicable repair.

The owner subsequently requested a scripted firmware-buffer examination. A [LiveKD-backed probe](ucsi-memory-probe.md) discovers current mappings and attempts only the identified 48/64-byte reads. The first Administrator run at 12:18:59 UTC failed during debugger launch; the second at 12:26:17 UTC opened the live view but missed its relative command file after a directory change. Absolute script/log paths corrected that automation issue. Twenty PowerShell and twenty actual WinDbg JavaScript checks pass, including a deliberate directory change; full offline replay also passes.

The third live capture at 12:35:05 UTC completed normally in about 1.57 seconds. Discovery was Validated; both PM08 (48 bytes) and EURM (64 bytes) reads were Unavailable. No firmware bytes were obtained. This is a completed examination with a view-access limitation, not another launcher failure or evidence of a firmware/GPU defect. The cause of the unavailable reads and helper unloading remain unverified. No patch is justified from this result; N0 remains the available existing-hardware comparison. An unchanged memory-probe rerun has no identified diagnostic benefit.

The owner then requested capture during insertion. The [guided live window](hotplug-window.md) completed at 12:52-12:53 UTC. All 80 mapping discoveries and normal-kernel controls succeeded; all 160 firmware-buffer read attempts failed. First/last PTEs were valid and KD's cache was disabled. ETW start/stop succeeded; Xperf/TraceFmt recovered 8,221 events, zero lost events/buffers, zero formatting errors and two unknown records. Root-port reads succeeded but plugged/router-detected remained No, followed by Billboard fallback. No UCSI-labelled formatted records were observed. No external router/GPU or actionable patch resulted. This tested insertion during recording; repeated unchanged windows have no identified new variable. N0 remains unperformed. The tool's 37 PowerShell and 27 WinDbg offline checks are separate software validation.
