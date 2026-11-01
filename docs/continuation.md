# USB4 investigation continuation

**Signing/readiness review completed, 1 November:** a private [local test-signed package and reversible test-boot route](local-test-signing.md) are prepared; the signing key was deleted and production security is unchanged. The [driver review](driver-readiness-review.md) fixed filter initialization, registry typing, callback annotations and two workflow defects. Checks: 4,631 parser, 36 actual-callback/doubled-DDI, 64 workflow and 41 signing/boot; static analysis has zero project results. **No driver has been loaded.** Explicit owner approval and manual firmware/reboot steps are still required; HVCI must remain running. A same-test-boot fallback baseline is required before installation. Native USB4 entry and the original failure remain unresolved.

**Pre-attachment experiment prepared, 1 November:** [role-policy source, controlled test and rollback](role-policy-experiment.md). The unsigned KMDF filter supplies the documented disable-correction policy at UCSI startup; it has **not been installed or loaded**. Native core: 4,631 assertions; PS5.1 workflow: 57 checks with device operations mocked. The real Microsoft client must confirm policy acceptance before a single attachment is allowed. Windows-accepted signing is unresolved; Secure Boot, firmware, drivers and ICS were not changed. This is a causal test, not a verified USB4 fix.

**Latest, 1 November:** [fresh ASUS-Dell comparison completed](asus-dell-matched-comparison.md). Verified 35 ASUS capture files plus 3.17 GB full dump; current policy 0 versus Dell 1, same 14 Windows images. ASUS completes SET_UOR but controller detection stays negative before/after it. Failure also occurs with USB flag 1, weakening any explanation that requires the earlier alternate-mode-only flag. No generic recapture or new firmware intervention is queued; no supported Windows fix is established.

**1 November recovery update:** the second Dell run's 33-file return and separate 2.25 GB dump are [verified and analysed](dell-dump-recovery.md). Dell cached policy is 1 versus ASUS 0; Dell additionally exposes the documented role-correction `_DSM` function 4, although its raw return fields are absent from the dump. The USB handoff failure did not lose the trace or snapshot. The revised selector/resume flow passes 183 PS5.1 assertions. Do not repeat Dell for this handoff; a new normal-fallback ASUS comparison and a causal repair remain outstanding. Ethernet link is up at 1 Gbps, but usable share access is not yet established; Internet sharing was left untouched.

**31 October 2026: unresolved.** This is the durable starting point after the Device Management chat `Tech V (Work)` reached its limit. The aim is to understand and, if evidence supports it, repair the ASUS-DEG2 pairing, with a possible diagnostic tool for other owners later. A deployable repair has not been established.

## Recovered context and its limits

The linked conversation's latest exchanges and the earlier Dell-bundle/results exchanges were read directly. Older browser history stalled while loading; the chat tool returned five recent turns with no older-page cursor. Earlier troubleshooting below is reconstructed from this repository's [timeline through step 62](timeline.md), [experiment ledger](experiments.md), public evidence and local preservation records. This is a recovered working context, not a claim to have read the complete conversation verbatim. Public records omit the conversation ID and private paths.

| Question | Current evidence | Limit |
| --- | --- | --- |
| Is the assembled GPU/dock/PSU dead? | Identical assembly and supplied cable work on Dell Latitude 5540: external router, native USB4 at a reported 40 Gbps, NVIDIA-bound RTX 4080 SUPER and display output. | Does not qualify every host or sustained workload. [Dell control](dell-control.md). |
| Can this ASUS establish any USB4 connection? | Direct ASUS-Dell peer connection with the supplied cable: both adapters Up; Gen 3, two bonded lanes, reported 40 Gbps. | Host-to-host connection does not validate an external PCIe/GPU tunnel. [Peer control](peer-test.md). |
| Is it confined to the original Windows installation? | A separate native-boot Windows installation reproduces fallback with no external router/GPU; essential preflight checks pass. | Shared hardware/firmware and some selected drivers remain. [Fresh Windows](fresh-windows.md). |
| Where does DEG2 fail on ASUS? | Ordinary USB and Billboard enumerate; external USB4 router and GPU do not. USB4KD records no external router/tunnel and no BIOS PCIe-disable flag. | Locates a failure boundary without identifying the responsible component. [Findings](findings.md). |
| What distinguishes the recorded hosts? | ASUS performs successful OS data-role correction before alternate-mode-only reporting; Dell succeeds without that request. Fourteen captured Windows images match byte-for-byte. | Correlation, not evidence that the role request causes failure. |
| What did the final commands establish? | 37/37 mode-inspection GETs completed. One mode exit was rejected. The later single error GET returned `0x0004`. | Diagnostic-command rejection is separate from the original failure. The bad field and exclusive attribution across the intervening gap are unproven. |

