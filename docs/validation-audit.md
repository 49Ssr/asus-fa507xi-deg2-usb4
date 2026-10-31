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

## Deeper negotiation collector, 31 October

The owner explicitly requested this investigation after retiring earlier experiments. The active source is now one collector and an import-only shared library. The standalone memory probe and earlier reset scripts remain archived. [Procedure and instrumentation](handoff.md#n5-existing-hardware-partner-handoff-proposed).

| Check | Observed result | What it validates |
| --- | --- | --- |
| Windows PowerShell 5.1 parsing and actual Preview | Passed | Script compatibility and non-mutating default, not hardware capture |
| Preparation/undo guards, in memory | Seven cases passed: absent/zero/nonzero originals, backup failure, intervening change, interrupted undo | Saved-state handling and refusal paths without registry/device mutation |
| Current capture/phase workflow, in memory | Sixteen cases passed: fresh peer negotiation ordering, Compare/Direct/PeerHandoff, new-device preservation, peer loss at three stages, trace/phase failures, missing ETL, file cap, network snapshots and passive/IFR/query inventory order | Owned-session cleanup and intended control flow; no actual ETW/hardware result |
| Native tool and hashes/signatures | Actual prepared files checked; native help enumeration correctly rejected the currently absent test interface | Provenance and error handling; no firmware command reached the device |
| State-file replacement under PS5.1 | Actual create/replace passed; a locked-target replacement failed while retaining the original JSON | Atomic state-file implementation. An initial `$null` argument became an empty string in PS5.1; corrected to `[NullString]::Value` before release. |
| Recorder commands against the existing dump | Actual KD replay reached both markers, listed all 12 available buffers and reproduced 74 UCSI record references | Decoder commands work for the old snapshot; no live helper was loaded by this replay |
| Added WPP inputs | Five current-image PDB identities verified; TracePdb completed for USBXHCI, UCX, USBHUB3, SPB and PCI | Matching inputs prepared; private USBHUB3 WPP formats may still be unavailable |
| New Administrator preparation / deep hardware capture | Unperformed | No interface enablement, firmware response, negotiation cause or repair established yet |

The native readiness check enumerates interfaces and requests help; it does not send GET_CAPABILITY before passive recording. Firmware GET batches run only after each passive observation and recorder snapshot, with a second device inventory afterward. ETW covers a fresh peer negotiation as well as DEG2 attachment. Requested provider coverage, actual emitted records, formatting errors, loss and timing must be assessed from the new run.
