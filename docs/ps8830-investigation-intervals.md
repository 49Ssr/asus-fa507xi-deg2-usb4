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

**Interval 7, completed:** the bank3 c720 candidate is shared read preparation, with three reviewed direct callers: the existing UCSI reply (84/20bytes), private status (b1/1byte), and cc/4bytes. It is closed as a standalone USB4-entry lead. The cc parser matches the type, voltage/current fields and scaling in pinned upstream USB-PD definitions, supporting a **power-reporting** classification; no live reply or contract is known. [Exact code, reference and scope](../evidence/ec-pd-readers-and-vendor-gates.json), claims C46–C48.

The nearby D8/D9 control pair remains separate. Its prepared80/81 request comes from two firmware flags; a private bit0 latch changes only after both wrapper calls report success. That bit0 is distinct from the already traced outer service-block bit1. The wrapper switches to bank1/common1809, so the same CPU address in bank3 is not authoritative. Neither the byte values nor the public ITE DisplayPort patch define an ASUS USB4 override or safe inverse. No hardware request, new emulator, driver or boot occurred. The actual PS8830 writer, failed physical decision and Windows remedy remain unresolved.

### Interval 6

**Interval 6, completed:** mapped the retained EC bank2 address-byte42/channel1 candidate into a bounded [call and transaction table](../evidence/ec-address42-control-path.json), claims C44–C45. The shared preparation sends a selector/data pair with no readback. Initialisation writes five groups; after stage6, three desired bytes are compared with last-successful-write copies and only changed values are sent to selectors01/03/05. A zero transport return preserves the old copy; failed initialisation groups retain their stage. This is original code, not observed hardware traffic.

The surrounding helpers set/clear individual cached bits, but the peripheral and signal names remain unverified. Address overlap with an ACPI endpoint does not identify the bus or PS8830. This candidate is **deferred for PS8830 intervention**, while possible indirect routing/power/reset effects remain open. No new emulator, live request, driver, boot or write was used. Exact full-image/bank mapping and12byte anchors were checked; mid-instruction/truncated range fragments were excluded and retained privately. Actual attachment-time mode programming and a Windows remedy remain unresolved.

### Interval 5

**Interval 5, completed:** the existing ASUS trace contains four matched hardware-ring and host-topology PLUG records, all for internal DP_IN adapters6/7. None is logged for failed USB4 logical adapter2. The global receive/topology path is therefore active in both passes. Dell has ten matched records, including its root USB4 adapter1 after RouterDetected Yes and before DFP1 notification-pump success. This is an observation of Windows packet handling, not PD-wire traffic. [Pinned logs, paired records and code scope](../evidence/usb4-host-notification-boundary.json), claims C41–C43.

The original host code separates a minimum-length check and ring log, deferred plug/unplug callback dispatch, then topology receipt before adapter lookup/client delivery. Both observed log types are enabled at least when their records emit; both decode summaries report zero lost events. Neither fact proves continuous enablement or that firmware generated every physical event. No Windows drop of an observed valid DEG2 packet is demonstrated. Notification interception/acknowledgement repair is now **deferred**, instead of extending this lead without a distinguishing observation. Actual ASUS entry/mode programming and a repair remain unresolved. No hardware change occurred.

### Interval 4

**Interval 4, completed:** the official USB-IF register table identifies CS18 Wake on Connect Status bit16 as **read-only**, cleared on sleep entry. It is not a pending software acknowledgement or write-one-to-clear field. RouterDetected bit13 is separate. This closes the blind status-clear lead without explaining why ASUS does not detect DEG2. Normative semantics are not proof of ASUS firmware conformance. [Pinned source/page and evidence](../evidence/usb4-wake-status-and-notifications.json), claims C38–C40.

The exact retained native driver primes its software plug-state manager and registers a notification callback. Both saved ASUS initialisation passes then report pump-start success, ReadAndArm and cached unplugged after RD No. This rules out an assertion that notification arming was simply absent in these passes; it does not prove physical PLUG packet reception or correct interrupt delivery. Cached unplugged is not another PHY measurement. No hardware request or write occurred. The actual ASUS mode writer and a Windows fix remain unresolved.

### Interval 3

**Interval 3, completed:** the recorded Windows sequence now separates router detection, usable-link polling and the later **Port Configured** acknowledgement. Dell reports RouterDetected Yes at00:17:45.0348339, completes lane0 CL0 polling at45.4420079, then reads CS19 `00040006` and writes `0004000e` at45.6230557, with acknowledgement recorded. Only bit3 changes. The native writer at RVA79860/branch7999a changes that configured/inter-domain field and calls the CS19 transport. This later write is not the initial RD trigger in this recorded sequence; setting it early on ASUS is not a supported fix. [Exact source lines, values and scope](../evidence/windows-port-configuration-order.json), claims C34–C37.

ASUS's selected root adapter has eight scalar read/write records and only two configuration writes in the retained decoded log. Both are later sleep/wake programming: CS19 `00040006` to `00010006`, with bit3 still clear, after the initial RD No. No lane-disable read before that initial decision is available here; its value remains unknown. The native lane1-disable test uses a separate cached CS1 field/mask4000, and a reset workaround has its own flags predicate. No reset/flag clear was executed.

The saved working ASUS peer rundown independently identifies the same root logical lane0 adapter2, both lane states2 and bonding1. This strengthens the partner-specific comparison without treating the peer snapshot as a fresh entry trace or mapping adapter2 to a UCSI connector number. The architecture graph now separates RD readback from CL0 polling and final operational-router discovery; its former direct code-backed RD-to-enumeration edge is explicitly unknown. Physical entry history and the actual ASUS PS8830 writer remain unresolved.

### Earlier intervals

