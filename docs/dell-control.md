# Portable Intel Dell-DEG2 control

**Successful control recorded, 31 October 2026.** The corrected collector recorded the Intel Dell Latitude 5540 establishing native USB4 and enumerating the DEG2 and RTX 4080 SUPER. NVIDIA binding was present before diagnostic GET requests; after recording, the owner confirmed display output. The ASUS remains unresolved. The first invocation had stopped during import; that separate startup defect is documented below.

## Measured result

| Measurement | Observed result |
| --- | --- |
| System | Dell Latitude 5540; BIOS 1.32.0; Windows 25H2, build 26200.9818 |
| ETL | 21:25:02.961-21:27:31.350 UTC; 148.389 seconds; 291,241,984 bytes, below the 1 GiB cap |
| Decode | 1,096,876 events; zero reported lost events/buffers; zero format errors; 294 unknown records remain |
| New DEG2 uplink telemetry | Speed `0x04` (Gen 3), width `0x02`, bonded lanes, both adapter states `0x02`; reported 40 Gbps. `Tbt3CompatibleMode = 0`: this successful control uses native USB4. |
| GPU/output observations | Prequery inventory: new RTX 4080 SUPER, Status OK, problem code zero, `nvlddmkm` bound. After recording, owner confirmed an image on the GPU-connected display. |
| Diagnostic GETs | 41/41 completed; no transport failure, final busy response or CCI error. Both error-status replies are zero. |
| UCSI command sequence | 48 commands and 48 ACKs; all 48 terminal command completions and ACK completions present; no UCSI errors/timeouts. Seven normal commands plus 41 diagnostic GETs. |
| Formatted driver messages | 2,167 UcmUcsiCx; 20 UcmCx; 3,050 USB4 host; 3,781 USB4 device-router lines |
| Driver comparison | All 14 copied driver/kernel images match the current ASUS installation byte-for-byte by SHA-256, including both USB4 drivers, UCM/UCSI, ACPI and PCI. This compares installed files; loaded module metadata also confirms USB4/UCSI version 10.0.26100.9818 on Dell. |
| Cleanup | Saved original diagnostic value was absent; state finished Restored. Before/after-cleanup adapters, IP, DHCP/interface, DNS, default-route and ICS snapshots match. |

The private ETL SHA-256 is `2F70CDA8695179930A644ABD99B327F7FDB0C49A653A618D9FBCB6CE6447B9FB`. Import verified all 55 returned files against their source hashes. Raw captures, driver files, PDBs, identities and network snapshots remain private.

### Difference from the ASUS failure

| Observation | Working Dell | Failed ASUS handoff and fresh attachment |
| --- | --- | --- |
| OS-requested data-role correction | No `SET_UOR` command in the recorded sequence; role-correction decision is No | Windows requests `SET_UOR(Dfp)`; it completes successfully on both DEG2 attempts |
| Subsequent partner report | UFP, USB flag `0x1`; operating modes stay `0x40` | UFP, alternate-mode flag `0x2`; operating modes change `0x40 -> 0x20` |
| Partner alternate-mode replies | Index 0: Intel SVID `0x8087`, VDO `0x00000001`; index 1: DP SVID `0xff01`, VDO `0x00001c46`; index 2 empty. Repeated index 0 replies agree. | Index 0 reports DP SVID `0xff01`, VDO `0x001c0045`; the 21:58 inspection confirms index 1 empty and stable index 0 repeats. Earlier VDO transcription corrected against raw bytes. |
| Mode support/current index | Supported bitmap `0x0f`, current index `0` | Supported bitmap zero, current index `1`; 21:58 inspection finds local count 1, only index 0 readable, and override support advertised |
| Result | External router, PCIe tunnel, NVIDIA driver and image | USB/Billboard fallback; no external router/GPU |

This makes the platform's data-role/advanced-link negotiation a specific investigation target. It does **not** prove `SET_UOR` caused failure: role correction may be required on ASUS, the two PPM implementations report different capabilities, alternate-mode ordering can differ, and UCSI reports do not establish the physical mux state. Intel's alternate-mode reply also does not imply the working link used Thunderbolt 3; port telemetry reports native USB4.

