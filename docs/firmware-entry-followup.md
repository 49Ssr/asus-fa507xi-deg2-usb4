# Firmware entry investigation, 1 November 2026

**Preconnected startup completed, 1 November:** powered DEG2 was connected to the same ASUS USB4 port before power-on and left connected, as confirmed by the owner. Both post-sign-in snapshots still show Billboard, no external USB4 router and no RTX 4080 SUPER; display N. The 20-second trace has 471,428 events, zero loss/format errors and 14 unknown formats. This sequence did not enable USB4. Initial BIOS/PD negotiation is outside the capture. [Measured observation](cold-start-observation.md), [structured evidence](../evidence/cold-start-result.json).

**Investigation continues after the ineffective role-policy trial.** The experimental filter is removed and stock policy verified. The owner chose to continue offline research in the current session; final Secure Boot/original-loader verification remains pending. No further security changes, firmware requests, driver loads or automatic reboots were performed in this follow-up.

## What the existing dumps now establish

The ASUS class extension caches UCSI version `0xffff`; Dell caches `0x0100`. Offline disassembly of the exact ASUS Microsoft ACPI client shows that its hardware preparation reads the mapped VERSION word into its client object. The existing ASUS dump retains `0xffff` in that client field too, with the reported-version opt-in false and a 4,096-byte mapped resource. The object/field relationship was checked against the client's accessors and preparation code. This narrows the possibility that `0xffff` is merely a class-extension sentinel. The physical mapped bytes themselves are not newly readable, and no live firmware read was performed.

This is an anomaly to investigate, **not a justification to force a newer protocol or command**. Microsoft documents that, without the function-5 opt-in, reported versions at least 2.0 use the older 1.2-compatible layout. Newer UCSI layouts contain breaking changes. Setting that opt-in or changing a version field alone could make Windows interpret the wrong memory layout. The previously decoded ASUS commands complete normally, so the anomalous word does not by itself prove that it prevents USB4. [Microsoft UCSI version handling](https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/ucsi).

## Exact-model BIOS inspection

The official ASUS FA507XI BIOS 314 EZ Flash archive was downloaded and its SHA-256 matched ASUS's published API value. The capsule was inspected offline with UEFIExtract A76, whose archive hash also matched its publisher's release digest. Neither firmware image nor installed firmware was modified or flashed.

| Artifact | SHA-256 |
| --- | --- |
| Official `FA507XIAS314.zip` | `44F8FBE4685C8D7F61C85922EE56D53AC1B5AFCE8650063E78220CD35485B26B` |
| Capsule `FA507XIAS.314` | `A72291441A378A38A1AA7D5198C4AEB91AED07F787A3025435393719351F4ED1` |
| Extracted `AmdUsb4Dxe` PE32 body | `E89BF3A8D965E122D5541715FF29DD42F53A687DB292CF36513C22FFB6176BFA` |
| Extracted `AmdCpmUcsiDxe` PE32 body | `B338177EAA4C7469E00AD42BEF79E279855A92C2CCCFE62F1F96E6AF20A482C5` |

`AmdUsb4Dxe` contains an AMD pre-OS connection manager, router/tunnel/link configuration routines and ReadyToBoot/ExitBootServices callbacks. Its core entry checks a platform configuration Boolean before entering the pre-OS manager. The relevant static entry is RVA `0x650`, the gate is queried with token `0x1dd`, and the pre-OS-manager call targets RVA `0x1828`. This is evidence of a separate startup code path, **not proof that it executes on this machine, accepts DEG2 or leaves a working tunnel for Windows**. The smaller UCSI DXE module patches the ACPI/NVS region; that does not identify the PD-controller firmware implementation.