**Interval 2, completed:** traced the retained AMD pre-OS modules beyond their names. `AmdUsb4PortLinkConfigure` (DXE RVA13150) uses USB4 adapter configuration packets, including PORT_CS_19 FEC-request bits and downstream-port reset; it is not the recovered PS8830 mode writer we need. Its direct caller is in lane-adapter enumeration. The reviewed ReadyToBoot/ExitBootServices callback bodies close their events. The small USB4 PEI entry is IA32 TE code: it checks support, prints diagnostics and returns. These code facts do not establish which paths ran on the laptop or explain the failed pairing. [Pinned code scope and limitations](../evidence/asus-preos-control-scope.json), claims C31–C33.

A bounded search for six standard I2C/SMBus GUIDs verified the existing corpus of2473leaf files/63036796bytes, with19matching leaves/14unique contents, including duplicated volumes and a dependency section. The four selected USB4/UCSI modules contain none of those six literal GUIDs. Positive matches elsewhere validate the search; they do not exclude private interfaces or direct controller access. The board-init SMBus candidate resolves to a notify/configuration callback, not an identified retimer transaction. The actual PD-to-APU/retimer writer remains unlocated.

Tool corrections are preserved privately: Store Python could not see the AppData extraction directory, so its zero-file result was rejected and replaced with the native PowerShell scan; IA32 TE headers require a0x180RVA/file correction; automatic PE rebasing shifted one independent disassembly and was corrected with verified raw-mode bytes. A GUID pointer in data was not treated as executing code after section mapping. None of these failed attempts supports an absence claim. No new hardware request, boot, driver or firmware execution occurred.

### Previous interval

**Interval 1, completed:** decoded eight ASUS ACPI I2CD resources and verified their exact resource bytes in the recovered original DSDT (SHA256 `f57e3bb75b6a15725ff295ed451161d33f3b238bb6cfda683a45286851f1938a`). Addresses are `08/11/0a/0f` and `18/21/1a/1f`, all400kHz. These are logical interfaces, not eight chips. Reviewed DSM methods return constants; no mode programming occurs in those methods. The original PRSpb request dispatcher routes initialisation, cleanup and I/O operations; its presence does not identify the attachment-time mode writer.

Pinned [Intel register definitions](https://github.com/intel/tbtools/blob/5de2ac9d5325c3746adbda7d9874b98397109ebb/src/data/registers.json) additionally identify ASUS's set CS18 bit16 as **Wake on Connect Status**. ASUS has RouterDetected/Bonding clear and cable-version0 in this sample; Dell has those first two set and cable-version16. Wake status is not proof of a blocked interrupt or present USB4 mode, and these samples do not reconstruct the complete connection history.

Two primary references add a concrete architecture to follow. TI [ZHCAG60](https://www.ti.com.cn/cn/lit/an/zhcag60/zhcag60.pdf?ts=1779483983495), pages2–4 and7–9, describes its PD controller coordinating APU crossbar requests/results and separate retimer programming through a safe state. Its Type-3 result read clears protocol state, so indiscriminate reads would not be passive. This is a TPS6X99X example, not an ASUS IT8853 register map. Infineon's [Host SDK guide](https://www.infineon.com/row/public/documents/30/316/infineon-ez-pd-ccgx-host-sdk-user-guide-productqualificationreport-en.pdf), pages11 and38, independently documents AMD platform firmware with APU/retimer I2C-master support and PS8830 selection. Neither proves ASUS's writer or wiring. [Structured evidence](../evidence/ps8830-configuration-path.json), model claims C27–C30.

**What remains unresolved:** no actual ASUS PD-to-APU or PS8830 attachment-time write sequence has been recovered, and the cause of the clear router-detection bit is still unknown. No hardware request, driver, boot or setting change was made.

Next concrete tasks:

1. **Next interval first:** trace the verified bank1 CPUb9ff call through common33d9 to bank3b8cd and the setters of03c7.bit1/0308.bit6 that choose the D8/D9 request. Determine the actual caller/state relationship before assigning USB4, mux, reset or power semantics. Keep private latch bit0 separate from outer block bit1; do not read/clear either live. If no control-to-entry link follows, defer this branch explicitly rather than extending an unnamed-flag investigation indefinitely.
2. Continue EC bus call-site classification only where a specific candidate connects to mode control. Bank2 CPUb5d4 address42/channel1 is mapped and deferred pending target/signal identity. Bank1 CPUc0d6 prepares70/channel1, and bank3 CPUc720 prepares98/channel4 and is now classified as shared read setup; none of these numbers is automatically a PS8830 address. Linear disassembly offsets must be translated through the8051 bank window. This initial static triage is not exhaustive/reachability proof; no new emulator was built.
3. Follow captured native port-control writes and status ordering if the candidate suggests a distinguishing field. Do not force router detection, interpret a wake latch as a diagnosed fault, or apply TI/Linux values to unqualified ASUS hardware. Qualify any future read for read-clear/side effects and history coverage first.

Lookup update: the official USB-IF document index exposed the November 2025 archive, which was downloaded and hash-pinned in interval4. The base-specification register page was extracted and visually checked; the original ZIP/PDF stay private. Earlier failed direct retrieval remains preserved. The newer ITE Linux driver path was absent from the inspected pinned upstream tree; an unmerged patch is not an installed ASUS implementation. No absence claim is based on either lookup failure. Two initial local commands used unsuitable PowerShell wildcard/path forms and were corrected; originals were not changed.

## Publication discipline

The local Git index predates API-published changes. Read fresh GitHub main, compare affected files with that immutable commit, and publish only the reviewed allowlist while preserving all other paths/history. Verify blobs, tree, parent and final head. Private dumps, firmware, disassemblies, hardware pointers, user paths and raw recovery receipts stay local. Update the evidence model for new claim-bearing results and regenerate the reports.
