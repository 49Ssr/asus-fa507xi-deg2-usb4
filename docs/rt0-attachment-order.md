# RT0: what succeeds before USB4 fails

The saved ASUS trace confirms a working USB host connection after Windows corrects the data role. It also binds that connection to connector 1 and RT0. The missing operation remains USB4 entry or link establishment; successful ordinary USB enumeration does not identify which of those failed.

## The port is now tied to the controller

Original ACPI gives UCSI child CR01 and both XHC3 companion ports identical physical-location descriptors: group token 0, group position 1. CR02 and XHC4 use position 2. Microsoft's [pinned sample](https://github.com/microsoft/Windows-driver-samples/blob/f4c1ff842b6a0001152f44cb61788b216a1c7627/usb/UcmTcpciCxClientSample/Sample.asl#L55-L76) explains how these fields correlate a Type-C connector with its xHCI ports.

The existing ASUS ETL independently reports UcmConnectorId=1 for DEG2's newly enumerated devices on PCI function 3. Its root-port rundown identifies USB2 port 1 and USB3 port 2 as the same connector. The previously checked ACPI USB4 association and AMD connection records complete the mapping:

`connector 1 / CR01 -> XHC3 -> NHI0 -> RT0`

`connector 2 / CR02 -> XHC4 --conditional ACPI dependency--> NHI1 / RT1`

Rechecking the complete original scopes corrected one earlier detail: XHC3 has the explicit USB4 `_DSD` association; the selected XHC4 scope has a conditional `_DEP` reference to NHI1. The older RT1 evidence overstated that second association. Its separate RT1/function6/NHI1 identification remains supported. This does not alter the tested RT0 mapping.

This supports the connector-1 targeting of the earlier tests. It supplies no reason to repeat them with another connector number or enable RT1.

## Existing traces, aligned by events

Times below are UTC on 1 November 2026, from separate recorded attachments. They are software observations, not a PD packet capture or physical-insertion clock.

| Observation | Failed ASUS attachment | Working Dell attachment |
| --- | --- | --- |
| First reported partner DFP, Type-C current mode | 00:52:16.9317051 | 00:17:44.7184193 |
| First PD partner report | DFP, 00:52:17.0075650 | UFP, 00:17:44.9977521 |
| First reported PD partner UFP | 00:52:17.2060961, after Windows SET_UOR | 00:17:44.9977521, without recorded Windows SET_UOR |
| First native router-detection decision | **No**, 00:52:17.0830516 | **Yes**, 00:17:45.0348339 |
| Windows role-correction decision | Yes, 00:52:17.1299775; request completes 17.1631249 | No, 00:17:45.3105086 |
| Successful enumeration of DEG2 SuperSpeed hub 8087:5787 | 00:52:17.8444045 | 00:17:45.7334882 |
| Successful enumeration of Billboard 041f:d002 | 00:52:18.7435261 | 00:17:47.1882700 |

USBHUB3 event 61 reports successful enumeration; event 43 then supplies the device identity and parent relationship. Matching both identifiers and the port avoids confusing neighbouring hub operations. Event 43 can arrive substantially later than enumeration completion, as the Dell trace demonstrates. Its timestamp must not be treated as when the device first became usable.

On ASUS, the successful SuperSpeed-hub enumeration follows the UFP report by about 638 ms. The saved hierarchy also includes DEG2's downstream hub, UAS storage bridge and network controller. Ordinary USB working was already known; the additional evidence is its timing, exact identity and connector binding.

## What this removes, and what remains

ASUS is not permanently stuck in the USB device role in this attachment. Host enumeration succeeds. The earlier successful role request therefore has a later, independent consequence visible in the USB stack. This still does not measure the physical DR_Swap transaction or prove how firmware configured PS8830.

Dell's reported role transition precedes successful router detection. ASUS's first negative router decision precedes its Windows role correction. A timing-dependent entry failure remains plausible, but these records do not establish whether Enter_USB was omitted, rejected, accepted with failed training, or followed by an unobserved exit. The existing policy-only trial did not repair the failure and cannot reproduce Dell's firmware sequence.

The USBHUB3 rundown also contains zero capability fields with **UsbCPortCapabilitiesValid=0**. These are unavailable capability data, not evidence that USB4, PCIe tunnelling or the retimer is disabled. They are not a setting to flip.

The repair target is the controller's USB4-entry decision and resulting mode/training state across that role transition. A useful Windows operation must expose or affect that specific state. No such operation or working repair was established by this analysis.

[Exact source hashes, original ACPI anchors, extracted records and limits](../evidence/rt0-attachment-order.json). Both ETLs and all failed attempts remain private and unchanged. No live device request, setting, driver, boot, cable or network change was made.
