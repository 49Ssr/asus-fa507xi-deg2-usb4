# EC blocking flag: writers, read address and remaining access problem

**Current priority:** the [architecture-led investigation plan](investigation-plan.md) defers a dedicated flag-reader driver. This flag remains a secondary lead; a proposed observer must first show which failed branch its returned value would distinguish. The read target and earlier access checks below remain valid findings, with no live flag value established.

**1 November 2026:** the firmware read address is established, and the path that explicitly sets the flag has been followed back to a host-command receiver. **The flag has not been read on the running ASUS. No USB4 fix is demonstrated.** The saved failed-connection dump cannot supply this memory address. New ordinary-process EC/root-ACPI checks also failed before a memory read. [Structured evidence](../evidence/ec-blocking-flag.json).

## What the flag actually stops

The bit is **XDATA `030e.bit1`** in the pinned BIOS314 EC image. It is not a documented USB4 enable setting.

- The already tested common bus engine refuses normal controller address byte `98` on channel4 while the bit is set. Bootstrap address `80` is exempt.
- There is also an **outer gate**: bank1 `b23c` checks `03ad` and then this bit. A set bit returns before trampoline `32f8`, which calls bank3 `bc20`.
- `bc20` calls the controller event worker `bc3c`, another helper `be59`, **Windows UCSI command service `c89a`**, then `bef9`. Thus a persistent set bit suppresses the whole group, not just a single USB4 mode choice.
- Bank2 `b74b` also returns early when the bit is set, before its controller transaction.

The failed-connection Windows trace already has ten UCSI commands and ten completions without CCI error/busy/unsupported. Together with the outer gate, this is strong evidence **against a continuously set flag throughout those exchanges**, assuming this BIOS-supplied implementation matches the running EC. It is not a direct flag read and does not exclude a short earlier pulse. The BIOS image has not been hash-matched to live EC flash.

## What sets it

| Path in original firmware | Effect | What is established |
| --- | --- | --- |
| Common `0a71` reads a command from PMC3 input `1522`; trampoline `30eb` selects bank3 dispatcher `b947`; case `75` reaches `ba07` | `030e |= 02` | An explicit **host-command** setter. It is not a UCSI opcode and is not a discovered attachment-event setter. |
| Same receiver/dispatcher, case `76`, handler `ba0f` | `030e &= fd`; `03a3 = 0a` | Explicit clear plus retry/state counter assignment; not a qualified repair. |
| Bank1 `be2d`, inside a broader initialization path | Clears bit1 | Another clear site; the surrounding routine is not a safe standalone reset. |
| Bank2 `c93b..c942` | Copies all of retained byte `221b` into `030e` | Another possible writer. The original bounded copy was executed offline for every byte value. Its storage-loading context was not emulated. |
| Bank1 standard EC write getter counterpart `e427`, helper `f081`, offset `0e` | Can replace `030e` | A generic host write can affect it. Executed only against emulator RAM, never on the laptop. |
| Host memory access to the EC shared window | May write the byte without executing an EC setter instruction | The DSDT exposes the window as SystemMemory. A search for EC `MOV DPTR` instructions alone cannot prove exclusive ownership. |

The retained-byte save at bank1 `a35e..a367` stores **only `030e & 40`** into `221b`. That path does not preserve bit1. It weakens the idea that normal persistence deliberately saves the blocking bit, but it does not prove that all possible storage/initialization paths sanitize it.

The sole exact direct set sequence occurs at physical image offset `1ba07`. The two exact direct clear sequences occur at `0be2d` and `1ba0f`. The direct branch to `30eb` occurs at common `0a8f`; its bank3 dispatcher address is loaded by the common trampoline. These are literal-reference results, **not an exhaustive control-flow proof**: indirect addressing, generic writes and host writes remain possible. No normal plug-in path has been shown to set bit1. Do not rename it a proven firmware fault or clear it experimentally.

## A concrete read address

