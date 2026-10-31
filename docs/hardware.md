# Hardware and comparison baseline

## Affected host

| Item | Observed configuration |
| --- | --- |
| Laptop | ASUS TUF Gaming A15, 2023, FA507XI |
| CPU / integrated graphics | AMD Ryzen 9 7940HS / Radeon 780M |
| Internal discrete GPU | NVIDIA GeForce RTX 4070 Laptop GPU, 8 GB |
| USB-C ports | One USB4 40 Gbps port; one separate USB 3.2 Gen 2 Type-C port |
| USB4 host | AMD PCI vendor `1022`, device `1668`; Microsoft `Usb4HostRouter` stack |
| BIOS | FA507XI.314; firmware-reported date 16 April 2024 |
| Current Windows | Windows 11 Pro 25H2, build 26200.9818 |
| Earlier Windows during testing | 26H2, builds 26300.9711 and 26300.9818 |
| Current USB4 host driver | 10.0.26100.9818 |
| Current host driver SHA-256 | `912EFBFCA273C62484DB952632EEB0D2B061BD7A1C830970FDA23CDB50BEEB1F` |
| Boot security | Secure Boot retained; test-signing disabled |

The USB4 capability is documented for this model. It must not be relabelled as a Thunderbolt 4-certified laptop. The internal RTX 4070 is not evidence that the eGPU has run out of PCIe lanes. No evidence obtained during this investigation establishes a lane-allocation failure.

The F2 firmware UI has no exposed USB4/PCIe tunneling switch on this machine. Absence of that switch does not establish lack of PCIe tunneling support.

## eGPU assembly

| Item | Configuration |
| --- | --- |
| Dock | Minisforum DEG2, USB4 v2 / Thunderbolt 5 and OCuLink |
| Dock controller | Intel JHL9480, per vendor specification |
| GPU | Gigabyte GeForce RTX 4080 SUPER WINDFORCE V2 16G |
| GPU product code | GV-N408SWF3V2-16GD |
| PSU | Cooler Master Elite Gold 1000 FM, MPW-A001-AFAG |
| GPU power | PSU's native 600 W 12V-2x6 cable |
| Dock power | ATX supply plus CPU/EPS 4+4 connection |
| Main cable | Detachable cable supplied with the DEG2 |
| Display | Arzopa portable display connected to the desktop GPU by HDMI in the working comparison |

The owner checked the power connections, PCIe seating, upstream connector/mode and all four USB-C plug-orientation combinations. Repeated connector manipulation was not treated as a substitute for evidence.

There is no confirmed GPU warning LED. A suspected red/orange reflection was subsequently attributed to room lighting. The exact momentary fan behaviour for this card was never independently verified. Fan inactivity alone is not a validated diagnostic for a dead card.

## Working Dell comparison

The assembled hardware produced HDMI output and accepted the NVIDIA driver on an Intel Thunderbolt 4 Dell laptop. Photographs of Windows USB4 settings supplied the following values:

| Field | Value |
| --- | --- |
| Windows | 25H2, build 26200.9711 |
| Host manufacturer/model | Intel / Gen12 |
| Host PCI device | `8086:A73E` |
| Host firmware | 23.3 |
| Host USB4 version shown | 1.0 |
| External router manufacturer | Micro Computer (HK) Tech. Ltd. |
| Router model | TBGAA |
| Router silicon vendor/product | `8087:5786` |
| Router silicon revision | 133 |
| Router firmware | 62.62 |
| Unit vendor/product/revision | `1161:5472`, revision 3 |
| Router USB4 version shown | 2.0 |
| Negotiated link | 40 Gbps down / 40 Gbps up, Gen 3 dual lane |

Host firmware 23.3 must not be confused with dock firmware 62.62. The router's reported firmware does not necessarily identify the separate USB Power Delivery controller firmware.

This is a working end-to-end comparison. It does not prove that the cable has identical signal margins or negotiation behaviour with an AMD host.

## Cable limitation

A second UGREEN Type-C cable was tried without a change. Its exact model, advertised data rate and length were not recorded. The owner subsequently checked the listing and reported that it was unsuitable for Thunderbolt. There is therefore no confirmed second suitable cable test. Lack of a Thunderbolt logo alone would not establish that a full-featured passive cable cannot support a lower-speed USB4 link; a USB 2.0/charge-oriented cable is a different case.

The Arzopa video cable was suggested as a possible free lower-speed experiment, but its availability, exact specification and result are unconfirmed. No known-good separate USB4 peripheral has yet been tested on this ASUS.

## Existing UGREEN dock

On 31 October 2026, the owner identified the existing UGREEN dock using Amazon UK ASIN `B0DRP1F6R7`. The product is the **UGREEN Revodok Pro 3121, SKU 55767**. The [manufacturer's product page](https://fr.ugreen.com/products/revodok-pro-3121-hub-usb-c-12-en-1) specifies a conventional 10 Gbps USB-C hub with DisplayPort Alt Mode video, rather than a USB4/Thunderbolt router.

Connecting this hub can check ordinary USB and USB-C display functions, but cannot establish USB4 link negotiation or PCIe tunneling. Because ordinary USB already works through the DEG2, this is a limited comparison for the missing external USB4 router. Identification of this hub does not supply the outstanding known-good second USB4 peripheral test; no new test result is claimed.
