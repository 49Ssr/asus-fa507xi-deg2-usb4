# Live ASUS PD access: IT8853 identified, power-profile boundary measured

**Follow-up:** a trace-only replay recovered four retained message19 records, identifying the EC response-ready stage after command/parameter transmission. No failed field read was repeated. Standard UCSI power-profile reads already succeed in the saved ASUS trace. Original timestamps/command arguments are absent; exact attribution remains an inference. Both trace sessions cleaned up, twenty new original-code cases pass, and no USB4 repair is qualified. [Detailed recovery and prerequisites](it8853-transport.md).

**1 November 2026:** the installed ASUS driver successfully returned capability-table version **17** and the OEM PD-controller identity **`IT8853`**. Subsequent power-profile queries timed out in the driver's EC transport both while disconnected and with DEG2 detected. Neither produced a valid PDO. The connected run also has an owner-reported UGREEN insertion confound. The identity result remains valid; a USB4 repair and USB4-port association remain unproven.

## Completed live reads

| Read | Measured result | Cleanup |
| --- | --- | --- |
| 16:28 UTC capability check | Non-hardware API version `00010001`; capability byte `17`, transport status 0, 64 ms | Handle closed; temporary task removed |
| 16:31 UTC OEM identity getter | Fresh capability17; twelve successful bytes: `495438383533000000000000`, decoding to `IT8853` | Handle closed; temporary task removed |
| 16:38 UTC disconnected PDO baseline | API and capability17 passed. First source-PDO1 byte, table6/offset05/selector00: Win32 success, 16 output bytes, driver transport status `0102`, 1,568 ms | Handle closed; temporary task removed; no connection stage |
| 16:45 UTC connected-only PDO1 check | DEG2 detected before the read; API and capability17 passed. Same first PDO byte returned driver transport `0102`, 661 ms. Owner reports UGREEN was briefly inserted/removed before DEG2 and `CONNECTED` | Handle closed; temporary task removed; stopped after one field byte |

The initial administrator launch was cancelled before execution. The owner subsequently requested the prompt again and completed the live reads above. The cancelled launch and each actual result are preserved separately. [Structured evidence](../evidence/oem-pd-diagnostics.json).

The identity is **firmware-reported through ASUS's getter**. It does not supply the PD firmware version, independently verify a chip marking or identify which Type-C port the dynamic telemetry follows.

## What the timeout means

The pinned driver's polling helpers synthesize `0x102` when a transport wait expires. Multiple stages can return it: pre-command drain, command/parameter acceptance, post-command readiness and response readiness. The original completion packets do not identify the stage; the subsequent recorder replay linked above recovers response-ready timeout records, with attribution limits retained. **It is not a USB-PD rejection code, proof of a faulty chip or proof that the dock has no advertised power profiles.**

The raw private reader historically names the completion field `EcStatus`. Its precise meaning is the **driver's EC transport status**; that field must not be interpreted as a PD protocol error. Executed scripts/results retain their original hashes. The newly prepared connected-only reader uses the clearer `DriverTransportStatus` name.

The OEM PDO getter returns sentinel `7fffffff` on transport failure and `ffffffff` when its table-version prerequisite is not met. Neither is a valid empty-PDO measurement. Offline original-code cases verify the failure sentinel as well as successful byte assembly. No failed payload byte was treated as real data.

The disconnected baseline's framing was qualified, but availability of the dynamic field in that physical condition was not established. The later attached-condition check also failed to obtain this field; its intervening UGREEN insertion prevents treating the two runs as a clean paired experiment. The collector stopped at the first error. No remaining PDO/contract fields or connected snapshot were read. No automatic repeat, timeout increase, reset or alternative opcode followed.

## The installed route and its prerequisites

| Component | Version | SHA-256 |
| --- | --- | --- |
| AsusSAIO.sys | 1.0.9.0 | `eef750c7fb515d162a76423531f4f6773bcf837d9607069e797a26d198edd892` |
| AsusWinIO64.dll | 1.1.4.0 | `a07802f565b9b1ec527b2d1eec69debfb92f90022953b63f1122edb50d2d5b54` |
| AsusEC_X64.dll | 2.0.0.4 | `c7f337191d2366dfedbe90a6423ec743094a588a032c0a0cb2434dad688c29fe` |

All three installed copies have valid Microsoft Windows Hardware Compatibility Publisher signatures. Only the already-running driver was opened; no DLL was loaded by the probes and no driver was installed or started. Vendor binaries and disassembly remain private.

