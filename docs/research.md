# Research and sources

Checked during the 30 October 2026 investigation. Manufacturer documentation is separated from firsthand community reports. Similar symptoms on another product are a lead, not proof of this machine's cause or permission to use its firmware.

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
