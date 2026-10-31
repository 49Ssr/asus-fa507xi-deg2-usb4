# Role negotiation: follow-up on the existing captures

**31 October 2026. Offline analysis completed; initial-role hardware test subsequently completed without reported attachment.** The comparison justified a narrowly defined Windows-initiated test, but it did not establish the requested connection or a working repair. [Measured result](initial-role-test.md#measured-result-2303-2304-utc).

## What was examined

The original deep ASUS comparison and successful Dell-DEG2 control were re-read, including the automatic UCSI commands before diagnostic queries. Matching driver code was inspected against the existing ASUS kernel dump with Microsoft's signed debugger, exact-symbol matching and the already retained driver images. No live kernel helper, firmware command, setting change or new hardware recording was used for this analysis. The owner's pasted PowerShell window corroborates the run sequence; its overlapped copy-command text is not used to reconstruct packet contents.

The [selected events and decoded-log hashes](../evidence/negotiation-followup.json) provide the review index. Original traces and full disassembly remain private. These are Windows observations, not USB-PD CC-wire packets.

## The narrower comparison

All times below are UTC on 31 October; DFP/UFP in the partner column describe the partner, not the laptop.

| Stage | ASUS-DEG2, fresh attach | Dell-DEG2 |
| --- | --- | --- |
| Initial Type-C report | 20:10:24.108: partner DFP, USB flag `0x1`; laptop consumes power | 21:25:17.386: partner DFP, USB flag `0x1`; laptop consumes power |
| First PD report | 20:10:24.198: partner still DFP, USB flag `0x1` | 21:25:17.790: partner already UFP, USB flag still `0x1` |
| OS role-correction decision | 20:10:24.313: Yes | 21:25:18.110: No |
| OS correction request | 20:10:24.333: `SET_UOR(Dfp)`; completion at .361 | No `SET_UOR` in the recorded sequence |
| Later report/result | 20:10:24.421: partner UFP, flags `0x2` (alternate-mode-only); no external router | Partner stays UFP/USB-capable; external router, GPU and output work |

The ASUS handoff repeats the corresponding sequence: request at 20:09:25.878, completion at .903 and UFP/alternate-mode-only report at .955. The divergence therefore is not simply "Dell starts DFP, ASUS starts UFP": **both initially report the same partner role. Dell's report changes during PD negotiation without a recorded Windows role request; ASUS reaches the OS correction path.** Firmware-led negotiation is consistent with the Dell ordering, but the wire-level cause is not exposed.

The working ASUS-Dell peer phase is an important control: Windows requests `SET_UOR(Dfp)` at 20:08:43.330, firmware rejects it at .375, and the peer link subsequently works. The fact that Windows requests a correction is therefore not sufficient evidence of a broken USB4 path. A successful role change also does not prove native USB4 entry.

## What arms the ASUS correction

The matching `UcmUcsiCx` function `CheckIfPowerDirectionDifferentFromDefaultEntry` writes the connector's `PerformRoleCorrectionOnNextPdContract` byte. Despite its name, this part of the function maps the connector's reported partner type to the local data role. It sets the byte when local role maps to UFP and `m_IsUsbDeviceControllerEnabled` is false; otherwise it clears it. `CheckIfRoleCorrectionIsNeededEntry` consumes and clears that byte before choosing the next state. The retained ASUS dump has the device-controller flag false. The trace's correction path is consistent with that implementation.

Microsoft's [ACPI client sample](https://github.com/microsoft/Windows-driver-samples/blob/main/usb/UcmUcsiAcpiSample/UcmUcsiAcpiSample/Acpi.cpp) documents the platform policy mapping; the installed ACPI client's corresponding consumer was separately disassembled. The [documented `_DSM` function 4](https://learn.microsoft.com/en-us/windows-hardware/design/component-guidelines/usb4-acpi-requirements#device-specific-method-to-prevent-data-role-swap-for-host-to-host-connections) is a firmware-provided way to disable correction. This audit did not establish a registry switch controlling the flag. The previously examined URS override remains inapplicable to the observed missing-URS path.

**Limit:** Dell's device-controller policy was not independently recovered. Its No decision must not be attributed exclusively to the later UFP report or assumed to use the same policy as ASUS. The runtime interface also reports different client class/protocol versions despite the matching on-disk images; those observations keep configuration/version interpretation open and do not justify changing a version override.

## A different test is justified

The ASUS advertises SET_CCOM support, connector-1 DRP operation and provider capability. Its recorded default attachment to powered DEG2 starts as power consumer/local UFP and later needs data-role correction. A single **Rp-only CC-mode selection before attachment** tests a different initial path: can ASUS attach as source/local host and enter USB4 without that later correction? This differs from repeating `SET_UOR`, exiting an alternate mode or reinstalling a controller.

[UCSI 1.22 section 4.5.8](https://www.intel.com/content/dam/www/public/us/en/documents/technical-specifications/usb-type-c-ucsi-spec.pdf) defines SET_CCOM and DRP as its reset/default for a DRP-capable connector. Microsoft's [UCSI test documentation](https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/ucsi#ucsicontrol-exe) names the command SET_UOM and supplies the corresponding DFP/DRP examples. These are names for command `0x08`; this is not SET_NEW_CAM.

The [test](initial-role-test.md) saves restoration intent before sending one Rp-only request, requires disconnection for both SETs and returns to documented default DRP afterward. The exact prior CC policy cannot be read, so restoration is deliberately described as default DRP. The owner ran it at 23:03-23:04 UTC: Rp-only completed but there was no reported attachment or PD negotiation in the 30.886-second trace. Default DRP restoration completed; no recovery is pending. This closes the unchanged Rp-only candidate for now without establishing the intended causal comparison or disproving the later-role-correction hypothesis. Do not repeat it unchanged. The [result](../evidence/initial-role-result.json) retains coverage limits, including 118 unknown records and absence of wire-level CC evidence. A disconnected SET_UOR is not a supported pre-arming alternative under section 4.5.9.
