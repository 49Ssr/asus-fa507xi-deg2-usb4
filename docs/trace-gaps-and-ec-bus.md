# Remaining trace records decoded; EC bus-transfer code exercised

**1 November 2026:** the data fields in all342 previously undecoded records from the saved ASUS attachment trace have been recovered. They describe USB endpoint activity, device-slot setup, buffer cleanup and USB4 timing-policy handling. They do not contain the missing USB-C entry exchange. The original EC bus-transfer routine has also now been executed offline, including its refusal, error and timeout paths. **The physical ASUS-DEG2 failure remains unresolved.** [Structured evidence](../evidence/trace-gaps-and-ec-bus.json).

## What the remaining records contain

The unchanged239,206,400-byte trace has SHA-256 `9e0501dae7910fc709aeca47ea64017a63539ae72cfaf240b602389ada0ef172`. A read-only `OpenTrace/ProcessTrace` consumer scanned all1,114,490 events. It recovered342 missing records and two already-readable control records. Processing and file-consumer close both returned0; no live trace session was opened.

| Count | Driver / message | Recovered content and scope |
| --- | --- | --- |
| 331 | USBXHCI /12, GUID`a3776331-57bf-31b1-028e-c9b09d96ef8f` | Endpoint context plus three32-bit fields: state before, triggering event, state after. There are26 contexts. These are USB endpoint state-machine records, not USB4 entry messages. |
| 7 | USBXHCI /11, GUID`cb7a5c27-8baa-3da6-3050-9d7564b04261` | Device-slot context installation. The original successful set-context path emits these records; payload is pointer/slot/address. |
| 2 | USBXHCI /25, GUID`2cbb8eab-a489-3cb9-c10a-668c9784ba4d` | An unused common-buffer resource being freed; one address field. This is not a controller-communication timeout record. |
| 2 | Usb4HostRouter /22, GUID`10adc54e-b705-390a-5f23-145e373e5c16` | Logging prefix and policy context, emitted by the timing-policy routine's branch that makes no policy change. It is a verbose trace, not an error branch. |

The two known controls are host-router message15 at00:52:17.0325819 and00:52:27.8446332 UTC. Both decode to minimum timing mode1 and match the already-formatted records. This independently checks the payload extraction and timestamps. The neighboring message22 records are in the same timing-policy function, not a recovered decision to enter USB4 or select DisplayPort.

**These descriptions are analyst labels.** Microsoft's public PDBs omit the four original format strings. We recovered field sizes/order and caller behavior from the pinned original driver instructions; we did not invent vendor sentences and present them as recovered text. Numeric endpoint states are mapped to their compiled handler symbols where possible. Several states share a handler, so all symbol aliases are retained; event IDs and ambiguous state names are not guessed.

## The endpoint stall was followed through

One recovered endpoint sequence enters the halt/reset path at00:52:18.7426572 UTC. The surrounding already-decoded trace identifies the request: Windows was fetching a **Device Qualifier descriptor**. The endpoint stalled, Windows reset it successfully, and USBHUB3 continued descriptor enumeration through an operation-success path.

The first captured no-external-router result was already present at00:52:17.0830516, approximately1.66 seconds earlier. Thus this later descriptor stall does not explain that earlier absence of the USB4 dock. This is not a claim that every endpoint event was harmless or that every subsequent operation succeeded. It distinguishes this particular handled USB request failure from the missing USB4 connection attempt.

## Following the code that talks to the controller

Earlier relay tests replaced the whole EC bus call with a supplied result. The new `--engine` mode executes the original common routine`1ff4` and its original helpers against the same pinned BIOS314 EC image. Its peripheral register reads/writes terminate in RAM; byte-ready, completion, bus-state and error inputs are simulated. The ready/completion double consults the firmware's remaining-byte counters; it is not an independent I2C-device or electrical model. This advances software coverage **through the transfer engine**, not through a physical PD chip.

For channel4 the firmware's table selects bus registers`1ca0..1caa`. The original code writes address byte`98` to`1ca3` and exchanges data through`1ca7`. The outgoing UCSI register selector and command/data bytes therefore reach the bus engine; the numeric register selector`98` is a different field from the coincidentally identical address byte.

