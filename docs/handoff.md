# Independent review and next tests

**31 October 2026: unresolved.** This page is the entry point for a second opinion, including Claude. The goal is to identify the shortest discriminating test or a verified applicable fix. No root cause has been established.

## Evidence to read first

1. [Findings](findings.md), including the `_OSC`, Billboard and USB4-version caveats.
2. [Separate full-Windows result](fresh-windows.md), including its missing drivers and partial WPP decoding.
3. [Experiment ledger](experiments.md), [exact hardware](hardware.md), [structured observations](../evidence/observations.json) and [trace excerpts](../evidence/trace-excerpts.txt).
4. [Research](research.md) and [private policy audit](policy-audit.md) before proposing a registry or firmware change.

## Current state

- ASUS FA507XI, Ryzen 9 7940HS, internal RTX 4070 Laptop; BIOS 314. Its documented USB4 port is 40 Gbps; the laptop is not being described as TB4-certified.
- DEG2 / JHL9480, Gigabyte RTX 4080 SUPER WINDFORCE V2, Cooler Master 1000 W PSU, original supplied DEG2 cable. Identical assembly works on the Intel Dell: external TBGAA router, firmware 62.62, 40/40 Gbps, NVIDIA driver and HDMI output.
- Original Windows: 25H2 26200.9818, USB4 driver 10.0.26100.9818. Original Parade SPB 1.0.8 / HID 1.0.11 restored. Related-model trial packages removed. Private v2 override absent; Secure Boot retained and test-signing disabled.
- Separate native-boot Windows: 26200.8037, USB4 driver 10.0.26100.7920. Required host/root/UCSI/I2C/Parade devices healthy before and after connection; no external router or new GPU. The shared firmware and selected OEM drivers remain common variables.
- ASUS host/root initialize and firmware grants USB `_OSC` controls `0xf`; only ordinary USB hub/Billboard fallback appears. This is earlier than the missing NVIDIA adapter, PCIe authorization of an enumerated external router, or GPU workload performance.
- All four plug orientations, EC reset, graphics mode changes, OS file repair, scoped controller reinstall and retimer restarts were ineffective. The v2 override was ignored and is an invalid negative test of its intended path.
- No second suitable cable or known-working separate USB4 peripheral is available at last report. The spare UGREEN cable was reported unsuitable. The existing UGREEN 3121 is a 10 Gbps USB-C hub; its USB/Ethernet/display operation would not validate USB4/PCIe.
- The owner prefers Windows diagnosis and existing/borrowed hardware. A detailed ASUS report has already been sent. No verified applicable FA507XI PD/USB-C or DEG2 firmware image was found in the inspected sources.

## Missing comparisons, in priority order

All rows below are **unperformed**. Borrowing a suitable item is sufficient; no purchase or successful fix is assumed. Keep the same assembled GPU/dock/PSU, correct upstream port/mode, laptop barrel power and other USB4 devices disconnected. Change one named variable per direct comparison. Record the exact cable/peripheral and the external-router result, not just fan activity or the Windows warning.

| ID / comparison | Method and result to record | What the result would change |
| --- | --- | --- |
| N1: suitable alternate 40 Gbps cable | Verify the cable is rated for USB4/TB4 data, then connect DEG2 directly to the same ASUS port. Check Windows USB4 settings for the external router; if present, record bandwidth and GPU enumeration. Use the Dell as a control for the replacement cable if available. | ASUS success makes cable-dependent interoperability a useful lead. It does not prove the original cable is universally faulty. Failure leaves host/dock/firmware and cable interactions open. |
| N2: documented lower-speed USB4 cable | Separately try a cable documented for 20 Gbps USB4 operation. Record the actual negotiated rate if a router appears; the printed rating alone is not the measurement. | Other-model DEG2 reports motivate this test. Success suggests rate/cable-dependent negotiation; it does not identify a specific PD or signal-integrity defect. Failure does not rule out firmware. |
| N3: another known-working USB4/Thunderbolt peripheral | Prefer a device with a PCIe function, such as a genuine USB4 NVMe enclosure or another eGPU. Verify it on a working host first. On ASUS, separately record external router presence and its PCIe function; avoid interpreting USB 3 fallback as success. | Another router plus functioning PCIe device demonstrates that ASUS can negotiate and tunnel in that tested pairing. DEG2-specific interoperability becomes more likely. Another failure broadens suspicion to the ASUS/host path, but does not by itself prove physical port damage. |
| N4: borrowed TB4 hub between ASUS and DEG2 | Secondary workaround test only. First verify the hub's external router on ASUS, then connect DEG2 downstream and record both routers and GPU. | A working chain is a practical workaround and constrains the failing pairing. It changes topology and cable segments, so it cannot isolate a single firmware component. Do not buy a hub on an assurance that this works. |

For every test, report these milestones separately: **USB fallback -> external router -> PCIe GPU/device -> working driver/output -> stable workload**. Router enumeration alone does not prove PCIe tunneling, and GPU appearance alone does not prove workload stability. If a router appears but the GPU does not, the failure stage has changed and a new PCIe/device investigation becomes justified.

## Questions for an independent reviewer

1. Which causal conclusions in this repository are too strong? In particular, challenge the inference from no external router to a pre-enumeration problem, and the limits of the fresh Windows baseline.
2. Is there a documented FA507XI/JHL9480 interaction or overlooked host/PD/retimer requirement that fits both Windows failures and the working Dell? Separate exact-model evidence from other ASUS/AMD reports.
3. Choose one next feasible test. State the hypothesis, prerequisites, exact observations to collect, what both outcomes mean and any rollback. If suggesting another Windows command or driver change, explain what new information it obtains beyond the completed tests.
4. If proposing firmware, identify the exact product/revision, official source, applicability evidence and recovery path. A compatible chip family or another model's success is insufficient.

Raw traces are not public. The excerpts and manifest are curated observations, not a substitute for independently decoding the originals. Request a specific sanitized event/property extraction if a conclusion depends on omitted detail. Do not assume the public repository contains undisclosed raw evidence or that the current interpretation is correct merely because it is detailed.

## State to retain

The separate Windows image, boot entry and private results remain available. Native boot and capture completed; boot-entry removal is untested. Recreating the image, repeating blanket driver resets or revisiting the inactive registry override has low value without a new mechanism to test. Do not discard evidence or flash another model's firmware as a routine next step.
