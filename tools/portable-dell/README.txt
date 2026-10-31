DELL -> DEG2 SUCCESSFUL-CONNECTION CONTROL

1. Copy the entire USB4-Dell-Control folder from USB onto the Dell SSD,
   preferably C:\USB4-Dell-Control. Keep the folder together; do not copy
   just START.cmd or the PowerShell files. Leave at least 3 GiB free.
   Keep the Dell awake on its normal charger. Local recording avoids logging
   the USB stick's own trace-writing traffic and reduces USB I/O overhead.
   Keep DEG2 powered and the display connected to the GPU.
2. On the Intel Dell, right-click START.cmd and choose Run as administrator.
3. Disconnect DEG2 USB-C from the Dell when prompted. Symbol preparation
   runs before recording; Wi-Fi/Internet helps download matching Microsoft
   symbols. Driver files and symbol identities are also saved for later decoding.
4. Wait for GREEN before connecting DEG2 to the SAME Dell Thunderbolt port
   that worked before. Leave it connected while recording and queries finish.
5. Answer whether the GPU display showed an image. Then DISCONNECT DEG2
   when prompted so the original diagnostic setting can be restored safely.
6. After the console finishes, copy the complete Results folder back into
   USB4-Dell-Control on the USB, including SymbolCache and State. Eject the
   USB safely and bring it back to ASUS. Retain the Dell copy until reviewed.

Running directly from USB is supported if the storage check passes. Connect
the stick directly to the Dell, never through DEG2, because DEG2 must be
disconnected during preparation and cleanup. Drive letters may differ.

The collector uses the same 27-provider trace profile as the ASUS comparison,
including USB transfer/header/payload keywords. It saves disconnected and
attached PnP/driver states, driver-image/PDB identities, driver flight recorders,
and separately timed UCSI GET replies after a 25-second passive window.
Alternate-mode queries include additional mode offsets and cable recipients.
Actual provider emission, decoding and physical insertion time need analysis.

One documented UCSI diagnostic-interface DWORD is enabled where the Dell
exposes the expected Microsoft ACPI UCSI device. Its original presence/value
and networking/ICS configuration are saved before any change. Result-file
creation/replacement is tested first. Final logging errors do not skip cleanup.
The collector
restarts only that UCSI device, then restores its original setting at cleanup.
If Windows says a normal restart is required, restart normally and run START
again; the original backup is retained. No automatic reboot is issued.
If interrupted, use UNDO.cmd as administrator on the same Dell with DEG2
disconnected. Unexpected intervening values are preserved for review.
No network configuration, driver package or firmware image is replaced.
Secure Boot, test-signing and memory-integrity settings are not changed.

Signed Microsoft LiveKD temporarily loads its kernel helper to read logs.
The wrapper stops only processes/session it owns; helper unloading is not
independently established. A blocked debugger is recorded as missing coverage;
no security controls are weakened. Raw USB-PD CC wire packets are not captured.

The ETL is sequential and capped at 1 GiB. Firmware commands have a 90-second
phase budget and five-second per-command limits. Busy/transport failure stops
further firmware queries. Connector/mode enumeration is bounded and reported.
Recorded means data was saved, not that GPU output or every decoder succeeded.

Tool provenance:
- LiveKD 5.65, Microsoft Sysinternals; signature and SHA-256 checked.
  https://learn.microsoft.com/sysinternals/downloads/livekd
- KD 10.0.29661.1004 and debugger extensions, Microsoft Windows debugger kit;
  valid Microsoft debugger signature. Matching PDBs use Microsoft's symbol server.
- UcsiControl 10.0.26572.1000, extracted from official MUTT 3.0.1 without
  installing the MSI. This user-mode EXE is unsigned and is pinned by SHA-256:
  22AC51EF4503E4FF3344B7C33FFB7509F43D26F5F4942A2C382DD91F4FB7B9A7
  https://learn.microsoft.com/windows-hardware/drivers/usbcon/ucsi
  https://www.microsoft.com/download/details.aspx?id=51604

The private bundle contains Microsoft tools for this owner's diagnostic use.
Binaries, raw captures, drivers and symbols are not published to GitHub.
Bundle files are listed with SHA-256 digests in bundle-manifest.json.
Results may contain device/network identifiers and stay private by default.

Source and measured ASUS findings:
https://github.com/49Ssr/asus-fa507xi-deg2-usb4
