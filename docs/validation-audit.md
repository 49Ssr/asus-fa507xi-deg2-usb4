# Native-boot toolkit validation audit

**Current state, 31 October 2026:** the initial failure was preserved and corrected. Image preparation, driver staging, native boot and one hardware capture subsequently completed. The eGPU failure persisted. Boot-entry removal has not been exercised. [Hardware result](fresh-windows.md).

## Initial real failure

The first Prepare selected the x64 Professional image at index 6, version 10.0.26200.8037. Source-media, space/encryption and driver-bundle checks completed. DiskPart created a new VHDX with 64 GiB virtual capacity and a 4 MiB container file.

The first `Assert-VirtualDiskTarget` call failed while casting BusType to an integer. It stopped **before `Initialize-Disk`**, image application, driver injection or boot-entry creation. The finally block detached the image. Saved phase was `Creating`, with the conversion error.

## Why the tests missed it

The tests constructed a disk-shaped object with numeric BusType 15. The Windows Storage module instead exposes BusType through a script property: underlying CIM value 15 becomes `File Backed Virtual`; 17 becomes `NVMe`, and 7 becomes `USB`. Read-only inspection of the installed `Storage.types.ps1xml` established that contract. Presenting the toolkit as ready based on the numeric mocks was an error.

The owner mounted the existing VHD read-only and observed `File Backed Virtual`, 68719476736 bytes, RAW, IsReadOnly true, IsBoot false and IsSystem false. It was detached in finally. This confirmed the representation and that initialization had not occurred; it did not validate later deployment steps.

## Correction and observed execution

The guard accepts the exact file-backed virtual representations while retaining image-to-disk association, capacity, boot/system and RAW-state checks. Association is resolved again before each partition/format operation. The ArchiveFailed mode preserves only the verified small detached creation failure under a unique local directory; other failures are rejected.

| Stage | Observed result |
| --- | --- |
| Parser, disk guards and boot command plan | 51 non-mutating checks passed after correction; mocked checks do not validate real execution |
| Archive original failed attempt | Completed; failed container retained |
| Apply full Windows image and seven scoped System packages | Completed; state reached ImagePrepared without a recorded error |
| Add separate BCD loader | Completed; state reached BootEntryCreated |
| Native boot / Audit Mode | Owner reached the test desktop |
| Recorder / shared result transfer | Completed; results read from original Windows afterward |
| Essential USB4 path preflight | Passed; measured devices Started with problem code zero |
| External router / external GPU | Neither enumerated |
| Remove test boot entry | Unperformed |

## Baseline and operating limits

Prepare and AddBoot are separate modes. The setup preserves the original Windows default, boot files and UEFI order; no automatic reboot is issued. Incomplete files and raw results remain private for inspection.

The ASUS System Control Interface package contains broader OEM services, software management and update-related binaries. System class alone does not mean a package contains no update tooling. The first test boot was instructed to stay offline to limit uncontrolled changes; no firmware update is established by installing this package.

The fresh environment was a scoped baseline, not a factory image. Nine other PnP problem entries remained, and older WPP formats were partly unavailable. Those limits belong to the negative hardware result even though the required host/root/UCSI/I2C/Parade checks passed. See the [full result](fresh-windows.md).

Successful execution on this host does not establish universal toolkit safety or compatibility. Do not enable test-signing, alter Secure Boot or flash foreign firmware to work around a guard or an unresolved negotiation problem.