The analysis DLL's legacy capability getter at RVA `55470` sends command `BB` with input byte `50` and requests one output byte. Its PD identity and PDO getters require table version **14 or later**. The actual identity branch subtracts 14 before an unsigned comparison; export existence alone is insufficient qualification. Live version17 matches the older vendor registry cache, and is stronger evidence of current command completion than that cache.

The identity loop uses command `DD`, table5 offsets2..13, selector1. The source-PDO reader uses table6, selector0; PDO1 bytes are read at offsets05,04,03,02. The contract getter uses offsets21,20,1f,1e. Status-event and temperature getters have also been mapped, but **have not been issued**. Static identity support does not establish dynamic-field availability or USB4-port mapping.

An archived vendor `TableM5_v5` record dated16October contains 256 bytes, all `ff` except byte1=`01`. Its selection parameters have not been matched to the identity getter. The new successful identity read demonstrates why that older snapshot could not establish an absent controller.

The exact driver checks TokenUser against `SeLocalSystemSid`, identified through the matching WDK layout. Temporary SYSTEM tasks provided the required caller identity. Each normal collection unregisters its exact task and retains protected private evidence. SYSTEM is a Windows service identity; this route required no boot-security change. [Microsoft account documentation](https://learn.microsoft.com/en-us/windows/win32/services/localsystem-account), [task principal](https://learn.microsoft.com/en-us/windows/win32/taskschd/principal-userid).

## Controller-specific source lead

ITE's vendor-submitted Linux driver describes IT8851/IT8853 UCSI access over **direct I2C**. The accompanying vendor binding identifies IT8853 as a two-connector part. Its interrupt/status and acknowledgement registers provide a concrete reference for further analysis. They do **not** establish that ASUS's EC table interface exposes those registers, or that its Linux transport can be transplanted into Windows. No direct ITE register read or acknowledgement write was sent. [Vendor driver submission](https://lists.openwall.net/linux-kernel/2026/08/07/804), [vendor binding update](https://lkml.iu.edu/hypermail/linux/kernel/2609.2/07383.html).

The recovered ASUS tables expose UCSI through the EC/ACPI mailbox rather than an explicitly named IT8853 Windows device. OEM table offsets are not established as direct chip-register addresses. Port ownership, data freshness and the actual entry/exit failure remain to be traced.

## Narrow connected-condition check

The owner confirmed DEG2 powered on and disconnected. After the disconnected baseline stopped, a separate, narrower check was prepared: verify powered DEG2 presence on the same tested ASUS USB4 port, wait20seconds, pass the API/capability controls, then read **one source-PDO1 getter**. This changes the physical condition; it does not repeat the failed disconnected baseline or bypass its stop rule. Existing matched captures already retain DEG2's first advertised PDO `2f81912c` (5V/3A), supplying a comparison value. [Existing capture evidence](billboard-comparison.md).

**Completed result:** the owner confirmed `CONNECTED`; the post-wait snapshot detected DEG2 and no matching RTX4080SUPER before the read. API/capability17 controls passed, but the same first PDO byte returned transport `0102` after661ms. No remaining PDO bytes were read. The owner subsequently reported connecting UGREEN first, removing it, then connecting DEG2 before submitting `CONNECTED`. That report is retained alongside the untouched raw result/journal. Final DEG2 presence is verified; the attachment history is not a clean before-and-after sequence.

This leaves the selected OEM dynamic field **unusable in the runs performed**. It does not erase the controller-identity result, prove all IT8853 diagnostics unusable or identify the USB4 failure. No unchanged repeat or further live probe is queued. The next qualification work is the field's caller/firmware prerequisites and port ownership. It must precede any new control experiment.

## Validation and system state

[The offline test](../tools/analysis/Test-OemPdCapability.py) now executes **41 cases** using pinned original client/driver bytes and explicit EC/kernel test doubles. It covers capability framing/status propagation, the version14 gate, twelve-byte identity sequence, source/contract byte order, first-error stops and the real timeout-status/sentinel mapping. It qualifies software control flow, not hardware support or timing. Private workers/runners parse under PowerShell5.1 and their C# compiles without device access.

Seventeen existing ASUS trace/archive files show the capability-check job being scheduled, but did not supply its value. The live reads supplied that missing evidence. The existing Dell/ASUS captures and recovered firmware tables remain preserved.

No firmware update, policy/reset command, new driver, boot, security setting or network configuration change occurred. All four completed device handles closed and their four temporary tasks were removed. No Windows USB4 fix has yet been demonstrated. [Earlier access boundaries](control-reachability.md), [ASUS/Dell comparison](billboard-comparison.md).
