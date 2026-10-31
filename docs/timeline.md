# Troubleshooting timeline

All dates below are 30 October 2026 unless specified. Times attached to trace names are UTC; Belfast was on GMT on this date. Earlier steps are ordered from the owner's report rather than assigned invented timestamps.

| Step | Action / observation | Result and limitation |
| --- | --- | --- |
| 1 | Assembled DEG2, Cooler Master PSU and RTX 4080 SUPER | ASUS produced no external display. PSU fan ran; GPU fans initially stayed still. Fan activity was not a reliable fault criterion. |
| 2 | Rechecked physical power, PCIe seating and upstream connection | No change on ASUS. No confirmed power fault identified. |
| 3 | Tried the assembly on the Dell Intel TB4 laptop | GPU fans ran, HDMI output appeared and NVIDIA driver installed. This changed the working hypothesis away from a dead GPU. |
| 4 | Windows updates on comparison laptop | Working Dell build recorded as 26200.9711. The screenshot identifies its Intel router and external TBGAA router. |
| 5 | ASUS graphics modes | Ultimate and Eco configurations, with reboot, did not make an external GPU/router appear. |
| 6 | Investigated ordinary dock USB functionality | Mouse and USB hubs worked. This established fallback USB operation, not a working USB4/PCIe path. |
| 7 | Separate Ethernet-sharing failure | UGREEN was the intended upstream Internet connection. Disabling and re-enabling the relevant adapter restored sharing. This was a networking detour, not evidence of eGPU recovery. |
| 8 | DISM/SFC and scoped USB controller repair, approximately 19:08-19:27 | Repair completed and devices recovered. A later SFC run was clean. eGPU symptom unchanged. |
| 9 | Normal Windows restart and EC reset | No change. Owner explicitly performed the long power-button reset before powering on. |
| 10 | Firmware UI inspection | No USB4/PCIe tunneling switch found. Secure Boot retained. No foreign firmware flashed. |
| 11 | Initial WPR capture around 20:01 | Only 253 metadata events: inadequate for connection analysis. Later direct captures superseded it. |
| 12 | Direct capture 20:08:03 | 8,403 events; zero lost events. Established the repeating no-external-router/fallback pattern. |
| 13 | Parade-scoped Windows Update search | Successful, zero matching updates. This was initially narrower than an all-vendor search. |
| 14 | Restarted all eight existing Parade peripheral devices at 20:47:41 | Six SPB and two HID devices restarted and recovered. No new problem devices. No link recovery. |
| 15 | Direct capture 20:47:54 | 6,500 events; zero lost. Old postprocessing raised a missing `Guid` error after capture; the saved trace itself remained usable. |
| 16 | Longer captures 21:06:31 and 21:07:44 | 9,876 and 12,787 events respectively; zero lost. Host restart captured initialization and `_OSC` grant `0xf`. |
| 17 | Four USB-C plug orientations / alternate UGREEN cable | No change. UGREEN cable capability was not established and later reported unsuitable. |
| 18 | UCSI isolation | Temporarily disabled `ACPI\USBC000\0`, tested, and re-enabled in `finally`. No new adapter reported. No full inventory saved during the disabled interval. |
| 19 | Removed 26H2 enablement package KB5121794 and restarted | System now reports 25H2 26200.9818; failure unchanged. Shared USB4 binaries remained, so this was not a clean OS or full cumulative-update rollback. |
| 20 | Exact-model firmware and driver research | BIOS 314 remained the newest exact-model BIOS found; no applicable public FA507XI USB-C/PD firmware image was verified. |
| 21 | ASUS engineering escalation | Owner authorized a technical report; it was sent in an existing ASUS support thread with selected evidence. Public case/contact identifiers are omitted. No engineering response was available at the last check. |
| 22 | Related-model official ASUS Parade package extracted | Package signature, catalogs, file membership and hardware-ID matching were checked. It was not listed for FA507XI. |
| 23 | Installed SPB 1.0.17 and HID 1.0.16 | All eight peripheral devices bound; symptom unchanged after restart. This did not establish a PD or retimer firmware change. |
| 24 | Restored original Parade drivers | Trial OEM packages deleted without force; original SPB 1.0.8 and HID 1.0.11 selected. A wrapper incorrectly stopped on PnPUtil code 259; actual rollback bindings were verified. |
| 25 | Private `EnableUSB4v2Support` override | Value set to 1, original absence recorded, normal reboot completed. Initially and incorrectly described as a test of the v2 policy path. |
| 26 | Direct capture 22:12:23, including host restart | 9,229 events, zero lost, no WPP formatting errors. Policy still reported v2 disabled. No external USB4 router; Billboard fallback repeated. |
| 27 | Offline code audit correction | The driver ignores the override unless test-signing is enabled. Test-signing was verified disabled. Override removed; the script now blocks the ineffective Enable operation. |
| 28 | All-vendor Windows Update driver search | Result code 2 (success), package count 0. No applicable package offered by that search. |
| 29 | BitLocker check | Both OS and secondary internal NVMe volumes reported fully decrypted, 0% encrypted, no protectors. Native-boot hosting is not blocked by encryption. |
| 30 | Initial temporary full-Windows toolkit preparation | Seven signed, installed System-class driver packages selected. At this point no disk/boot operation or fresh-Windows hardware test had completed; later outcomes are in steps 31-33. |
| 31, 31 October | First actual VHDX preparation | Created a 4 MiB container, then guard rejected Windows PowerShell's friendly BusType string. It stopped before disk initialization/formatting and detached. Correction adds friendly-string coverage and a guarded preservation/retry mode. No fresh-Windows boot result yet. |
| 32, 31 October | Corrected preparation and native boot | Failed attempt preserved, separate image applied successfully, baseline drivers staged, explicit boot entry created and Audit Mode reached. |
| 33, 03:16-03:17 on 31 October | Separate full Windows connection capture | Build 26200.8037, USB4 driver 10.0.26100.7920. Required preflight devices healthy; no external USB4 router/GPU; same fallback hub/Billboard. 7,720 events, zero reported loss; older WPP formats partly unknown. Owner returned to original Windows. |
| 34, 31 October | Existing UGREEN dock identified | Amazon ASIN B0DRP1F6R7 maps to Revodok Pro 3121 / SKU 55767. Conventional 10 Gbps USB-C hub, so it cannot supply the missing separate USB4-peripheral comparison. No new connection test claimed. |
| 35, 04:16 on 31 October | Seven ASUS UEFI photographs reviewed | External USB ports shown Unlock, Fast Boot Disabled, SVM Enabled and display mode Dynamic. No USB4/PCIe switch visible. Secure Boot submenu not photographed; no new setting change claimed. |
| 36, 04:27 on 31 October | Full Task Manager live kernel snapshot captured; subsequently inspected offline | USB4KD worked with matching symbols. One host/root, zero external routers/tunnels, `PcieTunnelsDisabledInBios = 0`, fallback USB devices Started. Both logical UCM connectors report local DFP roles. Retained host recorder has 38 successful configuration-request messages, not a successful link. No demonstrated repair or cause; [report and limits](kernel-snapshot.md). |
| 37, 31 October | Expanded offline snapshot inspection | All 12 available WPP buffers, 334 timestamped formatted records; three USB4 histories decoded with SmFxDbg, two UCSI rings decoded from public enums. Register reads succeed but USB4 plugged/router-detected checks return No. The firmware's UCSI and EC shared-memory pages are missing from this dump. No repair identified. |
| 38, 31 October | Additional existing-hardware comparison identified | Microsoft's USB4NET supports a direct Dell-to-ASUS peer test with the supplied DEG2 cable. ASUS in-box P2P driver package verified present. Proposed N0 is unperformed; no sharing or network configuration changed. |
| 39, 31 October | Scripted UCSI/EC memory probe prepared | Signed Microsoft LiveKD 5.65 and current symbols prepared. 19 PowerShell and 20 WinDbg JavaScript checks passed; offline replay discovers both regions and correctly reports missing bytes. Live loading/read access remain unperformed. No repair mode or security changes. [Method and limits](ucsi-memory-probe.md). |
| 40, 12:18:59 on 31 October | First live memory-probe launch failed; invocation corrected | KD opened a truncated log path and attempted COM1 instead of attaching to LiveKD. Wrapper reported NotCompleted despite LiveKD exit 0; no firmware bytes collected. Short relative filenames, minimal quoting and child environment paths now pass 20 PowerShell and 20 WinDbg JavaScript checks plus offline replay. Corrected live invocation awaits a rerun. |

