# Linux USB4 comparison

This kit asks whether FA507XI and DEG2 establish an external USB4 router under Linux. It records ordinary USB, Type-C roles/identity, USB4 topology and PCIe devices, plus kernel/uevent logs and available USB4/UCSI tracepoints. A router appearing is useful even if PCIe authorization is pending. GPU display output is not the pass criterion.

**Preparation status:** stock SystemRescue13.02 downloaded and checked against the publisher's SHA256 and detached signature. Its embedded kernel configuration enables USB4, UCSI/ACPI and tracing. Collector Preview, offline boundary tests and launcher syntax are checked. The custom boot flow, real USB persistence and hardware capture have not been exercised. No Linux boot or physical-device change has occurred during preparation.

## Files prepared on Windows

The private `local/LinuxCaptureBundle` folder contains:

- The original `systemrescue-13.02-amd64.iso`, unchanged, with its signature/checksum.
- `USB-OVERLAY`, containing the collector, console launcher, configuration and payload hashes.
- This guide as `START-HERE.md`.

The ISO is1381629952bytes. Its SHA256 is `ad4d670b72859d887c7960142a9a9d36a3e50446694a035e254442f65d6e7572`. The signature verifies with the key published by SystemRescue, primary fingerprint `0FF11AF081E98345594812037091115F8320B897`. No Windows trust store is modified. [Official download/checks](https://www.system-rescue.org/Download/).

## Writing the USB is a separate later action

No USB device has been selected, formatted or written. The previous8GB stick may contain original research returns. Its contents must be inventoried and independently preserved before a writer is used. Existing evidence must not be sacrificed to create this test media.

SystemRescue's [Windows instructions](https://www.system-rescue.org/Installing-SystemRescue-on-a-USB-memory-stick/) use Rufus **ISO mode with FAT32**, retaining the ISO's label. That creates a writable filesystem onto which the overlay can be copied. A raw/DD write creates a read-only ISO filesystem and will not work with this collector's output guard. The kit deliberately rejects Ventoy/device-mapper and internal-disk destinations rather than guessing how to save results.

After the exact USB and its contents have been reviewed, the later preparation is:

1. Write the verified stock ISO to that USB using the official method. This erases the selected USB.
2. Copy the **contents** of `USB-OVERLAY` to its root. Keep the directory layout. Do not place the whole overlay folder inside another folder.
3. Verify the copied payload hashes. The collector checks them again before asking for a connection.

The resulting root contains `USB4-CAPTURE-MEDIA.txt`, `usb4/`, `sysrescue.d/`, and the stock SystemRescue files. It needs at least128MiB free. Do not change BIOS settings or Secure Boot to make a failed boot proceed; retain the exact error for review. The existing remote Windows session is not to be restarted for this preparation.

## The single observation

When local access is available, use the boot USB in a USB-A port and keep barrel power. DEG2 stays powered and uses the same tested ASUS USB4 port/cable. Keep unrelated USB-C attachments out of this comparison. Boot the stock SystemRescue entry; there is no Linux installation step. Its console should start the collector automatically.

The collector starts logging before the connection prompt. With DEG2 disconnected, press Enter when ready, then connect only at **GREEN**. It records a45-second observation and ends automatically. If a dock/router was already connected at startup, it instead offers an observation of that existing connection and marks the lack of a fresh attachment. An already-connected state does not silently become a fresh-attachment test.

Results are saved under `USB4-RESULTS/<run>` on the boot USB. The program independently checks the USB transport, FAT filesystem, marker, exact script location and payload hashes. It remounts only that already-mounted boot USB if needed, then restores its original read-only mount state. It never mounts an internal Windows volume. Files remain private; kernel logs may contain identifiers and pointers.

The script has no automatic reboot. Leave the finished result available for review. A normal return to Windows can be planned with the owner present; remote reconnection is not assumed.

## How the result is interpreted

| Result | Meaning |
| --- | --- |
| ExternalRouterPresentAuthorizationPending | A USB4 router appeared. Linux has not authorized its PCIe access; missing GPU enumeration is not an entry failure |
| ExternalRouterPresentRequiresTopologyReview | A router is visible; identify its route/device and PCIe endpoints before attributing it to DEG2 |
| ExternalRouterObservedThenAbsent | The sampled history includes a router that is absent finally. Preserve the earlier transition |
| DEG2FallbackObservedNoExternalRouter | The dock's USB signature appeared without an external router in the observations. The omitted/rejected-entry/training distinction remains unresolved |
| AttachmentNotEstablished | The intended changed condition was not observed. It is not a valid USB4 failure comparison |
| StoppedRequiresReview | Preparation/runtime prerequisite failed. Original and partial results remain available |

The internal NVIDIA GPU is excluded from the new-endpoint list by the disconnected baseline. Newly appearing display endpoints still need topology review; the program does not declare them the external RTX4080SUPER automatically. Missing sysfs attributes stay unknown. A Type-C identity directory is collected only if the driver exposes it.

There are no authorization, role/mode, retimer scan, raw register, firmware update or security-setting writes. Only capture files and temporary logging controls are changed. The collector uses a private trace instance, requests a monotonic trace clock when available, records trace statistics, stops its own logger processes and removes its own trace instance. Each file is limited to32MiB. Trace availability, logger exits and errors are retained. The45seconds describe the observation window, not a guaranteed total runtime for every kernel operation.

## Limits

A successful Linux connection would prove this pairing can work in that session. It would point toward an OS/firmware interaction; changed boot/power history remains a confound. Failure would not prove a hardware defect. An external router alone does not distinguish native USB4 from Thunderbolt3-compatible mode; retain the generation, Type-C mode and link fields for review. USB4 control-channel traces and driver-exposed discovery data do not automatically provide a raw CC/PD transcript or applied PS8830 state.

This first kit does not bundle tbtools or change router registers. It needs no runtime package download. Further reads or a narrowly identified authorization operation can be considered from the returned evidence. No such operation is silently added to this observation.

The original firmware-consumer and Windows diagnostic-interface investigation remains open. Preparing this comparison is not a working Windows repair.
