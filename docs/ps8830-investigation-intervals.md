# PS8830 investigation intervals

## Authorization and limits

Owner-directed continuation is restored: heartbeat `investigate-asus-usb4-capture-and-firmware-settings`, every15minutes in this chat, ACTIVE and read back. Routine notifications are muted while the owner sleeps. The1% allowance stop remains. The interval14 deletion was real and is preserved as history; the new queue follows the owner's capture/settings leads.


Latest owner change before sleep: the stop point is **1% remaining**, superseding the earlier10% threshold. The existing15-minute heartbeat was updated and its stored prompt/readback verified.

Before overnight work, the owner requested more frequent research and explicitly welcomed controller/USB4 documentation, published papers, specifications, component images and public schematics. Use them to resolve concrete mode-control or wiring questions, identifying model/revision differences. Existing captures are sufficient for the saved offline tasks; no further general dump is requested now. Hardware evidence gaps and the absence of a working repair remain explicit. Project cleanup preserves originals and failed attempts.

On 1 November 2026 the owner requested recurring research intervals tracing what configures the ASUS PS8830 and why native USB4 router detection stays clear with DEG2, using existing captures and updating GitHub. This supersedes the earlier offline-runner-only scheduling preference. Hardware access remains offline-only: no new device/EC/I2C/vendor requests, driver installs, test boots, firmware flashes, security or network changes.

Before each interval, read current Codex usage limits. Stop and disable the heartbeat at 1% or less remaining in any applicable allowance window, if ordinary usage is unavailable, or if the limit cannot be checked reliably. Do not buy credits, use resets, or automatically resume after a reset. Usage is account-wide; the check is a boundary guard, not an exact per-token billing cap. Recheck before expanding work and at the end.

Historical heartbeat before interval14 deletion: `trace-asus-ps8830-configuration`, every 15 minutes in this chat (owner update before overnight work). Keep each research interval to at most 15 minutes. Notify only for meaningful findings, failures, completion, a usage stop or needed owner input. Stop if useful offline paths are exhausted; credit consumption is not a research objective.

## Starting evidence

- [Native Windows branch comparison](offline-investigation.md): ASUS CS18 `00010400`, RouterDetected bit13 clear; Dell deep CS18 `00003510`, bit13 set. Both initially take Plugged No. Returned bits match the original Windows decisions.
- [Architecture map](investigation-map.md) and [truth table](investigation-truth-table.md): initialisation samples and final absence do not establish complete entry/link history.
- [PS8830 reference](../evidence/retimer-control-reference.json): separate host SMBus and PD-controller I2C paths; public Linux mode flag is software-written. ASUS's runtime owner is unverified.
- [Updater evidence](parade-updater-failure.md) and [I2C prerequisites](i2c-read-prerequisites.md): real CFU target-lifetime issue, but working ASUS peer link is counterevidence to a universal USB4 blocker. No blind retry or updater patch deployment.

## Current interval

**Interval21:** traced a real firmware/Windows USB4 dependency-policy hook: SMM modifies PBS465, and native-USB4 platform _OSC can clear its ACPI dependency state. It is a different setting from PD-control9c, and the SMI writes configuration rather than reading diagnostics. [Original code and AML](../evidence/usb4-dependency-handshake.json).

The existing ASUS dump supplies useful state: offline namespace lookup recovered M046=0x0c, DDEP=0x55 and DIMS=0xa7, without evaluating methods. The selected legacy NHI dependency branch requires DDEP==1 and M046<0x0b; both are false in that snapshot. This excludes that specific branch as the proposed setting fix, not every platform dependency or the USB4 failure. Stored465/current state and the9c consumer remain unknown. Next follow actual9c policy transfer and pair saved handoff evidence where available; no _OSC/SMI execution. No live request/change/deletion occurred.


**Interval20:** the selected PEI method is native PCD `SetBool`, token10b. Original HII names its input as PCIe DXIO timing control; the associated32-bit fields are PCIe receiver-detection/L0 polling overrides. The earlier3c3 field is WWAN support, and1f is CLK_REQ6 clock power management. [Primary definitions, checked question bytes and route](../evidence/pbs-pcd-and-hii-identities.json). None identifies the distinct PD-control9c consumer.

Three original PEI database copies are byte-identical. Their name table is absent and their734 local entries contain no HII-backed tokens; this is a scoped database result, not whole-image or runtime absence. Token10b has the expected Boolean type. Next follow the already located OEM SMM PBS reader at176b with bufferRBP-80 and its actual consumers. No live values, controller request or repair were established. No hardware request/change/deletion occurred.


