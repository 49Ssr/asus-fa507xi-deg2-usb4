# Research checkpoint

Updated 2 November 2026. [Current findings](status.md) are the public summary; [the current plan](investigation-plan.md) names the open work.

## Current work

The RT0 mapping and USB enumeration order are established. The first failed PD/retimer/link operation remains unobserved. Follow the original RT0/PBS policy consumer or an identified controller diagnostic implementation.

The Linux observation kit has been prepared and audited. Its startup was checked in a virtual machine; real USB persistence and ASUS attachment remain untested. Use [its current guide](linux-capture.md), not an earlier proposed boot sequence.

## Operating constraints

Scheduling remains paused. Physical boots/cables are owner-directed, and no unattended remote restart is authorized. No live EC/I2C/vendor command, driver change, mode override or flash is selected. Preserve original artifacts, failed attempts and private recovery records.

Owner-directed usage stop remains 1% in any applicable known allowance window. Verify allowances before expanding sustained work, stop if unavailable, and never purchase credits, use resets or automatically resume scheduling.

## Earlier journal

The complete dated journal is preserved at [the pre-cleanup revision](https://github.com/49Ssr/asus-fa507xi-deg2-usb4/blob/52e6e26890adf49c2846a0acc478089659808843/docs/ps8830-investigation-intervals.md). Its old “next task”, unexecuted-read and scheduling statements describe their dates and do not override current state.

[Evidence map](investigation-map.md) · [History index](history.md)
