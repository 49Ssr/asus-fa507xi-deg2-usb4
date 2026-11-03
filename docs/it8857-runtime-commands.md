# An ITE reset path and a four-byte state reader

**The acquired IT8857 add-in-card firmware contains a command receiver that can request `Data_Reset`, plus a separate command that returns four bytes of per-port state.** These paths now run in an offline CPU model. This is a useful implementation to trace, but it is not yet a Windows command for the FA507XI.

The image belongs to the ASUS USB4 PCIe add-in card. It is not the laptop's installed PD program. No firmware was flashed, controller command sent or driver loaded. [Evidence, input hashes and code locations](../evidence/it8857-runtime-commands.json).

## What the original instructions do

| Path in the reference firmware | Verified behaviour | Remaining uncertainty |
| --- | --- | --- |
| Command receiver, selector `05`, one-byte payload `01` | Requests internal state `0708`; that state passes PD control-message type `0e` (`Data_Reset`) to the send helper | Which physical host interface carries this protocol; whether the laptop implements it |
| Same receiver, payload `02` | Requests a different state, `0001` | Its full effects were not tested; it must not be treated as another encoding of Data_Reset |
| Read selector `10` hex | Copies four per-port RAM bytes into its reply, reversing their memory order | The field meanings, writer, freshness and laptop equivalent |
| Incoming SOP control-message `0e` | Passes type `04` (`Reject`) to the send helper in the tested handler | This is reference-code behaviour, not an observed ASUS or DEG2 reply |

The incoming and outgoing paths are separate. The reference can request a Data_Reset even though this incoming handler selects Reject. Neither result demonstrates successful transmission, acknowledgement or reset completion.

These selectors belong to the recovered receiver. **They are not UCSI opcodes, Windows IOCTLs or commands to send to DEG2.** The receiver was followed through its byte-input code into the state request; its electrical interface and bus address have not been identified. In particular, selector `10` is not a proven read at the updater's address `80`.

The four-byte reader obtains a controller-held record. Calling it “actual retimer state” would be premature: the writer could store requested configuration, a derived report or an older result. Tracing that writer is the next useful question.

## How the interpretation was checked

The [offline test](../tools/analysis/Test-It8857Dispatch.c) runs the pinned original instructions with RAM and explicitly supplied receiver-register values. It checks both port indices, the reset selector and neighbouring values, the outgoing state and a negative control, the incoming branch, and all four output bytes plus the out-of-range index. It stops before the state setter or transmit helper where applicable. It has no hardware backend.

The large table initially looked like a UCSI dispatcher. Its caller instead selects control versus data messages using the PD header's data-object count. That corrected the interpretation before any command was proposed. A separate initial read-selector inference also failed in the fixture: `06` returns a fixed `5a` first byte; the four-byte record is selected by `10` hex. Failed attempts are preserved privately.

Build from a Visual Studio C compiler environment with the pinned emu8051 sources and `bcrypt.lib`, then pass the private firmware file as the only argument. The program rejects the wrong size or SHA-256. See the evidence record for the emulator revision and the successful result. This is a reproduction tool for code analysis, not a diagnostic to run against a device.

## Checks against the existing Windows route

The retained ASUS GET_CAPABILITY reply reports optional features `0000bd`. Bits 8 and 9 are clear: GET_PD_MESSAGE and GET_ATTENTION_VDO are not advertised. Also, GET_PD_MESSAGE retrieves specified PD response objects; it is not an unrestricted wire recorder. This does not prove that no private state interface exists. No new UCSI command was sent.

A separate public driver proposal for ASUS desktop boards led to Microsoft's Resource Hub Proxy route. That route requires firmware-declared resources. The 23 retained laptop ACPI tables searched here contain no `MSFT8000`/RHPX declaration, and present Windows device metadata shows no matching proxy or ITE88xx node. This does not make the desktop proposal a laptop access path. [Microsoft's interface requirements](https://learn.microsoft.com/en-us/windows/apps/develop/devices-sensors/enable-usermode-access).

The previously unreviewed `Ext3rdCmd` export in AsusEC_X64 also calls the same backend dispatcher already examined. It does not establish an alternate existing PMC3 route. [Earlier Windows backend analysis](update-interface-reads.md).

## Continue from these two questions

1. What writes the four-byte record returned by the reference receiver, and which bits describe entry, exit, requested mode or a physical result?
2. What initializes that receiver's physical interface, and is an equivalent present in the laptop's EC/PD path?

Answering those would make a reader or reset experiment concrete. The present finding does not justify guessing a target address, treating the card image as laptop firmware, or repeating an unchanged boot. No Windows fix is demonstrated.

[Findings](status.md) · [Windows reset path](data-reset-command-path.md) · [Diagnosis plan](investigation-plan.md)
