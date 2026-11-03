# Can Windows reach the missing controller state?

**We know how Windows reaches ASUS's UCSI relay. We do not yet have a verified Windows read of the PD controller's entry decision or the PS8830's applied state.** That is the access problem behind the uncertain repair path.

The [diagnosis plan](investigation-plan.md) ranks the next work. This page records what the available interfaces can and cannot do.

## Available interfaces

| Route | What has worked | What is missing |
| --- | --- | --- |
| UEFI-variable reads | Stored USB4/TBT3 settings and RT0/RT1 fields | The controller's applied attachment-time decision |
| Windows USB4/UCSI traces and dumps | Roles, commands, topology and native router-detection samples | Private PD negotiation and complete physical-link history |
| Standard DEG2 descriptors | BOS, Billboard status and strings | A fresh entry request/reply or retimer/training result |
| Existing ASUS OEM driver | Fixed identity string and cached PD firmware word | A current controller-state read; the attempted dynamic PDO getter is a firmware stub |
| ASUS Parade updater endpoint | Inspected code and retained failed requests | Proof that this endpoint reaches the runtime mode/status interface |
| DEG2 WinUSB interface | Enumerated interface and a reference GUID match | The actual firmware's command handler, reply format and side effects |
| IT8857 UEFI vendor tool | Version branch, B6 transaction and address conversion traced | Reconfigures host I²C; no established Windows bridge or physical PD bus match. [Audit](it8857-version-path.md) |
| EC PMC3 transfer handler | Original receiver and handlers execute offline; fixed update address80 | Identity/update reads identified; live-state fields and Windows access remain unresolved. [Read review](update-interface-reads.md) |
| AsusEC_X64 command DLL | HID and helper-driver backends traced | Matching HID absent from inventory; helper not in filtered service list and loader can install it. [Details](update-interface-reads.md) |

Supporting records: [settings](../evidence/firmware-settings-read.json), [attachment](rt0-attachment-order.md), [dock report](billboard-comparison.md), [OEM access](control-reachability.md), [PD version](pd-firmware-version.md), [interface review](../evidence/windows-repair-route-review.json).

## What the reference code contributes

The acquired [Infineon SDK 3.9.0](infineon-sdk-review.md) contains AMD/PS8830 definitions and compiled functions. It helps explain mode-setting order, status handling and failure paths. It is an Infineon implementation; ASUS's photographed controller is ITE IT8857FN. The transports and registers cannot be assumed interchangeable.

The [PS8830 reference](component-behavior.md) exposes software-written mode/orientation fields. Even a correct read of those fields would need an independent entry or training result. The SDK's APU status transaction is also distinct from a PS8830 read and from a DEG2 USB vendor command.

## DEG2: firmware inventory versus negotiation capture

**3 November:** the compiled Infineon reference reads are now traced. The earlier review already established that its flash log is a fault history, not a full PD transcript; this work closes the unknown about the getter itself. [Source pins, original-code checks and limits](../evidence/deg2-windows-capture-review.json).

| Reference read | What the original code returns | What it can establish |
| --- | --- | --- |
| D6 status | Existing dock/component update state and firmware versions, limited to the requested/stored length | Component inventory if the protocol matches DEG2 |
| D7 identity | At most 73 bytes in the inspected library | Configured identity; newer client formats can expect an additional byte |
| DE flash log | Optional 512-byte fault/event record | Some retained resets or faults; not the Enter_USB request and reply |

The 24-byte flash getter checks initialization and returns an existing pointer. It performs no stores or calls. It does not start a capture or clear the record. The application handler declines DE; only the optional fallback supplies the log. The original D6/D7 branches were also checked with supplied memory and mocked USB replies. These are tests of the published reference binary, not requests to DEG2.

