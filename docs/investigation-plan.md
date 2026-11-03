# Diagnosis plan

Updated 3 November 2026. The goal is a working ASUS–DEG2 connection. The immediate problem is choosing between a pairing-specific negotiation problem, a broader ASUS peripheral problem, and a cable/link interaction. The current evidence does not select one.

**The best next hardware comparison is another known-working USB4 PCIe device on ASUS. With only the existing hardware, the best code lead is the acquired IT8857 vendor tool's controller-access path.** These are recommendations based on the [findings](status.md), not new measured results. No new hardware operation is prepared by this page.

## 1. Find out whether ASUS can use another PCIe peripheral

Borrow a known-working USB4/TB enclosure or dock that exposes a PCIe device. A native USB4 device is the closest control; record the actual connection mode if using a Thunderbolt-compatible device. The existing UGREEN USB 3.2 hub cannot answer this question, and the working ASUS–Dell peer link does not exercise PCIe tunnelling.

| Result on ASUS | Consequence |
| --- | --- |
| External router and PCIe device both appear | Concentrate on DEG2 compatibility and the cable/entry sequence used by that pairing |
| External router appears, but PCIe device does not | Investigate the separate tunnel/authorization problem for that device; this is later than DEG2's observed failure |
| No external router appears | A broader ASUS peripheral-entry problem becomes more plausible; confirm the borrowed assembly works elsewhere before drawing that conclusion |

Use the borrowed device's known-working cable first. If it works, try DEG2 with that cable as a separate comparison. This avoids changing the device and cable together and then attributing the result to one of them.

A second useful control is DEG2 on another AMD USB4 host. Success would narrow the problem toward this ASUS platform or unit; failure would motivate a wider compatibility comparison. One additional AMD host cannot establish an AMD-wide defect. Manufacturer/router firmware, actual link mode and cable identity matter more than the CPU brand alone.

These comparisons need borrowed hardware. They are worth pursuing alongside code work rather than waiting for reverse engineering to finish. A second suitable cable alone is also useful: success on Dell does not exclude an ASUS-specific interaction. The unsuitable UGREEN cable previously tried was not that control. [Hardware and prior cable checks](hardware.md).

## 2. With existing hardware: audit the IT8857 read path

The photos corrected the target to IT8857FN. An official ASUS package already acquired for a different board contains an IT8857 tool with an advertised version-only option. Audit that path without running the updater:

1. Follow program startup and the version-only branch through transport selection to the controller transaction. Record any writes performed before the read, including initialization.
2. Identify the bus/address conventions and how the tool selects a controller. Compare them with the recovered FA507XI EC relay. Equal channel numbers do not establish the same bus.
3. Determine whether that transport can be reached from Windows through an existing interface. If it cannot, record the missing interface explicitly; do not turn a UEFI recipe into a Windows command by analogy.
4. If a current controller read becomes possible, identify exactly what it returns. A B6 firmware version may help identify the program, but it will not reveal the failed entry sequence. A useful follow-on must expose current state or a log whose meaning is documented or recovered from the matching implementation.

The deliverable is a traced read path and an answer about Windows access, including side effects and missing pieces. It is **not** another search for the same firmware strings or another read of the existing `00 53` cache. [Acquired tool and cache semantics](pd-firmware-version.md) · [Known Windows interfaces](windows-repair-route.md).

This audit may establish that the available route cannot supply the required record. That is an access limit, not proof that USB4 cannot be repaired. The exact laptop PD image is still missing; reference firmware for another board is not a substitute.

## 3. Ask for the information the vendor can actually supply

The useful ASUS engineering request is specific: confirm the fitted IT8857/PS8830 firmware versions for this board, whether an applicable PD or retimer update exists, and whether a supported diagnostic records USB4 entry and the applied retimer state. Include the Dell success, ASUS Linux failure, working ASUS peer link and physical chip correction.

Minisforum can independently confirm DEG2's PD-controller identity, firmware/diagnostic interface and known compatibility with this ASUS/AMD platform. Its reported router firmware is not necessarily the PD firmware. A firmware package or documented logger would be more useful than another generic reinstall recommendation. These are proposed requests; nothing has been sent by this plan.

## The observation that would choose a repair

| Missing observation | What it could distinguish |
| --- | --- |
| Controller entry decision plus partner/cable discovery | Why entry was not requested, or why a different mode was selected |
| Entry request and reply | Omitted request versus rejected request; for native USB4 this includes Enter_USB |
| Applied PS8830 mode/orientation plus an independent training result | Incorrect requested routing versus failure after the intended configuration |
| First link success followed by exit/power events | A connection that was established and then lost |

Do not assume that the host's UCSI log is a physical PD transcript, that a cached Billboard word is the last packet, or that a retimer configuration bit proves link training. Native USB4 and Thunderbolt compatibility paths also need to be distinguished. [Component semantics](component-behavior.md) · [Dock report](billboard-comparison.md).

A software route could be sufficient if the controller exposes those records. None is established yet. A PD protocol analyser would observe the negotiation directly, but would not by itself prove the ASUS retimer's applied configuration. The current hardware inventory contains no identified raw PD recorder.

## Where Data_Reset fits

Data_Reset is a plausible recovery experiment if ASUS leaves USB4 discovery unfinished after correcting the data role. It is not yet a diagnosed remedy. The Windows-to-EC relay is understood; the receiving laptop controller's reset interpretation is not. The same UCSI bit has different meanings across versions.

Before building a sender, identify the actual handler or a documented command for this firmware, its completion behaviour, and recovery from interruption. The test would then ask whether the external router appears after that one operation, while recording role and link changes. A successful request alone would not count as a repair. [Command-path evidence](data-reset-command-path.md) · [Reset hypothesis](ucsi-data-reset.md).

## Work that does not currently justify another test

- All four plug orientations, powered preconnection, the peer-to-DEG2 handoff and the policy-only driver trial have already been tried. The Rp-only test did not establish attachment. Repeating them needs a genuinely different condition. [Results](experiments.md).
- An unchanged ASUS Linux or Dell Windows capture would not add the missing controller record. Dell USB boot is unavailable on the work laptop.
- RT1 is the other host instance; the stored USB4/TBT3 enable fields are already enabled. A settings menu alone would not show the applied controller state.
- GPU-driver work addresses a later stage. The observed blocker is external-router discovery.
- Generic I2C scans, guessed vendor requests and unrelated firmware images do not identify the failed transition.
- More reference-code fixtures are useful only when they resolve a question about the actual proposed read or command. They are not new measurements of this laptop.

Scheduling remains paused. Physical tests, reboots and configuration changes remain owner-directed. The [handoff](handoff.md) records the outstanding recovery check separately from the USB4 diagnosis.
