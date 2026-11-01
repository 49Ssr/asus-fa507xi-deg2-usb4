# PS8830 investigation intervals

## Authorization and limits

On 1 November 2026 the owner requested recurring research intervals tracing what configures the ASUS PS8830 and why native USB4 router detection stays clear with DEG2, using existing captures and updating GitHub. This supersedes the earlier offline-runner-only scheduling preference. Hardware access remains offline-only: no new device/EC/I2C/vendor requests, driver installs, test boots, firmware flashes, security or network changes.

Before each interval, read current Codex usage limits. Stop and disable the heartbeat at 10% or less remaining in any applicable allowance window, if ordinary usage is unavailable, or if the limit cannot be checked reliably. Do not buy credits, use resets, or automatically resume after a reset. Usage is account-wide; the check is a boundary guard, not an exact per-token billing cap. Recheck before expanding work and at the end.

Heartbeat: `trace-asus-ps8830-configuration`, every 30 minutes in this chat. Keep each research interval to at most 15 minutes. Notify only for meaningful findings, failures, completion, a usage stop or needed owner input. Stop if useful offline paths are exhausted; credit consumption is not a research objective.

## Starting evidence

- [Native Windows branch comparison](offline-investigation.md): ASUS CS18 `00010400`, RouterDetected bit13 clear; Dell deep CS18 `00003510`, bit13 set. Both initially take Plugged No. Returned bits match the original Windows decisions.
- [Architecture map](investigation-map.md) and [truth table](investigation-truth-table.md): initialisation samples and final absence do not establish complete entry/link history.
- [PS8830 reference](../evidence/retimer-control-reference.json): separate host SMBus and PD-controller I2C paths; public Linux mode flag is software-written. ASUS's runtime owner is unverified.
- [Updater evidence](parade-updater-failure.md) and [I2C prerequisites](i2c-read-prerequisites.md): real CFU target-lifetime issue, but working ASUS peer link is counterevidence to a universal USB4 blocker. No blind retry or updater patch deployment.

## Current interval

**Interval 1, completed:** decoded eight ASUS ACPI I2CD resources and verified their exact resource bytes in the recovered original DSDT (SHA256 `f57e3bb75b6a15725ff295ed451161d33f3b238bb6cfda683a45286851f1938a`). Addresses are `08/11/0a/0f` and `18/21/1a/1f`, all400kHz. These are logical interfaces, not eight chips. Reviewed DSM methods return constants; no mode programming occurs in those methods. The original PRSpb request dispatcher routes initialisation, cleanup and I/O operations; its presence does not identify the attachment-time mode writer.

Pinned [Intel register definitions](https://github.com/intel/tbtools/blob/5de2ac9d5325c3746adbda7d9874b98397109ebb/src/data/registers.json) additionally identify ASUS's set CS18 bit16 as **Wake on Connect Status**. ASUS has RouterDetected/Bonding clear and cable-version0 in this sample; Dell has those first two set and cable-version16. Wake status is not proof of a blocked interrupt or present USB4 mode, and these samples do not reconstruct the complete connection history.

Two primary references add a concrete architecture to follow. TI [ZHCAG60](https://www.ti.com.cn/cn/lit/an/zhcag60/zhcag60.pdf?ts=1779483983495), pages2–4 and7–9, describes its PD controller coordinating APU crossbar requests/results and separate retimer programming through a safe state. Its Type-3 result read clears protocol state, so indiscriminate reads would not be passive. This is a TPS6X99X example, not an ASUS IT8853 register map. Infineon's [Host SDK guide](https://www.infineon.com/row/public/documents/30/316/infineon-ez-pd-ccgx-host-sdk-user-guide-productqualificationreport-en.pdf), pages11 and38, independently documents AMD platform firmware with APU/retimer I2C-master support and PS8830 selection. Neither proves ASUS's writer or wiring. [Structured evidence](../evidence/ps8830-configuration-path.json), model claims C27–C30.

**What remains unresolved:** no actual ASUS PD-to-APU or PS8830 attachment-time write sequence has been recovered, and the cause of the clear router-detection bit is still unknown. No hardware request, driver, boot or setting change was made.

Next concrete tasks:

1. **Next interval first:** inspect retained `AmdUsb4Dxe`, `AmdUsb4Pei` and related extracted modules for the actual board PD/APU mode-control transport and configuration structures. Trace callbacks/GUIDs and fields with their source offsets; don't scan for one guessed address and call it a match. Compare any candidate with the TI/Infineon architecture while keeping ITE-specific implementation unproven.
2. Continue EC bus call-site classification only where a specific candidate connects to mode control. Bank2 CPUb5d4 prepares bus address-byte42/channel1, bank1 CPUc0d6 prepares70/channel1, and bank3 CPUc720 prepares98/channel4; none of these numbers is automatically a PS8830 address. Linear disassembly offsets must be translated through the8051 bank window. This initial static triage is not exhaustive/reachability proof; no new emulator was built.
3. Follow captured native port-control writes and status ordering if the candidate suggests a distinguishing field. Do not force router detection, interpret a wake latch as a diagnosed fault, or apply TI/Linux values to unqualified ASUS hardware. Qualify any future read for read-clear/side effects and history coverage first.

Lookup limits retained: direct USB-IF page retrieval was refused; the full spec was not fetched. The newer ITE Linux driver path was absent from the inspected pinned upstream tree; an unmerged patch is not an installed ASUS implementation. No absence claim is based on either lookup failure. Two initial local commands used unsuitable PowerShell wildcard/path forms and were corrected; originals were not changed.

## Publication discipline

The local Git index predates API-published changes. Read fresh GitHub main, compare affected files with that immutable commit, and publish only the reviewed allowlist while preserving all other paths/history. Verify blobs, tree, parent and final head. Private dumps, firmware, disassemblies, hardware pointers, user paths and raw recovery receipts stay local. Update the evidence model for new claim-bearing results and regenerate the reports.
