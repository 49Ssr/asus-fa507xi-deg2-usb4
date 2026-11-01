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
| Native tool and hashes/signatures | Prepared files checked; native help enumeration correctly rejected the absent interface before preparation | Provenance and preflight error handling |
| State-file replacement under PS5.1 | Actual create/replace passed; a locked-target replacement failed while retaining the original JSON | Atomic state-file implementation. An initial `$null` argument became an empty string in PS5.1; corrected to `[NullString]::Value` before release. |
| Recorder commands against the existing dump | Actual KD replay reached both markers, listed all 12 available buffers and reproduced 74 UCSI record references | Decoder commands work for the old snapshot; no live helper was loaded by this replay |
| Added WPP inputs | Five current-image PDB identities verified; TracePdb completed for USBXHCI, UCX, USBHUB3, SPB and PCI | Matching inputs prepared; private USBHUB3 WPP formats may still be unavailable |
| New Administrator preparation / deep hardware capture | Completed: Ready state, three recorder transcripts, 84 completed GETs; 3,097,071 ETW events with zero reported loss | Diagnostic execution validated on ASUS. Peer works; DEG2 router/GPU remain absent. No cause or repair established. |

The native readiness check enumerates interfaces and requests help; it does not send GET_CAPABILITY before passive recording. Firmware GET batches run only after each passive observation and recorder snapshot, with a second device inventory afterward. ETW covers a fresh peer negotiation as well as DEG2 attachment. Requested provider coverage, actual emitted records, formatting errors, loss and timing must be assessed from the new run.

## Deep passive collector inventory failure, 1 November

The first deep Dell attempt returned NotCompleted during the initial inventory with a missing Data-member error. No connection marker, ETW session or dump was collected. Four returned files verify at part, gzip and raw SHA-256 levels; a private import preserves them without modifying the USB originals.

The original 137-case qualification mocked Save-DeepInventory and Save-DeepInputs. It checked the retained Dell inventory's milestone interpretation but did not exercise current native PnP replies. That gap allowed a normal Win32_PnPDeviceProperty reply without Data to stop StrictMode execution. A read-only ASUS repro found 25 such replies among 53 scoped devices.

V2 tests missing/null/array/zero/malformed and unrequested property replies; unavailable optional data stays unknown, and absent critical binding cannot qualify a working GPU. Actual inventory and static-input collection now run without mocks before lifecycle doubles are installed. All 14 copied driver hashes verify. Two real driver images resolve through service ImagePath in DriverStore, avoiding the incorrect fixed-System32-path assumption. Missing diagnostic parameter keys are recorded absent rather than enabled. Phase/error position/stack improve future failure provenance. The complete PS5.1 suite passes 166 assertions; the revised portable bundle's hashes, compilation and Preview are also checked.

No revised Dell capture, policy extraction or firmware repair is claimed from these software checks. The corrected kit is a separate v2 USB folder; the original failed run and earlier investigation remain intact.

## Native dump handoff recovery, 1 November

The V2 Dell trace/static collection succeeded, but dump selection failed. The original NotCompleted status and manifest without a dump are retained. All 33 returned files and the separately copied 2,248,310,784-byte USB-root dump hash-verify; offline KD opens the snapshot and supplies the external router, PCIe/USB3 tunnels, cached UCSI policy and loaded ACPI branches. This is actual artifact validation, separate from software mocks. The dump lacks the firmware page containing XDCE/UDRS; SMBIOS and some USB4KD helper queries fail explicitly. [Full evidence and interpretation](dell-dump-recovery.md).

V2 displayed creation instructions before recording the freshness cutoff after a further Enter prompt. The valid dump predates that late cutoff. The entered path was not retained, so the owner's suspected path error is not established as the sole cause. The revised cutoff derives from the saved endpoint inventory before the instructions. Automatic/Browse/file/folder selection, retry/cancel/pending and same-run FINISH-DUMP completion avoid repeating the attachment trace. All 183 PS5.1 assertions pass, including native read-only inputs and new mocked selector/resume cases. Actual Task Manager/Browse interaction and new hardware capture remain untested for this revision. Historical >2 GiB compression qualification is not a new Dell UI test. USB contents, network/ICS, firmware and device settings were not changed during recovery/qualification.

## Measured local ASUS acquisition, 1 November

The owner completed the revised local entry point, native Full Task Manager snapshot and valid pasted-path selection. Capture result is Captured_RequiresOfflinePolicyAndMemoryValidation, with no capture/evidence errors; before/after-dump fallback qualifies and output answer is N. All 35 files and the separate 3,172,020,224-byte dump were privately copied with source/read-back SHA-256 and stable source metadata; originals retained. Offline exact-symbol inspection recovers current OPM and PPM configuration 0, loaded ACPI support mask, USB4 topology and tunnel policy. The 71.037-second ETL decodes 1,114,490 events, no reported loss/format errors, 342 unknowns. Ten normal Windows commands and ten ACKs match all completions; the collector injected none. All 14 copied image hashes match Dell. [Measured comparison](asus-dell-matched-comparison.md).

