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

Supporting records: [settings](../evidence/firmware-settings-read.json), [attachment](rt0-attachment-order.md), [dock report](billboard-comparison.md), [OEM access](control-reachability.md), [PD version](pd-firmware-version.md), [interface review](../evidence/windows-repair-route-review.json).

## What the reference code contributes

The acquired [Infineon SDK 3.9.0](infineon-sdk-review.md) contains AMD/PS8830 definitions and compiled functions. It helps explain mode-setting order, status handling and failure paths. It is an Infineon implementation; ASUS's photographed controller is ITE IT8857FN. The transports and registers cannot be assumed interchangeable.

The [PS8830 reference](component-behavior.md) exposes software-written mode/orientation fields. Even a correct read of those fields would need an independent entry or training result. The SDK's APU status transaction is also distinct from a PS8830 read and from a DEG2 USB vendor command.

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
