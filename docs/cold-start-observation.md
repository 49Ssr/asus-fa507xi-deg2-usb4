# One preconnected cold-start observation

**Preconnected startup completed, 1 November:** powered DEG2 was connected to the same ASUS USB4 port before power-on and left connected, as confirmed by the owner. Both post-sign-in snapshots still show Billboard, no external USB4 router and no RTX 4080 SUPER; display N. The 20-second trace has 471,428 events, zero loss/format errors and 14 unknown formats. This sequence did not enable USB4. Initial BIOS/PD negotiation is outside the capture. [Measured observation](cold-start-observation.md), [structured evidence](../evidence/cold-start-result.json).

The [collector](../tools/Capture-USB4ColdStart.ps1) defaults to Preview. Prepare saves the current boot stamp, machine binding, Microsoft base binding, absent experimental-package check, source hashes and inventory under private `local/ColdStart`. Collect requires that saved run, the same machine and sources, a different Windows kernel boot stamp, stock binding and an owner confirmation that DEG2 was powered/connected before the power button. It permits one attempt and observes an already-connected device for 20 seconds. It does not reconnect, restart devices, install a driver, configure boot tracing or modify network/security settings.

## Measured result

The successful collection belongs to the new 13:27 UTC Windows kernel session. The earlier 13:02 UTC session produced only a read-only inventory; its collector window was closed before capture began. That session had no ETL/active collector to clean up. The original preparation and preliminary inspection are preserved separately.

| Item | Beginning | End |
| --- | --- | --- |
| Billboard fallback | Present | Present |
| Healthy matching external DEG2 router | Absent | Absent |
| Healthy RTX 4080 SUPER PCIe function | Absent | Absent |

The owner answered `PRECONNECTED` and then display `N`. ETW ran from 13:31:50 to 13:32:10 UTC and stopped successfully. The raw file is 89,391,104 bytes, SHA-256 `7A447F0FFCB7CEEF80BACBB0DC050985C781A490881292BA457F1842657EB01B`. Matching TraceFmt decoding reports 471,428 events, zero loss, zero format errors and 14 unknown formats. The trace was closed before analysis; source hashes still match preparation.

USB4 rundown contains only the root router, no external topology, current link speed/negotiated width 0, and no active USB3/PCIe/DP tunnels. It also reports domain powered down with one power-down request. This is a steady-state snapshot, not proof that power management caused the failure: Microsoft explicitly supports sleeping idle USB4 domains. No decoded UCSI sends occur in this post-sign-in window; that does not establish that none occurred during boot. [Microsoft USB4 power/validation requirements](https://learn.microsoft.com/en-us/windows-hardware/design/component-guidelines/usb4-required-testing).

The EC reset was discussed and the owner was advised to omit it; the collector does not independently establish whether one occurred or time the suggested off interval. The measured condition is the owner-confirmed powered preconnection and sustained failed state. This startup sequence was insufficient as performed. It does not prove whether the BIOS connection-manager path executed or identify a bad PD/retimer/controller component. Do not repeat the same startup or collector unchanged. The next work is [offline firmware-entry/retimer analysis](firmware-entry-followup.md).

## Exercised owner sequence (historical)

1. Save work. Keep ASUS barrel power and the existing Ethernet/Internet-sharing connections.
2. Perform a full shutdown, rather than sleep/hibernate or Fast Startup. The owner can run `shutdown.exe /s /t 0`; the collector never invokes shutdown. Do not add `/hybrid` or `/f`. [Microsoft shutdown options](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/shutdown).
3. Once ASUS is off, leave it off for about 20 seconds. Power DEG2 on and connect its existing cable to the same tested ASUS USB4 port **before pressing ASUS's power button**. Keep the tested cable orientation. This is not an EC-reset procedure.
4. Start the usual Windows installation. Leave DEG2 powered and connected throughout sign-in. Do not change BIOS settings for this observation.
5. Run the generated local `COLLECT-AFTER-STARTUP.cmd` as Administrator. Confirm `PRECONNECTED` only if the sequence above happened, then answer the RTX display question. Its command window remains open after completion or failure. No dump-path entry or USB transport is involved.

Prepared boot state has stock UCSI binding, no bound/running experimental filter and no installed experimental extension. The owned test loader/certificate trust were already removed. Secure Boot is still off in the prepared session; original-loader/Secure Boot restoration remains a separate pending verification. The collector records observed Secure Boot state without changing it. A normal start should use the restored original default; no test entry is recreated.

## Interpretation and coverage

- A healthy matching external DEG2 router and RTX PCIe function are separate milestones. Owner-confirmed display output is recorded separately. Billboard is not success.
- ETW begins after sign-in. It cannot show BIOS execution, the initial pre-OS exchange or physical PD packets. Missing boot-trace coverage is explicit in the result.
- A new boot stamp rejects a simple resume in the same kernel session, but owner confirmation is still needed to establish the physical sequence.
- A failed/incomplete run is preserved. Trace cleanup stops only its randomly named owned session. If cleanup fails, the session identity and error remain recorded for recovery; do not start another test blindly.

Windows PowerShell 5.1 qualification: **29 checks** cover milestone separation, unset PnP fields, machine/source/boot binding, repeat-attempt rejection, private-path containment, parsing and prohibited operations. These do not test the new hardware startup or guarantee native-command timeout/forced-process-termination cleanup. The first actual Prepare stopped on an unset filter property lacking `Data`; this was corrected to accept only an explicit Empty property, with malformed nonempty values still rejected. The subsequent actual stock-driver preparation succeeded. Both records are preserved.
