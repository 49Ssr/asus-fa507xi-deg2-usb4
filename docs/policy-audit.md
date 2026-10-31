# Correction: `EnableUSB4v2Support` was ignored

## Why this matters

An experimental registry value was suggested after local inspection showed that the Microsoft USB4 host driver recognizes it. The first analysis missed a surrounding test-signing condition. The owner set the value and restarted as instructed, but the intended policy path did not activate.

That was an analysis mistake, not a user error, failed reboot, or demonstrated inability of the enabled policy to fix the connection. The value has been removed, and the helper was corrected to refuse Enable when test-signing is off.

## Inspected binary

| Field | Value |
| --- | --- |
| File | `Usb4HostRouter.sys` from the installed DriverStore package |
| Version | 10.0.26100.9818 |
| SHA-256 | `912EFBFCA273C62484DB952632EEB0D2B061BD7A1C830970FDA23CDB50BEEB1F` |
| Symbols | Matching Microsoft public PDB, GUID `467BC6215A3EDC9640ABA1BC45993F68`, age 1 |
| Method | Offline public-symbol enumeration, disassembly, and matching WPP TMFs; read-only Code Integrity query on the running host |

The file is loaded from DriverStore on this machine. Assuming it must exist at `System32\drivers\Usb4HostRouter.sys` would inspect the wrong location. The service's ImagePath identifies the loaded package.

## Verified local implementation

The parameter is under:

```text
HKLM\SYSTEM\CurrentControlSet\Services\Usb4HostRouter\Parameters
EnableUSB4v2Support (DWORD)
```

`Usb4Hrd::Driver::QueryAndCacheDriverParametersFromRegistry` reads the value. A nonzero value maps to an internal enable enum, while zero maps to disable. `Usb4HrdHal::HardwareAbstraction::DetermineUSB4v2Policy` consumes that cached enum or falls back to its OS/vendor policy.

However, the registry loader checks `Usb4Hrd::Driver::m_isTestSigningOn` before applying the value. The matching TMF contains this explicit diagnostic:

> USB4 v2 policy indicated in registry but ignored because test-signing is disabled.

That is text from the matching driver's diagnostic metadata. It was **not** observed as a runtime event in the later connection trace, which began after initial DriverEntry. The gate was established through offline code inspection and the host's actual Code Integrity state.

`QueryIsTestSigningOn` queries `SystemCodeIntegrityInformation` (class 103 / `0x67`) and tests the `0x2` flag. The host returned options `0xF401`, with that flag clear. The latest runtime trace instead reported:

```text
Disabling USB4 v2 support due to OS policy.
```

## Outcome and limits

- The requested normal Windows restart actually happened after creation of the value.
- The override was present before the later capture and absent after Undo.
- The driver did not use the override on this production boot configuration.
- No test-signing, Secure Boot, code-integrity bypass or binary patch was applied.
- The enabled path's relevance to this dock's pre-router failure remains unproven.
- The Dell already runs the dock at 40 Gbps with a host USB4 version reported as 1.0; v2 is not inherently required just because the dock advertises v2.

This is a version-specific private implementation finding, not a supported Microsoft registry configuration or a community fix. Addresses and internal enum meanings may change with another binary. Changing a boot-security mode merely to force this experiment is not part of the current workflow.

## Follow-up: user control of idle settings

On 31 October, a possible idle-power experiment was investigated before making another registry change. The startup recorder reports `m_UserControlOfIdleSettings: false`. The same matching driver recognizes a parameter named `UserControlOfIdleSettings`, but recognition alone again does not establish that a production system can use it.

Read-only disassembly of `QueryAndCacheDriverParametersFromRegistry` shows that the final assignment requires both `m_isTestSigningOn` and a nonzero parameter. With test-signing off, the assignment is false regardless of the requested value. This was checked at the actual assignment, rather than inferred from the parameter's name or existence.

**Outcome:** no idle-control registry value was written and no security setting changed. No runtime enabled-path or repair result is claimed. The consumer of this internal flag was not exhaustively traced, so its precise downstream effect is not asserted here.

Microsoft's [WDF user-control documentation](https://learn.microsoft.com/en-us/windows-hardware/drivers/wdf/user-control-of-device-idle-and-wake-behavior) also explains that ordinary user idle preferences depend on the driver allowing user control. It specifically warns against directly changing the framework-owned `IdleInWorkingState` value. A generic per-device registry edit is therefore not a justified substitute for a verified supported power control.

The working ASUS-Dell rundown has the USB4 domain awake; the failed DEG2 recording starts with the cable disconnected and the domain asleep, then records a successful wake. Those are different starting conditions, not proof that idle caused the DEG2 failure. The [existing-hardware partner handoff](handoff.md#n5-existing-hardware-partner-handoff-proposed) is a way to test startup state without forcing an unsupported registry path.