## Decisions to carry forward

- Continue Windows diagnosis using the existing equipment. Another cable/peripheral is an optional comparison if available; it is not a promised fix or a purchase prerequisite for continued research.
- Avoid repeating the completed resets, controller reinstall, ineffective policy override, unchanged memory probes, Dell capture or rejected mode exit without a newly identified variable.
- Keep the original Parade baseline, Secure Boot and normal signing configuration. Exact-model applicability is required before proposing firmware. Support escalation was reported; completed engineering review and a firmware remedy are unconfirmed.
- Preserve UGREEN upstream Internet and built-in Ethernet Internet Connection Sharing. The USB4 peer adapter is a separate test interface, not the sharing destination.
- Preserve raw captures, dump, driver/symbol provenance, support records and the native-boot image/maintenance tools. The earlier cleanup archived 212 files with verified hashes; it did not remove the test image or boot entry.
- Keep source history and reviewable, sanitized observations on GitHub. Raw memory, traces, firmware responses and account/device identifiers stay private.

## What is useful next

**Earlier 1 November inventory correction (subsequently superseded by the recovery above):** the first deep Dell launch stopped at inventory before ETW/dump acquisition. All four returned files hash-verify. V2 fixes native PnP replies lacking Data and now exercises real read-only inventory/static inputs; 166 PS5.1 assertions pass. Use the separate corrected [USB4-Deep-Compare-v2 kit](deep-compare-capture.md); original USB results and a private verified import are retained. This failure supplies no new USB4 handshake result, and the earlier successful Dell control remains separate evidence.

**Latest direction:** the owner proposes deeper Dell inspection, a fresh ASUS dump and firmware reverse engineering. The [acquisition and ownership review](reverse-engineering-approach.md) defines the missing data, matched phases, unavailable-memory limits and criteria for a real patch. Dell's internal policy/ACPI comparison was subsequently recovered as described above; a generic larger dump is not a firmware image. This review does not claim new paired captures or a prepared flash.

**Historical portable-kit preparation at the owner's request:** [Dell-first matched capture](deep-compare-capture.md), using passive ETW, native Task Manager full snapshot, selected ACPI and verified split return transport. 137 PS5.1 assertions and independent reconstruction of the retained >2 GiB ASUS dump pass. New source kit copied/hash-verified to the identified 8 GB USB without formatting or replacing existing folders; new Dell/ASUS execution remains pending.

**Subsequent owner-requested work:** the [existing-capture follow-up](negotiation-followup.md) traces the correction-flag writer and separates the hosts' initial and PD-time reports. The [initial CC-role test](initial-role-test.md#measured-result-2303-2304-utc) then ran once: Rp-only accepted, no reported attachment/PD, default DRP restored, no recovery pending. Its trace has 238,588 events, zero reported loss and 118 unknown records. It did not establish the intended causal comparison. Preserve the new evidence; repeat neither that unchanged test nor the earlier rejected mode exit. No next firmware intervention is prepared.

The [research review](research.md#continuation-review-31-october-2026) distinguishes native USB4 entry from alternate-mode commands. A custom repair needs an observed failed transition, an applicable control over it and a reversible result that changes router enumeration. No such control is currently validated.

The immediate development opportunity is an [offline evidence comparer and report generator](tool-scope.md), using existing captures first. It can make the negotiation divergence and coverage gaps easier to inspect without sending another firmware command. A successful comparison report must still label the cause unresolved. Optional changed-hardware tests remain in the [existing matrix](handoff.md#deg2-cable-and-peripheral-comparisons).

## Repository maintenance

The public repository was maintained through GitHub's API, while the local checkout's `.git` still points at its initial commit and has no remote configured. Consequently, a large local working-tree diff is not a list of unpublished changes. At continuation, all 38 public file paths were present locally; 33 Git blob hashes matched exactly and the remaining five differed only in blank lines/line endings. Compare against the current remote tree before publishing or resetting anything. This review changes documentation only; it supplies no new hardware test.

## Continuation cleanup, completed

Six confirmed duplicate directories, containing 68 files and 345,985,244 bytes, were moved to the Windows Recycle Bin. They were two downloaded Dell results/update copies and four repeated file-transfer helper directories. Every file matched a retained project copy by SHA-256 before removal; every retained copy was rehashed afterward. The private receipt records both locations and each hash. Recycle Bin was not emptied, so this is recoverable removal of clutter, not a claim of reclaimed disk space. No unique capture, support record, test installation, boot entry, driver, network setting or USB-drive file was removed.
