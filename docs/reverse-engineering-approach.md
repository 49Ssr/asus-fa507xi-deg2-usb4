# Matched comparison and firmware investigation

**31 October 2026. Acquisition design and evidence-gap review; new paired captures and a firmware patch are not completed.** The owner subsequently requested the portable kit: [prepared capture and qualification](deep-compare-capture.md). The next acquisition must answer a named question rather than repeat the existing collector unchanged.

## First question

**Why does Dell report DEG2 as UFP during PD negotiation without an OS SET_UOR, while ASUS reaches a later correction and alternate-mode-only report?** Separate two questions: what determines Windows's correction decision, and what prevents native USB4 entry. Answering the first does not automatically answer the second.

The [existing captures](negotiation-followup.md) already record both hosts initially reporting partner DFP/power consumer. The Dell capture is a successful, pre-attachment control with zero reported event loss. Fourteen captured Windows images match. ASUS's correction-flag writer was traced. Those results remain useful; a new capture should supply the missing policy/firmware context.

## Gaps that justify new data

| Question | Existing evidence | Specific next evidence |
| --- | --- | --- |
| Why is Dell's correction decision No? | Successful trace, but Dell's persistent device-controller policy was not independently recovered | Dell's loaded UCSI/ACPI objects, `m_IsUsbDeviceControllerEnabled`, corresponding ACPI `_DSM` branches and initialization/configuration evidence |
| Is ASUS's current driver state consistent with the older dump? | The ASUS dump is from 04:27, before the later instrumented comparisons and temporary CC-mode test | One fresh kernel snapshot with normal DRP, DEG2 attached in ordinary USB/Billboard failure, timestamped against a new passive trace |
| Where is the first divergence? | UCSI-visible role/partner reports and USB4 host state; no physical PD packets | Aligned attachment/PD/role/mode-entry/port-link milestones, with missing stages marked unknown |
| Which component owns the failure? | AMD host, ASUS AML/EC transport, Parade driver family and DEG2 Intel router are identified at different levels | Board/controller identities, firmware provenance and a call/message path assigning the failed transition to a component |
| Can a patch be installed and recovered? | No identified faulty instruction, applicable patch image or qualified recovery path | Exact code/data target, causal test, accepted update mechanism and verified restoration before deployment |

The transient `PerformRoleCorrectionOnNextPdContract` flag is consumed and cleared. A final snapshot showing zero cannot reconstruct its earlier value. Use the continuous trace for ordering and the dump for persistent policy and object state.

## Matched acquisition

Use the same assembled DEG2/GPU/PSU/cable and recorded plug orientation; normal barrel power; normal CC policy. Dell must reproduce its working router/GPU state and ASUS its original attached fallback state. The Rp-only no-attachment result is a separate experiment, not the failing baseline.

1. Record host, BIOS, loaded module identities, connector/port mapping and diagnostic-interface state. Preserve saved preparation/undo records. Record unequal settings rather than silently calling them controlled variables.
2. Start bounded passive ETW before connection. Record a disconnected baseline, prompt time, actual first recorded attachment, PD/role transitions and the final router/GPU or fallback milestone. Do not inject role/mode/reset commands during this window.
3. After the outcome is observed, capture one **Full live kernel memory dump** on each host while DEG2 remains attached. Record capture start/end separately from trace events; the dump is a state snapshot, not a recording of every handshake stage. Keep full dumps private. Microsoft documents the [Task Manager procedure and incomplete-memory limits](https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/task-manager-live-dump).
4. Extract the UCM/UCSI/USB4 objects and ACPI namespace from each dump offline with matching symbols. Discover object addresses per dump; do not reuse ASUS addresses on Dell. Record unavailable pages and command failures explicitly. If a required field is absent, change the acquisition method for that field before repeating.
5. Stop only owned tracing, preserve hashes and network/ICS snapshots, and compare the same milestones. Acquire additional disconnected/transient snapshots only when a specific remaining question requires them.

The old Dell collector does not independently recover all these policy fields. Use the subsequently prepared [USB4-Deep-Compare kit](deep-compare-capture.md), not that old START launcher. It automates preparation, passive tracing and verified return transport, and guides native Task Manager dump creation. It stops ETW before the interactive dump step and records that separation explicitly. No new dump has yet been recorded with this kit.

