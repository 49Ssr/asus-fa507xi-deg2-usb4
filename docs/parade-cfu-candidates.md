# Parade CFU firmware candidates: offline review

**Two real firmware payload candidates were recovered from Microsoft's Update Catalog. Neither is installed or qualified for this ASUS FA507XI.** This follows the [failed preconnected-startup observation](cold-start-observation.md), not a successful fix.

## Installed state and candidate distinction

Read-only PnP checks reconfirm the existing Parade firmware updater **1.0.6.0** and firmware reporting **1.3.0.2** on both present PS8830 firmware children. The installed offer word is `0x01030002`. The original retimer peripheral-driver trial changed SPB/HID drivers while retaining that firmware version; these CFU packages contain actual firmware offer/payload files.

| Catalog updater | Offered version word / dotted bytes | Component | Result |
| --- | --- | --- | --- |
| [1.0.7.0](https://www.catalog.update.microsoft.com/ScopedViewInline.aspx?updateid=08ab0ab7-99dc-4ed6-860e-2357cc70240f) | `0x01030005` / 1.3.0.5 | `0x30` | Offline candidate only |
| [1.0.8.0](https://www.catalog.update.microsoft.com/ScopedViewInline.aspx?updateid=3a8a1524-c431-4f2b-a46e-de5c5286614c) | `0x01030004` / 1.3.0.4 | `0x30` | Offline candidate only |

Both catalog detail records and extracted INFs name PS8830 Firmware Driver and match `HID\VID_045E&UP:FA00_U:00F5`, which is present on this ASUS. Both CAT signatures validate under Microsoft Windows Hardware Compatibility Publisher. The INF, DLL, offer and payload all pass catalog membership checks. These establish provenance/integrity and a generic device-ID match, **not ASUS board qualification, a known DEG2 fix or safe recovery**.

The higher updater version carries a lower firmware offer word. Do not choose a branch solely by the updater version. Earlier broad Parade search results at 1.0.17.0/1.0.18.0 were also inspected: those sampled entries target PS8833 peripheral ACPI IDs, rather than this PS8830 firmware child. Catalog classification/title alone is insufficient.

## What was done

The normal web reader could not open the catalog; a direct HTTPS read of Microsoft's site succeeded. Two Microsoft-hosted CABs were downloaded privately and extracted as data. Each contains a 16-byte offer and an 86,016-byte payload. Each payload was reconstructed into a contiguous 65,536-byte image and re-encoded to the original bytes exactly. Embedded labels identify the same AMD PS8830 project family with a later May 2023 date. The two candidate images themselves differ in 16,513 bytes, so they are not interchangeable copies.

| CAB updater | CAB SHA-256 | Payload SHA-256 |
| --- | --- | --- |
| 1.0.7.0 | `0FF2BD85C1450E7CC4947006891F5E65865CDAEAA3129E2DB310FBAE94A48C0D` | `4C09CB579F0E7FB6F3DE29523B65D31F255A835057AB461ABE35D2553F0084BD` |
| 1.0.8.0 | `502DDDDB2B87B5974A39446562911C3029006E5926785DBD906DFBD4F200B98B` | `7FF1C6C3B1F3F0D43B654E0F59F1A2DA175CF4F5E4FD07684FB1FDA16DD5D37E` |

A read-only Windows Update Agent search completed at 13:42 UTC using the machine's currently configured source and criteria `IsInstalled=0 and IsHidden=0 and Type='Driver'`. Result code 2 (success) returned zero pending drivers. No update was downloaded or installed through WUA, and no source/policy setting was changed. This does not prove that a catalog package is incompatible; it does mean this search supplied no machine-specific offer validating either candidate. [Microsoft Search API](https://learn.microsoft.com/en-us/windows/win32/api/wuapi/nf-wuapi-iupdatesearcher-search).

## Gate before any test

Map the relevant board/port variants and CFU version/downgrade handling, seek exact-model qualification, and establish recovery before proposing deployment. Installing a Firmware-class updater may trigger persistent flash writes; removing its Windows driver is not a demonstrated rollback of those writes. The retained 1.3.0.2 package is an offered image, not a verified readback of the physical flash or a proven recovery mechanism. A test-boot copy does not isolate motherboard firmware.

No package was staged or installed, no updater DLL was executed, no CFU offer/output/reset was sent, and no firmware bytes were written. No change to Secure Boot, HVCI, BCD or networking was made. Native readback still shows TESTSIGNING off/HVCI running. The next investigation is offline variant and recovery analysis, rather than another unchanged attachment test. [Structured candidate evidence](../evidence/parade-cfu-candidates.json), [installed-image analysis](firmware-entry-followup.md).
