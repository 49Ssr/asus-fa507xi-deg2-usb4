# Diagnosis plan

Updated 3 November 2026. The goal is a working ASUS–DEG2 connection. The immediate problem is choosing between a pairing-specific negotiation problem, a broader ASUS peripheral problem, and a cable/link interaction. The current evidence does not select one.

**The best next hardware comparison is another known-working USB4 PCIe device on ASUS. With only the existing hardware, the next code question is whether ASUS's EC exposes a current PD read to Windows; the acquired IT8857 tool's access path has now been traced.** These are recommendations based on the [findings](status.md), not new measured results. No new hardware operation is prepared by this page.

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

## 2. With existing hardware: follow the laptop EC command path

The [IT8857 tool audit is complete for its selected version path](it8857-version-path.md). It reads B6 after reconfiguring a CPU-visible I²C controller. Its address conversion agrees with the ASUS EC's normal address convention, but it supplies no established Windows route to the laptop's EC-controlled bus. Running that updater is not the next step.

Trace the FA507XI EC host-command dispatcher for an implemented current PD read or transfer through the already-recovered bus engine. Determine whether Windows can invoke that specific handler through an existing driver. Internal periodic callers, cached getters and the stubbed table 6 request must remain distinct.

The useful result is an exact reachable read, or a clear account of which exposed handlers cannot provide it. A fresh firmware version could help identify the controller program; it would not itself reveal USB4 entry. Any subsequent state/log reader must identify what it observes and whether reading consumes an event or changes state. [Known Windows interfaces](windows-repair-route.md).

This is an access investigation. It does not make another board's PD image suitable for the laptop, and it does not displace the hardware comparisons above.

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
