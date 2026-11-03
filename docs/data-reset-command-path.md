# Data_Reset: the ASUS command path and the missing handler

2 November 2026. **The EC forwarding path is established. The receiving PD controller's reset handler is not. No live reset or working repair is claimed.**

**3 November follow-up:** the acquired IT8857 card reference now has a traced receiver-to-Data_Reset state request. Its separate per-port reader also executes offline. These are different-board paths, not the missing FA507XI UCSI reset implementation. [Reference handlers and limits](it8857-runtime-commands.md).

## Windows can reach the forwarding path

| Layer | What the inspected code does |
| --- | --- |
| Microsoft UcsiControl | Its Send path uses the existing UCSI test interface. The inspected executable has legacy 48-byte and extended 528-byte request forms |
| Windows ACPI client / ASUS `_DSM` function 1 | Submits CONTROL and MESSAGE_OUT through the firmware mailbox. The recovered ASUS AML copies all eight CONTROL bytes; it does not remove bit 23 |
| ASUS EC bank3 `c89a` / `bacf` | Saves the opcode and forwards the remaining CONTROL bytes plus MESSAGE_OUT to the PD-controller bus |
| Controller bus | Channel 4, address byte `98`, CONTROL register `98`; these two occurrences of `98` have different meanings |
| Receiving PD controller | Its implementation must turn the request into a particular reset. This is the unverified boundary |

The old mode-exit trial already demonstrated a firmware reply through the Windows route. This does not establish current interface readiness or data-reset support. The new offline test executes ASUS's original relay with bit 23 clear and set, and confirms that both encodings survive unchanged. It stops at a simulated bus. [Earlier relay and live-command evidence](ec-firmware-decision.md), [mode-exit result](experiments.md), [Microsoft UCSI test interface](https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/ucsi#ucsicontrolexe).

## New finding: ASUS initializes a version instead of reading one here

The inspected bank2 caller supplies the EC mailbox pointer, then enters the common `3230` trampoline. That trampoline selects bank3 and dispatches to `c85d`. The initializer clears the 48-byte mailbox, writes version **`0100`**, saves its base and clears the software state through `c822`. This initializer makes no PD-bus call.

Executing those original instructions with three initial RAM patterns produces the same version and cleared mailbox. This proves the initializer's behavior, not that every boot runs it or that another writer cannot change the value later. The EC version, the Windows-facing ACPI region, and the receiving controller's register are separate records. It does not explain the retained Windows `ffff` value by itself.

The reviewed ASUS `_DSM` read path copies completion and message data; it contains no version-copy operation. ITE's direct-I2C reference driver instead reads two version bytes from controller register `80`. That direct-driver read is not an already available Windows command on this EC-mediated laptop. [Retained Windows version evidence](firmware-entry-followup.md), [ITE transport source](https://lists.openwall.net/linux-kernel/2026/08/07/804).

## The SDK contains the receiving-side reference

The acquired SDK's AMD primary build explicitly enables UCSI 2.0 and USB4. Its `Cy_Ucsi_HandleCommands` checks the connector and existing PD contract, selects `CY_PDSTACK_DPM_CMD_SEND_DATA_RESET` for the data-reset encoding, and calls its DPM dispatcher. Its 1.1 build instead requests Type-C error recovery; its 1.0 build selects soft/hard reset.

Three numbers must stay separate: UCSI's connector-reset opcode is `03`; the SDK's internal DPM command is `14` hex; the PD wire control-message type is `0e` hex. The internal enum is not a Windows IOCTL or a DEG2 USB vendor request.

The SDK also handles reset acceptance/completion through alternate-mode cleanup, mux changes and timers. Sending a request is not proof those stages completed. These are **Infineon reference implementations**; the verified ASUS EC and PS8830 images are not an identified copy of the receiving ITE PD-controller firmware. [SDK review](infineon-sdk-review.md), [file hashes, line references and test results](../evidence/data-reset-command-path.json).

## Would a bootable diagnostic interface help?

Linux has a UCSI debugfs command/response console when that kernel feature is enabled. It offers specific standard commands, including connector reset. It does not discover every vendor operation, flush the PD controller into USB4, or capture the physical PD exchange. Its ACPI transport reaches the same firmware `_DSM` path. [Pinned command console](https://github.com/gregkh/linux/blob/2fe596715f840d053aed5cee5455f701bdcd2b50/drivers/usb/typec/ucsi/debugfs.c), [pinned ACPI transport](https://github.com/gregkh/linux/blob/2fe596715f840d053aed5cee5455f701bdcd2b50/drivers/usb/typec/ucsi/ucsi_acpi.c).

A UEFI settings interface likewise does not supply the missing controller command specification. Another unchanged rescue boot is not selected. A useful boot-based experiment must add an identified controller read, reset handler or packet-recording interface first. A PCI rescan and a PD data reset are different operations.

## What remains before sending from Windows

Find the matching receiving-controller firmware or documentation, or establish a supported read that identifies its protocol/reset semantics. Then the existing Windows transport can be used for one correctly defined request, followed by role, router, GPU and display checks. A newer version cannot be inferred from `ffff`, USB4 capability or the SDK's build settings.

[Reset hypothesis](ucsi-data-reset.md) · [Current findings](status.md) · [Research checkpoint](ps8830-investigation-intervals.md)
