# Could a data reset restart USB4 entry?

2 November 2026. **A plausible repair candidate, not an executable ASUS test or a demonstrated fix.** No reset was sent and no new driver or boot was prepared.

**Command-path follow-up:** [The ASUS EC initializes a fixed 1.0 mailbox version and preserves the reset bit](data-reset-command-path.md). The SDK supplies a real 2.0 reset handler. The actual receiving ASUS PD firmware remains unidentified; no live reset has been sent.

## The change we actually want

ASUS already completes the USB data-role correction and enumerates DEG2's USB hub. The proposed change is to restart USB4 discovery **after** that correction while preserving the resulting roles. This tests whether the controller failed to reconsider USB4 after the role changed. The existing traces do not prove that this is the cause.

USB-PD `Data_Reset` resets data connections and exits alternate modes while preserving the power contract and data roles. The Type-C specification's exit procedure then returns to USB4 discovery and entry. A USB-PD hard reset is different: after a data-role swap it restores the data roles associated with the CC resistors. It can undo the condition we want to preserve. [Type-C 2.4, section 5.4.4.2](https://e2e.ti.com/cfs-file/__key/communityserver-discussions-components-files/196/USB-Type_2D00_C-Spec-R2.4-_2D00_-October-2024.pdf), [USB-PD 3.0 version 2.0 with ECNs, sections 6.3.14 and 6.8.3](https://e2e.ti.com/cfs-file/__key/communityserver-discussions-components-files/138/USB_5F00_PD_5F00_R3_5F00_0-V2.0-20190829-_2B00_-ECNs-2020_2D00_02_2D00_07.pdf).

## Why a generic Windows reset script is insufficient

The same UCSI command field has changed meaning:

| UCSI version | CONNECTOR_RESET bit 23 |
| --- | --- |
| 1.0 | 0 selects soft reset; 1 selects hard reset |
| 1.1 / 1.2 | Reserved; must be zero |
| 2.0 and later | 0 selects hard reset; 1 selects data reset |

The matching Linux implementation branches on those versions. UCSI 1.22 instead specifies a disconnect/connect sequence and reserves bit 23. Microsoft's example page still labels its examples soft/hard; those labels alone do not establish what ASUS would execute. [Pinned Linux implementation](https://github.com/gregkh/linux/blob/2fe596715f840d053aed5cee5455f701bdcd2b50/drivers/usb/typec/ucsi/ucsi.c#L1357), [UCSI 1.22, section 4.5.3](https://www.intel.com.br/content/dam/www/public/us/en/documents/technical-specifications/usb-type-c-ucsi-spec.pdf), [Microsoft examples](https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/ucsi#ucsicontrolexe).

The saved ASUS class-extension and ACPI-client version fields are both `0xffff`, with the reported-version opt-in false. These are retained software fields, not a new physical read. Microsoft documents that this opt-in state makes Windows use the 1.2 layout for reported versions at least 2.0. It does not prove that the controller implements a version-2 data reset. Do not reinterpret `ffff` as evidence of the newest protocol or change it to force support. [Existing ASUS evidence](firmware-entry-followup.md), [Windows version handling](https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/ucsi#ucm-ucsi-acpi-device-for-ucsi-20-and-greater).

## What would make this worth running

Identify how the actual ASUS controller accepts a data reset, using its implementation or matching documentation. The reference SDK's HPI/I2C operations have not been connected to ASUS's ITE path or DEG2's USB interface. The already reviewed UCSI relay is not itself proof that the receiving controller implements a particular reset type.

With that command identified, a small Windows runner could wait for the corrected host role, issue one data reset, and record whether an external router, RTX device and display appear. It must record the resulting role too: command acceptance alone is insufficient. No repeated reset loop, persistent policy change or new full dump is needed for that question. Any future procedure needs an explicit restoration path; disconnecting and reconnecting restores an attachment, not a verified byte-for-byte controller snapshot.

**Current decision:** continue into the controller's reset handler/transport. Do not send a version-2 command, substitute a hard reset, or claim that a repair runner exists yet. This is a specific software-repair hypothesis, separate from the PS8830 status-read research.

[Structured source review](../evidence/ucsi-reset-review.json) · [Windows repair research](windows-repair-route.md)
