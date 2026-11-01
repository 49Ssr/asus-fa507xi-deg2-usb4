# Portable matched capture: Dell first

**Acquisition update, 1 November:** both the [Dell recovery](dell-dump-recovery.md) and [fresh local ASUS comparison](asus-dell-matched-comparison.md) are now analysed. The portable Dell instructions and historical qualification below are retained; do not repeat them as the next action. The ASUS owner run used native Full dump creation and a valid pasted path; automatic/Browse selection remains separately software-tested.

**Current status, 1 November:** the second Dell trace and separate dump have been [recovered and analysed](dell-dump-recovery.md). No repeat Dell run is needed for the failed handoff. The revised source kit fixes the late freshness cutoff and provides automatic/Browse selection, retry, pending status and FINISH-DUMP.cmd for a new saved run. **183 PS5.1 assertions pass**; its new UI/hardware workflow has not been exercised on Dell. The V2 inventory correction below is retained as history.

**V2 inventory correction, historical.** The first Dell launch stopped during inventory before recording; its return transfer succeeded. The later Dell acquisition is recovered and the fresh matched ASUS acquisition has subsequently completed, as linked above. This implements the next acquisition in the [reverse-engineering approach](reverse-engineering-approach.md). It adds the full native kernel snapshot and ACPI/policy context missing from the previous Dell recorder; it is not another role-change experiment or a firmware patch.

## First Dell attempt and correction

The 00:05-00:06 UTC run returned four hash-verified files. Status reports `NotCompleted`, no trace, no dump and no connection marker. The missing `Data` member error occurs in the initial inventory path before static inputs or ETW. The transfer itself is complete; this is a collector defect, not a new negotiation failure. [Sanitized result](../evidence/deep-compare-first-run.json).

The old qualification mocked inventory/static-input acquisition and missed the native response shape. A read-only repro on ASUS inspected 53 scoped devices and found 25 `Win32_PnPDeviceProperty` replies lacking Data. V2 records missing/null/error metadata explicitly, preserving valid zero and array values. Critical UCSI and GPU bindings remain required. It also resolves installed driver images through validated service paths and records phase plus error position/stack.

**166 PS5.1 assertions pass**, including the original regression and actual unmocked scoped inventory/static-input collection with all 14 copied driver hashes verified. No new ETW session, kernel dump, UCSI command or setting change was performed in qualification. The original USB bundle/RETURNED set and a verified private import are preserved. Use the separate v2 source kit; the original 137 checks remain historical qualification, not proof that the first Dell run succeeded.

## Owner procedure

The current revised source is built into a new directory; do not overwrite an existing kit or its results. Historical V2 files were recovered from the returned USB. The resume launcher is for a saved run created with the revised kit on the same laptop. Existing captures need no repeat or migration.

