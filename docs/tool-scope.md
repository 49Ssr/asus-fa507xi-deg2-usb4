# Scope of a future USB4 diagnostic tool

**Preconnected startup completed, 1 November:** powered DEG2 was connected to the same ASUS USB4 port before power-on and left connected, as confirmed by the owner. Both post-sign-in snapshots still show Billboard, no external USB4 router and no RTX 4080 SUPER; display N. The 20-second trace has 471,428 events, zero loss/format errors and 14 unknown formats. This sequence did not enable USB4. Initial BIOS/PD negotiation is outside the capture. [Measured observation](cold-start-observation.md), [structured evidence](../evidence/cold-start-result.json).

The [policy-only trial](role-policy-test-result.md) remains ineffective and rolled back. Earlier preparation/proposed-action notes below are historical.

**Signing/readiness review completed, 1 November:** a private [local test-signed package and reversible test-boot route](local-test-signing.md) are prepared; the signing key was deleted and production security is unchanged. The [driver review](driver-readiness-review.md) fixed filter initialization, registry typing, callback annotations and two workflow defects. Checks: 4,631 parser, 36 actual-callback/doubled-DDI, 64 workflow and 41 signing/boot; static analysis has zero project results. **No driver has been loaded.** Explicit owner approval and manual firmware/reboot steps are still required; HVCI must remain running. A same-test-boot fallback baseline is required before installation. Native USB4 entry and the original failure remain unresolved.

**Pre-attachment experiment prepared, 1 November:** [role-policy source, controlled test and rollback](role-policy-experiment.md). The unsigned KMDF filter supplies the documented disable-correction policy at UCSI startup; it has **not been installed or loaded**. Native core: 4,631 assertions; PS5.1 workflow: 57 checks with device operations mocked. The real Microsoft client must confirm policy acceptance before a single attachment is allowed. Windows-accepted signing is unresolved; Secure Boot, firmware, drivers and ICS were not changed. This is a causal test, not a verified USB4 fix.

**Design proposal, 31 October 2026. Not implemented or release-qualified.** The existing collectors are research instruments for exercised ASUS/Dell workflows with private dependencies. A public source repository is not yet a standalone, general-purpose repair package.

## First useful deliverable

Build an offline comparer for captures already held by the owner. It should accept explicit input paths, leave originals untouched and produce a local report with these separate outcomes:

| Report field | Required distinction |
| --- | --- |
| Environment | Host model, BIOS, Windows/driver versions and dock firmware; unknown values stay unknown. |
| Connection milestone | USB fallback; external router; PCIe function; driver binding/output; measured stable workload. Peer links use a separate milestone. |
| Negotiation order | Attachment, PD contract, role-correction request/completion, partner flags, router appearance and observation window, tied to one capture and timestamp. |
| Evidence quality | Capture hash, source/decoder identity, event loss, unknown formats, missing providers/pages and unsupported replies. |
| Comparison | First observed divergence and alternative explanations; no automatic causal conclusion from different flags or command order. |
| Privacy | A preview of the exact export and an allowlist of public fields. Raw evidence stays private. |

Use sanitized fixtures from the working Dell, working ASUS-peer and failing ASUS-DEG2 observations. Missing/truncated input, reordered records, zero/unknown version fields, partial decoding and contradictory metadata must produce explicit coverage warnings. Parser tests should not require Administrator access or attached hardware. A round-trip test must show that the exporter cannot include an extra private field merely because it appears in an input object.

## Collection after the comparer works

Start with inventory/topology and bounded ETW collection on explicitly supported Windows versions. Default to preview. Capability-detect host/controller/protocol support; retain the exact ASUS guards rather than weakening them to accept unrelated machines. Model-specific UCSI test-interface preparation is an explicit optional action with original-state restoration, not passive discovery. Reading UCSI through the interface still involves firmware commands.

Capture software success, hardware enumeration and workload stability remain different results. Collectors need owned trace/process cleanup, space/time limits, incomplete-run recovery and proof that networking/settings restore. Redistribution rights and dependency acquisition must be established before distributing a bundle. The existing signed debug tools and hash-pinned UcsiControl should not be silently repackaged as universally supported dependencies.

## Gate for any repair mode

Require a reproducible failure transition and a documented or independently justified control applicable to the exact target. Record original state, one bounded intervention, rollback and pre/post milestones. A candidate must restore router/device operation on the affected pairing and retain working controls across restart/reconnect before it is described as a fix. Broader hardware support requires separate results.

Neither `SET_NEW_CAM`, a guessed mode number, the unavailable URS override nor another model's firmware meets that gate today. The [research review](research.md#continuation-review-31-october-2026) explains the protocol boundaries. Until those requirements are met, publish a diagnostic report generator with an unresolved status rather than automatic repair claims.
