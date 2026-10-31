# Experiment ledger

## Completed attempts

| Experiment | Scope | Observed outcome | What remains open |
| --- | --- | --- | --- |
| Working Dell comparison | Identical eGPU assembly and supplied cable | Display output and driver installation work | ASUS-specific interoperability and cable margins |
| ASUS graphics mode changes | Ultimate/Eco and restart | No external router or GPU | Other host firmware/configuration interactions |
| EC reset | Owner's long power-button reset before startup | Symptom unchanged | Persistent firmware defect or other causes |
| DISM then SFC | Windows image/files | Completed; later SFC clean | Clean files do not equal a known-good Windows configuration |
| USB controller reinstall/rescan | USB4 host, four xHCI controllers, UCSI | Targets recovered; no symptom improvement | All possible OS causes are not ruled out |
| Retimer device restart | Six Parade SPB + two HID devices | Eight restarts succeeded; no new problem devices; no recovery | No firmware was changed by the restart |
| UCSI disable/re-enable | Temporary software isolation, guaranteed re-enable path | No new adapter reported | No full inventory during disabled state; interaction not comprehensively ruled out |
| Four plug orientations | Cable end orientations | No change | Cable quality/capability still not independently isolated |
| UGREEN spare cable | Different Type-C cable | No change; owner later reported unsuitable specs | No confirmed second suitable cable test |
| 26H2 enablement rollback | KB5121794 removed; current 25H2 | No change | Shared USB4 binaries retained; not a fresh OS or CU rollback |
| Newer Parade System drivers | Official ASUS package for related TUF models | SPB 1.0.17 / HID 1.0.16 bound; no change | Not a proven PD/retimer firmware update or exact-model validation |
| Restore original drivers | Remove trial packages, select originals | SPB 1.0.8 / HID 1.0.11 restored, healthy | Original baseline itself may still have a compatibility issue |
| Private v2 registry override | One driver parameter, normal restart, host-restart capture | Ignored by test-signing gate; removed afterward | Intended enabled path was not tested; relevance unproven |
| Parade-only update scan | Applicable Windows Update driver packages filtered for Parade | Success, no match | Other vendors were initially untested |
| All-vendor driver update scan | `IsInstalled=0 and Type='Driver'` | Result 2, zero packages | Manual/vendor-unpublished firmware remains a possibility |
| Separate full Windows baseline | Native VHDX boot, build 26200.8037, USB4 driver 10.0.26100.7920, scoped OEM baseline | Essential preflight healthy; same fallback and no external router/GPU | Not a factory image; not every platform driver was present. Common firmware/driver/cable interactions remain possible. See fresh-Windows results. |

## Newer Parade package, precisely

The trial package was downloaded from ASUS infrastructure and had valid ASUS installer Authenticode signing. Its INF/CAT/SYS contents and catalog membership were checked. Hardware IDs matched the eight present peripheral devices.

Installer filename: `Parade_Retimer_ROG_Parade_B_V1.0.016.00_38025_1.exe`.

Installer SHA-256: `D4D2C93D5C8AF35FD1A619CE7936D10EDD8FECCD31CED9C36BBFCD535E701A5D`.

It published SPB 1.0.17.0 and HID 1.0.16.0. The file archive had two INF/CAT/SYS sets and installer/removal scripts; no separate firmware image was identified. The peripheral's CFU firmware reporting remained 1.3.0.2. Therefore the result was a System-driver trial, not a successful firmware flash.

The package was not officially listed for FA507XI. Matching hardware IDs and valid signatures do not substitute for exact-model qualification. The trial was rolled back. Its broad bundled force-removal script was not used.

Original baseline:

| Role | Driver |
| --- | --- |
| Six Parade SPB peripheral devices | 1.0.8.0 |
| Two Parade HID peripheral devices | 1.0.11.0 |
| Parade CFU firmware driver | 1.0.6.0 |
| Reported existing Parade firmware | 1.3.0.2 |
| ASUS System Control Interface | 3.1.73.0 |

## Deeper negotiation comparison, completed

Owner-run preparation enabled the documented UCSI interface and saved its absent original state. The 20:08-20:10 UTC comparison recorded 3,097,071 events, zero reported loss, 4,735 decoded UCSI lines and 84 completed diagnostic GETs. Peer negotiation succeeded; DEG2 handoff and fresh attachment did not enumerate a router/GPU. Both failures complete PD and data-role correction, followed by alternate-mode-only partner reporting and operating-mode value `0x40 -> 0x20`. No command-mailbox stall or patch target was established. [Measured order, query anomalies and limits](handoff.md#n5-existing-hardware-partner-handoff-proposed).

## Unperformed or withdrawn tests

- Direct Dell-DEG2 capture under a comparable profile: portable bundle prepared at the owner's request, with a separate Dell entry point and unchanged ASUS guards. PS5.1 software checks and actual bundled debugger replay passed; Dell hardware capture remains unperformed. [Procedure and exact validation limits](dell-control.md).
- Internal `UserControlOfIdleSettings` registry experiment: withdrawn before any write. The matching host driver checks test-signing at the assignment, so a production-mode override would not enable this flag. No enabled-path test or repair claimed. [Audit](policy-audit.md#follow-up-user-control-of-idle-settings).
- A second suitable 40 Gbps cable, or a documented 20 Gbps USB4 cable: unavailable at last report. The [next-test matrix](handoff.md) separates these comparisons and their outcomes.
- A separate known-working USB4 peripheral on the ASUS: unavailable/unconfirmed.
- A Thunderbolt 4 hub/dock between ASUS and DEG2: possible hypothesis, not tested.
- The UGREEN Revodok Pro 3121 has been identified as a conventional 10 Gbps hub. No new test was performed; it cannot stand in for a separate USB4 peripheral.
- BIOS defaults, reflash or downgrade: not performed; no verified regression-specific reason established.
- Foreign PD/retimer/dock firmware: not flashed.
- GPU VBIOS update: not performed; current evidence fails before GPU enumeration.
- Test-signing/Secure Boot changes: not performed.
- WinPE hardware validation: proposal withdrawn after checking Microsoft's limitations.
- Linux comparison: owner preferred continuing on Windows; not performed.

## Decision discipline

"No change" is useful only for the actual configuration that ran. Do not upgrade a limited negative result into a complete exclusion of Windows, firmware, cables, security, or hardware. A status check that proves a driver is installed is not a measurement of link establishment.
