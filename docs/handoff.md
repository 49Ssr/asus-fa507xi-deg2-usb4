# Research handoff

Read [findings](status.md), then the [diagnosis plan](investigation-plan.md). The plan is the single list of current priorities; dated notes preserve results and earlier proposals.

## Resume here

The [update-interface review](update-interface-reads.md) found identity, flash/status reads and six parameters preserved across reset, but no identified live PD log. The parameter reader ignores errors and can issue a write. AsusEC_X64 uses either a HID device absent from the present inventory or a separate helper-driver path that can install a service; neither is an established existing PMC3 bridge. Continue with the controller-side state producer and a Windows PMC3 or equivalent route. No hardware request is selected.

The strongest additional hardware comparison is another known-working USB4 PCIe peripheral on ASUS. The [plan](investigation-plan.md) explains what each possible result would change. No new test or borrowed device is assumed available.

## Do not lose these facts

- Photographs identify IT8857FN and PS8830 A3. `IT8853` was a fixed EC string.
- Connector 1/XHC3/NHI0/RT0 is the failing path. RT1 is the other instance.
- ASUS fails under Windows and Linux; the ASUS–Dell peer link works at 40 Gbps.
- Role correction completes before ordinary USB enumeration. Its timing remains a hypothesis, not a proven cause of USB4 failure.
- The Infineon SDK 3.9.0, BIOS 314 and different-board ITE references are already acquired. Do not request or download them again without a reason.
- The exact laptop PD firmware, reset handler and live PD/PS8830 state-read interface remain unidentified.

## Recovery and operating state

The experimental filter was removed and stock policy verified. On 3 November, Windows reported Secure Boot off, test signing off and HVCI running; the exact experiment certificate was absent. Current BCD enumeration and complete boot-restoration verification remain unfinished. Keep that maintenance item separate from claims about the USB4 cause. [Readback](../evidence/boot-state-20261103.json).

Scheduling is paused. Physical boots, cable changes and configuration changes require owner direction. Preserve original private dumps, traces, firmware, failed attempts and recovery records. The local Git index is stale after API publication; follow [AGENTS.md](../AGENTS.md) for updates.

## Earlier procedures

The [earlier handoff](https://github.com/49Ssr/asus-fa507xi-deg2-usb4/blob/52e6e26890adf49c2846a0acc478089659808843/docs/handoff.md) retains the original instructions. The links below preserve existing references; they are historical, not a request to repeat a test.

<a id="deg2-cable-and-peripheral-comparisons"></a>
[Earlier cable and peripheral comparisons](https://github.com/49Ssr/asus-fa507xi-deg2-usb4/blob/52e6e26890adf49c2846a0acc478089659808843/docs/handoff.md#deg2-cable-and-peripheral-comparisons)

<a id="n5-existing-hardware-partner-handoff-proposed"></a>
[Peer-to-DEG2 handoff procedure](https://github.com/49Ssr/asus-fa507xi-deg2-usb4/blob/52e6e26890adf49c2846a0acc478089659808843/docs/handoff.md#n5-existing-hardware-partner-handoff-proposed) — completed without restoring USB4; [decoded result](negotiation-followup.md).

<a id="next-owner-action-inspect-the-asus-mode-tables"></a>
[Earlier mode-table inspection](https://github.com/49Ssr/asus-fa507xi-deg2-usb4/blob/52e6e26890adf49c2846a0acc478089659808843/docs/handoff.md#next-owner-action-inspect-the-asus-mode-tables)

<a id="next-owner-action-one-current-mode-exit"></a>
[Mode-exit procedure and result](https://github.com/49Ssr/asus-fa507xi-deg2-usb4/blob/52e6e26890adf49c2846a0acc478089659808843/docs/handoff.md#next-owner-action-one-current-mode-exit)

<a id="next-owner-action-read-retained-error-status-once"></a>
[Retained-error read](https://github.com/49Ssr/asus-fa507xi-deg2-usb4/blob/52e6e26890adf49c2846a0acc478089659808843/docs/handoff.md#next-owner-action-read-retained-error-status-once)

[Documentation index](README.md)
