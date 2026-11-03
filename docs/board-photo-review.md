# Board photographs: IT8857FN identified, PS8830 A3 confirmed

**The fitted ITE package reads IT8857FN.** Two clear close-ups independently show that marking. The previous `IT8853` result was an accurately captured response from an EC getter that returns a literal string; it did not read the chip's silicon identity. This changes which controller reference we should prioritize. It does not invalidate the traced EC mailbox, cache getters or recorded failures. [Structured evidence and photo hashes](../evidence/board-photo-review.json).

## What the photographs show

Twenty-five owner photographs were reviewed on 3 November 2026. Overlapping views connect the close-ups to board locations. Originals remain unchanged and private; the public record uses photo IDs and hashes. No byte-identical duplicates were found, and repeated subjects were retained.

| Visible part | Clearest photographs | Function and scope |
| --- | --- | --- |
| **ITE IT8857FN**, package lines `2302-DXG`, `A1DCHA` | P15, P21; context P08/P22 | Physical PD-controller part identification. Exact firmware and EC-bus binding remain unverified. |
| **Parade PS8830 A3** | P20; context P10/P19/P22 | USB4 retimer, now independently confirmed by its marking. A3 is package text, not a measured firmware version. |
| **Parade PS8802 A3** | P18; context P19/P22 | Separate USB-C 10 Gbps switch/retimer; do not mistake it for PS8830. |
| **Parade PS8419 A1** | P17; context P10/P22 | HDMI retimer; proximity to the USB-C area does not make it a USB4 controller. |
| **PI3DPX8121**, split marking `PI3DPX8` / `121ZLDE` | P16; context P08 | DisplayPort mux/redriver near the eDP connector. |
| Separate ITE package marked **8308FN** | P15; context P08 | Its function was not qualified in this review; it is a different package from IT8857FN. |

Function references: [Parade PS8830](https://www.paradetech.com/products/ps8830/), [PS8802](https://www.paradetech.com/products/ps8802/), [PS8419](https://www.paradetech.com/products/ps8419/), and [Diodes PI3DPX8121 product brief](https://www.diodes.com/assets/Databriefs/PI3DPX8121-Product-Brief.pdf). Locations come from the owner's overlapping photographs, not these generic product pages. Still photographs do not establish every multilayer net or exact per-port ownership.

## What changes in the firmware investigation

ITE's 24 September 2026 vendor binding submission explicitly includes IT8857 in its software-compatible UCSI family and describes it as a two-connector part. [Original submission, readable archive mirror](https://lore.landau.one/lkml/20260924-ucsi-itepd-it527x-v3-1-a7392aa087f5@ite.com.tw/T/), [canonical message](https://lore.kernel.org/linux-usb/20260924-ucsi-itepd-it527x-v3-1-a7392aa087f5@ite.com.tw/).

That makes the **already-acquired IT8857 USB4-card reference** more relevant to the fitted part than the older hardware-name assumption. It remains firmware for another board. Family compatibility does not establish ASUS's installed build, configuration, reset behavior or updater transport. Neither the photograph nor the binding turns that image into a laptop flash candidate. [Acquired references and cached0053](pd-firmware-version.md).

Continue by comparing the IT8857 reference and vendor UCSI implementation against the exact laptop EC relay and firmware. The earlier `IT8853` bytes, failed telemetry attempts and original-code results stay in the evidence trail with this correction attached. No live command, reset, updater or boot was performed for the photo review.

## What remains unknown

The visible labels do not establish the motherboard assembly/revision, an external PD firmware-memory part, the installed PD program or the failed negotiation state. Nearby eight-pin packages must not be called firmware flash from shape alone. No working repair is demonstrated.

[Hardware baseline](hardware.md) · [EC getter and relay](ec-firmware-decision.md) · [Current findings](status.md)