## Corrections that matter

1. **GPU fan assumptions:** No reliable source established that this exact card must spin briefly on every startup. The working Dell test was the useful evidence.
2. **Capture postprocessing:** A `Guid` property assumption under StrictMode caused the wrapper to report an error after a successful trace recording. Capture validity and report-generation success are different facts.
3. **PnPUtil code 259:** The restore wrapper accepted only 0/3010 and stopped on an already-current package result. It was an error in wrapper handling, not proof that the original driver restoration failed.
4. **Registry override:** Inspection initially missed the test-signing gate. The reboot did occur; the user did not cause the invalid experiment. See [the code audit](policy-audit.md).
5. **WinPE:** A Windows installer/WinPE environment was initially proposed too strongly as a hardware isolation test. Microsoft advises against hardware validation with WinPE. The proposal was withdrawn; a full Windows installation is a different experiment.
6. **Native-boot guard:** Numeric BusType mocks missed the real Storage module's `File Backed Virtual` string. The first actual attempt stopped before initialization. The corrected deployment and later native boot completed; removal is still untested. See the [validation audit](validation-audit.md).
7. **LiveKD invocation:** Offline replay did not test LiveKD's argument forwarding. The first live run failed during debugger launch. Shortened options and minimal quoting pass offline replay; live attachment remains unverified. This failure supplies no new hardware result.
