# Reading the missing state with the existing hardware

> Detailed research record. For the latest result and selected test, start with [current findings](status.md). Preparation statements below describe their dates; later results supersede them.

2 November 2026. The earlier stop described the end of the saved task list too broadly. The owner reopened the investigation with specific capture and hidden-setting leads. No working repair or live PD capture is claimed here.

## What the exact ASUS BIOS contains

The retained, hash-verified FA507XI BIOS314 contains AMD PBS and CBS HII forms. IFRExtractor1.6.1 was obtained from its author's release and its published SHA256 checked. Ten question records were independently compared with their original module bytes. [Source pins and field map](../evidence/firmware-settings-and-capture-paths.json).

| Setting | Image-defined choices/default | Stored read / remaining uncertainty |
| --- | --- | --- |
| PD USB4 Control | Disabled0 / Enabled1; default1 | Captured Enabled1; actual ASUS consumer remains unknown |
| USB4 pre-CM | Disabled0 / Enabled1 / Auto15; default15 | Captured Auto15; resolved policy remains unknown |
| RT0 Router / PCIe Tunnel | Disabled0 / Enabled1 / Auto15; default15 | Both captured Auto15; host instance maps to NHI0, high-speed lane state remains unknown |
| RT1 Router | Disabled0 default / Enabled1 / Auto15 | Captured Disabled0; maps to NHI1/function6, separate from the failed RT0 path |
| RT1 PCIe Tunnel | Disabled0 / Enabled1 / Auto15; default15 | Captured Auto15; consumer remains unknown |
| PD Thunderbolt3 Alt Mode | Enabled0 default / Disabled1 | Captured Enabled0; use during this pairing remains unknown |

These are real settings in this image, not proof that a setting is wrong, writable on this machine, or sufficient to fix it. RT means the menu's router instance; it does not identify a Parade retimer or a USB-C connector. A working ASUS–Dell peer link does not establish PCIe tunnelling, but the saved ASUS runtime already reports native capabilities granted. A later tunnel restriction alone is not an explanation of the missing external-router detection.

