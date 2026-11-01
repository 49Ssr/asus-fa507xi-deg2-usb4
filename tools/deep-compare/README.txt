USB4 DEEP COMPARISON V2 — DELL FIRST

Use the new USB4-Deep-Compare-v2 folder. The original USB4-Deep-Compare and its RETURNED folder are preserved. Its first run stopped during inventory before any trace or dump; v2 fixes Windows property replies without a Data field. The older USB4-Dell-Control folder is a different, completed experiment.

1. On the Dell Latitude 5540, connect its normal charger. Keep the same assembled DEG2/GPU/PSU powered, with the external display connected to the RTX 4080 SUPER.
2. Right-click START-DELL.cmd -> Run as administrator. Leave the USB stick plugged directly into the Dell throughout.
3. The script checks the laptop, USB4/UCSI devices and bundle hashes, then copies its verified files to internal NTFS storage. No installation is required. It needs approximately the laptop's RAM size plus 4 GiB of free SSD space for capture; packaging later checks actual space separately.
4. Disconnect DEG2 when prompted. Preparation saves driver identities, selected ACPI tables and network state. At GREEN, connect DEG2 to the same Dell USB4/TB port previously tested. Leave it connected for the 45-second observation and the snapshot step.
5. After the passive trace stops, create the requested full kernel snapshot manually:
   Close any existing Task Manager when asked, then press Enter; the script opens Administrator Task Manager. Go to Details -> right-click System (PID 4) -> Create live kernel memory dump file -> Full live kernel memory dump.
   Choose FULL. Do not select Kernel stacks or a normal process dump. Leave the optional user/hypervisor page additions off. Wait for the success dialog, choose Open File Location, then Copy as path on the completed .dmp file.
6. Paste that path into the capture window. Quoted Copy-as-path text is accepted. The script checks the dump header and freshness, then checks that the working DEG2 router/GPU is still present. Answer the display-output question.
7. Packaging runs on the SSD and may take several minutes. It compresses the trace, firmware tables, driver images and full dump. Return files are split into parts no larger than 1 GiB and read-back SHA-256 checked on the USB. The original dump and local evidence remain on the Dell.
8. Wait for Capture: Captured_RequiresOfflinePolicyAndMemoryValidation and RETURN COPY VERIFIED. Safely eject the USB and return it to the ASUS. Keep the Dell originals until we confirm import. Do not upload raw results to GitHub.

If capture stops or packaging fails:
- Preserve the displayed error. A verified copy can still contain a failed capture; its manifest records the actual result and whether a full dump is included.
- RETURN.cmd, Run as administrator with the SAME Windows account on the SAME laptop, can retry packaging the latest saved run without another attachment test.
- STOP-TRACE.cmd, Run as administrator on that laptop, stops only the trace named in that run's machine-bound ownership record after an interruption. No generic trace sessions are stopped.
- If the compressed set exceeds available USB space, the script leaves it on the SSD and reports the required size. It does not format the USB, delete anything, discard the dump or silently omit large files.

The local folder is the running account's LocalAppData\USB4-Deep-Compare, inside that account's profile. Run records preserve the exact paths. Use the same Administrator account for capture and return. The USB gains only this bundle's latest-run record and RETURNED subfolder; existing unrelated files remain intact.

START-ASUS.cmd is reserved for the later matching ASUS FA507XI capture in its normal attached USB/Billboard failure state. Do not run it instead of the Dell launcher now. Both launchers use the same passive workflow and scope themselves to the known models.

What is new:
- Full native kernel dump for offline extraction of UCSI policy, USB4/UCM objects and loaded ACPI namespace. No LiveKD driver/helper is used.
- ACPI DSDT, first SSDT and FACP exports with length/checksum/hash checks. Windows exposes only the first table of each duplicate name; missing SSDTs are disclosed. Activation/license tables are excluded.
- Firmware, driver, network, timeline and transport provenance. The transient handshake remains an ETW sequence; the dump follows the passive trace and is not an atomic capture of its earlier stages.
- V2 preserves unavailable optional PnP metadata as explicit issues, requires a real GPU/UCSI service binding, resolves installed driver paths from their service entries, and records error phase/stack. Read-only native inventory and static-input collection were exercised in qualification.

No firmware/UCSI commands, registry/device/driver/boot-security/network changes or automatic reboot. Task Manager itself creates the snapshot. A valid header does not guarantee every required page or private policy field was captured; analysis checks that after return. This is a diagnostic capture, not a firmware patch or a validated fix.
