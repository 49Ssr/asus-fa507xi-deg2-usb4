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

## Read-only inspection completed

The owner mounted the existing VHD read-only, printed the real Storage properties, and detached it in finally. It reported `File Backed Virtual`, size 68719476736, partition style RAW, IsReadOnly true, IsBoot false and IsSystem false. The temporary disk number was only an observation; setup must resolve it again from the exact VHDX association rather than reuse it.

This validates the specific representation that caused the failure and confirms that initialization had not occurred. It does not validate the later offline deployment or boot lifecycle.

## Next stage

After updating the local checkout, ArchiveFailed preserves this exact failed attempt. A fresh Prepare run is the next real integration test. AddBoot remains a separate subsequent step after inspecting preparation results. Keep the first test boot offline: the ASUS System Control Interface bundle includes broader OEM services and update tooling, so an Internet-connected first boot would add an uncontrolled variable.

Do not enable test-signing, alter Secure Boot, flash firmware, or rerun the old uncorrected preparation command to work around a guard. Corrections and mocked tests must remain labelled separately from real hardware results.
