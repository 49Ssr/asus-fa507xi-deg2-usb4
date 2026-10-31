# Temporary full-Windows test

**Completed on 31 October 2026:** image preparation, driver injection, native boot and one connection capture. The separate Windows reproduced the missing external router/GPU; see the [result and limitations](fresh-windows.md). The procedure below documents reproduction, not an instruction to redeploy Windows as the next test. Boot-entry removal remains untested.

This is a separate full Windows baseline on the same physical laptop. It is not WinPE or a virtual-machine USB passthrough test. It is intended to test whether the existing Windows installation is involved, not to promise an eGPU fix.

## Control and data flow

The local assistant session in the original Windows does not automatically move into the new installation. The recorder is copied into the VHDX in advance. The owner runs it there, and it copies the raw results into the ignored project `local/Results/` directory. After booting back, the original session can inspect them.

A private marker identifies the hosting project across changed Windows drive letters. It does not depend on the new installation using the same letter for every physical volume.

## Local prerequisites

- ASUS FA507XI; 64-bit Administrator Windows PowerShell for setup modes.
- A fully decrypted fixed NTFS hosting volume with at least 75 GiB free. Both owner volumes were confirmed fully decrypted; the secondary internal SSD has ample space.
- An ordinary ASCII project path without junctions, symbolic links, NTFS compression or EFS encryption.
- A full x64 Windows 11 Professional install image from the owner's Windows media: `sources/install.wim`, `install.esd`, or first `install.swm` with its companion pieces. `boot.wim` is rejected.
- A Windows image build no newer than the current boot environment. Record the actual image and resulting runtime build for comparison.
- The private `local/Drivers/manifest.json` and seven original installed System-class packages prepared for this host. Binaries are excluded from Git.

On a fresh clone, `tools/Export-FA507XIBaseline.ps1 -Preview` reviews the bound packages, and running it without Preview copies them into ignored local storage. It installs nothing, rejects Firmware-class packages, and requires the original Parade versions. The investigation owner's bundle was already prepared.

## Driver baseline

| Package | Version |
| --- | --- |
| AMD I2C | 1.2.0.121 |
| AMD GPIO | 2.2.0.130 |
| AMD Micro PEP | 1.0.40.1 |
| AMD PPM provisioning | 8.0.0.20 |
| ASUS System Control Interface | 3.1.73.0 |
| Parade SPB | 1.0.8.0 |
| Parade HID | 1.0.11.0 |

These are copied by exact INF hash from currently installed packages, with a private per-file hash manifest and valid catalog signatures. They are not claimed to be the newest possible packages. The Microsoft USB4/xHCI/UCSI drivers come from the Windows image. No Firmware-class package is injected; the physical device firmware remains shared with the existing installation. Missing CFU updater child drivers must not be mistaken for a missing primary retimer driver.

ASUS SCI can have a normal null-driver binding/status rather than a running kernel service. The recorder's essential checks focus on the USB4 host and root router, UCSI, I2C and eight Parade peripheral devices.

## Workflow

From the local repository:

```powershell
# Read-only preview, including automatic media discovery.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Prepare-USB4Test.ps1 -Mode Preview

# Administrator console. Uses exactly one connected installer source, or add -ImagePath.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Prepare-USB4Test.ps1 -Mode Prepare

# Separate explicit operation after reviewing the preparation result.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Prepare-USB4Test.ps1 -Mode AddBoot
```

Prepare creates a new expanding 64 GiB VHDX. The script verifies that it resolves to one file-backed virtual disk of the expected capacity, then repeats the association checks before partitioning/formatting. It never cleans/resizes/repartitions a physical drive. The VHDX is serviced offline and detached afterward. Incomplete files are retained for inspection; reruns do not overwrite an existing VHDX or preparation record.

AddBoot exports a BCD backup and creates one new explicit loader GUID. It does not run BCDBoot, replace the existing boot files, select a new default OS, alter UEFI order, change security settings, or reboot. A failure partway through entry creation is recorded and requires inspection before retrying.

Restart manually, select **USB4 test - temporary Windows**, and select it again if initial Windows setup restarts. If the normal menu has a zero timeout, Windows Advanced startup provides **Use another operating system**.

The prepared image requests Microsoft's Audit mode. It should reach the built-in Administrator test desktop and may display the Sysprep dialog. Close that dialog; do not reseal/generalize the test installation. If it instead reaches OOBE, stop and record the exact screen rather than improvising account/setup changes.

## Connection test

1. Keep the first test boot offline: unplug Ethernet and leave Wi-Fi disconnected. Keep the DEG2 disconnected initially. Use the ASUS's normal barrel charger and the same known-working assembled hardware/cable.
2. Run **Run USB4 diagnostic.cmd** on the test desktop.
3. Follow the disconnected baseline prompt, then connect the DEG2 when recording begins.
4. After the warning or approximately 20 seconds, press Enter. Recording continues another 15 seconds.
5. Check the printed result and saved shared location, then restart back into the original Windows.

The recorder checks the expected host/root-router/UCSI/I2C/Parade devices before interpreting a negative result. It captures ordinary USB fallback, external USB4 routers and new display adapters separately. If prerequisites are missing, the negative result is explicitly inconclusive.

An external router appearing is progress even before an NVIDIA driver is installed. Actual display output and GPU workloads are later checks. If the router remains absent with a valid baseline, firmware/hardware/cable interoperability becomes a stronger lead; it is not mathematically proved and a shared OS bug remains possible.

## Recovering the first preparation guard failure

The first real preparation attempt on 31 October created a 4 MiB VHDX container, then stopped before initialization because Windows PowerShell returned BusType as the friendly string `File Backed Virtual` rather than a numeric value. The finally block detached the image. No Windows image or driver was applied, and no boot entry was created. The guard now accepts the numeric value and exact friendly/enum labels while continuing to reject physical disks.

The `-Mode ArchiveFailed` recovery checks the saved phase/error, exact VHDX path/capacity, small file size, detached status and contained source/destination paths. It preserves the failed directory under a unique `local/NativeBoot-failed-*` name without deleting it. Other failures and later-stage images are rejected. The owner used this path successfully before the completed deployment; it is a recovery for that specific early failure, not a general reset mode.

## Removing the boot entry

After returning to the original Windows:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Prepare-USB4Test.ps1 -Mode RemoveBoot
```

The removal operation checks its explicit GUID, description and VHDX path. It refuses to delete the currently running test entry and retains the image, private BCD backup and results. Automatic recursive deletion is deliberately absent. Any subsequent file removal should be a separate reviewed action.

## Validation boundary

The original mocked guard tests missed the Storage module's real BusType representation. The corrected preparation, first boot, essential preflight and connection capture have now run on this machine; the eGPU still did not enumerate. This does not validate the toolkit on other machines, prove every OEM dependency was present or exercise boot-entry removal. Keep mocked tests, observed setup execution and the hardware result separate. See the [audit](validation-audit.md).
