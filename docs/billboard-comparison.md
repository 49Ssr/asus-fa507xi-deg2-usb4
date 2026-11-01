# DEG2's own USB4/DP report: ASUS versus Dell

**1 November 2026: new data recovered from both existing dumps, without a new boot, connection, device request or driver change.** DEG2 reports USB4 success on Dell and DP-mode success on ASUS. Its reported USB4 entry word is identical on both. This narrows the comparison but does not yet supply a Windows repair.

## What the device reports

The same VID/PID `041f:d002`, revision `8200`, is present in both snapshots, including the working Dell. A Billboard-capable device's presence alone must not be used as the failure criterion.

Both cached BOS descriptors are 112 bytes with six capabilities. Exactly **one byte differs**, BOS offset 40: ASUS `35`, Dell `17`. That is the first byte of the Billboard configuration bitmap. Other bytes, including all three AUM data words, match.

| Device-reported field | ASUS | Dell |
| --- | --- | --- |
| USB4, SVID `ff00`, mode 0 | Code 1: not attempted or exited | Code 3: successful |
| Thunderbolt, SVID `8087`, mode 0 | Code 1 | Code 1 |
| DisplayPort, SVID `ff01`, mode 0 | Code 3 | Code 1 |
| USB4 AUM word / reported EUDO | `2087e000` | `2087e000` |
| Thunderbolt AUM word | `00000001` | `00000001` |
| DP AUM word | `401c0045` | `401c0045` |
| Billboard revision / preferred index | 1.2.2 / 0 | 1.2.2 / 0 |
| Additional failure byte | `00`; valid for preferred mode | `00`; preferred mode succeeded, so not interpreted |

The Windows trace labels configuration code 1 as `Alternate Mode Failed`. Preserve that raw label, but its precise Billboard meaning is **not attempted or exited**, rather than proof of an attempted entry that was rejected. Code 2 is the distinct unsuccessful-attempt state. The additional ASUS flags for insufficient power and absent PD communication are clear; that is not proof that either subsystem is fault-free.

These meanings and the USB4 AUM word's EUDO role were checked against USB-IF Billboard 1.2.2 tables 3-7/3-9, including visual inspection. [Official specification package](https://www.usb.org/sites/default/files/USB%20Billboard%20Rev%201.2.2%2020210209.zip).

**Limit:** this is a device-provided cached report, not a CC-wire capture. It does not establish the word's freshness, whether it is a firmware template, when Enter_USB was sent, whether Accept was received, or whether entry was followed by an exit. Successful entry also does not guarantee subsequent operation.

The EUDO decodes to USB-mode code 2 and cable-speed code 4 on both hosts, with PCIe/DP/TBT support bits set. The decoder retains the speed numerically: it is not the host's negotiated rate. An interpretation that this word is uniquely malformed on ASUS is contradicted by the identical working Dell report. [Primary EUDO field definitions](https://chromium.googlesource.com/chromiumos/platform/ec/+/master/include/usb_pd_vdo.h).

## Power comparison from the existing traces

Both machines receive the same four source PDOs from DEG2:

| Source object | Raw word | Fixed profile |
| --- | --- | --- |
| 1 | `2f81912c` | 5 V / 3 A |
| 2 | `0002d12c` | 9 V / 3 A |
| 3 | `0004b12c` | 15 V / 3 A |
| 4 | `000641e0` | 20 V / 4.8 A |

ASUS's RDO `1384b12c` selects object 1 at an operating request of 3 A; Dell's `438781e0` selects object 4 at 4.8 A. These are reported requests, not measured charging power. Both RDOs set USB-communications capable and clear capability mismatch. ASUS reports the same source list twice around role correction; Dell reports it once. The later zero-length PDO reply terminates pagination; it does not mean the four preceding profiles were absent. [PDO/RDO units](https://raw.githubusercontent.com/torvalds/linux/master/include/linux/usb/pd.h).

Voltage remains a variable, not a demonstrated cause. ASUS's exact FA507XI specifications separately list USB4/DP and USB3.2/DP/power-delivery ports. That does not justify forcing a 20 V contract on USB4 or assuming removing barrel power will reproduce Dell's contract. No such test or request was issued. [ASUS specifications](https://www.asus.com/laptops/for-gaming/tuf-gaming/asus-tuf-gaming-a15-2023/techspec/).

## Reproduce the decoding

[Decoder](../tools/analysis/Decode-USB4Billboard.py), [ASUS bytes](../evidence/fixtures/deg2-asus-bos.hex), [Dell bytes](../evidence/fixtures/deg2-dell-bos.hex), [structured evidence](../evidence/billboard-comparison.json).

From the repository directory:

```text
python tools/analysis/Decode-USB4Billboard.py --hex evidence/fixtures/deg2-asus-bos.hex evidence/fixtures/deg2-dell-bos.hex
python -m unittest discover -s tests -p test_billboard_decoder.py -v
```

The tool reads saved files only. It checks descriptor boundaries/counts, revision, mode indexes and duplicate extensions; it preserves missing data and invalid versus valid-zero failure fields. Four tests cover the actual comparison, all configuration meanings, missing extensions and eleven malformed inputs. Independently, both fixtures were compared byte for byte against their respective debugger readouts. Neither fixture contains a nonzero container ID, serial, memory address or machine identity. Raw dumps/readouts stay private.

The reader loaded matching USBHUB3 symbols (PDB `8F8CCE9FDDEB56AB3E1D5F3E67FC273F`, age 1) and identified the device through the USB tree. Dump hashes, lengths, snapshot times, readout hashes and decoded-input hashes are in the evidence file. Header snapshots are ASUS 00:53:54.969 and Dell 00:20:19.337 UTC on 1 November. Missing unrelated pages/image warnings remain in the private logs; the BOS bytes themselves were readable. No live debugger or bus transaction was used.

## Consequence for a Windows fix

Together with the [matched root-port observations](asus-dell-matched-comparison.md), this places the unresolved boundary around USB4 discovery/entry, exit and lane configuration before an external router becomes usable. The report cannot choose among those causes. It does not identify a PCIe-authorization or NVIDIA-driver problem.

The [role-policy trial](role-policy-test-result.md) already changed the intended Windows consumer without enabling USB4. The [retimer lifetime bug](i2c-read-prerequisites.md) is separate and is not established as the DEG2 cause. Changing a Billboard status, suppressing the warning, forcing an unsupported CAM or changing the EUDO in a host cache would not change negotiation.

**No state-changing Windows test is queued.** The next intervention needs the actual ASUS EC/PD/mux control that implements entry or exit, evidence that Windows can reach it, and a restoration path for that exact state. That control remains unidentified. Another generic capture, blind boot or guessed speed/firmware write would not close this gap.
