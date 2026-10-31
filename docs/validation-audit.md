# Validation audit, 31 October 2026

## Actual outcome

The first real Prepare run selected the x64 Professional image at index 6, version 10.0.26200.8037. Source-media checks, available-space/encryption checks and driver-bundle validation completed. DiskPart created a new VHDX with 64 GiB virtual capacity and a 4 MiB container file.

The first `Assert-VirtualDiskTarget` call then failed while casting its BusType to an integer. It stopped **before** the first `Initialize-Disk` call. The script's finally block detached the image. Saved state is phase `Creating`, with that conversion error. The directory contains only the state, creation script/log and VHDX; image application, driver injection and boot entry creation were not reached.

## Why the initial tests were insufficient

The guard tests constructed a disk-shaped object with numeric BusType 15. They did not reproduce the Storage module's real PowerShell-facing property contract. Passing those tests was evidence about the constructed objects, not real disk preparation. Presenting the toolkit as ready on that basis was an error.

Read-only inspection of the installed Windows Storage module now establishes that `Storage.types.ps1xml` defines BusType as a script property: its underlying CIM value 15 becomes the string `File Backed Virtual`; 17 becomes `NVMe`, and 7 becomes `USB`. PartitionStyle similarly becomes `RAW`, `MBR` or `GPT`. This independently explains the observed failure. A draft correction accepts only the exact file-backed virtual representations and retains the image association, disk number, capacity, boot/system and raw-state checks.

## Further review findings

- The preparation and AddBoot paths are separate. Prepare cannot reach the BCD-writing branch when invoked in Prepare mode.
- No cleanup should delete or overwrite the failed image. A draft recovery mode preserves the exact small detached creation failure under an archived local directory; it is not yet a user instruction to resume.
- The full offline image application, driver injection, first boot and boot-menu lifecycle have not been validated end to end on this machine.
- The ASUS System Control Interface package is broader than a USB controller driver: its INF includes OEM services, a software manager and update-related binaries. Inclusion of a System-class package alone does not prove absence of update tooling. No package from this preparation attempt was installed or executed. Its role and an offline-first test baseline require review before resuming.
- A meaningful negative fresh-Windows result also needs a healthy USB4 root router, in addition to the host, UCSI, I2C and Parade peripherals. A draft collector change adds that explicit prerequisite.

## Current instruction

Preparation remains paused. Do not run AddBoot, enable test-signing, alter Secure Boot, flash firmware, or repeatedly rerun the old preparation command to work around the guard. The known failed state and original capture evidence are preserved. Corrections and mocked tests must be labelled separately from real hardware results.