This validates this actual acquisition and manual valid-path handoff, not every pending/Browse UI branch or firmware coverage. The earlier 183 collector/28 local-wrapper checks retain their separate scope. Windows protects reading the original full dump: a read-only administrator copy was required; no ACL was changed. Initial trace postprocessing was retried after creating its output directory; tracefmt's zero exit code alone did not prove output creation. Both attempts are retained privately, and the final log/summary confirms decoding. Client Fdo type queries and USB4KD relation helpers have explicit limits; typed PPM state and topology supply the reported values. No live firmware/helper operation, unavailable-memory retry or setting write occurred.

## Role-policy prototype qualification and pre-load correction, 1 November

The final unsigned x64 KMDF 1.15 source builds using MSVC 14.44.35207 / SDK 26100 / official NuGet WDK 10.0.26100.6584. INF verification and catalog generation pass; this does not confer a Windows-accepted signature. Native shared-parser tests pass 4,631 assertions. The PS5.1 runner passes 57 checks including actual Preview, real unsigned-catalog refusal before writes, atomic state files, startup proof, exact package identity, interrupted install, 3010 handling, one-shot router/GPU capture, no-trace recovery and scoped rollback. Device/ETW/install/restart/signing-success/network paths use doubles; there is no loaded-driver, VM, hardware rollback or Driver Verifier result.

The first fixture/parser incorrectly interpreted ACPI Size as total request length. Static inspection of the actual installed image and Microsoft's sample established Size=44 argument bytes within a 60-byte request. The corrected parser accepts that contract and rejects the old field value; no earlier build was installed. A workflow-test failure also came from choosing a mock run by lexical GUID ordering, corrected to identify the newly created run. Earlier results are retained privately. [Full design and limits](role-policy-experiment.md), [structured evidence](../evidence/role-policy-experiment.json).

The owner reported substantial Windows input/application delays during preparation and later reported improvement. Read-only checks showed Microsoft's original UCSI binding, no experimental service/filter, no remaining debugger/build process and no active logman session. The cause is unresolved. No prototype policy or driver was active during that report; this does not establish that all analysis workloads were causally irrelevant.

## Signing and complete-filter review, 1 November

The parser-only qualification did not cover the entire driver. The review corrected filter identification before excluded-device return, bounded registry type checking/NOEXPAND, and an internal-versus-external callback function-class warning found by real kernel static analysis. Two thin annotated callbacks now use one dispatcher. A native harness executes actual Driver.c callbacks with DDI doubles: 36 assertions pass. Core parser remains 4,631 assertions. Kernel analysis has two runs and zero project results after excluding external SDK/WDK bodies; the earlier header-only allocator warnings and malformed analysis-log option are retained privately.

Real CLI/file tests also caught and fixed RunDirectory being overwritten by a dot-sourced parameter block and a trace-helper parameter shadowing the capture directory. The workflow now passes 64 PS5.1 checks including real private baseline files/hash validation. Signing/boot checks pass 41 cases: actual embedded/catalog signature mathematics, digest membership, corrupt executable/signature rejection, signing-key cleanup, production refusal and CLI binding; boot/trust mutation and reboot context use doubles. The first corruption fixture changed WIN_CERTIFICATE padding rather than encoded signature bytes and was corrected before claiming rejection.

A seven-day non-exportable test key signed a private copy's SYS; CAT was regenerated afterward and signed. Both signature mathematics and SYS/INF catalog membership verify. The temporary key/certificate was removed from CurrentUser/My. No Root/TrustedPublisher import, BCD modification, security toggle or kernel load occurred. A local-test boot route with exact ownership/rollback and same-boot control is prepared, pending explicit owner approval and firmware/reboot actions. [Design and limits](driver-readiness-review.md).


## Actual baseline decoder mismatch and correction, 1 November

**Baseline gate corrected, 1 November:** the first real stock-policy baseline stopped before attachment. Its startup ETL has 27,800 events, zero loss, zero format errors and zero unknowns. It records `UsbDeviceControllerEnabled:0x00000000(false)` and class configuration 0. The checker incorrectly required the simplified string `UsbDeviceControllerEnabled:false`; earlier synthetic fixtures reproduced that simplification. This was a tool false rejection, not firmware rejection or a failed filter load. No experimental driver was installed and no baseline attachment occurred.

The parser now recognizes the exact TMF boolean representation, rejects mixed/unknown/inconsistent values and still requires the exact forced-policy message for the override. The retained real ETL is successfully decoded and validated by the corrected function. PS5.1 workflow qualification is now 79 checks, including the real retained trace and guarded resume cases; device/ETW mutation remains doubled in software tests. `ResumeBaseline` permits only the exact fresh same-boot, machine/target/package-bound, pre-attachment record; it revalidates the saved startup and sharing, then captures the one attachment without repeating the UCSI restart. A completed or already-attempted attachment cannot resume. The owner-specific helper also now returns its saved baseline path as data, keeping its display label on the host stream. The signed SYS/INF/CAT have not changed. Actual resumed attachment remains pending; an interactive continuation window is open.

