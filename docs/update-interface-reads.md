# What the IT8857 update interface can read

**The acquired updater exposes chip identity, update-engine status, firmware bytes and six saved “Redriver Parameter” bytes. None has been identified as the missing PD negotiation state.** The inspected Windows routes do not currently provide a working bridge to the laptop's PMC3 transfer receiver.

This is an analysis of the original ASUS add-in-card tool and the locally acquired ASUS DLL/driver binaries. The add-in-card firmware is not the FA507XI controller image. There was no native updater/DLL execution or hardware command. [Hashes, instruction anchors and results](../evidence/update-interface-reads.json).

## Reads found in the tool

Selectors below are bytes sent by the original program, in transmission order. They are not commands to try on the laptop. Address `80` is the tool/EC address-byte convention, not a 7-bit Windows device address.

| Read | Use in the original program | What it establishes |
| --- | --- | --- |
| `FF C0`, four bytes | Checks chip identity and derives flash size | Identity, not attachment state; the main update path calls it after the sequence labelled “Stop_CPU” |
| `A0`, six bytes | Saves bytes labelled “Redriver Parameter” before the update, then writes them back after reset | Data preserved across an update; individual fields and their freshness are unidentified |
| `1E`, one byte | Polls after writing `1E 01` when the first saved parameter byte is nonzero | Completion of that unidentified parameter operation, not USB4 entry |
| `FF F7`, one byte for configured IT8857 | Checks update-engine status after control writes | Flash-operation status |
| `FF FF`, one byte | Polls during chip erase | Erase status |
| `FF F7`, 128-byte blocks for configured IT8857 | Reads flash data after setting a flash address and issuing a read operation | Firmware contents; not a passive live RAM snapshot |
| `FF D3`, one byte | Read-modify-write inside the watchdog-reset routine | Reset control, not the USB PD `Data_Reset` message |
| `1A`, one byte | Waits for `5A` before restoring the saved parameter bytes | A post-reset readiness condition used by the tool; further semantics unknown |

The separate `B6` version reader and alternate version-register reader use the **normal** address. They do not turn the EC's fixed update-address transfer into a normal-address read. [Version-path analysis](it8857-version-path.md) · [EC transfer](ec-host-transfer.md).

## The six-byte read has two important traps

The function prints and saves its buffer **without checking the initial read result**. A failed read that leaves the initialized buffer untouched becomes six displayed zeros. If a failed transfer leaves partial data with a nonzero first byte, the function can still issue `1E 01` and poll. It is not a read-only diagnostic routine.

The updater later copies those same six bytes into an `A0` write after its watchdog reset. This establishes preservation/restoration behaviour; it does not identify requested mode, applied PS8830 mode, partner capabilities or a training result.

[The offline reproducer](../tools/analysis/Test-It8857UpdateRead.py) executes the original reader instructions with RAM-only substitutes for I2C and printing. Successful, failed, partially filled and busy replies confirm those branches. It does not emulate the physical controller or prove what the six bytes mean. Selected instructions were also decoded independently with radare2.

The flash-reading route may eventually help obtain the controller program. The acquired updater's main path first sends sequences labelled “Stop_CPU” and “Enter_Test_mode”. This is not a method for preserving attachment-time state, and the laptop transport remains unresolved. Its 128-byte reads also exceed the EC relay's 32-byte limit. Splitting them requires identifying how the controller advances its read position; that behaviour has not been established.

## What Windows can reach today

| Inspected route | Result |
| --- | --- |
| Installed AsusSAIO legacy EC request | Fixed host ports `25C/25D`, PMC4 framing; no PMC3 port selector in this packet |
| AsusEC_X64 `ExecuteECCommands`, HID backend | Searches for ASUS VID `0B05`, PID `4543`, usage `84`, usage page `FF32`; no matching present HID node appeared in the Windows device inventory |
| AsusEC_X64 `ExecuteECCommands`, driver backend | Sends IOCTL `9C40E058` to its EC helper; its loader can extract an embedded driver and create/start its service |

The filtered ASUS/AsIO service inventory contained running AsusSAIO and the touchpad driver, not the EC helper. Having the DLL on disk is therefore not an already-installed driver route. The DLL was inspected as a file and never loaded. These findings do not exclude every other driver, firmware method or USB identity on the machine.

## What remains to be found

Two separate pieces are still missing: **a reachable Windows transport to the correct controller interface, and a register or log whose producer identifies the live PD decision.** Obtaining bytes alone would not solve both.

The next firmware work is to identify the update-side parameter/status implementation in the acquired IT8857 reference and compare its reachable handlers with ASUS's EC relay. Any proposed Windows bridge must reach PMC3 or a demonstrated equivalent; retrying the PMC4 cache getter cannot do that. The inspected updater supplies no established Enter_USB request/reply, rejection reason or PS8830 training result.

This is a specific access and protocol gap, not evidence that Windows diagnostics are categorically impossible. No live state or working repair was obtained in this analysis.

[Current findings](status.md) · [Windows routes](windows-repair-route.md) · [Diagnosis plan](investigation-plan.md)