Microsoft documents [UCSI `_DSM` function 4](https://learn.microsoft.com/en-us/windows-hardware/design/component-guidelines/usb4-acpi-requirements#device-specific-method-to-prevent-data-role-swap-for-host-to-host-connections) to disable OS data-role correction for platforms affected by host-to-host swaps. Existing ASUS AML advertises mask `0x0f`, omitting function 4. That is a vendor-evaluation lead, not a BIOS compliance finding or an established eGPU workaround; Microsoft's stated scenario is host-to-host. Offline inspection confirms the class driver's role-correction decision consumes and clears the connector's `PerformRoleCorrectionOnNextPdContract` flag. No supported registry workaround, runtime patch or successful repair was established.

### Coverage limits that affect interpretation

- Recording started before attachment. GREEN appeared at 21:25:07.990; the first attachment-related UCSI notification is at 21:25:17.350. The nominal 25-second passive window is measured from GREEN, leaving about 15.66 seconds after that notification before inventory; IFR and active queries start later. The physical insertion instant is not independently measured.
- Both debugger transcripts reached their markers. Some individual commands still report errors: the ACPI client's WPP header is unavailable, its WDF records supplement it, and USB4KD reports an error before supplying a partial topology containing the DEG2 and PCIe tunnel. Transcript completion does not prove every decoder succeeded. Helper unloading remains unverified.
- Dell does not advertise cable-detail support and returns zero cable-property bytes despite a working 40 Gbps link. Those replies cannot establish cable speed or absence of an e-marker. ASUS's implausible cable-speed/version fields also remain unresolved.
- Identical Windows files weaken a corrupt/different-build explanation; hardware, ACPI, firmware, state and configuration still differ. This is not an exclusion of every Windows interaction.
- Repeating the identical Dell capture has no identified benefit. Before another experiment, audit how the ASUS correction flag is set and whether its firmware role/mode transition can be changed through an applicable, reversible interface. A generic controller reinstall does not test this difference.

## Run the prepared private bundle

1. Transfer the entire corrected `USB4-Dell-Control` folder on USB, then copy it onto the Dell SSD, preferably `C:\USB4-Dell-Control`. Keep at least 3 GiB free on that volume. Keep the Dell on its normal charger and DEG2 powered, with the display attached to the GPU.
2. Right-click `START.cmd` and select **Run as administrator**. Follow the initial disconnection prompt. Symbol preparation happens before tracing; Internet access allows matching Microsoft PDB downloads.
3. Wait for **GREEN** before connecting DEG2 to the same Dell Thunderbolt port that previously worked. Keep it connected until recording and status queries finish.
4. Answer whether the GPU display showed an image. Disconnect DEG2 when prompted so the original diagnostic setting can be restored. After completion, copy the entire `Results` directory, including `State` and `SymbolCache`, back onto USB. Retain the Dell copy until analysis is complete.

The drive letter can differ on the Dell: paths derive from the launcher's folder. `UNDO.cmd`, run as administrator on the same Dell with DEG2 disconnected, finishes restoration after an interrupted run. A required normal Windows restart is reported with a saved resumable state; the script does not reboot automatically.

Direct USB execution is supported if its storage check passes. The stick must connect directly to the Dell, because DEG2 is deliberately disconnected. SSD recording is preferred: the profile includes USB transfers/payloads, so writing its ETL to USB can add the recording device's own traffic. This is a method-based inference, not a measured failure of this stick. Microsoft describes the [USB transfer/payload keywords](https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/how-to-capture-a-usb-event-trace).

Source entry point: [Capture-DellDEG2Control.ps1](../tools/Capture-DellDEG2Control.ps1). It imports [the ASUS source](../tools/Capture-USB4PartnerSwap.ps1) and [shared capture primitives](../tools/Usb4Capture.Common.ps1), then supplies a separate Dell context. ASUS model, preparation and native-tool guard function bodies retain their verified hashes. Shared import-path handling and trace-start error cleanup were corrected; the ASUS entry point is not invoked by Dell. The public source checkout does not redistribute the private binary bundle.

## Evidence and changes

| Component | Method |
| --- | --- |
| ETW | Same 27-provider profile, including USB transfer/header/payload keywords; recording starts before insertion. Sequential ETL capped at 1 GiB; only its owned session is stopped. |
| Attachment | Five-second disconnected baseline, 25-second passive attachment window, inventories before/after active queries. Router, new NVIDIA device, bound NVIDIA driver and owner-observed display image are separate milestones. |
| Driver identity | Copies 14 scoped installed Windows driver/kernel images where present, records versions/SHA-256 and bounded PE CodeView/PDB identities. Metadata derives from the copied bytes. PnP parent, service, driver-version and problem information accompanies the device inventories. |
| Flight recorders | Signed Microsoft LiveKD/KD, exact-symbol requirement, Microsoft symbol-server cache on the USB and the previously exercised USB4/UCM/UCSI recorder commands. Logs retain errors and decoder limits. A failed symbol warmup does not erase the ETW control. |
| Firmware | If one healthy Microsoft ACPI UCSI device is available, raw GET replies after passive observation/IFRs. Additional local/partner mode offsets, two cable recipients and repeated partner reads supplement the ASUS query set. No guessed mode ID is forced. |
| Original state | Machine-bound private record of the diagnostic DWORD's original presence/value and network/ICS state precedes any write. Only the selected UCSI device restarts. Original state restores after physical disconnection; unexpected intervening values stop overwrite. No network settings are edited. |
| Storage / failure cleanup | Actual JSON creation, replacement and readback are tested before preparation. Final evidence-write failures are reported without skipping restoration. If a trace starts but its startup log cannot be saved, the starting function stops that exact session before throwing. A restoration-state write failure still attempts the selected UCSI restart. |

Native UCSI help returns exit code 1 even after successful enumeration in the actual tool. Readiness therefore checks the help text and exact single device identity, not a zero exit code alone. Firmware responses are separately classified as completed, unsupported, firmware error, busy or transport failure. Busy/transport failure stops further requests. The phase has a 90-second budget, five-second command limits, eight-connector and eight-mode-offset bounds; limits are recorded.

If the Dell has no ACPI UCSI device, the absence is reported and firmware coverage is marked unavailable while Windows USB4 evidence is retained. If an expected UCSI interface cannot be prepared, the run stops before its connection prompt and attempts original-state cleanup. No firmware flash, controller-wide reinstall, security-policy change or automatic Windows reboot is requested.

LiveKD temporarily loads its signed kernel helper. The wrapper owns its process tree and records timeouts; helper unloading is not independently established. This is Windows/firmware-interface evidence, not raw USB-PD CC wire traffic. Capture completion alone does not establish GPU operation or complete decoding.

## Package and validation

The private bundle contains 419 hashed members plus its manifest, approximately 130 MiB. It includes the three PowerShell sources, [launchers/readme](../tools/portable-dell/README.txt), Microsoft debugger components, LiveKD 5.65, the hash-pinned unsigned UcsiControl from official MUTT 3.0.1 and existing TMF formats. It contains no ASUS dump, ETL, driver-image snapshot, original-state record or PDB. Dell-specific symbol downloads and results are created only when used.

| Validation | Actual result |
| --- | --- |
| Windows PowerShell 5.1 parser / actual Preview | Passed |
| Current installed PE/PDB identity | Actual USBXHCI identity matches the previously verified symbol key |
| Startup / storage / trace ownership | 13 assertions passed in PS5.1: parser, actual initializer with C/D/E root values and a nested path, actual JSON create/replace/readback, replacement refusal and owned-session error cleanup. ETW calls mocked; an actual drive-root folder was unavailable in the tool session. |
| Native enumeration and preparation/undo | 23 assertions passed, including original absent/0/1/2, backup failure, intervening value, required-restart resume, repeated Ready and restoration-state write failure; registry/device/network operations mocked |
| Capture lifecycle | 19 in-memory cases passed: ordering, driver milestones, partial coverage, trace/phase failures, ETL guard, cleanup, interrupted observation and final log/metadata I/O failures |
| GET encoding / protocol | Nine assertions passed, including PDO/mode-offset/cable encodings, bounded list termination, firmware errors and transport/busy stopping |
| Packaged binaries/extensions | All manifest hashes verified; native debugger signatures checked. Actual packaged KD/recorder replay on the existing offline dump reached both markers and decoded UCSI records. No live helper loaded for this replay. |
| Dell hardware capture | Completed; native USB4 router/PCIe GPU, NVIDIA binding and display image confirmed. Measured results and decoder limits above. |

### First-launch correction

The USB folder was one level below a drive root. Shared initialization derived the repository as the drive root, then passed its empty parent into `Join-Path`. Initial testing used a deeper workspace path and missed this layout. The correction falls back to the root itself before the Dell entry point supplies its own symbol directory. The supplied error establishes a collector startup failure, not a hardware or firmware failure. Replacing the five changed text/source files and manifest preserves existing `Results`/`State`; the binary bundle does not need recopying for this update.

Primary methods: [Microsoft UCSI diagnostics](https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/ucsi), [USB4 ETW/IFR](https://learn.microsoft.com/en-us/windows-hardware/design/component-guidelines/usb4-examining-connection-manager-driver-traces), [symbol configuration](https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/symbol-path) and [UCSI 1.22 tables](https://www.intel.com/content/dam/www/public/us/en/documents/technical-specifications/usb-type-c-ucsi-spec.pdf). Tool provenance and native hashes are in the private package manifest and its readme; binaries/results remain excluded from Git.