**Interval19:** original AmdCpmOemInitPeim has another checked PBS reader/caller. Its selected load is field3ba and routes through configuration token10b, not PD-control9c. The indirect method/token need primary-definition matching. Zero original callback-table entries are not a runtime observation. [Byte anchors and limits](../evidence/pbs-pei-field-routing.json).

The descriptor worker supervisor now terminates through its retained Process object, avoiding PID reuse. Harmless real child processes verified both normal exit and timeout termination; no USB function ran. The hardware path remains untested. Next follow the selected configuration-method definition and actual policy transfer, without treating this unrelated field as a USB4 fix. A clock discontinuity occurred during this run; no continuous overnight-work duration is claimed. No hardware request, elevation, driver, boot, setting change or deletion occurred.


**Interval18:** public Infineon app-common has a real, conditional flash-log response; the example-compatible v1 dependency was resolved and checked, not assumed from current master. Its compact fault log is not a full PD packet transcript, and DEG2 command compatibility is unproven. [Source and limitations](../evidence/infineon-log-route-and-reader.json).

The standard-string reader is now prepared at `tools/Read-DEG2BillboardStrings.ps1`, default Preview. It binds the exact present Billboard and parent, independently checks the hub port's driver key, then permits only standard descriptors. A hidden worker has a45-second supervisor limit; requests/replies/errors remain private and there is no retry. PS5.1 parsing, both C# compilations, Preview and pre-I/O rejection guards passed. The capture path has NOT run, so port binding, permissions and hardware return lengths are untested. Next review the complete reader before any owner use; no launch while the owner sleeps. Return to the original PBS9c policy consumer independently. No hardware request/change/deletion occurred.


**Interval17:** existing ASUS topology separates041f:d002 Billboard from its1d5c:5801 parent hub. Parade describes FL5801 Billboard/PD-bridge customization, but enabled DEG2 access is unproven. Public Infineon Griffin Creek source is available without login; its inspected FL5801 helper is an I2C UUID read, not a host PD logger. Retained vendor endpoints OUT01 bulk/IN82 interrupt (64B) match the public reference shape; configurable VID/PID also prevents a default-ID-only exclusion. Command semantics remain unqualified. Inspected fwupd device matches do not qualify its vendor requests for DEG2. [Evidence](../evidence/billboard-capture-contract.json).

The standard read's pure C# codec now compiles under PS5.1 and passes18 offline checks. Official packed connection-info layout uses35-byte header, address25/status31; no live I/O ran. Complete reader still needs exact fresh PnP-to-parent-hub binding, native timeout/cancellation and private output. Next implement that wrapper without running it, and compare the public PMG Billboard command handler only when protocol identity can be matched. PBS9c consumer remains unresolved. No elevation, device request, driver, boot, setting change or deletion occurred.


**Interval16:** the selected NBIO PBS-reader caller reads field3c3 at the checked stack-relative location, not PD-control9c. No complete9c consumer was recovered. A separate existing-capture lead is specific: both DEG2 BOS payloads advertise URL string7 and mode descriptions8/9/10, whose text is absent from the reviewed results. Microsoft's pinned USBView provides a standard hub-driver string GET; its enumeration code has no Billboard-specific string path. [Original code, payload pins and read requirements](../evidence/pbs-caller-and-billboard-string-route.json).

**Next:** prepare a narrow standard-string reader from that reviewed Microsoft route, with fresh exact-device/port/language binding, strict returned type/length/UTF16 checks and private output. No vendor command, new driver or boot. This is protocol identification, not a PD packet recorder; generic help text may yield no debug interface. Continue actual PD-control consumer research independently. No device request, elevation, hardware change or deletion occurred.


**Interval15:** the original PBS accessor confirms the0x500-byte variable and a default-persistence branch using attributes7, including UEFI runtime access. Its initializer writes PD USB4-control1 through a word store at9b; literal9c searches were insufficient. Question47 has no special direct-controller branch in the reviewed form callback. [Exact code, source pins and limits](../evidence/pbs-runtime-variable-path.json). Windows GET remains prepared/unexecuted; a metadata guard now prevents enhanced-authenticated data from being decoded as plain settings.