The [standard ACPI EC read command](https://uefi.org/htmlspecs/ACPI_Spec_6_4_html/12_ACPI_Embedded_Controller_Interface_Specification/embedded-controller-command-set.html) is `80`. In this exact EC image:

1. Common `0945` passes its offset to trampoline `30c3`.
2. Bank1 `e421` calls `f081`, which sets the high address byte to `03` and the low byte to the supplied offset.
3. The getter reads that byte and returns it. Therefore **offset `0e` reads XDATA `030e`**.

The recovered, checksum-verified DSDT separately declares `EC0.ERAM` as **SystemMemory `fedd8300`, length `100`**. Its offset `0e`, bit1 is unnamed. This gives a candidate direct host address **`fedd830e`**. The standard-read translation is established by original instruction execution; **the live host-window alias still needs an independent positive control** before interpreting a value at that physical address.

The same DSDT contains `\_SB.ATKD.RMEM`, a one-argument four-byte SystemMemory reader. For this candidate byte, an aligned request at `fedd830c` would include it in bits16..23. **RMEM was not invoked.** Finding its body does not provide a usable user-mode method-call interface.

Do not bypass ACPI by polling ports `62/66`: read commands still write command/address bytes, and an unsynchronized second client can interfere with Windows' EC transactions. The [ACPI interface specification](https://uefi.org/specs/ACPI/6.5/12_Embedded_Controller_Interface_Specification.html) defines the shared buffer handshakes. Also do not read live PMC3 input register `1522` to watch commands: in the model, consuming it clears input-ready state; a passive observer must not steal a command.

## Actual access checks this turn

| Check | Measured result |
| --- | --- |
| Existing ASUS failed-connection dump, physical `fedd8300`, 16 bytes | Debugger: physical memory read failed; no bytes obtained. No cache-mode retry. |
| Current EC device, standard `_STA` positive control expected to return15 | Device open refused with Win32 1; no IOCTL or EC command sent. |
| ACPI root, immediate-child namespace enumeration | Open succeeded; request refused with Win32 50; zero bytes; handle closed. |
| ACPI root, EX evaluation of known constant `\_SB.PCI0.SBRG.EC0._STA` | Open succeeded; request refused with Win32 50; zero bytes; handle closed. No RMEM fallback. |
| Current kernel-debugger state query | Query succeeded: debugger disabled, debugger not present. No local-debug session or boot-setting change. |

The first EC-control preparation stopped on a case-sensitive PDO-name guard before opening a handle. A corrected guard accepted the actual lowercase device name; both versions and the failed preparation are preserved privately. That preparation is not counted as a device request.

The dump attempt also asked for AML namespace metadata without a suitable symbol path; that part failed and supplies no new namespace evidence. The physical-address read does not depend on those symbols. The already recovered, verified AML tables remain the source for the ERAM/RMEM findings.

Microsoft documents [method evaluation as a request made by a device driver](https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/acpiioct/ni-acpiioct-ioctl_acpi_eval_method_ex). These measured failures reject the specific ordinary-process paths tested; they do not prove that every Windows route is impossible. The reviewed AsusSAIO command path reaches PMC4, not this generic EC read; its failed table6 getter should not be retried for this purpose. The newly inventoried existing AsusWmiAcpi image is signed, version2.1.76.0, SHA-256 `0f0a7bf9631751af691458831c9ee69845af19e8d49b57ad8f75f4250a060934`; its inspection has not established a usable generic memory reader.

## Conditional measurement option, and what it would prove

A usable live reader is **not implemented or loaded yet**. The concrete target is a narrowly scoped kernel-mediated reader for the existing EC shared-memory window, after checking the alias against known EC fields. It should expose only fixed read locations and return raw bytes plus QPC timestamps; it needs no controller command, policy write or firmware patch. Its signing/loading route and unload recovery must be settled before an attachment experiment. No new test boot is queued on the present result.

Once access is working, record a short disconnected baseline and the entire failed attachment alongside the existing Windows USB4/UCSI trace. Preserve raw `030e`, not only its bit1 interpretation. Cross-check the host alias; an unreadable address, all-ones reply or unvalidated constant zero is not evidence that the gate is clear.

- If the bit stays clear throughout the observed failure, stop treating this flag as the blocker for that trial and follow the controller's entry/exit and routing decision.
- If it changes to one, locate that transition relative to the first missing router and last successful UCSI command. Sampling alone does not identify the writer, and can miss shorter pulses.
- Then distinguish host command75, generic host writes and EC restore/internal activity. A CPU memory watchpoint alone cannot observe writes performed internally by the EC. The static setter is known; **the actual runtime writer is not**.

This observation separates “Windows cannot communicate with the controller” from “the controller remains responsive while USB4 entry fails.” Neither outcome by itself supplies a safe flag-clear repair.

## Reproduce the new offline checks

Build [Test-EcFlagPaths.c](../tools/analysis/Test-EcFlagPaths.c) against the same pinned emu8051 sources used by [the earlier harness](ec-firmware-decision.md#reproduce-offline), linking `bcrypt.lib`. Run it with the pinned complete256KiB `ec-main-full.bin`. It rejects wrong-length or wrong-hash inputs.

Six focused groups pass: standard read translation without XDATA writes, generic write translation in RAM, full PMC3 receiver/set-clear path including original bank trampolines, the outer UCSI gate, whole-byte restore, and the save mask. Byte values are swept to check preservation of unrelated bits. Peripherals remain RAM; the UCSI worker is a counting double. This verifies the interpretation of original instructions, **not live timing, host memory aliasing, physical bus operation or a working repair**. First build failed on a Windows header macro/name collision; it was corrected, with the failed log retained.
