# An ITE reset path and a four-byte state reader

**The acquired IT8857 add-in-card firmware contains a command receiver that can request `Data_Reset`, plus a separate command that returns four bytes of per-port state.** These paths now run in an offline CPU model. This is a useful implementation to trace, but it is not yet a Windows command for the FA507XI.

The image belongs to the ASUS USB4 PCIe add-in card. It is not the laptop's installed PD program. No firmware was flashed, controller command sent or driver loaded. [Evidence, input hashes and code locations](../evidence/it8857-runtime-commands.json).

## What the original instructions do

| Path in the reference firmware | Verified behaviour | Remaining uncertainty |
| --- | --- | --- |
| Command receiver, selector `05`, one-byte payload `01` | Requests internal state `0708`; that state passes PD control-message type `0e` (`Data_Reset`) to the send helper | Which physical host interface carries this protocol; whether the laptop implements it |
| Same receiver, payload `02` | Requests a different state, `0001` | Its full effects were not tested; it must not be treated as another encoding of Data_Reset |
| Read selector `10` hex | Copies four per-port RAM bytes into its reply, reversing their memory order | Several producers are now traced below; complete bit meanings and the laptop equivalent remain unknown |
| Incoming SOP control-message `0e` | Passes type `04` (`Reject`) to the send helper in the tested handler | This is reference-code behaviour, not an observed ASUS or DEG2 reply |

The incoming and outgoing paths are separate. The reference can request a Data_Reset even though this incoming handler selects Reject. Neither result demonstrates successful transmission, acknowledgement or reset completion.

These selectors belong to the recovered receiver. **They are not UCSI opcodes, Windows IOCTLs or commands to send to DEG2.** The receiver was followed through its byte-input code into the state request; its electrical interface and bus address have not been identified. In particular, selector `10` is not a proven read at the updater's address `80`.

The four-byte reader obtains a software-maintained record. The follow-up below traces actual producers, including an incoming Enter_USB path. It is not a retimer register read or a link-training measurement.

## What writes the record

The reference data-message table sends type `08` (`Enter_USB`) to the handler at common code `2d4c`. For mode values 0, 1 and 2, it selects an `Accept` reply. Only after its send helper returns `1` does this handler call the record updater. A helper result of `0` leaves the record unchanged. Mode 3 selects `Reject` and returns without that update. These are instruction tests with a supplied send result, not captured PD traffic.

The updater sets mask `00001800`, clears `00000020`, and conditionally sets bit 1 from another per-port field. It also marks a notification record and writes the notification peripheral. The original reader then returns the modified word, least-significant byte first. **The same mask change occurs for USB2, USB3 and USB4 mode requests; these bits alone must not be labelled “USB4 active.”** The mode encodings come from the [pinned Linux PD header](https://github.com/torvalds/linux/blob/46fec1c3029b552ec63b2d01af9d43a386f043ea/include/linux/usb/pd.h#L619).

Two other original routines replace the record with `00000001` or zero. Multiple software paths therefore maintain it. No tested producer reads the PS8830 or checks a trained link. The broader record layout, every writer and the physical meaning of the per-port bit-1 input are not fully decoded.

This gives the record a narrower, useful role: **it can reflect that a controller code path advanced after choosing an entry response.** It is not a packet history, and its current value cannot reconstruct all prior attempts. Whether the laptop has an equivalent remains unknown.

## How the receiver is initialized

The card's startup calls common trampoline `4b78` with channel selector `1`, reaching bank-2 routine `c49d`. The original routine programs the same `fc00` peripheral block used by the command receiver. Among its writes are `fc03=f0` and `fc1f=f8`; its full ordered sequence is recorded in the [follow-up evidence](../evidence/it8857-state-producers.json). The main loop calls the receiver through trampoline `4b9b`.

Those facts connect initialization to the receiver. **They do not establish a bus address to use from Windows.** The meanings of those peripheral registers, external wiring and laptop implementation are still missing. Interpreting `f0` as a usable slave address would skip that missing evidence. The laptop EC's established address bytes `98` and `80` cannot simply be replaced by it.

The [follow-up executable](../tools/analysis/Test-It8857StateRecord.c) reuses the pinned loader and bank model, checks initialization, record producers and their readback on both port indices, and substitutes only the send helper's return value for the Enter_USB branch. Build it as the translation unit with the same emu8051 sources and `bcrypt.lib`. It emits the prior dispatch result and follow-up result as two JSON Lines. No hardware backend exists.

## How the interpretation was checked

The [offline test](../tools/analysis/Test-It8857Dispatch.c) runs the pinned original instructions with RAM and explicitly supplied receiver-register values. It checks both port indices, the reset selector and neighbouring values, the outgoing state and a negative control, the incoming branch, and all four output bytes plus the out-of-range index. It stops before the state setter or transmit helper where applicable. It has no hardware backend.

The large table initially looked like a UCSI dispatcher. Its caller instead selects control versus data messages using the PD header's data-object count. That corrected the interpretation before any command was proposed. A separate initial read-selector inference also failed in the fixture: `06` returns a fixed `5a` first byte; the four-byte record is selected by `10` hex. Failed attempts are preserved privately.

Build from a Visual Studio C compiler environment with the pinned emu8051 sources and `bcrypt.lib`, then pass the private firmware file as the only argument. The program rejects the wrong size or SHA-256. See the evidence record for the emulator revision and the successful result. This is a reproduction tool for code analysis, not a diagnostic to run against a device.

## Checks against the existing Windows route

The retained ASUS GET_CAPABILITY reply reports optional features `0000bd`. Bits 8 and 9 are clear: GET_PD_MESSAGE and GET_ATTENTION_VDO are not advertised. Also, GET_PD_MESSAGE retrieves specified PD response objects; it is not an unrestricted wire recorder. This does not prove that no private state interface exists. No new UCSI command was sent.

A separate public driver proposal for ASUS desktop boards led to Microsoft's Resource Hub Proxy route. That route requires firmware-declared resources. The 23 retained laptop ACPI tables searched here contain no `MSFT8000`/RHPX declaration, and present Windows device metadata shows no matching proxy or ITE88xx node. This does not make the desktop proposal a laptop access path. [Microsoft's interface requirements](https://learn.microsoft.com/en-us/windows/apps/develop/devices-sensors/enable-usermode-access).

The previously unreviewed `Ext3rdCmd` export in AsusEC_X64 also calls the same backend dispatcher already examined. It does not establish an alternate existing PMC3 route. [Earlier Windows backend analysis](update-interface-reads.md).

## Continue from these two questions

1. Do the laptop EC's existing normal-PD reads expose a corresponding entry-result field? Start from its recovered read transactions and consumers, rather than transplanting the card's addresses or bit layout.
2. Can matched controller documentation or the actual laptop PD implementation establish the receiver's bus identity and register meanings? Its startup sequence is now known; its external binding is not.

Answering those would make a reader or reset experiment concrete. The present finding does not justify guessing a target address, treating the card image as laptop firmware, or repeating an unchanged boot. No Windows fix is demonstrated.

[Findings](status.md) · [Windows reset path](data-reset-command-path.md) · [Diagnosis plan](investigation-plan.md)