1. On the Dell Latitude 5540, keep normal barrel power, DEG2/PSU powered and the GPU-connected display attached. Plug the USB stick directly into the laptop and leave it there.
2. Right-click **START-DELL.cmd** in the new folder and select **Run as administrator**. The source/hash/model checks run before collection, then the kit stages verified source files onto internal NTFS storage.
3. Follow the disconnection prompt. Connect DEG2 at **GREEN**, using the same known-working Dell port. Leave it attached through the snapshot step.
4. After the nominal 45-second passive sleep and endpoint inventory, the script stops its trace and opens Administrator Task Manager. In **Details**, right-click **System (PID 4)**, select **Create live kernel memory dump file**, then **Full live kernel memory dump**. Wait for completion, return to the capture window and press Enter to find the completed file automatically, or B to browse. Invalid input can be retried; P/cancel leaves the dump pending. FINISH-DUMP.cmd resumes that saved run on the same laptop without another connection trace. Actual ETW duration includes workflow overhead and must be measured offline. [Microsoft's procedure](https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/task-manager-live-dump).
5. Answer the display-output question. Wait for compression and **RETURN COPY VERIFIED**. The capture result must also say `Captured_RequiresOfflinePolicyAndMemoryValidation`; a successful copy alone does not mean acquisition succeeded. Return the USB to ASUS and keep the Dell originals until import is confirmed.

Full [bundle instructions](../tools/deep-compare/README.txt) include **RETURN.cmd** for packaging the same saved run again and **STOP-TRACE.cmd** for its owned trace after an interruption. Both are machine-bound and run with the same Windows account on the laptop that recorded that run. START-ASUS.cmd is for the later corresponding FA507XI normal-fallback capture, not the current Dell step.

## Data and boundaries

| Collection | Purpose and limit |
| --- | --- |
| Passive ETW | Existing 27-provider profile, five-second disconnected baseline and 45-second attachment window, 1 GiB sequential cap. Actual insertion must be inferred from events; loss/unknown formats are assessed offline. Trace stops before interactive dump creation. |
| Native full kernel dump | Task Manager creates it; no LiveKD/helper is bundled or loaded. Header, x64 architecture, live-dump code, freshness and endpoint stability are checked. Missing pages and the presence of required UCSI policy objects still need offline validation. An observed endpoint change retains the snapshot with failed qualification. |
| ACPI | DSDT, first SSDT and FACP: exact length, signature, checksum and SHA-256. DSDT has a direct lookup fallback because it may be omitted from root enumeration. Duplicate SSDT instances remain unavailable through this API; kernel namespace inspection must supplement them. Activation/license tables are excluded. [Windows API limits](https://learn.microsoft.com/en-us/windows/win32/api/sysinfoapi/nf-sysinfoapi-getsystemfirmwaretable). |
| Driver/system/connector context | Fourteen installed Windows file copies, hashes/versions, firmware/USB4/UCSI/PnP properties, current BIOS and diagnostic-interface state. Installed files are not proof of loaded identity; the dump supplies that comparison. |
| Networking | Adapter/IP/DHCP/DNS/default-route/ICS snapshots before and after. No network configuration is changed. |
| Transport | Original dump stays on laptop. Compression streams on SSD; <=1 GiB USB parts are SHA-256 read-back checked. A complete manifest records source lengths/hashes and whether a dump is included. |

The kit sends no UCSI commands and makes no registry, device/driver, firmware, boot-security or network setting changes. It does not automatically reboot, enable the old test interface, execute AML, read controller flash or prove physical CC/PD packet coverage. The two model-specific entry points share the same acquisition workflow and refuse the wrong manufacturer/model/host controller.

## Storage and interruption handling

Capture is staged under the running account's **LocalAppData/USB4-Deep-Compare** directory, inside its profile. Preflight requires internal NTFS storage with physical-RAM size plus 4 GiB available; packaging separately checks actual source size and compressed capacity. Each run/package directory is new. Existing USB contents and prior captures are retained.

FAT32 is supported without formatting. If the compressed set will not fit, no result parts are copied and the script reports the needed space. SSD originals and compressed data remain available. Partial transfers lack a completed RETURN-MANIFEST and must not be treated as complete. Returning again creates a new attempt; it never deletes an earlier partial copy or silently drops the dump.

## Original validation before the first USB preparation

- **137 Windows PowerShell 5.1 assertions**: host/model and path refusal; real Windows ACPI API export; malformed tables; actual retained dump header and stale/wrong-header rejection; retained successful Dell GPU/router inventory; passive lifecycle/failure cleanup; source integrity and staging; compression, splitting and independent reconstruction; empty files; actual return copy, dump metadata revalidation, missing-space and mismatched-machine refusal. Hardware attachment, ETW and new snapshot creation are mocked.
- The exact compressor streamed the existing **2,300,018,688-byte ASUS dump**, beyond the 2 GiB boundary. An independent Python gzip reader reproduced its complete original SHA-256. The compressed file was 327,916,226 bytes. This uses an old artifact and is not a new hardware measurement.
- The final portable kit's eight source files and manifest were checked under actual PS5.1; its native helper compiled and Preview passed. The Windows Task Manager executable's Microsoft signature was verified. The nine-file USB copy was SHA-256 checked after writing; existing root entries remained present. No third-party executables/PDBs or private captures are included in the prepared source kit.

Qualification caught and corrected the omitted-DSDT enumeration case, .NET Framework's empty-input gzip behavior and a PS5.1 hashtable aggregation issue before transfer. These are software qualification findings, not Dell hardware results. Tests do not certify behavior on a Dell that has not yet run this kit.

Source: [collector](../tools/Capture-USB4DeepCompare.ps1), [native table/archive helper](../tools/deep-compare/DeepCapture.Native.cs), [builder](../tools/Build-USB4DeepBundle.ps1), [tests](../tests/Test-DeepCompare.ps1). Runtime imports the exercised shared trace primitives; the earlier ASUS/Dell firmware-command workflows are not invoked. Default collector/builder modes are Preview.
