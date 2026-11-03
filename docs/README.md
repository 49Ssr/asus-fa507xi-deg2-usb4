# Documentation index

Start with [current findings](status.md). The detailed notes preserve the source trail; older procedures are not a current request to run them.

## Start here

- [Current findings](status.md)
- [How the connection works](connection.md)
- [Linux USB4 comparison](linux-capture.md)
- [Experiment results](experiments.md)
- [Research handoff](handoff.md)
- [Current investigation plan](investigation-plan.md)
- [Continuing this investigation](continuation.md)

## Recorded comparisons

- [Hardware and comparison baseline](hardware.md)
- [Board photographs: IT8857FN identified; PS8830 A3 confirmed](board-photo-review.md)
- [ASUS Linux result: USB fallback reproduced](linux-asus-result.md)
- [Fresh ASUS versus Dell: matched evidence comparison](asus-dell-matched-comparison.md)
- [Fresh ASUS comparison against the recovered Dell](asus-local-comparison.md)
- [Portable Intel Dell-DEG2 control](dell-control.md)
- [Dell dump recovery and platform-policy comparison](dell-dump-recovery.md)
- [Separate full-Windows result, 31 October 2026](fresh-windows.md)
- [N0: ASUS-Dell USB4 peer link](peer-test.md)
- [One preconnected cold-start observation](cold-start-observation.md)
- [RT0: what succeeds before USB4 fails](rt0-attachment-order.md)
- [DEG2's own USB4/DP report: ASUS versus Dell](billboard-comparison.md)
- [What the traces say](findings.md)

## Controller and firmware research

- [Windows PD-version read: cached0053 and recovered ASUS ITE references](pd-firmware-version.md)

- [Data reset after role correction: repair hypothesis and missing ASUS command](ucsi-data-reset.md)
- [ASUS command path, fixed mailbox version and SDK reset handler](data-reset-command-path.md)

- [Infineon SDK 3.9.0: recovered AMD/PS8830 reference implementation](infineon-sdk-review.md)

- [Finding a Windows repair: the missing decision](windows-repair-route.md)
- [What RT1 controls on this ASUS](rt1-router-mapping.md)
- [Reading the missing state with the existing hardware](capture-paths-and-hidden-settings.md)
- [Useful boot tools for this investigation](boot-tools-review.md)
- [BIOS314 EC firmware: silent telemetry stub and UCSI relay](ec-firmware-decision.md)
- [EC blocking flag: writers, read address and remaining access problem](ec-blocking-flag.md)
- [IT8853 follow-up: OEM response wait isolated](it8853-transport.md)
- [Reaching the firmware: recovered code and tested access boundary](control-reachability.md)
- [Firmware entry investigation, 1 November 2026](firmware-entry-followup.md)
- [MCU read prerequisites and the working-link counterexample](i2c-read-prerequisites.md)
- [Parade updater failure: registry, existing dump and native code](parade-updater-failure.md)
- [Parade CFU firmware candidates: offline review](parade-cfu-candidates.md)
- [Remaining trace records decoded; EC bus-transfer code exercised](trace-gaps-and-ec-bus.md)
- [Matched comparison and firmware investigation](reverse-engineering-approach.md)
- [Research and sources](research.md)

## Earlier Windows procedures and results

- [Measured role-policy test, 1 November 2026](role-policy-test-result.md)
- [One initial-role comparison with existing hardware](initial-role-test.md)
- [Pre-attachment role-policy experiment](role-policy-experiment.md)
- [Driver readiness review, 1 November 2026](driver-readiness-review.md)
- [Local test signing and return to normal boot](local-test-signing.md)
- [Temporary full-Windows test](test-windows.md)
- [Portable matched capture: Dell first](deep-compare-capture.md)
- [Live connection window: 31 October 2026](hotplug-window.md)
- [Live kernel snapshot: 31 October 2026](kernel-snapshot.md)
- [Scripted UCSI / EC buffer examination](ucsi-memory-probe.md)
- [Role negotiation: follow-up on the existing captures](negotiation-followup.md)
- [Correction: `EnableUSB4v2Support` was ignored](policy-audit.md)
- [Native-boot toolkit validation audit](validation-audit.md)

## Evidence and maintenance

- [Linux collector: design and validation](linux-capture-internals.md)

- [USB4 investigation: current evidence map](investigation-map.md)
- [USB4 constraint table and next observations](investigation-truth-table.md)
- [What we know, what we are missing, and what can be tested without another boot](investigation-gaps.md)
- [Offline analysis and the saved router-detection difference](offline-investigation.md)
- [Scope of a future USB4 diagnostic tool](tool-scope.md)
- [Evidence and publication](privacy.md)
- [Troubleshooting timeline](timeline.md)
- [Investigation history](history.md)
- [Research checkpoint](ps8830-investigation-intervals.md)

## Additional technical notes

- [ASUS OEM PD reads: fixed identity string and power-profile boundary](oem-pd-diagnostics.md)
- [Retimer target leak: reproduced code path and controlled next test](parade-lifecycle-test.md)

[Tool guide](../tools/README.md) · [Contributing](../CONTRIBUTING.md) · [Repository home](../README.md)
