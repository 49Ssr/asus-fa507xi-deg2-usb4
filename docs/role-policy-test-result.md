# Measured role-policy test, 1 November 2026

**Readback added 3 November 2026:** Windows currently reports Secure Boot off, test signing off and HVCI running. The exact experiment certificate is absent from Root and TrustedPublisher, matching the saved prior state. The current non-elevated check did not enumerate BCD, so the full original-loader/boot-manager Verify remains uncompleted. No boot, trust or security setting was changed. [Fresh evidence](../evidence/boot-state-20261103.json).

**Windows accepted the policy override and stopped issuing its automatic role correction, but DEG2 still fell back to Billboard.** No external USB4 router, RTX 4080 SUPER binding or display appeared. The experimental package was removed and stock policy 0 verified. The owned test loader and certificate trust were then removed; manual Secure Boot restoration and an original-loader boot still require final verification.

## Same-boot comparison

The ASUS FA507XI, BIOS 314, Windows 26200.9818, supplied cable, powered DEG2 and tested port were retained. Both attachments used the same owned test boot with TESTSIGNING enabled and HVCI required. The Microsoft base client remained installed. Enabled ICS bindings were preserved.

| Observed item | Powered stock baseline | Experimental policy |
| --- | --- | --- |
| ACPI support mask / policy | `0x0f` / 0 | `0x1f` / 1, explicit Microsoft forced-policy message |
| Decoded `SET_UOR` sends | 1 | 0 |
| Partner reports | DFP, DFP, then UFP | DFP, DFP |
| Partner flags | `0x1`, `0x1`, then `0x2` | `0x1`, `0x1` |
| Reported PD RDO | `0x1384b12c` | `0x1384b12c` |
| Root-port Plugged / RouterDetected checks | No / No | No / No |
| Billboard / external router / GPU | Present / absent / absent | Present / absent / absent |
| External display | Baseline collector does not ask | Owner answered N |

The policy change reached both Microsoft's ACPI client and class-extension configuration. The reviewed filter was Running before the experimental attachment. The stock attachment contains seven non-ACK sends and seven ACKs; the override attachment contains five non-ACK sends and five ACKs. Neither decoded UCSI stream reports a CCI error.

Stock attachment: 1,010,054 ETW events, zero loss/format errors, 286 unknown formats. Override: 999,504 events, zero loss/format errors, 244 unknown formats. Unknown-format counts are retained as a coverage limit. These are decoded Windows events, not a physical PD packet capture or proof of complete firmware visibility. Trace durations differ; total event counts are not a performance comparison.

## What this changes in the investigation

This single controlled pair shows that **suppressing Windows' automatic correction alone did not enable USB4**. It also shows that alternate-mode-only flag `0x2` is not required for failure: the override failed while reporting flag `0x1`. The initial partner-DFP state and reported PD request remained different from the working Dell evidence.

The result narrows the hypothesis; it does not identify a defective chip, a patchable firmware location or an available Windows fix. The earlier role-selection and native USB4 entry/link-training path remain unresolved. Do not repeat this policy-only trial unchanged or interpret driver installation as USB4 success. [Original matched evidence](asus-dell-matched-comparison.md), [driver design](role-policy-experiment.md).

## Rollback and implementation corrections

PnPUtil successfully uninstalled/deleted only the saved experimental extension and restarted the exact UCSI target. Verification initially stopped because the generated decoder output path was 259 characters and its appended `.sum` exceeded the decoder's legacy path limit. The failed empty output and original trace are preserved.

Shorter report names now leave room for `.sum` and decoder logs; excessive paths fail explicitly. `VerifyRollback` rechecks only the exact owned same-boot retained rollback trace and all original postconditions, without another removal, restart or trace session. It requires package absence, driver not Running, original base/filter state, Microsoft policy false and unchanged enabled ICS before clearing pending. PS5.1 workflow checks now pass **87 cases**, including actual retained baseline/rollback ETL decoding and verification-only lifecycle guards. Device-operation tests still use doubles; the actual removal result is separate.

The retained rollback trace has 30,782 events with zero loss, format errors or unknowns. It reports support mask `0x0f`, ACPI false and class configuration 0. At 12:26 UTC all rollback postconditions passed and `PendingRollback` became false. At 12:27 UTC the owned test entry and exact certificate trust were removed; boot-manager readback matches the original snapshot. HVCI remains running. The current session still has TESTSIGNING on and Secure Boot off until the owner enables Secure Boot and boots the original loader, followed by final Verify. No automatic reboot occurred.

Raw inventories, traces, package identities and recovery records remain private. [Structured experiment record](../evidence/role-policy-experiment.json), [signing and complete restoration](local-test-signing.md).