Sources: [ASUS exact-model BIOS page](https://www.asus.com/supportonly/fa507xi/helpdesk_bios/), [official archive](https://dlcdnets.asus.com/pub/ASUS/GamingNB/Image/BIOS/117046/FA507XIAS314.zip), [UEFITool A76 release](https://github.com/LongSoft/UEFITool/releases/tag/A76). Firmware and extracted binaries remain private.

## Parade retimer boundary

The installed, signature-valid `PRHidDrv.sys` version 1.0.11.0 is associated with the ASUS PS8830 ACPI devices and uses Microsoft's Virtual HID Framework. Its SHA-256 is `9B701E2BEF6411AC2ECB01CF9819DDEEDEFD0975A77863726E77009D89D4296C`. Parade identifies PS8830 as a USB4/USB3/DisplayPort retimer. That establishes its role in the signal path; it does not establish that the chip is faulty. [Parade PS8830](https://www.paradetech.com/products/ps8830/).

Offline inspection recovered an 83-byte HID report descriptor: vendor usage page `0xfa00`, collection usage `0xf5`, report ID `0x20` with 60 payload bytes for output/feature reports, plus other input/output reports. The local get-feature handler at RVA `0x1000` accepts ID `0x20` with a 61-byte buffer and builds its reply from cached driver fields. Its reviewed path does not read current retimer link registers. A separate output callback at RVA `0x12b0` reaches firmware-update/readback routines. Consequently, a generic HID query or a routine named "firmware dump" must not be assumed to be a passive register read. **No HID feature/output report, vendor IOCTL, SPB transaction or retimer update was sent.** [Microsoft VHF callback model](https://learn.microsoft.com/en-us/windows-hardware/drivers/hid/virtual-hid-framework--vhf-).

Linux's upstream PS883x driver identifies USB/DP/TBT/USB4 connection-state bits, but that is register-level context, not a qualified Windows access method for this ASUS. Its platform-specific USB4 workaround is not evidence of applicability here. Further reverse engineering must map the actual Windows transport and any entry/reset side effects before a live command is proposed. [Upstream PS883x driver](https://github.com/torvalds/linux/blob/master/drivers/usb/typec/mux/ps883x.c).

## Completed startup observation

At preparation, this startup condition had not been confirmed as tested. The owner subsequently reported performing it; see the preliminary inspection above. The [cold-start observation](cold-start-observation.md) is now completed: powered preconnection was owner-confirmed, but both snapshots and USB4 rundown remain failed; display N. It used stock drivers and captured the already-connected state after sign-in. There is no repeat of that unchanged startup queued.

The observed failure shows that this startup sequence was insufficient as performed. It does not prove that the BIOS manager ran or reveal the failed physical PD/link-training exchange. The retimer/EC/PD path remains a distinct analysis target. There is still no validated Windows fix or identified safe firmware patch.

## Installed CFU firmware recovered for offline analysis

**Later qualification:** PnP's reported 1.3.0.2 is not an independent hardware-version check on both retimers. Instance 18 retains `Create SPB device fail` and version zero; the existing dump exposes retained target-reopen state. A conditional flash write also extends beyond the recovered 64 KiB image. [Updater evidence and corrected limits](parade-updater-failure.md).

Read-only PnP properties reconfirm two healthy PS8830 firmware-child devices using the installed Parade CFU driver 1.0.6.0 and reporting firmware **1.3.0.2**, dated 17 March 2023. This firmware version was already recorded during the earlier related-model peripheral-driver trial; it is not a newly discovered upgrade. The exact-model ASUS page describes the peripheral driver as enabling retimer firmware delivery through Windows Update. [ASUS FA507XI driver page](https://www.asus.com/uk/supportonly/fa507xi/helpdesk_download/).

The already-installed CFU package contains a 16-byte offer and an 86,016-byte payload. The offer version word is `0x01030002`, consistent with the reported version; its component ID is `0x30`. The payload was copied privately and parsed offline into 4,096 contiguous, non-overlapping 16-byte records covering addresses 0–65,535. Re-encoding every address/length/data record reproduces the original payload byte for byte. The resulting 65,536-byte image has SHA-256 `A6CF7221832BC4D5F1A62A5A99013F1D448FF19F0646C5FEA2828E13AA38456E`.

| Installed content | SHA-256 |
| --- | --- |
| Offer | `1FAA3D89A7BDC052F5F8CA4DAA595DECA946BDCDC437D8C2E50B4E90028BE635` |
| Payload | `21BE9C236BFE2DB703BD6E93BB0BC5DE19160B12016777EB6A8F462DFE1B0CB3` |

Embedded labels identify an AMD PS8830 retimer project dated 20230317 and bootloader 1.0.3. Other labels refer to USB4 transmitter training, receiver CTS timers, receiver-PLL delays and retraining. These provide concrete offline analysis leads, not executed-code proof or a patch location. Architecture, port mapping and the relation to EC/PD Enter_USB control still require mapping. The content format and version/offer distinctions were checked against [Microsoft's CFU guide](https://learn.microsoft.com/en-us/windows-hardware/drivers/cfu/cfu-firmware-implementation-guide) and [protocol specification](https://learn.microsoft.com/en-us/windows-hardware/drivers/cfu/cfu-specification).

No CFU offer, HID output report, reset, firmware installation or flash was sent. The image is the installed package's offered content; the physical flash was not dumped or compared byte for byte. A matching reported version is not proof that every flash byte matches, and installing the same package again is not an established fix. The Update Catalog was subsequently read by direct HTTPS after the normal web reader failed. Two actual PS8830 CFU candidates were recovered and checked offline: updater 1.0.7.0 offers 1.3.0.5; updater 1.0.8.0 offers 1.3.0.4. Hardware IDs and catalog membership match, but exact-model qualification/recovery remain unresolved. The configured Windows Update search returned no pending drivers. [Candidate review and deployment gate](parade-cfu-candidates.md). No newest-applicable-firmware claim is made. Preserve originals and keep all vendor binary content private.