Ten contained scenarios now pass:

- Invalid channel, unsuitable pin configuration or bus-state low bits not equal to3 can reject a transfer before an address write.
- Internal flag`030e.bit1` blocks normal controller address`98` on channel4, while address`80` is exempt from that particular check.
- With modeled ready/completion inputs, the original engine writes the complete25-byte outgoing packet and performs a one-register/20-byte read correctly.
- An injected status`04` takes a failure path. Supplying no ready event reaches the original timer timeout and recovery code. These inputs are not measured faults on ASUS.
- Original vendor-handler case`75` sets the blocking flag; case`76` clears it and sets a retry counter. Executing those handlers only inside the emulator reproduces blocking and restoration of the modeled transfer.

The gate has other state-management paths: bank1 code at`be2d` clears the bit, and bank2 code at`c93f` can restore the entire byte from another EC memory location. We have not established all runtime circumstances of those paths. The gate's value has **not** been read from the running EC during failure. Ten ordinary Windows commands completed in the saved attachment trace, which argues against a continuously blocked normal command path in that observation.

**Cases75/76 are EC vendor-handler cases, not UCSI commands or a proposed live repair.** No such command was sent. A simulated inverse does not establish that changing this flag is necessary, sufficient or safe on the real machine. We have found a concrete communication gate to investigate, not an explanation of why DEG2 fails USB4.

The bus model initially supplied idle bits in the wrong register. Original execution stopped before any address write; following the table corrected the model to`1ca9` low bits. This was a test-model error, not evidence of a hardware fault. Earlier failed outputs are preserved. Timer mode`11` matches the firmware's common initialization at`2998`; emulator timing is not a measurement of this EC's oscillator or physical bus timing.

## Tools and validation

- [Extract-USB4TraceGaps.c](../tools/analysis/Extract-USB4TraceGaps.c): reads an existing ETL only; compile with MSVC and`advapi32.lib`. Output includes private addresses and must remain private.
- [Decode-USB4TraceGaps.py](../tools/analysis/Decode-USB4TraceGaps.py): validates pinned driver inputs, exact payload lengths and the captured record set; decodes fields and preserves ambiguous handler aliases.
- [Read-PdbPublics.py](../tools/analysis/Read-PdbPublics.py): reads local MSF7/PE64 files, checks the PE GUID and DBI age, and extracts public symbol addresses. These stripped Microsoft PDBs have Info age4 and DBI/PE age1; that difference is reported, not hidden. Fresh downloads from Microsoft's exact GUID/age symbol paths match the cached PDB hashes. A deliberately mismatched PDB is rejected.
- [Test-TraceGapSerializers.py](../tools/analysis/Test-TraceGapSerializers.py):12 cases execute the four original logging serializers with a RAM logging sink. Their emitted bytes match the decoder layouts. Ten malformed payload lengths and an unreviewed message type are rejected. An initial callback-stack assertion was corrected to include the return-address slot; the failed attempt is preserved.
- [Test-EcPmcFirmware.c](../tools/analysis/Test-EcPmcFirmware.c), `--engine`:10 original-engine scenarios pass. Prior69 PMC,2,306 relay and15 caller cases also pass after the change. All are offline software checks.

The raw ETL, payloads, decoded record lists, kernel addresses, Microsoft PDBs and vendor firmware remain private. No new boot, reconnection, device request, driver install, firmware write or persistent setting change occurred.

## Motherboard number: still unverified

The owner's proposed`60NR0EB0-MB2010` has not been confirmed on this laptop. Current Windows inventory reports ASUS/FA507XI/version1.0, without that PCB or assembly number. The [official ASUS parts shop](https://partshop.asus.com/us/90nr0ff0-r00015.html) lists an FA507XI/Ryzen9 motherboard assembly as`90NR0FF0-R00015`. That is a product listing, not a serial-specific identification of the fitted board, and does not determine its PCB marking or revision.

We are not selecting firmware, board files or pin assignments from an unverified forum model label. ASUS also provides [public FA507XI service guides](https://www.asus.com/us/supportonly/fa507xi/helpdesk_service_guide/); a boardview, repair guide and full electrical schematic are different documents. The present decoding and firmware tests do not depend on buying a schematic.
