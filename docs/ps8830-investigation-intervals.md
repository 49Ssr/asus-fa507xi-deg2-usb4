# Research checkpoint

Updated 3 November 2026. [Current findings](status.md) are the public summary; [the current plan](investigation-plan.md) names the open work.

## Current work

The RT0 mapping and USB enumeration order are established. The first failed PD/retimer/link operation remains unobserved. Follow the original RT0/PBS policy consumer or an identified controller diagnostic implementation.

The [first ASUS Linux capture](linux-asus-result.md) booted, saved to USB and reproduced fallback. No external router or new PCIe device appeared; the host router was present and ACPI granted OS PCIe control. The trace's transmitted ERROR 0x7 packets are normal plug-event acknowledgements. A matching Dell Linux capture is currently unavailable. Use the saved successful Dell Windows captures; native detection and device-status comparisons already exist. Do not repeat Dell boot-menu attempts, the old Windows capture or ASUS unchanged. Continue from this result and the original policy/controller implementation; obtain a new capture only for a named missing record.

## SDK checkpoint

EZ-PD Host SDK 3.9.0 is extracted privately. [Review and source pins](infineon-sdk-review.md). The package contains the missing AMD headers and ELF implementations. The 80-byte APU status reader sends index 80 and reads three bytes in its selected configuration; seven emulator cases verified its guard and bit-6 result. No ASUS status was acquired. Next compare that APU transaction and the separate interrupt reader with the original ASUS controller-facing code. Do not conflate the reference HPI tunnel with DEG2 WinUSB or ASUS EC access.

## Data-reset candidate

The [reset review](ucsi-data-reset.md) identifies a distinct hypothesis: retry USB4 discovery after successful role correction while preserving the corrected role. UCSI reset encodings change by version; ASUS retained version ffff and compatibility-layout handling do not establish a data-reset implementation. No reset was issued. Trace the actual receiving-controller handler/transport; do not substitute a hard reset or build an unrestricted command sender. The SDK-to-ASUS status mapping remains open independently.

## Command-path result

[Original-code trace](data-reset-command-path.md): the ASUS initializer writes a fixed UCSI0100 version without a PD-bus read, and the outgoing relay preserves the reset bit. The SDK primary build contains a UCSI2.0 data-reset handler and subsequent mux/timer handling. These do not identify the receiving ASUS PD firmware. The Windows transport is known; actual Data_Reset interpretation and current interface readiness are not. Linux debugfs reaches the same ACPI path and does not enumerate private controller operations. No new boot or live request is selected. Next identify the receiving handler/documentation or a supported physical-controller version read.

## Controller firmware/version result

[Windows returned cached PD firmware bytes0053](pd-firmware-version.md) through implemented fields10/11 hex, correcting the older0f/10 mapping before live use. The handle closed and temporary SYSTEM task was removed. The EC B6 refresh can retain old data on failure; cache freshness remains unverified. Official ASUS packages supplied an IT8853 different-board image and an IT8857 UEFI tool advertising /ov version-only mode; neither updater ran. The Windows314 capsule matches the existing EZ Flash image. Next correlate0053 with the exact laptop image or current-controller read and audit the vendor version-only transport; do not treat a raw candidate dispatch table as a Data_Reset handler.

## Physical chip correction

[Owner photographs](board-photo-review.md) identify IT8857FN and PS8830 A3. The original EC getter's IT8853 literal is not a physical ID. Prioritize the already-acquired IT8857 reference and vendor family implementation, then qualify the actual laptop image and transport. The photo map distinguishes PS8802 and HDMI PS8419 from PS8830; nearby eight-pin parts and the motherboard assembly/revision remain unidentified. No live read, reset or flash was performed.

## Operating constraints

Scheduling remains paused. Physical boots/cables are owner-directed, and no unattended remote restart is authorized. No live EC/I2C/vendor command, driver change, mode override or flash is selected. Preserve original artifacts, failed attempts and private recovery records.

Owner-directed usage stop remains 1% in any applicable known allowance window. Verify allowances before expanding sustained work, stop if unavailable, and never purchase credits, use resets or automatically resume scheduling.

## Earlier journal

The complete dated journal is preserved at [the pre-cleanup revision](https://github.com/49Ssr/asus-fa507xi-deg2-usb4/blob/52e6e26890adf49c2846a0acc478089659808843/docs/ps8830-investigation-intervals.md). Its old “next task”, unexecuted-read and scheduling statements describe their dates and do not override current state.

[Evidence map](investigation-map.md) · [History index](history.md)
