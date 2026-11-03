# Diagnosis plan

Updated 3 November 2026. The goal is a working ASUS–DEG2 connection. The immediate problem is choosing between a pairing-specific negotiation problem, a broader ASUS peripheral problem, and a cable/link interaction. The current evidence does not select one.

**The next comparison using existing hardware is the Arzopa monitor cable: first prove it can run DEG2 on Dell, then try the same assembly on ASUS.** The cable has not been tested for this purpose. Another known-working USB4 PCIe peripheral remains the stronger comparison if one can be borrowed. More reference-code analysis should have a specific connection to a reachable laptop read or command; it is not the default next action.

## Current work while the owner is away

The [DEG2 read review](windows-repair-route.md#deg2-firmware-inventory-versus-negotiation-capture) traced the compiled reference status/identity handlers and flash getter. They supply firmware inventory or retained faults, not a negotiation transcript. Infineon identifies a separate TB5 Dock SDK available by access request; the acquired Host SDK is not that package. Review the TB5 dispatcher/logging implementation or a matched Minisforum package next. No DEG2 vendor request or Windows fix is established. The cable comparison remains pending; no remote reboot or attachment change is selected.

## 1. Try the existing monitor cable on Dell, then ASUS

The Arzopa USB-C video cable is a candidate, not a known USB4 cable. Its remembered charging capability does not establish its data capability. USB-IF's [cable compatibility table, slide 24](https://www.usb.org/sites/default/files/D1T1-2%20-%20USB%20Type-C%20System%20Overview.pdf) includes full-featured passive USB 3.2 Gen1/Gen2 cables for USB4 at 20 Gbps. That does not identify this cable's construction, electronics or supported speed.

When the owner is present:

1. Confirm DEG2 still works on Dell with the original cable and current dock/GPU setup. Keep the laptop's normal power supply attached.
2. Disconnect only the upstream connection and substitute the Arzopa cable on the same Dell port. Keep DEG2, GPU, power and display unchanged. Check for the external router and RTX 4080 SUPER, not just dock USB ports. Record the connection mode and speed if Windows exposes them; leave unknown fields unknown.
3. If the GPU connection works on Dell, move that same dock/cable assembly to ASUS's previously tested USB4 port. Keep ASUS on barrel power. Record router presence, GPU detection and display output separately. Do not add a reset, driver change or power-cycle experiment to this cable comparison.
4. Return to the original cable afterwards. No software setting is changed by this comparison.

| Outcome | What it means |
| --- | --- |
| Original cable no longer works on Dell | The working control has changed; resolve that before comparing cables |
| Original works on Dell, Arzopa does not | This candidate cannot provide the intended comparison; its failure says nothing new about ASUS |
| Arzopa works on Dell and ASUS | A cable-dependent connection difference is established; this may provide a usable connection, but does not prove the original cable is universally faulty |
| Arzopa works on Dell, ASUS still has no external router | ASUS fails with a second cable that operates this dock elsewhere; entry versus link-training failure remains unresolved |
| ASUS gets an external router but no GPU | The connection progressed beyond the previous observation; investigate PCIe discovery separately |

A working 20 Gbps connection would still be useful for detection. Do not assume 40 Gbps or infer transfer performance from display output. This comparison is pending; no result is claimed.

## 2. Find out whether ASUS can use another PCIe peripheral

Borrow a known-working USB4/TB enclosure or dock that exposes a PCIe device. A native USB4 device is the closest control; record the actual connection mode if using a Thunderbolt-compatible device. The existing UGREEN USB 3.2 hub cannot answer this question, and the working ASUS–Dell peer link does not exercise PCIe tunnelling.

| Result on ASUS | Consequence |
| --- | --- |
| External router and PCIe device both appear | Concentrate on DEG2 compatibility and the cable/entry sequence used by that pairing |
| External router appears, but PCIe device does not | Investigate the separate tunnel/authorization problem for that device; this is later than DEG2's observed failure |
| No external router appears | A broader ASUS peripheral-entry problem becomes more plausible; confirm the borrowed assembly works elsewhere before drawing that conclusion |

Use the borrowed device's known-working cable first. If it works, try DEG2 with that cable as a separate comparison. This avoids changing the device and cable together and then attributing the result to one of them.

A second useful control is DEG2 on another AMD USB4 host. Success would narrow the problem toward this ASUS platform or unit; failure would motivate a wider compatibility comparison. One additional AMD host cannot establish an AMD-wide defect. Manufacturer/router firmware, actual link mode and cable identity matter more than the CPU brand alone.

These comparisons need borrowed hardware. They are worth pursuing alongside code work rather than waiting for reverse engineering to finish. A second suitable cable alone is also useful: success on Dell does not exclude an ASUS-specific interaction. The unsuitable UGREEN cable previously tried was not that control. [Hardware and prior cable checks](hardware.md).

## 3. What further firmware work must establish

The [IT8857 tool audit is complete for its selected version path](it8857-version-path.md). It reads B6 after reconfiguring a CPU-visible I²C controller. Its address conversion agrees with the ASUS EC's normal address convention, but it supplies no established Windows route to the laptop's EC-controlled bus. Running that updater is not the next step.

The [laptop EC comparison](it8857-runtime-commands.md#what-the-laptop-ec-actually-exports) found partial status and power reporting, not an identified Enter_USB result. B0/B1 reads keep only four raw bits; failures can preserve old cached values. The CC four-byte read feeds voltage/current/power arithmetic, and its OEM getter reports nonzero power. The separate card reference record still has no matched laptop reader. Following a controller-side producer is useful only if it connects to a reachable laptop read or command; repeating these power/cache getters would not recover the handshake. No Windows repair or new hardware request is established.

The useful result is an exact reachable read, or a clear account of which exposed handlers cannot provide it. A fresh firmware version could help identify the controller program; it would not itself reveal USB4 entry. Any subsequent state/log reader must identify what it observes and whether reading consumes an event or changes state. [Known Windows interfaces](windows-repair-route.md).

This is an access investigation. It does not make another board's PD image suitable for the laptop, and it does not displace the hardware comparisons above.

## 4. Ask for the information the vendor can actually supply

The useful ASUS engineering request is specific: confirm the fitted IT8857/PS8830 firmware versions for this board, whether an applicable PD or retimer update exists, and whether a supported diagnostic records USB4 entry and the applied retimer state. Include the Dell success, ASUS Linux failure, working ASUS peer link and physical chip correction.

Minisforum can independently confirm DEG2's PD-controller identity, firmware/diagnostic interface and known compatibility with this ASUS/AMD platform. Its reported router firmware is not necessarily the PD firmware. A firmware package or documented logger would be more useful than another generic reinstall recommendation. These are proposed requests; nothing has been sent by this plan.

On 3 November, the inspected DEG2 section of the [official global support page](https://www.minisforum.com/pages/product-info) linked a manual and installation video, with no linked firmware or diagnostic download under Drivers & Downloads. This does not rule out a support-supplied package. Ask specifically for a package matching DEG2 hardware, its supported version/status reads and whether it can record entry failures without flashing. No such package was acquired in this check.

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
