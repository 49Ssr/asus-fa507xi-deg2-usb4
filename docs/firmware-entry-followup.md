# Firmware entry investigation, 1 November 2026

**Post-startup inspection, 1 November at 13:05 UTC:** Windows started a new kernel session at 13:02 UTC. Current inventory still shows DEG2 USB/Billboard fallback, with no healthy matching external router or RTX 4080 SUPER. Native Code Integrity flags show test signing off and HVCI running; no experimental driver service is present. Secure Boot registry state remains off. The owner reports performing the startup sequence and not waiting the full suggested 20 seconds; the actual interval was not measured. The prepared run still says Prepared and has no collection result/ETL. Continuous attachment and the collection-window outcome require clarification, so this is a preliminary inventory observation, not a completed matched startup capture. No further reboot or repeat attachment is queued merely to finish collecting this session.

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

## Next controlled observation

At preparation, this startup condition had not been confirmed as tested. The owner subsequently reported performing it; see the preliminary inspection above. The prepared [cold-start observation](cold-start-observation.md) tests that existing-hardware path once. It uses stock drivers and records router/GPU/Billboard state after sign-in without reconnecting DEG2. Preparation has run successfully on the actual ASUS; **the formal cold-start capture is pending**.

If it works, follow-up must qualify reconnect behaviour and Windows handoff before claiming a fix. If it fails, it eliminates this startup sequence as a sufficient workaround; it does not prove that the BIOS manager ran or reveal the failed physical PD/link-training exchange. The retimer/EC/PD path remains a distinct analysis target. There is still no validated Windows fix or identified safe firmware patch.
