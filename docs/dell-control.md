# Portable Intel Dell-DEG2 control

**Prepared, not yet run on Dell.** The same assembled DEG2/GPU/PSU/cable already works on the Dell. A trace starting before successful attachment can compare Type-C/PD decisions, USB4 link/router creation and PCIe/GPU enumeration against the [recorded ASUS sequence](handoff.md#n5-existing-hardware-partner-handoff-proposed).

## Run the prepared private bundle

1. Copy the entire `USB4-Dell-Control` folder onto the USB drive. Keep at least 3 GiB free. On the Dell, keep its normal charger connected and DEG2 powered, with the display attached to the GPU.
2. Right-click `START.cmd` and select **Run as administrator**. Follow the initial disconnection prompt. Symbol preparation happens before tracing; Internet access allows matching Microsoft PDB downloads.
3. Wait for **GREEN** before connecting DEG2 to the same Dell Thunderbolt port that previously worked. Keep it connected until recording and status queries finish.
4. Answer whether the GPU display showed an image. Disconnect DEG2 when prompted so the original diagnostic setting can be restored. Safely eject the USB after completion and bring back the entire `Results` directory.

The drive letter can differ on the Dell: paths derive from the launcher's folder. `UNDO.cmd`, run as administrator on the same Dell with DEG2 disconnected, finishes restoration after an interrupted run. A required normal Windows restart is reported with a saved resumable state; the script does not reboot automatically.

Source entry point: [Capture-DellDEG2Control.ps1](../tools/Capture-DellDEG2Control.ps1). It imports [the ASUS source](../tools/Capture-USB4PartnerSwap.ps1) and [shared capture primitives](../tools/Usb4Capture.Common.ps1), then supplies a separate Dell context. The ASUS entry point and model/hash guards remain byte-identical to the completed ASUS run. The public source checkout does not redistribute the private binary bundle.

## Evidence and changes

| Component | Method |
| --- | --- |
| ETW | Same 27-provider profile, including USB transfer/header/payload keywords; recording starts before insertion. Sequential ETL capped at 1 GiB; only its owned session is stopped. |
| Attachment | Five-second disconnected baseline, 25-second passive attachment window, inventories before/after active queries. Router, new NVIDIA device, bound NVIDIA driver and owner-observed display image are separate milestones. |
| Driver identity | Copies 14 scoped installed Windows driver/kernel images where present, records versions/SHA-256 and bounded PE CodeView/PDB identities. Metadata derives from the copied bytes. PnP parent, service, driver-version and problem information accompanies the device inventories. |
| Flight recorders | Signed Microsoft LiveKD/KD, exact-symbol requirement, Microsoft symbol-server cache on the USB and the previously exercised USB4/UCM/UCSI recorder commands. Logs retain errors and decoder limits. A failed symbol warmup does not erase the ETW control. |
| Firmware | If one healthy Microsoft ACPI UCSI device is available, raw GET replies after passive observation/IFRs. Additional local/partner mode offsets, two cable recipients and repeated partner reads supplement the ASUS query set. No guessed mode ID is forced. |
| Original state | Machine-bound private record of the diagnostic DWORD's original presence/value and network/ICS state precedes any write. Only the selected UCSI device restarts. Original state restores after physical disconnection; unexpected intervening values stop overwrite. No network settings are edited. |

Native UCSI help returns exit code 1 even after successful enumeration in the actual tool. Readiness therefore checks the help text and exact single device identity, not a zero exit code alone. Firmware responses are separately classified as completed, unsupported, firmware error, busy or transport failure. Busy/transport failure stops further requests. The phase has a 90-second budget, five-second command limits, eight-connector and eight-mode-offset bounds; limits are recorded.

If the Dell has no ACPI UCSI device, the absence is reported and firmware coverage is marked unavailable while Windows USB4 evidence is retained. If an expected UCSI interface cannot be prepared, the run stops before its connection prompt and attempts original-state cleanup. No firmware flash, controller-wide reinstall, security-policy change or automatic Windows reboot is requested.

LiveKD temporarily loads its signed kernel helper. The wrapper owns its process tree and records timeouts; helper unloading is not independently established. This is Windows/firmware-interface evidence, not raw USB-PD CC wire traffic. Capture completion alone does not establish GPU operation or complete decoding.

## Package and validation

The private bundle contains 419 hashed members plus its manifest, approximately 130 MiB. It includes the three PowerShell sources, [launchers/readme](../tools/portable-dell/README.txt), Microsoft debugger components, LiveKD 5.65, the hash-pinned unsigned UcsiControl from official MUTT 3.0.1 and existing TMF formats. It contains no ASUS dump, ETL, driver-image snapshot, original-state record or PDB. Dell-specific symbol downloads and results are created only when used.

| Validation | Actual result |
| --- | --- |
| Windows PowerShell 5.1 parser / actual Preview | Passed |
| Current installed PE/PDB identity | Actual USBXHCI identity matches the previously verified symbol key |
| Native enumeration and preparation/undo | 22 assertions passed, including original absent/0/1/2, backup failure, intervening value, required-restart resume and repeated Ready; registry/device/network operations mocked |
| Capture lifecycle | 16 in-memory cases passed: ordering, driver milestones, partial coverage, trace/phase failures, ETL guard, cleanup and interrupted observation |
| GET encoding / protocol | Nine assertions passed, including PDO/mode-offset/cable encodings, bounded list termination, firmware errors and transport/busy stopping |
| Packaged binaries/extensions | All manifest hashes verified; native debugger signatures checked. Actual packaged KD/recorder replay on the existing offline dump reached both markers and decoded UCSI records. No live helper loaded for this replay. |
| Dell hardware capture | Unperformed |

Primary methods: [Microsoft UCSI diagnostics](https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/ucsi), [USB4 ETW/IFR](https://learn.microsoft.com/en-us/windows-hardware/design/component-guidelines/usb4-examining-connection-manager-driver-traces), [symbol configuration](https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/symbol-path) and [UCSI 1.22 tables](https://www.intel.com/content/dam/www/public/us/en/documents/technical-specifications/usb-type-c-ucsi-spec.pdf). Tool provenance and native hashes are in the private package manifest and its readme; binaries/results remain excluded from Git.