The [UMAF README](https://github.com/DavidS95/Smokeless_UMAF/blob/c003b126cab6e29b1d72d061d59cea9e721a6910/README.md) explains that it replaces the boot's form browser to expose PBS/CBS menus. It is a settings interface, not a PD packet recorder. The linked [Flow X13 discussion](https://www.reddit.com/r/FlowX13/comments/1ci9u00/could_improper_usb_4_bios_installation_cause_egpu/) reports finding a USB4 toggle; it does not demonstrate a repaired FA507XI or even resolution of the original poster's problem. No UMAF download, boot or setting change was performed.

## Original code behind the variable

[The original PBS accessor](../evidence/pbs-runtime-variable-path.json) now confirms the exact0x500-byte read and a missing-variable path that constructs defaults and persists them with attributes7. Under the [UEFI runtime rules](https://uefi.org/specs/UEFI/2.11/08_Services_Runtime_Services.html#variable-services), those attributes include runtime visibility. This supports the prepared Windows GET as a specific access route; the owner-approved read now returned both variables with attributes7 and exact expected sizes.

The initializer writes1 to PD USB4 control through a two-byte store beginning at9b. A search for literal9c byte stores alone would miss it. The question47 callback has no special controller arm in the reviewed handler; changing a visible setting is not evidence of an immediate PD transaction. The later setup-to-platform policy consumer is still being traced. Image defaults are not current values.

## Read stored settings from Windows first

[Read-USB4FirmwareSettings.ps1](../tools/Read-USB4FirmwareSettings.ps1) defaults to Preview. Read mode uses Microsoft's documented [UEFI variable GET API](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-getfirmwareenvironmentvariableexw) for exactly two named variables. It checks FA507XI/BIOS314, requires an administrator process, temporarily enables the documented process privilege and restores its previous state. There is no firmware setter, device IOCTL, driver installation or reboot.

When convenient, right-click [READ-FIRMWARE-SETTINGS.cmd](../tools/READ-FIRMWARE-SETTINGS.cmd) and choose **Run as administrator**. The window stays open. No attachment/disconnection is needed. Raw values stay under private local/FirmwareSettings. Enhanced-authenticated payloads are retained without decoding because they can contain metadata. Only exact expected plain layouts are decoded; errors, unexpected sizes and unknown values remain explicit. Firmware may make these variables unavailable to Windows. A failed GET is not a disabled setting.

PowerShell5.1 parsing, embedded C# compilation, default Preview and original-byte field verification passed. Five offline result cases also preserve unavailable values, unknown encodings, wrong sizes and enhanced-authentication metadata without guessing settings. **Read mode completed on 2 November at 09:38 UTC after the owner requested the UAC prompt.** Both variables returned exact expected sizes; all ten fields were independently compared with retained raw bytes. The prepared reader captures stored configuration, not retimer execution or PD packets. If runtime access is unavailable, a UEFI variable export/view without saving settings is the alternative to investigate before any UMAF edit.

## What an actual PD/retimer capture requires

| Route | Existing-hardware opportunity | Present limit / next work |
| --- | --- | --- |
| Firmware settings GET | Inspect the exact hidden policy values in Windows | Prepared above; then follow the relevant consumer instead of guessing a toggle |
| DEG2 vendor USB interface | Its USB2 Billboard/WinUSB interface exists even during fallback, so it is a candidate transport for dock-side diagnostics | Exact firmware protocol/controller identity still needed. Standard descriptors can identify a transport; guessed vendor requests cannot establish safe logging. Qualify from firmware/source before sending commands |
| ASUS PD/retimer firmware interface | Read mode inputs or an entry-error/event log through existing code, if its register and transport are identified | Existing OEM dynamic PDO getter is a firmware stub; existing HID status is cached and updater outputs can write. These do not supply the needed observation |
| USB4 retimer sideband | Standard retimer registers can be accessed through a host router in implementations that expose them | Linux's [retimer scan](https://kernel.googlesource.com/pub/scm/linux/kernel/git/torvalds/linux/+/69050f8d6d075dc01af7a5f2f550a8067510366f/drivers/thunderbolt/retimer.c) broadcasts enumeration and enables sideband transmission. This is an active operation, not an unchanged Windows passive read; no replacement boot is queued |
| Windows ETW | Correlate an identified controller observation with Windows' detection, role and power decisions | Existing traces already cover that host boundary. Repeating them alone does not produce CC-wire packets |

The two laptops and Ethernet link do not themselves expose the CC-wire signal as a software packet capture. A software capture with the present hardware depends on finding an implemented controller log/state interface. If none exists, an external PD analyser is the wire-level route; no purchase is requested by this plan. The objective remains to qualify the software route first.

## A specific standard USB read to qualify next

Both original DEG2 BOS payloads advertise an additional-information URL at **string index7**, and USB4/TBT/DP descriptions at8/9/10. The retained analysis has the indices, not their text. Under Billboard1.2.2 section2.5 these are device/mode information and possible help links, not promised debug logs. They might identify a vendor or support interface; generic marketing text would leave the protocol unknown.

Microsoft's pinned [USBView code](https://github.com/microsoft/Windows-driver-samples/blob/f4c1ff842b6a0001152f44cb61788b216a1c7627/usb/usbview/enum.c) provides a user-mode standard-string GET through the existing USB hub driver. Its inspected enumeration code does not contain a Billboard-specific string collection path. The next collector can therefore use that documented transport for the advertised indices after freshly binding the exact device and supported language. It needs no new kernel driver or test boot. **The narrow collector is not yet implemented or executed.** No undocumented vendor request is justified by the indices.

[Payload pins, request requirements and scope](../evidence/pbs-caller-and-billboard-string-route.json). The same review follows the selected AmdNbioPei PBS reader: its identified stack-relative load is PBS3c3, not PD-control9c. That caller is not evidence that the hidden toggle programs the retimer. The full setup-to-controller consumer remains open.

## The Billboard and its parent hub are different targets

The retained ASUS tree puts **041f:d002 DEG2** on port4 of the **1d5c:5801 USB2 hub**. That is a hub port, not ASUS connector4. The [FL5801 manufacturer page](https://www.paradetech.com/products/fl5801-tbt4-usb4-port-controller/) describes customizable Billboard and PD-bridge functions. It gives a concrete family/interface lead; it does not prove the fitted chip, an enabled bridge or a logging command.

There is also [public Infineon Griffin Creek reference source](https://github.com/Infineon/mtb-example-pmg1s3-griffin-creek-dock/tree/e9104d5768c9b042244c7c705198be8926228d01), available without SDK login. The inspected FL5801 helper reads a UUID over the reference board's I2C master. It does not capture PD packets through Windows. Its vendor endpoint descriptors match DEG2: OUT01 bulk and IN82 interrupt, both64 bytes. Initialization can override VID/PID from configuration, so the default04b4 ID does not exclude it. This supports following its command handler; it does not establish compatible commands. The inspected fwupd quirks distinguish this hub from7102/7112 PD devices and from separate dock-management controllers. Their vendor requests are not qualified for DEG2.

The standard-descriptor reader now has a compiled, offline-tested [byte codec](../tools/analysis/BillboardDescriptorProtocol.cs). Official Windows headers use packed structures: connection status is at31, not a guessed32. The codec rejects hub/target substitution, wrong port/status, malformed replies and unqualified string indices. **The complete hardware reader is still not implemented or executed.** Current instance-to-hub binding, I/O cancellation and private output remain to implement. [Evidence and exact scope](../evidence/billboard-capture-contract.json).

## A reference log route and the prepared standard reader

The [example-compatible Infineon reference](https://github.com/Infineon/pmg-app-common/blob/9ed74f798cae23aa6744f206ee381f3593590554/cy_app_usb.c) implements a conditional512-byte flash-log response. The log contains fault counts and short event records; it filters some attach/trace events and cannot reconstruct a full PD exchange. The build option, getter implementation and command compatibility remain unverified for DEG2. No vendor request is prepared for execution.

The [standard reader](../tools/Read-DEG2BillboardStrings.ps1) now has a default Preview and a separate supervised worker. It checks the exact current Billboard, parent hub, port driver key, identity and BOS, then reads the advertised strings. All raw inputs/replies/errors stay private. **The capture path has not run.** Compilation, Preview and offline rejection checks do not establish working hub permissions, port metadata or device transfers. Review those remaining assumptions before owner use. The [worker supervision check](../tools/analysis/Test-BillboardWorker.ps1) now exercises harmless real processes for both completion and timeout. It verifies process handling only; no device transfer was tested. [Code scope and checks](../evidence/infineon-log-route-and-reader.json).

## Separating the identified menu settings

Original question bytes now identify the selected firmware paths: PBS3ba controls PCIe DXIO timing overrides,3bb/3bf hold PCIe polling values,3c3 is WWAN support and1f is CLK_REQ6 clock power management. The selected PEI call writes a Boolean platform-configuration token, not a PD command. These findings distinguish those paths from the still-unlocated PD USB4-control9c consumer. They do not justify changing the settings to force USB4 entry. [Definitions and original-byte checks](../evidence/pbs-pcd-and-hii-identities.json).

## What the existing dump says about USB4 dependency policy

The firmware has a real USB4 ACPI dependency setting at PBS465 and a software-SMI writer. The platform-wide `_OSC` native-USB4 branch can clear this setting's dependency state. This is separate from PD USB4-control9c; invoking the SMI would change configuration.

Offline inspection of the original failed ASUS dump recovered **M046=0x0c and DDEP=0x55**. The selected legacy dependency branch needs M046<0x0b and DDEP==1, so it is inactive at that snapshot. That is concrete evidence against changing this particular toggle as the fix. It does not reveal current NVRAM, PD negotiation or every other dependency. [Code, dump provenance and limits](../evidence/usb4-dependency-handshake.json).

## Stored policy recovered from Windows

The owner-approved read at **2 November 2026, 09:38:15 UTC** recovered both exact BIOS314 variable layouts with attributes7 and no Win32 errors. The ten selected fields were independently checked against the original returned bytes. [Sanitized observation and limits](../evidence/firmware-settings-read.json).

| Setting | Stored value |
| --- | --- |
| PD USB4 Control | Enabled1 |
| PD Thunderbolt3 Alt Mode | Enabled0 |
| UCSI Support / tunnel location | Enabled1 / MMIO1 |
| USB4 ACPI dependency | Disabled0 |
| USB4 pre-CM | Auto15 |
| RT0 Router / PCIe Tunnel | Auto15 / Auto15 |
| RT1 Router / PCIe Tunnel | Disabled0 / Auto15 |

The seven fields with previously recorded image defaults match those defaults. A disabled stored PD USB4 or TBT3 toggle is therefore not the explanation in this snapshot. Enabled values do not prove that firmware consumed them correctly. Auto remains unresolved. RT1's stored Disabled value does not identify the tested port or a retimer, and does not justify a toggle test before that mapping is established.

The selected original Quanta DXE routine can persist the separate PD Thunderbolt3 field4d. Its full effects and Windows transport remain unqualified. No setter was invoked. [Original code and limits](../evidence/tbt-policy-setter-scope.json). Raw variables remain private. No driver, reboot, connection change or firmware-setting write was needed for this read.

Scheduled research is paused at the owner's request. Interactive work must account for remote access without BIOS or cable access.

## RT1 is the other host-router instance

[The original firmware and saved capture now map RT1](rt1-router-mapping.md) to NHI1/function6 and RT0 to NHI0/function5. DEG2 fallback is under XHC3, the NHI0/RT0 companion. The setting feeds a genuine second-router boot policy, but its disabled state is unsupported as the repair for the captured first-router failure. No Windows reapply path or setting test is established.

## Standard USB information read succeeded

The exact current DEG2/parent binding was captured on2 November at10:03 UTC through the existing Windows hub driver. No elevation, reconnect or new driver was needed. All seven standard descriptor GETs and four hub metadata reads succeeded.

String7 is the Minisforum homepage,8 is generic Thunderbolt assistance text, and9/10 are literal null strings. These are device-provided information, not negotiation errors. The first reported mode-capability VDO is now0 versus2087e000 in the earlier ASUS fixture; status byte35 is unchanged. Reference Infineon code can populate this field from software-held EUDO, but DEG2 applicability and the cause of the different word remain unverified. It is not an observed PD exchange. [Sanitized results, source hashes and scope](../evidence/billboard-strings-result.json).

Earlier statements above that the standard reader had not run describe preparation history. It is now exercised on this one exact binding; other hardware and native-I/O timeout behavior remain unqualified. Do not repeat the read unchanged or issue guessed vendor requests.

## Choosing an intervention requires a different observation

[The Windows repair route](windows-repair-route.md) now separates the missing entry request/response, applied retimer/training state and later-loss history from the interfaces already exercised. Current registry GUID matching is not a firmware/command fingerprint. Reference BOS data can come from a template or saved EUDO written before mux completion. The complete selected BIOS setter also writes network/Setup data and MMIO, so it is not a qualified port-only reapply operation. These are reasons to qualify a specific diagnostic implementation, not a conclusion that Windows repair is impossible.

## Would the Infineon SDK help?

**Yes, as reference code and register/interface definitions. It is worth downloading; it is not a ready-made ASUS capture utility.** The [Host SDK guide](https://www.infineon.com/row/public/documents/30/316/infineon-ez-pd-ccgx-host-sdk-user-guide-productqualificationreport-en.pdf), pages10–11/38, describes AMD Phoenix reference firmware, APU/retimer interfaces and PS8830 selection. The public [hardware code](https://github.com/Infineon/pdaltmode/blob/fec544408cffffbfe459042262b5cd233a686722/cy_pdaltmode_hw.c) references AMD-specific headers and an APU mode-update function; the [retimer wrapper documentation source](https://github.com/Infineon/pdaltmode/blob/fec544408cffffbfe459042262b5cd233a686722/docs/xml/cy__pdaltmode__retimer__wrapper_8c.xml) calls AMD retimer initialisation. Those AMD implementations are not among the files in the inspected public tree.

Use the [official download page](https://softwaretools.infineon.com/tools/com.ifx.tb.tool.ezpdhostsdk). Version3.7 is a concrete archived candidate already identified in the catalog;3.9 is also listed. Download the package and retain it without running the installer. Static extraction can check AMD/PS8830 headers, source, libraries and reference settings. Availability of complete implementation source is not yet verified. It cannot supply ASUS's ITE firmware or prove the ASUS register alias by itself. Authentication is the observed download barrier, not proof that purchasing software is necessary.

## Other supplied material

The DHgate page could not be retrieved with the web reader; its pasted broad buying advice is not evidence of this failure. GPU performance percentages, RTX50-series problems, DDU and thermal limits do not identify why the external USB4 router is absent.

A newly located [Phoenix/JHL9480 developer report](https://lore-kernel.gnuweeb.org/linux-usb/TYCPR01MB1092795BE7AB51121BBAB292496862@TYCPR01MB10927.jpnprd01.prod.outlook.com/) is relevant to power handling, but its dock router is detected before the downstream PCIe hierarchy fails. The ASUS–DEG2 record lacks that first detection. Keep it as a stage-specific comparison, not a demonstrated Windows fix or justification for global power changes.

Next offline work: follow the exact PBS PD USB4-control field into its consumer; resolve the CBS router mapping and Auto policy; identify the dock diagnostic implementation or an existing retimer status interface. SDK access can proceed alongside this work. No new driver or blind boot is queued.

## Boot tools reviewed against the missing state

The [pinned UMAF/SREP/setup_var/tbtools review](boot-tools-review.md) separates menu access, stored-variable access, EFI image instrumentation and Linux USB4 diagnostics. The inspected tbpd entry backend is ChromeOS EC only; no ASUS ITE override or PD recorder follows from its mode option. Both UMAF archives were inventoried without execution. A future logged OS comparison could be useful; no bootable image or boot test was prepared or performed.