## What a newer dump can and cannot supply

The old ASUS dump and subsequent live probe could not supply the 48-byte UCSI or 64-byte EC shadow buffers. A newer kernel snapshot can recover current driver objects and loaded AML; it does not promise access to EC/PD-controller flash or those missing mappings. Do not repeat the unavailable-memory experiment unchanged. [Recorded limits](ucsi-memory-probe.md).

Static ACPI tables are useful firmware evidence, not a complete firmware image. Microsoft's [GetSystemFirmwareTable](https://learn.microsoft.com/en-us/windows/win32/api/sysinfoapi/nf-sysinfoapi-getsystemfirmwaretable) retrieves tables and returns only the first table when names are duplicated; an export must disclose incomplete SSDT coverage. Dump-based namespace inspection can supplement that limitation. Disassemble AML without executing methods: the retained ASUS receive method includes writes clearing notification-shadow fields.

## Firmware ownership map

| Layer | Established here | What must not be inferred |
| --- | --- | --- |
| Windows connector/connection managers | Same captured Microsoft binaries; UCSI correction writer and consumer inspected | Same runtime policy or proof Windows cannot participate |
| ASUS BIOS/ACPI interface | BIOS 314; `USBC000`/UBTC AML; `_DSM` support mask `0x0f`; send path copies command/message bytes to EC shadow under an EC mutex, receive path copies status/message bytes back and clears notification fields | The AML transport is the PD state-machine implementation, or changing the optional role-correction `_DSM` guarantees USB4 |
| PD/embedded-controller policy | An EC-mediated transport is visible | Exact PD-controller part, executing firmware image, version and signing/update path remain unidentified |
| Host router/PHY | AMD integrated USB4 host; no external router in failed state | A Dell Intel controller binary can be transplanted or meaningfully compared byte-for-byte |
| Retimer/control path | Retained original Parade INF maps ACPI PS8830-family IDs; [Parade identifies PS8830 as a USB4 retimer](https://www.paradetech.com/parade-introduces-ps8830-usb4-retimer-with-displayport-2-0-and-thunderbolt-3-0-alt-modes/) | INF support alone establishes board population, port routing, PD ownership or a flash-compatible image; six software nodes do not prove six physical chips |
| DEG2 | Intel JHL9480; working Dell router reports firmware 62.62 | Router NVM version identifies the separate PD firmware or clears every interoperability issue |

The [ASUS exact-model listing](https://www.asus.com/us/supportonly/fa507xi/helpdesk_bios/) identifies BIOS 314 and its package hashes. Obtain/hash the exact-model vendor package for offline extraction; retain originals. A downloadable BIOS capsule is not a complete readback of installed EC/PD/retimer firmware. This review did not download, extract, modify or flash a new capsule.

## Reverse-engineering sequence and patch decision

Trace the observed transition to its owning driver, AML method or controller image. Compare protocol behavior across Intel and AMD; compare binaries only where implementation and provenance make that comparison meaningful. Correlate fields with the physical port and state before assigning a meaning to an unknown register.

Microsoft describes [firmware-handled role switching](https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/ucsi) and a USB4 connection manager [independent of the UCSI stack](https://learn.microsoft.com/en-us/windows-hardware/design/component-guidelines/usb4-design-details-and-general-requirements). Therefore neither a completed SET_UOR nor an AML policy difference supplies the missing Enter_USB/link-training exchange. If those exchanges are invisible to all available software interfaces, vendor PD/EC logging or a suitable protocol capture becomes the next evidence source; another generic dump cannot manufacture it. This is a coverage boundary, not a requirement to buy hardware now.

Prefer an applicable Windows/runtime or OEM-supported policy remedy when the evidence identifies one. A firmware patch becomes a concrete candidate only after identifying the exact component/version/code, showing why the change corrects the transition, and establishing an accepted installation and recovery route. Modified signed images may require an OEM-signed engineering build; being able to edit bytes does not establish installability. No flash or boot-security change is part of this plan.

Success requires the ASUS pairing to enumerate the external router, bind the GPU, produce output and survive reconnect/restart, with the existing working controls preserved. A parser, command completion or new version string is not that result. No firmware defect, patch target or guaranteed repair is established yet.
