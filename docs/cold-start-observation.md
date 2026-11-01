# One preconnected cold-start observation

**Post-startup inspection, 1 November at 13:05 UTC:** Windows started a new kernel session at 13:02 UTC. Current inventory still shows DEG2 USB/Billboard fallback, with no healthy matching external router or RTX 4080 SUPER. Native Code Integrity flags show test signing off and HVCI running; no experimental driver service is present. Secure Boot registry state remains off. The owner reports performing the startup sequence and not waiting the full suggested 20 seconds; the actual interval was not measured. The prepared run still says Prepared and has no collection result/ETL. Continuous attachment and the collection-window outcome require clarification, so this is a preliminary inventory observation, not a completed matched startup capture. No further reboot or repeat attachment is queued merely to finish collecting this session.

**Startup reported; formal capture pending.** The exact-model BIOS contains a pre-OS USB4 manager, and the owner has now reported performing the requested startup. Exact sequence/continuous attachment is still being clarified. This is a different startup condition from the completed hot-attachment/role-policy tests. It changes no firmware or Windows policy.

The [collector](../tools/Capture-USB4ColdStart.ps1) defaults to Preview. Prepare saves the current boot stamp, machine binding, Microsoft base binding, absent experimental-package check, source hashes and inventory under private `local/ColdStart`. Collect requires that saved run, the same machine and sources, a different Windows kernel boot stamp, stock binding and an owner confirmation that DEG2 was powered/connected before the power button. It permits one attempt and observes an already-connected device for 20 seconds. It does not reconnect, restart devices, install a driver, configure boot tracing or modify network/security settings.

## Owner sequence

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