The complete PD-control consumer remains unlocated. Next: follow the known PBS-reader callers and setup/HOB/PCD transfer in retained AmdNbioPei rather than extending name-only or literal-offset absence claims. PEI is IA32 TE with0x180 stripped-header correction and per-image preferred base; validate raw bytes. Existing original names/GUIDs are triage, not proof of every consumer. Long-path disassembler failures and the corrected hash-identical short copies are retained. No hardware request, boot, setting change or deletion occurred.


**Owner reopened work after interval14:** stopping at the old queue was too narrow. Follow the new [capture/settings investigation](capture-paths-and-hidden-settings.md). Exact BIOS HII settings are now identified; a Windows read-only variable reader is prepared, not executed. SDK login/download could add AMD/PS8830 reference definitions. Trace the actual setting consumer and identify a safe controller-state/log interface. The original failure remains unresolved. No blind boot, live bus request or new driver is authorized by this checkpoint.


**Interval 14, completed:** inspected the official FA507X service guide and its original embedded board photographs. An example board reads `DA0NJSMBAD0 REV:D`, `MODEL:NJS`; this does not establish the owner's fitted board or USB-C control wiring. The images do not identify the attachment-time PS8830 writer. Infineon's official catalog provides an SDK source-distribution route, but the attempted3.7 package download returned401; no source package was acquired or executed. [Sources, limits and remaining evidence](../evidence/board-and-sdk-access-review.json).

**Earlier interval14 stop, superseded by owner reopening above:** the saved offline queue and finite public-source task have not produced a usable way to observe the candidate mode input during failure. Root cause and a Windows repair remain unresolved. More scans of unnamed flags or repeated general dumps would not close that gap. All original evidence and failed attempts are retained; no device request, driver, boot, firmware change or deletion occurred. The stop is for lack of a productive next offline task, not because the1% allowance threshold was reached.

Resume when new material identifies the ASUS controller interface/wiring, exposes the actual attachment-time mode/negotiation state, or provides relevant controller source. No new owner hardware test is requested by this checkpoint. Historical next-task text below is completed/deferred context, not a current queue.

### Interval 13

**Interval 13, completed:** checked the existing Windows paths against the newly identified mode inputs. The package assigns08/18 to the HID driver and companion endpoints to SPB. HID feature data is cached; output reports20/25 participate in firmware delivery. The generic SPB read uses a fixed resource-hub connection, so changing its register byte does not select the main-mode endpoint. [Original transport code and missing read contract](../evidence/parade-mode-read-contract.json). Microsoft's connection-ID documentation independently explains the fixed bus/address association.

No existing path is yet qualified to read the firmware mode byte or branch marker during failure. This is an access gap, not proof of an impossible repair or a reason to repeat the failed version read. No hardware request/change or deletion occurred. A finite public-source task remains: inspect the official service-guide board pages for component/board identification and any concrete manufacturer interface-source link. If it provides no new observable or interface, stop recurring work rather than consume allowance on more unnamed-register scans.

### Interval 12

**Interval 12, completed:** the candidate mode reads are in a vector-selected retimer interrupt handler, behind a paired-byte gate. Its code tests bit0 before bit7. With a stable input,00 skips these two configuration arms,01 selects bit0,80 selects bit7, and81 selects bit0 while bypassing bit7. [Interrupt path and original-code decision table](../evidence/ps8830-mode-interrupt-path.json).

This is a concrete distinction to seek in controller state, not evidence that ASUS supplied81 or chose the wrong mode. The code also records different branch markers, but their lifetime and external read path are unknown. The internal mode-byte writer and gate semantics remain unqualified. No hardware request, driver, boot, firmware write or deletion occurred. The first disassembly parser used the wrong JSON field name; the corrected byte-checked result and failed attempt are retained privately.

### Interval 11

**Interval 11, completed:** the timer branch depends on two event paths, a software gate and a selected internal read. Both event paths set the control bit before the gate test; the timer is not its sole writer. The internal return remains unidentified. Separately, the original code has distinct bit0/bit7 configuration branches and orientation-dependent lane masks. Six field positions match the pinned Linux PS883x connection-mode definitions. This supports a specific USB4-shaped branch to follow, as an inference rather than a proven ASUS host-register mapping. [Code, comparison and limits](../evidence/ps8830-mode-input-branches.json).

No failed-connection value or physical bit meaning was measured. No hardware test or dump is needed for the saved code work. The owner requested overnight work more often: the existing heartbeat was updated and read back at15-minute intervals, then the stop limit was changed to1% at the owner's explicit request. Useful code tracing remains; no new hardware request, driver, boot, firmware write or deletion occurred.

### Interval 10

