# BIOS314 EC firmware: silent telemetry stub and UCSI relay

**Subsequent bus-engine work:** the original common1ff4 transfer engine and helpers now execute in10 offline scenarios, with peripheral registers simulated. This is additional coverage beyond the relay tests below, which still stop at a doubled bus call. An internal bus gate and its original vendor-handler set/clear paths are identified, but its live state and relevance to USB4 failure remain unknown. [Full results and decoded trace gaps](trace-gaps-and-ec-bus.md).

**1 November 2026:** executable EC firmware has now been recovered from another region of the exact ASUS BIOS314 package. Its OEM table6 handler returns without writing a reply. Its capability17 and `IT8853` identity getters also reproduce the live results. This explains the diagnostic timeout in this EC build; it does **not** establish the cause of the ASUS-DEG2 USB4 failure. A separate UCSI relay forwards command/data bytes to the PD controller without a mode-policy substitution in the routines tested. **No working Windows USB4 repair has been established.** [Structured evidence](../evidence/ec-firmware-decision.json).

## Exact input and address model

The [official ASUS BIOS314 package](https://dlcdnets.asus.com/pub/ASUS/GamingNB/Image/BIOS/117046/FA507XIAS314.zip) supplies the input. The capsule is33,556,480 bytes, SHA-256 `a72291441a378a38a1aa7d5198c4aeb91aed07f787a3025435393719351f4ed1`. The EC image occupies capsule offsets `81800..c17ff` inclusive:262,144 bytes, SHA-256 `103721578b66daed81dcf7a0bed06709c072f9da1dc75a6d7887321e6e32b060`.

The image contains an ITE EC signature, the exact board-family marker `ASUS_FA507_707_XU_XV_XI`, build date2024/03/14 and EC build03.09F. A current read-only BIOS inventory reports `FA507XI.314`, EC major3/minor9. These are consistent identifiers; **the running EC's physical flash has not been read back or hash-matched**. The BIOS image is not a qualified flash rollback backup.

The 8051 address model has a common lower32KiB and an upper32KiB selected by the low three bits of SFR P1. For a nonzero bank selector and CPU address at least`8000`, the image offset is `cpu_address + (selector-1)*8000`. Common trampolines at`3000`, `3014` and`3028` select banks1,2 and3. Addresses below refer to **CPU addresses in bank3**, except where marked common. Disassembling bank2 at its physical file offset gives misleading relative branch addresses; the extractor emits complete64KiB CPU views.

The earlier IT8987-labelled, mostly blank body remains a placeholder. It was not the executable image. A neighboring64KiB 8051 body contains a PS8830 retimer project marker; it must not be treated as identified IT8853 PD firmware merely because it is8051 code. Its hash differs from the three previously reconstructed CFU images. The Cypress-labelled neighboring body is also not an identified IT8853 image.

## Why the OEM read times out

The original PMC4 service at`9590` receives host commands through XDATA status/input/output registers`1530/1532/1531`. It accepts the command prefix, opcode and parameters. Its `DD` handler at`982c` then dispatches by table index.

| Request | Original firmware path | Result |
| --- | --- | --- |
| `BB 50` | Getter at`980b` | Writes17 (`11` hex) to the host output register |
| `DD 05`, fields02..0d | Getter at`b038` | Returns the literal six-character identity `IT8853`, followed by six zero bytes |
| `DD 06`, any field | Table dispatch at`9854` selects`b162` | Bare return; **no output byte is produced** |

The table6 branch occurs before a field-specific getter. This is a missing implementation in this BIOS-supplied EC build, not evidence of a PD-wire timeout. Increasing the Windows driver's response wait cannot create a reply. The same conclusion applies to trying other fields in that table; no new live request is warranted by a field change.

The identity string is constructed from immediate character constants. **The successful live identity request did not independently read the PD chip's identity registers.** It reports the identity expected by the EC build. This tightens the wording of the [earlier live result](oem-pd-diagnostics.md); it does not invalidate the measured request completion.

The [previous trace replay](it8853-transport.md) recovered four response-ready timeouts after command/parameter transmission. A silent table6 return predicts exactly that host-side wait. Attribution of those four retained records to the two earlier PDO requests remains an inference because the records contain no original command arguments or timestamps. The static/live build match is strong supporting evidence, not a live flash-byte comparison.

## Where UCSI commands actually go

The EC contains a **different** controller bus path. Its common routine`1ff4` receives a channel, bus address and read/write descriptor. The UCSI relay uses channel4 and address byte`98`. This is a bus-address representation, distinct from the UCSI register offset of the same numeric value. No live bus transaction was issued in this investigation.

| Bank3 routine | Operation recovered |
| --- | --- |
| `c89a` | Takes a pending opcode from shared-mailbox offset08 into EC state`0585`, clears that mailbox byte, and branches to the outgoing relay |
| `bacf` | Builds a25-byte write: register`98`, saved opcode, remaining seven CONTROL bytes, and sixteen MESSAGE_OUT bytes from mailbox offset20 |
| `bba3` | Reads vendor interrupt register`bd`; when bit1 is set, reads20 bytes starting at`84`, copying four CCI bytes to mailbox offset04 and sixteen MESSAGE_IN bytes to offset10 |
| `bb4f` | Builds the vendor acknowledgement transaction with bytes`bc fe` and a one-byte read |

These offsets agree with [ITE's own UCSI driver submission](https://lists.openwall.net/linux-kernel/2026/08/07/804): CONTROL`98`, CCI`84`, MESSAGE_IN`88`, vendor interrupt`bd` and acknowledgement`bc`. This corroborates the interface family; it does not identify every ASUS vendor register or qualify generic ITE tooling on this laptop.

Original relay instructions preserve the command parameters and outgoing payload across every synthetic opcode byte and three payload patterns tested. This is **not a claim that all256 opcodes are valid or supported by the PD controller**. The tests stop at the controller bus boundary. The outer service's scheduling, asynchronous events, physical transport, power and mux/link training are not emulated.

There are also controller-specific transactions, including cache population through register`b6`, and gated writes using`d8/d9`. Their exact mode-policy meaning and safe inverse are unqualified. They are **not prepared as Windows commands**. **Correction from the later original-instruction replay:** table5 fields`10/11` hex read EC cache bytes`02ac/02ad`. The earlier `0f/10` mapping was incorrect. These are not a raw negotiation trace. No cache query was sent in the original 1 November work; [the later Windows read returned0053](pd-firmware-version.md).

## What this changes for the USB4 investigation

The saved ASUS and Dell captures remain the attachment evidence. They already show successful standard UCSI power-profile reads on ASUS, completed role correction, an absent external USB4 router and the dock's differing cached USB4/DP state. The new firmware work separates the failed OEM telemetry request from that working standard command path. It does not recover an Enter_USB wire exchange from the dumps.

The tested relay is not a demonstrated Windows-overridable USB4-versus-DP policy switch. The next unresolved boundary is the PD controller's actual entry decision and the consumer of its mux/retimer configuration. The [ITE DisplayPort proposal](https://lists.openwall.net/linux-kernel/2026/09/18/1326) shows how a different platform queries mode state and configures its mux/retimer; it supplies neither this ASUS board's USB4 consumer nor a transferable Windows repair.

No new boot, reconnection, device reset, driver installation, firmware write or security/network setting change was made. No raw register/mux write or flash test is queued. A candidate repair still needs an identified operation, ownership/timing, measurable router/GPU/display success and a verified inverse or recovery path. The failed pre-attachment role-policy trial and cold-start capture remain completed exclusions; this finding does not justify repeating them.

## Reproduce offline

**Coverage follow-up:** `--service` now executes the surrounding command-service routine in15 additional scenarios, with the controller bus, debug logger and OS-event delivery explicitly simulated. It tests retries, gates, reply/acknowledgement failures and retained-result counters. It does not establish physical bus operation, wall-clock timing or delivery to Windows. [Plain explanation and missing measurements](investigation-gaps.md), [service results](../evidence/ec-command-service.json). The earlier69 PMC and2,306 relay cases also pass with the revised harness.

1. Obtain the exact official capsule above. Run `python tools/analysis/Extract-BiosEc.py <capsule> <new-private-directory>`. It pins both hashes and refuses an existing output directory.
2. Obtain `core.c`, `opcodes.c`, `disasm.c`, `emu8051.h` and its MIT license from [emu8051 commit5dc681275151c4a5d7b85ec9ff4ceb1b25abd5a8](https://github.com/jarikomppa/emu8051/tree/5dc681275151c4a5d7b85ec9ff4ceb1b25abd5a8).
3. In an MSVC developer terminal, build `cl /TC /std:c11 /O2 /MT /W3 /I<emu8051-directory> tools/analysis/Test-EcPmcFirmware.c <emu8051-directory>/core.c <emu8051-directory>/opcodes.c <emu8051-directory>/disasm.c /link bcrypt.lib`.
4. Run the resulting executable with the private `ec-main-full.bin`; add `--relay` for the controller-boundary cases. These are ordinary user-space offline tests with no hardware backend.

**Validation:**69 PMC service/dispatch/getter cases and2,306 relay cases pass: **2,375 total**. PMC cases use three initial XDATA patterns. Relay cases comprise1,536 outgoing combinations,768 interrupt/completion combinations and2 acknowledgement outcomes. All unexpected peripheral accesses, stack imbalance, bank changes and execution-budget violations stop the harness. The PD-bus call at`1ff4` is an explicit RAM double; it is not tested as a physical I2C engine. Old truncated firmware input is rejected. Extraction succeeded against the full pinned capsule; attempting to reuse the output directory was rejected.

Early harness attempts exposed an incorrect assumption that MESSAGE_OUT immediately followed CONTROL; the original firmware correctly uses offset20, leaving MESSAGE_IN at10. Another initial assertion omitted the acknowledgement's one-byte read. Both assumptions were corrected from the original instructions; failed outputs remain private. The earlier69-case run used an initial truncated extraction whose tested instructions were intact; the final69 and2,306 cases use the complete256KiB pinned image. No vendor firmware, full disassembly, memory dump or identifying capture is published.
