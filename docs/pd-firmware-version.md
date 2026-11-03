# PD firmware: Windows version read and recovered ASUS references

**Windows returned controller-derived cached bytes `00 53`.** The implemented ASUS getter works. This is different from the fixed EC UCSI version and the retained Windows `ffff` field. It is not a live flash readback or a verified match to a firmware image. [Structured evidence](../evidence/pd-firmware-version.json).

## Physical chip identity, added 3 November 2026

Owner photographs now identify **IT8857FN**, not the literal `IT8853` returned by the EC diagnostic. This strengthens the reason to examine the already-acquired IT8857 reference while preserving its different-board limit. The cached `0053` read does not become a current flash-image match. [Photo evidence](board-photo-review.md).

## What was read

The existing signed ASUS driver returned API version `00010001`, capability 17, then two successful one-byte replies through command DD/table5/selector1:

| Field, hex | EC cache byte | Value | Driver transport status |
| --- | --- | --- | --- |
| `10` | `02ac` | `00` | 0 |
| `11` | `02ad` | `53` | 0 |

The device handle closed and the temporary SYSTEM task was removed. No driver was installed, no controller reset was sent, and the getter requested no direct PD-bus read. These were three EC requests including the capability control, plus a non-hardware API-version control. The raw private record calls the transport status `EcStatus`; it is not a PD-wire status.

Original ASUS code at bank3 `b800` reads controller register `b6` into this cache. Its successful read replaces both bytes; a failed refresh retains the old cache. Offline execution checks both outcomes and the two getter paths. **Freshness is therefore unverified.** Preserve the raw word `0053`; its decimal/BCD display convention and exact firmware-image identity are not established.

**Correction:** earlier notes assigned these cache bytes to fields `0f/10`. The original switch table and executed getter paths establish **`10/11`**. Field `0f` is a different branch. The incorrect draft stopped in offline checking; it was not sent to the device. A separate launch-wrapper type-name error stopped before staging or a device open; both failed attempts remain private.

## Real ITE firmware recovered from ASUS

ASUS's Z790-E support API links `ASUS_PD_update_tool_V004.zip`. Its updater embeds `ASUS_Expresso_IT8853_V004.bin` as a 63,682-byte PE resource. The package and resources were extracted without executing the updater. The outer executable is unsigned; origin is the official ASUS download endpoint, and local hashes are retained. It is **different-board reference firmware**, not an identified FA507XI image or a flash candidate. [Official package](https://dlcdnets.asus.com/pub/ASUS/mb/LGA1700/ROG_STRIX_Z790-E_GAMING_WIFI/ASUS_PD_update_tool_V004.zip).

The embedded Windows helper's firmware-version routine constructs a `b6` transaction and obtains a two-byte result, then prints a firmware version. The reference PD image also populates `b6/b7`. This supports treating ASUS's cached word as firmware-version metadata, without proving that the different-board implementation is identical or that the cache is current.

Candidate command-dispatch tables were found in the ITE image. Their command numbers alone do not identify a UCSI or Data_Reset handler. Several helpers consume inline data, so a linear disassembly must not interpret every following byte as an instruction. **The actual FA507XI Data_Reset handler remains unidentified.**

## ASUS also supplies a UEFI version interface

The official USB4 PCIe Gen4 card package labelled for Linux contains `PDUTC101.efi`, a shell and an IT8857 firmware image. The download matches ASUS's published SHA-256. Its help advertises `/ov` for showing the PD firmware version without updating it. This is a concrete vendor interface to investigate. [ASUS package listing](https://www.asus.com/uk/supportonly/usb4%20pcie%20gen4%20card/helpdesk_bios/).

It has not been executed or fully audited. The supplied recipes target an add-in card and other platforms. Its bus index is not established as the laptop EC's channel with the same number, and its slave address differs from the recovered laptop path. A version-only option does not establish that initialization or transport selection is suitable here. No boot or use of those recipes is selected.

## Where the laptop image search stands

The current exact-model driver listing exposes the known Parade retimer package; the firmware listing exposes touchpad updates. The signed Windows BIOS 314 installer was also extracted. Its capsule is byte-identical to the analysed EZ Flash capsule, and its listed contents contain no separate PD image.

A search of 4,909 binary inputs, including the capsule and extracted artifacts, covered 96,605,466 bytes using selected ITE-reference strings, a register-writer sequence and a candidate table layout. None matched. That does not exclude a different, compressed or differently built controller image. The exact laptop PD firmware is still unbound; the evidence does not justify calling it absent.

## Continue from these results

Correlate raw cached word `0053` with an exact laptop image or a documented current-controller read. Audit the vendor version-only path and its transport separately. Follow the receiving reset handler once its identity is established; do not assign the SDK's semantics or another board's binary to this laptop. Another generic dump or unchanged boot has no identified role in that work.

The [cache test](../tools/analysis/Test-PdVersionCache.c) is an offline original-instruction test using private, hash-pinned BIOS data. It has no live device backend. Firmware, updater binaries, raw memory and identifying receipts remain private.

[Command path](data-reset-command-path.md) · [Reset hypothesis](ucsi-data-reset.md) · [Current findings](status.md)
