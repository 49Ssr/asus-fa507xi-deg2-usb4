# Reaching the firmware: recovered code and tested access boundary

**Subsequent work:** [the installed ASUS PD diagnostic path](oem-pd-diagnostics.md) provides a concrete legacy EC capability getter. The guarded probe is prepared, but Windows cancelled its administrator launch before any device request. That follow-up has no hardware result yet. The measurements below remain the completed metadata-path results.

**1 November 2026:** recovered 23 cached AML tables from the existing ASUS dump, including firmware code absent from the original table files. A real ASUS memory-read helper exists, but the ordinary-process route tested here rejected both metadata requests. DEG2 also exposes a vendor USB interface; its diagnostic protocol remains unidentified. **No Windows repair or replacement test boot is prepared.**

## Recovering the code already in the dump

The original capture saved DSDT and the first SSDT. Windows' live registry exposes the same limited pair. The dump's HAL cache contains **22 SSDTs and one DSDT, totalling 277,336 bytes**. Every recovered table has a matching header length and valid ACPI checksum. The original two tables match their recovered counterparts byte for byte.

The recovered set includes `CPMUCSI`, `CPMMSOSC`, `CPMCMN`, `INTGPP03` and `CPMGPIO0`. These are additional firmware-code inputs; no firmware method was executed to recover them. Microsoft's documented [!acpicache](https://learn.microsoft.com/en-us/windows-hardware/drivers/debuggercmds/-acpicache) supplied the cached ranges. A saved `db` readout was decoded with strict continuity/length/header/checksum checks. Attempts using the debugger's binary file writer did not produce verifiable files; they were not counted as recovery.

The [offline recovery tool](../tools/analysis/Recover-USB4AcpiTables.py) now reproduces extraction from those saved text inputs. Four tests cover valid recovery, malformed inventories, missing/unreadable/discontinuous bytes and corrupted headers/checksums. Replaying the real readout recovers all 23 tables. It performs no device access and never substitutes zeros for unreadable bytes. Raw tables, indexes, debugger plans and readouts remain private. [Sanitised evidence and table hashes](../evidence/control-reachability.json).

ACPICA iASL 20260408 independently disassembled all 23 tables. Intel's published archive SHA-256 was verified before running the tool; the exact Intel archive was recovered from a package mirror after Intel download access failed. No package installer/script ran. A combined-namespace attempt failed on duplicate definitions and is not treated as valid. Individual disassembly used the `M000` argument count confirmed in the loaded namespace. Reviewed methods were cross-checked with the matching debugger; this is not a claim that every external call in every table is resolved. [Intel tool and checksum](https://www.intel.com/content/www/us/en/download/774881/acpi-component-architecture-downloads-windows-binary-tools.html).

## ASUS controls: existence versus access

The complete `CPMUCSI` table shows the `_DSM` command path copying Windows' command/output bytes into the EC mailbox, and status paths copying the EC reply back. It does not expose a separate USB4-entry method in that table. The `_OSC` implementation locally selects USB4 capability mask `0x0f`; its optional `M625` route is not present in the loaded namespace. No new policy override was issued.

Under the actual `NHI0` USB4 controller, **`RPRM` is a two-argument physical-memory read helper**. Its body creates a four-byte SystemMemory region at the supplied address and optionally masks the returned width. The loaded namespace confirms its existence. This is a genuine firmware mechanism, not a hypothetical register API.

It is **not yet a usable application interface**. No call to `RPRM`, its write counterpart or `_RST` was made. Arbitrary MMIO reads are not automatically harmless. Even reaching the known UCSI mailbox would not automatically reveal PD wire packets or an entry-error log; the contents relevant to the failure still need identification.

Two bounded checks tested the existing Windows device-object path without a new driver, boot or security change:

| Check | Result |
| --- | --- |
| Read `_ADR`, independently confirmed as static Integer 5 in the loaded dump namespace | Handle opened; request rejected with Win32 1, unsupported function; zero output |
| Enumerate immediate ACPI child names using the documented SDK layout | Handle opened; request rejected with Win32 1; zero output |

Each request ran once, with a durable intent record, fixed packet, exact model/BIOS/host-driver/ACPI-location guards and bounded cancellation. Both handles closed. Neither requested a reset, physical-memory access or vendor firmware command. This establishes that **these direct metadata requests were rejected**, not that every possible Windows driver route is impossible. It does not identify which layer rejected the requests. No automatic retry or method-evaluation fallback followed. The probe sources/results stay private with their hashes.

Microsoft documents ACPI evaluation and enumeration as [device-driver requests](https://learn.microsoft.com/en-us/windows-hardware/drivers/acpi/evaluating-acpi-control-methods-synchronously), [including namespace enumeration](https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/acpiioct/ni-acpiioct-ioctl_acpi_enum_children). Finding an AML method does not establish a working ordinary-application bridge to it.

The matching Microsoft USB4 driver also has an `EnableDebugInterface` parameter. Its actual registry-loader branch checks test signing before reading it. The reviewed debug dispatcher accepts a configuration-space read request and rejects other codes; no bridge from it to arbitrary ACPI/memory access was established. A normal registry toggle is not an available shortcut through that gate. Nothing was enabled or patched.

## DEG2's USB interface

The existing ASUS dump retains a 32-byte configuration descriptor for DEG2's `041f:d002` device: one vendor-class interface, a 64-byte bulk OUT endpoint `01`, and a 64-byte interrupt IN endpoint `82`. The Microsoft OS compatibility descriptor specifies `WINUSB`; its vendor-request code is `05` for that descriptor mechanism. **That value is not a command for reading PD logs.**

This gives a concrete transport to investigate. It does not identify the controller silicon or the format/purpose of its messages. No endpoint read, bulk write or vendor control request was sent to DEG2.

Infineon's primary DMC SDK documents dock status/identity queries and an optional flash-log retrieval request. Those demonstrate that diagnostic access exists in that firmware family. We have not matched DEG2 to that implementation, so none of its request numbers was sent to DEG2. Similar endpoints and a WinUSB binding are insufficient qualification. [Pinned SDK header](https://raw.githubusercontent.com/Infineon/pmg-app-common/6e1aa9e5786abef91f288bf70b64d89ea400be81/cy_app_dmc_vendor.h), [USB implementation](https://raw.githubusercontent.com/Infineon/pmg-app-common/6e1aa9e5786abef91f288bf70b64d89ea400be81/cy_app_usb.c).

## Next boundary

The remaining work is concrete: identify a supported, Windows-accepted driver route to a relevant ASUS status read, or establish DEG2's exact firmware diagnostic protocol. Access alone must then be shown to reveal the missing USB4-entry/exit evidence. A status-field edit, generic memory poll or unqualified vendor request would not supply that evidence.

No persistent system setting, driver, firmware, boot or network configuration was changed. This work adds code coverage and measured interface results; it does not establish the negotiation cause or a working fix.
