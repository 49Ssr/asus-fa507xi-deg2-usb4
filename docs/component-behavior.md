# Chip controls: what we can read and what a result would mean

**The useful targets are the IT8857FN controller decision and the PS8830 mode/orientation, followed by an independent link result.** Component documents help identify those records. They do not supply a verified FA507XI electrical schematic or automatically connect a Windows program to the chip.

[Physical chip identification](board-photo-review.md) · [Source hashes and results](../evidence/component-behavior.json)

## Documentation reviewed

| Fitted part | Available reference | What it tells us |
| --- | --- | --- |
| IT8857FN | [ITE vendor UCSI implementation](https://lists.openwall.net/linux-kernel/2026/08/07/804), [family binding](https://lore.landau.one/lkml/20260924-ucsi-itepd-it527x-v3-1-a7392aa087f5@ite.com.tw/T/), acquired different-board firmware | Actual command, completion, event and version register semantics in the reference family. Exact laptop program and electrical binding remain unknown. |
| PS8830 A3 | [Manufacturer block diagram](https://www.paradetech.com/products/ps8830/), [pinned Linux driver](https://github.com/torvalds/linux/blob/46fec1c3029b552ec63b2d01af9d43a386f043ea/drivers/usb/typec/mux/ps883x.c) | Separate platform/PD control connections and software-written mode/orientation inputs. This is not a complete chip datasheet or the ASUS board wiring. |
| PS8802 A3 | [Manufacturer description](https://www.paradetech.com/products/ps8802/), [Chromium EC registers](https://chromium.googlesource.com/chromiumos/platform/ec/+/08f5a1e6fc2c9467230444ac9b582dcf4d9f0068/driver/retimer/ps8802.h), [reader](https://chromium.googlesource.com/chromiumos/platform/ec/+/08f5a1e6fc2c9467230444ac9b582dcf4d9f0068/driver/retimer/ps8802.c) | Separate status and mode fields, plus explicit wake behavior during reads. This is the 10 Gbps USB-C part, not USB4 link telemetry. |
| PS8419 A1 | [Parade product page](https://www.paradetech.com/products/ps8419/), manufacturer datasheet v0.9 publicly hosted by TI | HDMI pinout and physical configuration/local-I2C controls. It does not explain a missing external USB4 router by itself. |
| PI3DPX8121 | [Manufacturer brief](https://www.diodes.com/assets/Databriefs/PI3DPX8121-Product-Brief.pdf) | DisplayPort mux/redriver with pin-selected settings. ASUS ownership of those pins remains unknown. |
| PI3CH480 | [Manufacturer datasheet](https://www.diodes.com/assets/Datasheets/PI3CH480.pdf), DS40329 rev5-2 | Four-channel switch controlled by physical enable/select inputs. Its truth table is not a register interface for a scanner. |
| Separate ITE8308FN | Owner marking | No authoritative matched function/register document was obtained in this review. Keep its role unknown. |

The PS8419 reference is a manufacturer-authored 22-page document dated 12 April 2020. Its [public TI-hosted copy](https://e2e.ti.com/cfs-file/__key/communityserver-discussions-components-files/138/PS8419_5F00_DS_5F00_Version0.9_5F00_20200412.pdf) carries restricted-distribution markings; the downloaded file and rendered pinout remain private. None of these sources is a verified full FA507XI circuit diagram.

## Registers with useful, distinct meanings

| Component | Reference field | Meaning and limit |
| --- | --- | --- |
| ITE | `80`: UCSI version | Reports the interface version in the vendor implementation. ASUS's EC-initialized mailbox value and cached PD firmware word are different records. A version alone does not prove a specific reset handler. |
| ITE | `84`: completion; `88`: message input | Command response, not a complete physical PD transcript. |
| ITE | `98`: control; `bd`: event; `bc`: event acknowledgement | The reference event handler reads a result and then writes an acknowledgement. Running it independently beside the OS would consume shared events. These are register indices, not interchangeable Windows commands or bus addresses. |
| PS8830 | `00..02`: connection configuration; byte2 bit7 requests USB4 | The reference driver writes these fields. A readback could establish requested configuration after the ASUS interface is matched. It would not independently prove accepted entry, CDR lock or a trained USB4 link. |
| PS8802 | Page0 `72`/`76`: transmit/receive status | The public header defines normal-operation bit7 and 10 Gbps bit5. These are distinct from its software mode settings and cannot report USB4 operation. |
| PS8802 | Page2 `06`: mode; bits6/4/2 enable DP/USB/flipped orientation | The original reader uses this register to wake the chip before reading the mode. Its current ASUS value has not been acquired. |

## The read path has behavior of its own

The pinned PS8802 reader was compiled from its original C function bodies with simulated bus, power and timer inputs. It refuses a read while the fixture reports hard-off. An awake query performs a wake read followed by a mode read. A first-read failure is followed by a requested 500 microsecond delay and retry; repeated or final mode-read failures propagate as errors. This is reference-code execution, not an ASUS timing or register measurement.

[Test-Ps8802ReadBehavior.py](../tools/analysis/Test-Ps8802ReadBehavior.py) takes the hash-pinned upstream C/header and compiles those functions against RAM-only fixtures. It has no hardware or network backend. A mismatched input is rejected before compilation. No firmware or upstream source file is bundled into it.

This matters when choosing a capture: a PS8802 read may wake it, and an ITE event routine acknowledges events. A generic scan would not have the passive behavior needed to observe an untouched connection.

## The IT8857 reference adds a concrete version writer

The already-acquired USB4-card image contains a writer at file offset `7a98` that places `01` and `10` at XDATA `00b6/00b7`. That adds an IT8857 example to the B6 version-metadata evidence. The ASUS cache returned `00 53`; freshness, display encoding and exact program identity remain unverified. The reference's part family now matches the photographed chip, while its board firmware remains different. [Version acquisition](pd-firmware-version.md).

## What would make a useful Windows capture

The missing observations are current PD-reported interface/state information, requested PS8830 mode/orientation, and a separate entry/response or physical-link result. Their order matters: a correct mode setting with failed training is different from never requesting USB4.

The existing ASUS OEM getters supply a fixed name and a firmware cache. The attempted dynamic getter is a firmware stub. The retained updater-interface NACK did not yield a mode or training record. The updater endpoint has not been proved equivalent to the runtime control interface shown in the reference diagrams.

**No executable Windows acquisition for these missing records is ready yet.** The next code question is to bind an actual ASUS transport to the IT8857 version/status window or the PS8830 runtime mode window, including read side effects and ownership. That is the concrete gap to investigate; another unchanged boot, mode override or blind bus scan would not fill it.

No live controller request, driver installation, reset, flash, BIOS operation or cable change was performed during this review.

[Current findings](status.md) · [Windows access routes](windows-repair-route.md) · [Current plan](investigation-plan.md)
