# Research handoff

The current objective is to identify the first failed USB4 transition on the RT0 path and an operation that could repair it. The cause is unresolved.

1. Read [current findings](status.md) and [the connection explanation](connection.md).
2. Use [experiment results](experiments.md) to avoid repeating completed or invalid comparisons.
3. For the selected later observation, use only [the current Linux guide](linux-capture.md).
4. For offline work, follow the original RT0/PBS policy consumer or a source-matched controller log interface. [Windows repair research](windows-repair-route.md) describes the missing records.

## State to preserve

- Connector 1/XHC3/NHI0/RT0 is confirmed for the captured failure. RT1 is the other instance.
- Stored PD USB4 and TBT3 settings are enabled. Auto still needs its applied consumer/state.
- Windows role correction completes; USB4 router detection still fails. Dell's earlier role sequence is a correlation, not a proven cause.
- The old filter is removed; stock policy was verified. Do not treat historical test-signing instructions as an active installation request.
- Original dumps, traces, firmware, failed attempts and recovery receipts remain private. Never publish them wholesale or delete them as cleanup.
- Scheduling is paused. Physical boots, cables and firmware access are owner-directed. Do not restart an unattended remote Windows session.

## Earlier procedures

The former handoff accumulated completed and superseded “next owner action” instructions. It is preserved at [the pre-cleanup revision](https://github.com/49Ssr/asus-fa507xi-deg2-usb4/blob/52e6e26890adf49c2846a0acc478089659808843/docs/handoff.md). It is not the current procedure.

<a id="deg2-cable-and-peripheral-comparisons"></a>
[Earlier deg2 cable and peripheral comparisons](https://github.com/49Ssr/asus-fa507xi-deg2-usb4/blob/52e6e26890adf49c2846a0acc478089659808843/docs/handoff.md#deg2-cable-and-peripheral-comparisons)

<a id="n5-existing-hardware-partner-handoff-proposed"></a>
[Earlier n5 existing hardware partner handoff proposed](https://github.com/49Ssr/asus-fa507xi-deg2-usb4/blob/52e6e26890adf49c2846a0acc478089659808843/docs/handoff.md#n5-existing-hardware-partner-handoff-proposed)

<a id="next-owner-action-inspect-the-asus-mode-tables"></a>
[Earlier next owner action inspect the asus mode tables](https://github.com/49Ssr/asus-fa507xi-deg2-usb4/blob/52e6e26890adf49c2846a0acc478089659808843/docs/handoff.md#next-owner-action-inspect-the-asus-mode-tables)

<a id="next-owner-action-one-current-mode-exit"></a>
[Earlier next owner action one current mode exit](https://github.com/49Ssr/asus-fa507xi-deg2-usb4/blob/52e6e26890adf49c2846a0acc478089659808843/docs/handoff.md#next-owner-action-one-current-mode-exit)

<a id="next-owner-action-read-retained-error-status-once"></a>
[Earlier next owner action read retained error status once](https://github.com/49Ssr/asus-fa507xi-deg2-usb4/blob/52e6e26890adf49c2846a0acc478089659808843/docs/handoff.md#next-owner-action-read-retained-error-status-once)


[Documentation index](README.md) · [Current investigation plan](investigation-plan.md)