**Interval 10, completed:** the retained PS8830 code uses the training-related words. Two routines calculate the record address, divide its word by5 and load a counter. The timer interrupt decrements active counters, queues expiry events and the main loop calls the indexed handler. For the receiver-PLL-delay record, a conditional arm sets a control bit and starts40 counts; the callback clears the same bit. [Original-code relationships](../evidence/ps8830-timer-consumers.json).

This establishes a timed control path in the retimer firmware. It does not show that ASUS takes this path with DEG2, identify the electrical bit, establish the tick duration or provide a Windows write interface. The installed-package image is still not a physical flash readback. No hardware request or change occurred; no working fix is known.

### Interval 9

**Interval 9, completed:** classified the remaining EC address70/channel1 helper: three fixed two-byte pairs plus high/low-nibble forwarding of a tracked byte, with a local history/mirror and no qualified USB4/retimer identity. The saved EC candidate queue is now classified or deferred. [Code facts and useful-path audit](../evidence/ec70-and-retimer-consumer-audit.json), claims C52–C53.

The audit found a specific remaining path in the already retained **PS8830 package image**:12 adjacent five-byte records pair words with training-related labels. The labels were already known; the new work pins the record layout and corrects two raw hits that are actually8051 branches to a shared RET before the following text. These are not measured timer values, a training error, or a qualified patch point. Recurring research remains useful for one bounded consumer-qualification pass, rather than repeating EC scans. No hardware request, boot, driver or firmware write occurred; root cause and Windows repair remain unresolved.

### Interval 8

**Interval 8, completed:** traced bank1b9ff through the common bank switch to the D8/D9 selector. The caller checks045e.bit1; selection uses global03c7.bit1 and0308.bit6. A setup-block setter and two inhibit clears are identified. Original AML names a matching ERAM layout bit TCCN, but uses it only as a declaration in the23 retained tables; the other selector bit is unnamed. The live alias/value and chip meaning remain unverified. [Code-derived decision table, source pins and limits](../evidence/ec-vendor-request-selection.json), claims C49–C51.

A concrete recovery limit is now explicit: if the first wrapper succeeds and the second fails, the reviewed pair body leaves its software latch unchanged and sends no compensating request. That is not proof of unchanged hardware, so changing the latch back would not establish rollback. No failed live pair is claimed. No control-to-USB4-entry link emerged; **D8/D9 is deferred as a repair branch**, rather than extending an unnamed-flag investigation. No hardware request, driver, test boot or firmware write occurred.

### Interval 7

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

1. **Earlier interval14 queue decision, superseded above.** The official service-guide photo/source-distribution review is complete; see interval14. A manufacturer SDK package link was located but its download requires authentication. No controller implementation, fitted-board wiring or safe live mode read was recovered. Resume only with new discriminating source/evidence, not repeated EC/register scans, a new driver, NACK retry, endpoint switch, reset, update or general dump.
2. The named EC candidate queue is classified/deferred. Do not repeat those scans without a new mode-control relationship. Bank2 CPUb5d4 address42/channel1 is mapped and deferred pending target/signal identity. Bank1 CPUc0d6 prepares70/channel1, and bank3 CPUc720 prepares98/channel4 and is now classified as shared read setup; none of these numbers is automatically a PS8830 address. Linear disassembly offsets must be translated through the8051 bank window. This initial static triage is not exhaustive/reachability proof; no new emulator was built.
3. Follow captured native port-control writes and status ordering if the candidate suggests a distinguishing field. Do not force router detection, interpret a wake latch as a diagnosed fault, or apply TI/Linux values to unqualified ASUS hardware. Qualify any future read for read-clear/side effects and history coverage first.

Lookup update: the official USB-IF document index exposed the November 2025 archive, which was downloaded and hash-pinned in interval4. The base-specification register page was extracted and visually checked; the original ZIP/PDF stay private. Earlier failed direct retrieval remains preserved. The newer ITE Linux driver path was absent from the inspected pinned upstream tree; an unmerged patch is not an installed ASUS implementation. No absence claim is based on either lookup failure. Two initial local commands used unsuitable PowerShell wildcard/path forms and were corrected; originals were not changed.

## Publication discipline

The local Git index predates API-published changes. Read fresh GitHub main, compare affected files with that immutable commit, and publish only the reviewed allowlist while preserving all other paths/history. Verify blobs, tree, parent and final head. Private dumps, firmware, disassemblies, hardware pointers, user paths and raw recovery receipts stay local. Update the evidence model for new claim-bearing results and regenerate the reports.
