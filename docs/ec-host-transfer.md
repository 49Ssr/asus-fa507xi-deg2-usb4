# The EC has a transfer command, but it targets the update interface

**The BIOS-supplied EC implements a host-requested bus transfer. Its target is fixed at address byte `80`, not the normal PD address `98`.** This was checked by executing the original receiver and handlers in an offline CPU model. No command was sent to the laptop.

That is more specific than saying that all useful EC reads are internal. The remaining questions are whether an existing Windows interface reaches this receiver, and what read operations the fitted IT8857 supports at its update address.

## What the recovered route does

The host receiver is PMC3, separate from the PMC4 path used by the successful Windows cache getter. Its command handlers stage outgoing bytes, request a transfer, and return the stored result:

| Operation | Recovered behaviour |
| --- | --- |
| Stage payload | Saves up to 32 outgoing bytes in EC RAM |
| Transfer | Uses EC channel 4 and fixed address byte `80`; caps the requested read length at 32 bytes |
| Report completion | Returns `CC` for the bus helper's success result, `EE` for failure |
| Retrieve result | Returns the stored length and buffer; this does not itself prove that the previous transfer succeeded |

The address is assigned by the firmware immediately before its bus call. Putting `98` in the payload does not change the destination: it becomes a data byte sent to address `80`. Therefore this route cannot reproduce the normal `B6` version read simply by changing the packet contents.

The same EC image has an internal helper that sends two-byte selectors to address `80` and reads one byte. Its version-initialization routine uses this helper before the separate normal-address `B6` read. This establishes that the two address spaces have different framing in the original firmware. It does not identify arbitrary update-interface reads or their side effects.

## Windows access is still a separate question

The reviewed AsusSAIO legacy EC request uses fixed host I/O ports `25C/25D` and sends the prefix used by PMC4. Its request packet has no host-port selector. Sending a PMC3 opcode through that existing cache-read route would not select PMC3.

The driver contains low-level port helpers, but their existence is not an application-callable port API. This review has not established a Windows request that reaches the PMC3 receiver. It also has not ruled out every other installed driver or firmware method.

## What was verified

The [offline test](../tools/analysis/Test-EcPmcTransfer.c) runs the original PMC3 receiver, bank trampolines, command handlers and response-output code. The actual bus call is replaced with a RAM fixture. It checks payload preservation, the fixed destination, length limiting, success/failure replies and result retrieval. On a failed simulated transfer, retrieval can return the old buffer; the preceding completion result must not be discarded.

The input is the already-pinned BIOS 314 EC image. This tests code behaviour, not physical access, live flash identity, timing or controller acceptance. [Hashes and code anchors](../evidence/ec-host-transfer.json).

## Continue from here

Follow the acquired IT8857 reference tool's update-address read helpers and the installed drivers' host-interface selection. A useful result would be a defined read operation and a demonstrated route to the correct receiver. Do not equate a bus-transfer wrapper with a PD logger, send a normal-address register to the update interface, or enter update mode merely to see what happens. The missing handshake and Data_Reset implementation remain unresolved.

[Version-path audit](it8857-version-path.md) · [Windows access](windows-repair-route.md) · [Diagnosis plan](investigation-plan.md)
