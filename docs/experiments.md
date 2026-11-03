# Experiment results

Results are summarised below. An intended condition that was never established is not a negative test of that hypothesis. The [diagnosis plan](investigation-plan.md) identifies useful remaining comparisons.

| Test | Result | What it means |
| --- | --- | --- |
| Dell with the same assembled DEG2, GPU, PSU and supplied cable | Router, GPU and display work | Working control. [Record](dell-control.md) |
| Separate Windows installation on ASUS | Same missing router/GPU | Failure is not confined to the original installation. [Record](fresh-windows.md) |
| ASUS–Dell USB4 peer connection | 40 Gbps negotiated link | Establishes this peer path, not GPU PCIe tunnelling. [Record](peer-test.md) |
| Move the cable from a working Dell peer connection to powered DEG2 | DEG2 still lacked router/GPU; root-router power state changed between partners | Did not preserve all of the working peer state. [Decoded handoff](negotiation-followup.md) |
| All four USB-C plug orientations | No change reported | Orientation changes have already been tried. [Hardware record](hardware.md) |
| Second UGREEN cable | No change; its capability was later found unsuitable | Not a valid second USB4 cable control. [Cable limitation](hardware.md#cable-limitation) |
| Standard ASUS role correction | Completes; ordinary USB devices then enumerate; no external router at recorded checks | Permanent wrong USB role is insufficient as the explanation. [Record](rt0-attachment-order.md) |
| Disable Windows automatic role correction with the experimental filter | Policy accepted; USB4 still failed | This policy alone was insufficient. Filter removed and stock policy verified. [Result and recovery](role-policy-test-result.md) |
| Rp-only initial-role test | No attachment established; DRP restored | Intended comparison was not achieved. [Record](initial-role-test.md) |
| One current-mode exit request | Firmware rejected it; retained error 0x0004 | Does not explain the original entry failure. [Record](handoff.md#next-owner-action-one-current-mode-exit) |
| Powered DEG2 connected before ASUS startup | No router/GPU in post-startup capture | This startup attempt did not repair the pairing; initial negotiation was outside the trace. [Record](cold-start-observation.md) |
| Stored USB4/TBT3 settings read | Both enabled; RT0 Auto, RT1 Disabled | These stored values alone do not identify the failed applied state. [Record](../evidence/firmware-settings-read.json) |
| Standard Billboard descriptors/strings | Read successfully; generic help/status metadata | No qualified vendor log or raw PD record recovered. [Record](../evidence/billboard-strings-result.json) |
| Linux attachment on ASUS | Booted and saved to USB; 10 Gbps USB hub present, no external router/new PCIe device observed | Reproduces the failure outside Windows with OS PCIe control granted. Entry/retimer/training state remains unresolved. [Result](linux-asus-result.md) |

## Not selected for repetition

The previous policy filter, Rp-only attempt, mode exit, cold-start comparison and generic full dumps have not gained a new condition that justifies repeating them unchanged. No driver reinstall, blind mode number, RT1 toggle, firmware flash or new Windows deployment is selected.

The original [dated ledger](https://github.com/49Ssr/asus-fa507xi-deg2-usb4/blob/52e6e26890adf49c2846a0acc478089659808843/docs/experiments.md) retains request details, invalid attempts, corrections and old preparation stages. These are historical records rather than instructions to run them again.

[Current findings](status.md) · [Tool guide](../tools/README.md)
