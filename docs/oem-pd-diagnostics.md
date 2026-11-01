# ASUS's installed PD diagnostics: a concrete access route

**1 November 2026:** the installed, signed ASUS analysis client contains PD-controller identity, source-capability, cable-marker and status getters. The matching, already-running ASUS driver has the EC transport they use. This is a specific OEM diagnostic path to qualify; it is not yet a USB4 repair or a raw PD-packet recorder.

## What was established from the installed binaries

| Component | Version | SHA-256 |
| --- | --- | --- |
| AsusSAIO.sys | 1.0.9.0 | `eef750c7fb515d162a76423531f4f6773bcf837d9607069e797a26d198edd892` |
| AsusWinIO64.dll | 1.1.4.0 | `a07802f565b9b1ec527b2d1eec69debfb92f90022953b63f1122edb50d2d5b54` |
| AsusEC_X64.dll | 2.0.0.4 | `c7f337191d2366dfedbe90a6423ec743094a588a032c0a0cb2434dad688c29fe` |

All three installed copies have valid Microsoft Windows Hardware Compatibility Publisher signatures. No library was loaded into the probe process. Private copies, disassembly and identity receipts are retained; vendor binaries are not redistributed.

The analysis DLL exports `Adapter_Read_PD_IC_PN`, cable-marker VID/PID/XID readers, source-capability readers and PD status/event readers. Its legacy x64 capability getter at RVA `55470` sends EC command `BB` with one input byte `50` and requests one output byte. Nonzero EC completion status becomes the sentinel `7fffffff` in the client.

**The PD-identity getter requires capability-table version 14 or later.** Its actual branch subtracts 14 before an unsigned comparison. An export name alone does not prove that this older laptop's EC implements it. Six original-code cases verify rejection of versions 0/13 and the error sentinel, and acceptance of 14/15/255. A zero transport error and a low capability version would be different findings.

The vendor's existing registry cache currently says `HealthyTableVersion = 17`. This supports pursuing the getter, but is not a fresh EC response. A separate archived `TableM5_v5` record dated 16 October contains 256 bytes, all `ff` except byte 1 (`01`). It supplies no readable PD identity. Its table-selection parameters and port association have not been matched to the identity getter, so it is not proof of an absent controller or unimplemented diagnostic. The archive remains private.

For a sufficiently new table, the identity getter requests twelve bytes from table 5, offsets 2 through 13, using the client's `DD` read sequence. The event getter reads table 6, offset `34`, and the temperature getter offset `33`. **None of those table reads has been sent.** Port association and snapshot freshness remain unqualified: charging-port diagnostics must not be assumed to describe the separate USB4 port.

## Access, without another driver or test boot

The exact driver checks the calling process's TokenUser SID against `SeExports + 108`, which the matching WDK layout identifies as `SeLocalSystemSid`. Ordinary administrator membership is insufficient. This is why a temporary SYSTEM task is prepared for the single capability request. SYSTEM is Windows' privileged service identity; it is not a reason to disable boot protections. [Microsoft account documentation](https://learn.microsoft.com/en-us/windows/win32/services/localsystem-account), [task principal documentation](https://learn.microsoft.com/en-us/windows/win32/taskschd/principal-userid).

The prepared private probe:

1. Pins FA507XI, BIOS 314, the running driver's exact hash and valid signature. It never starts or installs a driver.
2. Opens only `AsusSAIO` and first requests its non-hardware API version. It must return `00010001`, with the correct output length.
3. Sends exactly one application-level capability request using the OEM packet layout. No `DD` table command, write/clear/reset command, arbitrary address or caller-supplied opcode is accepted.
4. Saves transport status, output length, EC completion, returned capability byte, elapsed time and handle closure. A durable attempt marker prevents an automatic repeat.
5. Runs from a unique staging folder writable only by Administrators and SYSTEM. On normal collection, it unregisters its exact temporary task and retains private evidence.

The driver's EC implementation can retry internally. Its kernel mutex wait has no timeout; a user-mode timer cannot guarantee cancellation of a stuck synchronous dispatch. The runner therefore does not claim a hard timeout, retry a pending request, stop the ASUS driver or reboot Windows.

**Current execution state:** Windows cancelled the administrator launch before the elevated runner started. No SYSTEM task, device-open marker or capability result was created. No automatic relaunch followed. The private, reviewed administrator launcher remains prepared; this is not a successful EC read or a failed hardware test.

## Validation and next decision

[The offline test](../tools/analysis/Test-OemPdCapability.py) executes the pinned client getter, driver wrapper and identity gate in Unicorn with explicit EC/kernel test doubles. **Sixteen cases pass.** These verify packet framing, status propagation, mutex acquire/release order and the version threshold; they do not qualify real EC timing or hardware support. The private worker and runner parse under PowerShell 5.1, and their C# compiles without invoking its device-access entry point.

Seventeen existing ASUS trace/archive files were also copied and inspected privately. Their extracted strings show the vendor's capability-check job being scheduled, but supply no capability value or PD identity. Scheduling is not successful completion. Those logs do not replace the proposed read.

If the capability read succeeds, its version determines whether the OEM PD getters are applicable. Any identity/status read must preserve the exact getter's prerequisites and establish which port it describes before comparing DEG2 with the working ASUS–Dell peer. If the driver control or EC read fails, preserve that boundary rather than guessing another command. A Windows intervention still needs a demonstrated consumer of the failing entry/exit condition and a reversible change.

This investigation complements the [recovered firmware code and tested metadata paths](control-reachability.md) and the [existing ASUS/Dell Billboard comparison](billboard-comparison.md). It does not supersede their measured results or make another boot necessary.
