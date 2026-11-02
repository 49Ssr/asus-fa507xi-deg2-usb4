# Continuing this investigation

This repository preserves the USB4 investigation after the original chat reached its limit. Start with [current findings](status.md), [research handoff](handoff.md) and [the tool guide](../tools/README.md).

The latest technical question is the failed RT0 USB4 entry/link transition. A stored setting, successful UCSI command or final missing router does not identify the physical cause. The Windows policy-only trial failed; no working repair is established.

The Linux kit is the selected later comparison with existing hardware. It is prepared and audited, but real USB persistence and ASUS capture have not run. Physical access is required; the current remote session is not to be restarted for it.

Public JSON and code references are checked by the offline runner. Original private artifacts remain necessary for re-decoding. Automated checks and a VM startup do not certify a hardware fix.

Past decisions, failed attempts and earlier chat-recovery notes remain in the [investigation history](history.md). The [current plan](investigation-plan.md) names the work still open.
