# Documentation

Read [findings](status.md) for the evidence and [the diagnosis plan](investigation-plan.md) for the next steps. The technical notes below retain the reasoning, corrections and failed attempts. A dated procedure is not an instruction to repeat it.

## Overview

- [Findings](status.md)
- [Diagnosis plan](investigation-plan.md)
- [How the connection works](connection.md)
- [Experiment results](experiments.md)
- [Research handoff](handoff.md)
- [Continuing in another chat](continuation.md)
- [Tool guide](../tools/README.md)

## Hardware and comparison results

- [Hardware, cable and host details](hardware.md)
- [Board photographs and corrected IT8857FN identification](board-photo-review.md)
- [ASUS and Dell: matched Windows captures](asus-dell-matched-comparison.md)
- [ASUS capture against the recovered Dell dump](asus-local-comparison.md)
- [Working Dell control](dell-control.md)
- [Dell dump recovery and platform policy](dell-dump-recovery.md)
- [Separate Windows installation on ASUS](fresh-windows.md)
- [ASUS Linux result](linux-asus-result.md)
- [Working ASUS–Dell peer link](peer-test.md)
- [Powered preconnected startup](cold-start-observation.md)
- [Attachment order and RT0 port mapping](rt0-attachment-order.md)
- [DEG2's Billboard and power reports](billboard-comparison.md)
- [Earlier trace findings](findings.md)

## Controller access and firmware

- [Available Windows interfaces and their limits](windows-repair-route.md)
- [Component controls: IT8857, PS8830 and the other photographed chips](component-behavior.md)
- [PD firmware cache and acquired ASUS reference images](pd-firmware-version.md)
- [Data_Reset hypothesis](ucsi-data-reset.md)
- [Reset command path and unknown receiving handler](data-reset-command-path.md)
- [What the Infineon SDK 3.9.0 supplies](infineon-sdk-review.md)
- [RT1 is a separate host instance](rt1-router-mapping.md)
- [Hidden settings and possible capture interfaces](capture-paths-and-hidden-settings.md)
- [UMAF and other boot tools](boot-tools-review.md)
- [ASUS EC relay and stubbed diagnostic getter](ec-firmware-decision.md)
- [EC blocking flag and its writers](ec-blocking-flag.md)
- [OEM response wait: earlier IT8853-labelled investigation](it8853-transport.md)
- [Recovered control paths and access failures](control-reachability.md)
- [Earlier firmware-entry analysis](firmware-entry-followup.md)
- [MCU read prerequisites and working-link counterexample](i2c-read-prerequisites.md)
- [Parade updater failure](parade-updater-failure.md)
- [Parade CFU image candidates](parade-cfu-candidates.md)
- [Trace decoding and EC bus-transfer code](trace-gaps-and-ec-bus.md)
- [OEM identity and power-profile getters](oem-pd-diagnostics.md)
- [Retimer target-lifetime analysis](parade-lifecycle-test.md)
- [Earlier reverse-engineering approach](reverse-engineering-approach.md)
- [Research sources and earlier interpretations](research.md)

## Previous tests and procedures

These pages explain how the evidence was collected. Check [experiment results](experiments.md) before using any procedure.

- [Role-policy filter: measured result and removal](role-policy-test-result.md)
- [Role-policy experiment design](role-policy-experiment.md)
- [Initial-role experiment: no attachment](initial-role-test.md)
- [Driver readiness review](driver-readiness-review.md)
- [Test signing and restoration records](local-test-signing.md)
- [Temporary Windows test setup](test-windows.md)
- [Portable ASUS/Dell capture procedure](deep-compare-capture.md)
- [Hot-plug trace](hotplug-window.md)
- [Live kernel snapshot](kernel-snapshot.md)
- [UCSI buffer examination](ucsi-memory-probe.md)
- [Role-negotiation comparison and follow-up](negotiation-followup.md)
- [Correction to EnableUSB4v2Support interpretation](policy-audit.md)
- [Native-boot toolkit review](validation-audit.md)

## Tools, evidence and history

- [Linux collector instructions](linux-capture.md)
- [Linux collector implementation and checks](linux-capture-internals.md)
- [Generated evidence map](investigation-map.md)
- [Generated constraint table](investigation-truth-table.md)
- [Earlier evidence gaps](investigation-gaps.md)
- [Offline analysis runner](offline-investigation.md)
- [Possible future diagnostic tool](tool-scope.md)
- [Evidence and privacy](privacy.md)
- [Chronological record](timeline.md)
- [History and preserved revisions](history.md)
- [Research checkpoint](ps8830-investigation-intervals.md)

[Contributing](../CONTRIBUTING.md) · [Repository home](../README.md)
