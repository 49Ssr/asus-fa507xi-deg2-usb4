# Linux connection capture

This test asks whether ASUS can discover DEG2's external USB4/Thunderbolt router under Linux. It records PCIe devices too, while keeping pending authorization separate from a failed connection. It does not install Linux or apply a fix.

**Tested on ASUS, 2 November 2026:** the kit booted and saved a fresh attachment to the USB. It observed ordinary USB fallback with no external router or new PCIe device. [Result and limits](linux-asus-result.md). A matching Dell Linux capture remains uncollected. The original SystemRescue 13.02 image has a verified checksum and signature.

## Before preparing the USB

The private `local/LinuxCaptureBundle` folder contains the ISO, `USB-OVERLAY` and this guide as `START-HERE.md`. The owner's prepared stick has completed one ASUS capture. The steps below describe how to prepare equivalent media; preserve existing results before rewriting it.

The earlier 8 GB stick may still contain research returns. Identify that exact drive and preserve its files independently before using a writer. Do not erase evidence to prepare this test. The Windows session must remain running while the owner is remote.

## Prepare the test USB when local access is available

1. Use the verified stock `systemrescue-13.02-amd64.iso` with Rufus, following [SystemRescue's Windows instructions](https://www.system-rescue.org/Installing-SystemRescue-on-a-USB-memory-stick/). Select **FAT32** and **ISO mode**, retaining the image's volume label. Writing the selected USB erases it.
2. Copy the **contents** of `USB-OVERLAY` into the USB's root. Do not put the overlay folder itself inside another folder.
3. Verify the copied payload hashes. The collector checks them again before asking for a connection. Keep at least 128 MiB free.

The root should contain the normal SystemRescue files plus:

```text
USB4-CAPTURE-MEDIA.txt
usb4/
  capture_usb4.py
  start-capture.sh
  payload-manifest.json
sysrescue.d/
  900-usb4-capture.yaml
```

Raw/DD mode produces a read-only ISO filesystem and is rejected by this collector. Ventoy/device-mapper and internal-disk destinations are also rejected. If boot fails, keep the exact error for review; do not change BIOS settings or Secure Boot to work around it.

## Run one observation

1. Save work and close Windows normally. Keep barrel power. Use the boot USB in a USB-A port. Keep unrelated USB-C devices out of this comparison.
2. Leave DEG2 powered **ON**. Use the same tested ASUS USB4 port and cable. Start with DEG2 disconnected if possible.
3. Boot the USB through the one-time boot menu. Choose **Boot SystemRescue using default options**. The collector should open on the console automatically.
4. Press Enter at its prompt. At **GREEN**, connect DEG2 and leave it connected. The recording window is 45 seconds.

If DEG2 is already connected, or appears before the connect prompt, the collector keeps the connection unchanged and labels the timing. It does not discard the run or ask for a reconnect. If Linux exposes no host router, it saves that failure before asking you to attach anything.

There is no dump-path entry or manual export step. Results go automatically into **`USB4-RESULTS/<run>` on the boot USB**. The program does not reboot the laptop. Leave its final message available for review; return to Windows with the owner present.

## What the result means

| Message | Interpretation |
| --- | --- |
| External router detected; PCIe access awaiting authorization | Router detection worked. A missing GPU is not yet an entry failure |
| External router detected; identity/devices saved | Review the recorded identity, route and PCIe devices before attributing success to DEG2 |
| Router appeared and disappeared | The earlier success is preserved even though the final state is absent |
| Dock USB functions appeared; no external router observed | Fallback was seen. Entry rejection, routing and training are still not separated |
| Intended attachment was not observed | The comparison did not establish the intended condition |
| Recording stopped | Keep the error and any partial results. Do not repeat blindly |

The internal GPU is not counted as a newly appearing external GPU. A router alone also does not distinguish native USB4 from Thunderbolt 3-compatible mode. The saved fields support that review where the driver exposes them.

## What changes during the test

The collector writes its evidence to the verified boot USB and uses a temporary, separate Linux trace instance. It restores the boot USB's original mount state and stops its own loggers. It does not mount an internal Windows volume or send authorization, role/mode, retimer-scan, firmware or reboot commands.

Kernel logs may contain identifiers and memory addresses. Keep the returned folder private; publish only reviewed excerpts.

Linux success would establish that the pairing can work in that session and narrow the OS/firmware interaction. Different boot/power history remains a confound. Linux failure would not prove a hardware defect. The kit does not promise a raw PD-wire transcript or applied PS8830 state.

[Collector design and validation](linux-capture-internals.md) · [Current findings](status.md) · [Tool guide](../tools/README.md)