Windows itself has a usable transport for this class of interface: [WinUSB accepts user-mode vendor control transfers](https://learn.microsoft.com/en-us/windows/win32/api/winusb/nf-winusb-winusb_controltransfer). Infineon's [Dock user guide, sections 8 and 8.2](https://www.infineon.com/assets/row/public/documents/24/44/infineon-ez-pd-pmg1-s3-dock-user-guide-usermanual-en-09018a9080d3e3ed.pdf) documents a Windows component-version query through its tool. That is a possible inventory route once matched, not a packet recorder. No new kernel driver is inherently required for a working WinUSB binding.

The independently maintained [fwupd DMC client](https://github.com/fwupd/fwupd/tree/5a209d7627cfe7f08c07fda74d1ec4377747fe05/plugins/ccgx-dmc) confirms the inventory protocol and separates it from update commands. Its inspected device list does not include DEG2's 041f:d002. Neither that absence nor the shared interface GUID settles compatibility. Reading an interrupt endpoint would not automatically capture PD: this reference uses interrupts for firmware-update messages.

### The missing package is the Dock SDK

The acquired **Host SDK 3.9.0** is different from the **Dock SDK**. In [an Infineon support answer](https://community.infineon.com/t5/EZ-PD-USB-Type-C/CYPM1322-97BZXI-andThunderbolt-5/td-p/1172878), the vendor directs developers working on PMG1-S3 Thunderbolt 5 firmware to the [Dock SDK access-request page](https://softwaretools.infineon.com/assets/com.ifx.tb.tool.ezpddocksdk). This is a concrete reason to request access; another Host SDK download is unnecessary.

The useful review is its TB5 USB command handler, component identity and logging options, compared against DEG2. It would still be reference code, not Minisforum's production image. The public Griffin Creek example uses Goshen Ridge; its behavior cannot be assumed to describe DEG2's TB5 implementation. No raw PD logger or DEG2 firmware package has yet been acquired.

For a manufacturer diagnostic to answer this case, it needs to retain the attachment sequence: partner/cable discovery, the entry request and reply (or the reason entry was skipped), any Data_Reset/exit, and the result passed between the PD and router controllers. A report of current mode alone cannot recover that sequence. A Windows USB trace cannot recover CC traffic that the controller never exports.

## Three tempting shortcuts that do not work as evidence

**A matching GUID does not identify a vendor protocol.** DEG2's interface matches an Infineon example, but the same GUID appears in an unrelated SDK. The inspected Infineon application conditionally dispatches DMC requests and invokes its application handler before optional log handling. Its D6/D7 fields describe component identity, image status and versions; they are not the missing PD exchange. That code does not establish DEG2's command implementation.

**A cached mode word is not a packet transcript.** In the Infineon reference, BOS may start from a configuration template. Saving an EUDO can also precede the mux operation and its result. DEG2's ASUS/Dell difference remains a real device report, but it does not prove which entry packet was sent or accepted.

**A BIOS variable setter is not a port-only repair.** The inspected Quanta function writes across PBS, network-stack, Setup and ASUS setup-item data, plus MMIO. An early write can precede a later failure. No atomic USB4-only operation or Windows runtime caller was established. It was not invoked.

[Original-code anchors and limits](../evidence/windows-repair-route-review.json).

## Data_Reset remains a candidate, not a ready command

The proposed recovery is to restart USB4 discovery after role correction without undoing that role. The [command-path trace](data-reset-command-path.md) establishes EC forwarding, but not the laptop PD firmware's reset handler. UCSI reset meanings differ by version, and the retained version fields do not settle that question.

The existing transport is useful if the receiving operation can be identified. Building another unrestricted sender before then would not resolve the uncertainty. [Reset hypothesis and prerequisites](ucsi-data-reset.md).

## What would change this assessment

A matched controller implementation, documented logger or traced current-state reader could supply a useful Windows route. The first deliverable should state exactly which decision or result it observes, how current the value is, and whether reading it consumes an event or changes device state. If a route returns only identity or a cache, record that limit and pursue a different source.

No usable route has been established yet. That does not prove that a Windows repair is impossible. It means the repository should not advertise a logger, reset test or patch before its actual behaviour is known.

[Diagnosis plan](investigation-plan.md) · [Findings](status.md)
