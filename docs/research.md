# Research and sources

Checked during the 30-31 October 2026 investigation. Manufacturer documentation is separated from firsthand community reports. Similar symptoms on another product are a lead, not proof of this machine's cause or permission to use its firmware. The proposed comparisons and their interpretation are in the [next-test matrix](handoff.md).

## Primary technical references

1. [Microsoft: USB4 design details and general requirements](https://learn.microsoft.com/en-us/windows-hardware/design/component-guidelines/usb4-design-details-and-general-requirements). Explains the Windows USB4 architecture and notes that its connection manager is independent of UCSI. Relevant to interpreting the host/root versus external-router boundary.
2. [Microsoft: USB4 ACPI requirements](https://learn.microsoft.com/en-us/windows-hardware/design/component-guidelines/usb4-acpi-requirements). Relevant to OS control negotiation. An `_OSC` grant is a permission observation, not an end-to-end cable/link result.
3. [UEFI: ACPI 6.4, device configuration](https://uefi.org/htmlspecs/ACPI_Spec_6_4_html/06_Device_Configuration/Device_Configuration.html). Defines USB `_OSC` control bits, including PCIe tunneling control.
4. [Microsoft: USB Type-C troubleshooting notifications](https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/usb-type-c-troubleshooting-notifications). Important for the distinction between a Billboard mode marked not attempted/exited and a proved rejected transaction.
5. [Microsoft: PnPUtil command syntax](https://learn.microsoft.com/en-us/windows-hardware/drivers/devtest/pnputil-command-syntax). Used for scoped enumeration, device restart and driver package handling. Published OEM package numbers are local identifiers and can change.
6. [Microsoft: WdfDriverOpenParametersRegistryKey](https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/wdfdriver/nf-wdfdriver-wdfdriveropenparametersregistrykey). Supports the registry-path interpretation in the local driver audit.
7. [Microsoft WDF function enumeration](https://github.com/microsoft/Windows-Driver-Frameworks/blob/main/src/publicinc/wdf/kmdf/1.27/wdffuncenum.h). Used to identify the WDF API table entry rather than guessing from an indirect call.
8. [Microsoft: Windows Update OperationResultCode](https://learn.microsoft.com/en-us/windows/win32/api/wuapi/ne-wuapi-operationresultcode). Code 2 means success. The all-vendor search returned zero offered packages.
9. [Parade: PS8830](https://www.paradetech.com/products/ps8830/). Identifies the retimer's role. A peripheral driver update is not automatically a PD-controller or retimer firmware update.
10. [USB-IF: USB4](https://www.usb.org/usb4). General standard and interoperability background; a USB-C connector or ordinary USB hub result alone does not identify the negotiated USB4 path.
11. [Synopsys: USB4 SoC design and cables](https://www.synopsys.com/articles/understanding-usb4-soc-design-upgrades.html). Explains that suitable passive USB 3.2 Type-C cables can also carry a lower-speed USB4 connection. Lack of a Thunderbolt label alone is insufficient to classify every cable.
12. [Arzopa: manual and guide centre](https://www.arzopa.com/pages/download). Describes its supplied full-featured USB-C video cable. It does not independently verify this owner's exact cable as a compliant USB4 test cable.

## Exact-model support and trial package

- [ASUS FA507XI BIOS/firmware page](https://www.asus.com/us/supportonly/fa507xi/helpdesk_bios/): BIOS 314 was the newest exact-model BIOS found. The inspected listing also had touchpad firmware; no applicable USB-C/PD firmware image was verified.
- [ASUS FA507XI driver page](https://www.asus.com/uk/supportonly/fa507xi/helpdesk_download/): original Parade package baseline. No evidence was obtained that every firmware update would necessarily be pushed automatically by MyASUS or Windows Update.
- [ASUS FA507UU driver page](https://www.asus.com/laptops/for-gaming/tuf-gaming/asus-tuf-gaming-a15-2024/helpdesk_download?model2Name=FA507UU): source listing for the newer related-model Parade package. It was trialled and rolled back; exact-model qualification was not claimed.
- [Official trial installer](https://dlcdnets.asus.com/pub/ASUS/GamingNB/Image/Driver/USB/38025/Parade_Retimer_ROG_Parade_B_V1.0.016.00_38025_1.exe): included for provenance, not a recommendation to install it. See the [experiment ledger](experiments.md) for the verified hash and outcome.
- [Minisforum DEG2 product page](https://www.minisforum.com/products/deg2): vendor hardware specification, including the USB4/TB5 and OCuLink operating paths.
- [Minisforum product support](https://www.minisforum.com/pages/product-info): no applicable, verified public DEG2 firmware image was found in the inspected support section.
- [UGREEN Revodok Pro 3121](https://fr.ugreen.com/products/revodok-pro-3121-hub-usb-c-12-en-1): manufacturer identifies SKU 55767 and a conventional 10 Gbps USB-C hub. This is the owner's existing hub, identified from Amazon ASIN B0DRP1F6R7; its operation would not establish a USB4 router or PCIe tunnel.

## Relevant vendor firmware precedents

### ASUS ROG Xbox Ally X and DEG2

[ASUS-hosted discussion, page 5](https://rog-forum.asus.com/t5/handheld-gaming/psa-currently-xbox-ally-x-is-not-compatible-with-thunderbolt-5/td-p/1136335/page/5) contains firsthand DEG2 detection failures, reports of particular cables working, an ASUS customer-service post directing users to PD firmware 0019, and subsequent reports that the supplied TB5 cable worked after updating. A support post also states that manual installation was required for that product.

This is a useful precedent for USB-C/PD compatibility work, on **another laptop/handheld model**. It does not establish that FA507XI needs the same update or that its firmware image is compatible.

Some cable reports are individual customer observations. An advertised 20 Gbps cable working elsewhere is not a guarantee for this ASUS, and buying a particular cable has not been presented as a confirmed fix.

### ASUS ROG Flow Z13 GZ301VU and Thunderbolt 5 devices

[ASUS GZ301VU firmware page](https://www.asus.com/uk/supportonly/gz301vu/helpdesk_bios/) lists PD Firmware Update V2.13.0.001 dated 26 September 2025, with an explicit description adding Thunderbolt 5 device support. A [firsthand DEG2 investigation](https://egpu.io/forums/postid/1121211/) reports detection being fixed by a system firmware update.

This is another product, with a different host platform. Its relevance is that a PD firmware change can affect TB5-dock negotiation on older hosts. Its firmware must not be assumed applicable to the FA507XI.

### Other AMD/DEG2 reports are not the same failure stage

A [GMKtec K12 report](https://egpu.io/forums/postid/1120954/) describes a router connecting at 40 Gbps and a later hang during PCIe authorization. A [DEG2 discussion](https://egpu.io/forums/postid/1119631/) describes other hosts crashing or hanging during later PCIe/GPU activity. These are firsthand reports, not vendor diagnoses. In this investigation the ASUS does not enumerate the external router, so their later-stage fixes cannot be assumed relevant.

Unverified customer claims about a vendor supplying another product's reference firmware were not used as a basis for flashing. Neither a chip-family match nor an AI interpretation of a report establishes a compatible firmware image.

## Full-Windows isolation test references

- [Microsoft: WinPE introduction](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/winpe-intro?view=windows-11): advises against using WinPE for hardware validation. The earlier WinPE suggestion was withdrawn.
- [Microsoft: native-boot VHDX](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/boot-to-vhd--native-boot--add-a-virtual-hard-disk-to-the-boot-menu?view=windows-11): full Windows can run from a VHDX on the real hardware alongside an existing installation.
- [Microsoft: native-boot requirements and limits](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/deploy-windows-on-a-vhd--native-boot?view=windows-11): includes hosting-volume encryption restrictions.
- [Microsoft: offline driver servicing](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/add-and-remove-drivers-to-an-offline-windows-image?view=windows-11): supports preparing the required hardware driver baseline before first boot.
- [Microsoft: custom boot entries](https://learn.microsoft.com/en-us/windows-hardware/drivers/devtest/adding-boot-entries): basis for an explicit additional OS loader entry.
- [Microsoft: Audit mode](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/boot-windows-to-audit-mode-or-oobe?view=windows-11) and [Reseal](https://learn.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/microsoft-windows-deployment-reseal): allow the new image to reach a test desktop without setting up the owner's normal accounts or applications.

No third-party driver binaries, Windows images, PDBs, raw firmware dumps, or copied forum articles are redistributed here.

## Further Windows diagnostic tools, reviewed 31 October 2026

USB4KD was subsequently run against a full live kernel snapshot; the other tools below remain untested. None establishes a fix or replaces the missing cable/peripheral comparisons.

| Tool / primary source | Potential contribution | Applicability and current limit |
| --- | --- | --- |
| [Microsoft USB4KD](https://learn.microsoft.com/en-us/windows-hardware/design/component-guidelines/usb4-kernel-debugger-extension), with a [Task Manager full live kernel dump](https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/task-manager-live-dump) | Inspect captured USB4 host/router/port/adapter and tunnel state. | Completed offline on the 04:27 snapshot, with signed Microsoft debugger 10.0.29661.1004 and matching symbols. One host/root, zero external routers/tunnels, cached `PcieTunnelsDisabledInBios = 0`, fallback devices present. A framework-relation helper lookup failed; direct fields and PnP/WDF corroborate the reported state. No cause or repair identified. [Full findings and limits](kernel-snapshot.md). |
| [Microsoft Windows Device Portal USB4 viewer](https://learn.microsoft.com/en-us/windows-hardware/design/component-guidelines/usb4-windows-device-portal) | Visualize host/device routers, adapters and tunnels. | Untested. May give clearer topology but may only reproduce the already-known absence of a downstream router; setup alone is not progress toward a diagnosis. |
| [Port Authority](https://github.com/harvey-withington/port-authority) and [PortLens](https://github.com/asthanarht/Portlens) | Windows USB topology, negotiated USB rates and explanatory views. | READMEs reviewed; binaries/source not execution-validated here. Port Authority explicitly says its collector does not yet gather the connector-level UCSI data needed for some USB4/PD cases. Neither README demonstrates a FA507XI/DEG2 repair. |
| [WIKO/Huawei eGPU troubleshooting guide](https://github.com/dreamforse/eGPU-USB4-windows-fix-thunderbolt) | Community enumeration, host restart and later GPU/display recovery recipes. | Its documented host is Intel and its GPU is a Radeon RX 7600M XT. Many steps require an enumerated GPU or PCIe switches; host restart was already attempted here. Its general claims and display-tunnel explanations are not adopted as established facts for this setup. |

The completed capture used Administrator Task Manager, Details, System, Create live kernel memory dump file, Full live kernel memory dump. For a future changed-condition comparison, capture with DEG2 attached after reproducing the warning. Keep the default memory-pressure abort protection; additional user/hypervisor memory is not required for this method. Kernel-stacks-only output is not the intended input. Record the actual saved path locally. Full dumps are private and excluded by `*.dmp`; publish only reviewed findings.

The completed analysis established that offline host/root/port/tunnel queries work with this snapshot. That does not validate every USB4KD command or guarantee that every captured page is available. A memory snapshot is not a USB-PD wire trace and cannot supply an unreported firmware exchange.

### Expanded offline methods and existing-hardware comparison

- The signed debugger also contains `SmFxDbg.dll`. Its local help documents `!smfx_machine2 <engine-implementation-pointer> <module>`. It successfully decoded the USB4 port, plug-state manager and root-router histories. UCSI engine-type lookup failed; direct record reads and that driver's public enums supplied the retained UCSI source-state/event names instead. [Actual results and decoder limits](kernel-snapshot.md#expanded-recorder-state-machine-and-acpi-inspection).
- [Microsoft RCDRKD log dump](https://learn.microsoft.com/en-us/windows-hardware/drivers/debuggercmds/-rcdrkd-rcdrlogdump) supports all driver buffers or one selected address. The expanded pass enumerated all 12 available USB4/UCSI/UCM buffers rather than only the original two selected buffers. [WDF log dump](https://learn.microsoft.com/en-us/windows-hardware/drivers/debuggercmds/-wdfkd-wdflogdump) supplied the ACPI client's separate framework recorder.
- [AMLI namespace inspection](https://learn.microsoft.com/en-us/windows-hardware/drivers/debuggercmds/-amli-dns) and [AML disassembly](https://learn.microsoft.com/en-us/windows-hardware/drivers/debuggercmds/-amli-u) worked after matching ACPI symbols were supplied. They located the BIOS UCSI transport and its regions, but both shared-memory backing pages are absent from the dump. No AML method was executed.
- [Microsoft USB4 interdomain connections](https://learn.microsoft.com/en-us/windows-hardware/design/component-guidelines/usb4-interdomain-connections) documents USB4NET and the resulting P2P network adapter. N0 subsequently passed: the existing Dell and ASUS, directly connected with the supplied DEG2 cable, both report P2P adapters Up. The completed working-link rundown adds a reported Gen 3 dual-lane 40 Gbps negotiation. This is not GPU PCIe tunnelling or measured payload throughput. [Result, register-decoding sources and limits](peer-test.md). Corporate device-installation policy or role negotiation can confound a negative result; [ACPI requirements](https://learn.microsoft.com/en-us/windows-hardware/design/component-guidelines/usb4-acpi-requirements) describe the optional data-role-correction workaround.

## Deeper negotiation capture and UCSI workaround precedent

| Primary source | Contribution to the prepared capture | Evidence limit |
| --- | --- | --- |
| [Microsoft USB tracing](https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/how-to-capture-a-usb-event-trace) | Confirms that transfer headers/payloads require specific keywords; FullDataBusTrace includes up to 4 KiB for supported bulk/interrupt/control transfers. The earlier `0xF861B` mask omitted those keywords. | USB host transfers are not the firmware controller's complete USB-PD CC traffic. First chained MDL only; no isochronous payload. |
| [Microsoft busiotools USB profiles](https://github.com/microsoft/busiotools/tree/master/usb) | Reference provider coverage for UCM/UCSI, USB, SPB and related bus layers. Local installed-provider metadata and matching UCM symbols add case-specific checks. | An enabled/requested provider may emit no events or have unavailable private WPP formats. |
| [Microsoft UCSI test interface](https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/ucsi#how-to-test-ucsi) and [MUTT package](https://www.microsoft.com/en-us/download/details.aspx?id=51604) | Documents the per-device TestInterfaceEnabled DWORD and UcsiControl interface. Preparation and the live comparison completed: 84 GET requests returned completed responses with CCI ErrorIndicator zero. | Returned data includes consistency questions; command completion does not establish correct metadata or a working USB4 link. The native EXE from the official MSI is unsigned and pinned by hash; no test certificate or boot-security change is required by this user-mode tool. |
| [Microsoft USB4 ETW and flight recorders](https://learn.microsoft.com/en-us/windows-hardware/design/component-guidelines/usb4-examining-connection-manager-driver-traces) | Supports combining live ETW with retained in-driver logs instead of assuming ETW alone exposes every decision. The new recorder commands recovered all 12 available buffers in an actual replay of the existing dump. | Offline replay validates decoder commands against the old snapshot, not live helper loading or the new hardware comparison. |
| [Upstream Linux ASUS UM325 UCSI fix, commit 326e1c2](https://github.com/torvalds/linux/commit/326e1c208f3f24d14b93f910b8ae32c94923d22c) | Avoids an extra firmware status read after a notification because copying the EC shadow can clear pending CCI. The extracted FA507XI M318 also copies and clears shadow status, providing a concrete ordering hypothesis. | Different laptop and OS. No duplicate Windows read, lost FA507XI notification or applicability of this quirk has been established. A driver change must follow observed command/read/ACK ordering. |

The [prepared comparison](handoff.md#n5-existing-hardware-partner-handoff-proposed) starts its trace before a fresh Dell-peer negotiation, followed by DEG2 handoff and, if needed, a fresh DEG2 attachment. Driver recorders are read before each active firmware-query batch. Per-phase PnP inventories before and after those queries help distinguish passive enumeration from a probe-associated change. Firmware logging or a suitable physical PD analyzer would be needed for packets that this firmware never exposes to Windows; no such wire capture has been obtained.
