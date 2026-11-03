# Research and maintenance rules

## Read first

- [Current findings](docs/status.md)
- [Research handoff](docs/handoff.md)
- [Current plan](docs/investigation-plan.md)
- [Linux capture guide](docs/linux-capture.md)
- [Research checkpoint](docs/ps8830-investigation-intervals.md)

These pages replace the old stream of dated status updates. [History](docs/history.md) preserves the earlier instructions and observations; superseded “next actions” are not current authorization.

## Technical state

The ASUS FA507XI/DEG2 failure is unresolved; no Windows repair is demonstrated. The captured path is connector1/XHC3/NHI0/RT0. RT1 is a separate host instance. Stored PD USB4/TBT3 settings are enabled; resolved policy and attachment-time controller programming remain unknown.

Windows role correction succeeds and ordinary USB enumeration follows. Dell's different role ordering is a correlation, not a proven cause. Final router absence does not prove a link never existed. Separate wire observations, code facts, software reports and hypotheses.

The Linux kit is an observer, not a repair or a raw PD recorder. Current source/kit revisions and checks are recorded in evidence. The first ASUS Linux capture saved to USB and reproduced fallback with no observed external router or new PCIe device. A matching Dell Linux capture is currently unavailable. Use the existing successful Dell Windows captures as the control. Do not ask for more Dell boot-menu attempts or an unchanged Windows capture. See docs/linux-asus-result.md; do not repeat ASUS unchanged. PCIe authorization pending is different from failed router detection; internal GPU inventory is not external-GPU success.

## SDK reference now available

EZ-PD Host SDK 3.9.0 has been extracted privately without installation. Read [the SDK review](docs/infineon-sdk-review.md) and its source pins before continuing. Missing AMD headers and compiled implementations are now available; do not ask for another download. APU index 80/status-bit-6 behavior was checked in offline emulation, not on ASUS. Do not send reference HPI or I2C commands to ASUS/DEG2 without identifying the actual implementation.

## PD firmware acquisition

The [Windows PD cache read](docs/pd-firmware-version.md) completed: bytes0053, getters10/11 hex, driver status0, handle closed and temporary SYSTEM task removed. Older0f/10 notes were corrected before hardware use. The cache originates from PD registerB6 but can survive a failed refresh. Real ASUS IT8853 and IT8857 different-board references are privately available under local/PdFirmwareResearch; do not redownload them or run the updaters. The UEFI tool advertises /ov version-only mode; the laptop bus mapping/startup effects remain unverified. No exact laptop PD image or Data_Reset handler is established. New owner photographs identify IT8857FN and PS8830 A3; the older IT8853 OEM response is a literal EC string, not silicon identification. Read docs/board-photo-review.md and prioritize the actual photographed part; preserve earlier captures and do not transplant the different-board IT8857 image.

The [version audit](docs/it8857-version-path.md), [PMC3 transfer trace](docs/ec-host-transfer.md) and [update-interface read review](docs/update-interface-reads.md) are complete for their recorded scope. Update-address reads include identity, flash/status and a six-byte parameter block, not an identified live PD log. The A0 reader ignores errors and conditionally writes; AsusEC_X64 can install a separate helper driver. No existing Windows PMC3 bridge is established. The [runtime command analysis](docs/it8857-runtime-commands.md) now traces the reference record's Enter_USB producer and receiver initialization. Its masks also occur for USB2/USB3 requests; they are not unique USB4 or training flags. Compare the laptop's normal-PD reads and consumers for an equivalent entry-result field. The card peripheral values are not established laptop addresses. Do not repeat completed audits or execute vendor tools/DLLs.

## Component behavior

Read docs/component-behavior.md before proposing a register capture. PS8830 software-written mode flags are not physical-link proof; PS8802 reads can wake it; the ITE event handler acknowledges events. The original PS8802 reader runs against RAM-only fixtures in tools/analysis/Test-Ps8802ReadBehavior.py. Current ASUS state and transport bindings remain unqualified. The IT8857 card reference contains a B6/B7 writer for0110; it is not the laptop image.

## Owner constraints

Scheduling is PAUSED. Do not resume it. Physical boots, BIOS access and cable changes require owner direction. Do not restart an unattended remote session or infer network recovery from Tailscale availability. No live EC/I2C/vendor request, new driver, mode override, flash, security/network change or attachment emulation is selected.

Respect the owner's 1% allowance stop in every applicable known usage window. Verify limits before sustained expansion and ending. If limits cannot be verified or ordinary usage is unavailable, stop research. Never purchase credits, consume resets or automatically resume after a reset. Do not repeat work to consume remaining allowance.

## Preserve evidence

Keep original dumps, ETL/XML, firmware, driver packages, failed attempts and recovery receipts private and intact. Never publish raw memory, binaries/firmware, pointers, instance suffixes, serials, account identifiers, support cases or owner paths. Standard model/VID/PID/version fields and reviewed code offsets are acceptable.

Treat sources/ in the parent workspace as read-only synced material. Cleanup is project-scoped: inventory first, preserve originals, verify reconstructible copies and retain a receipt. Prefer recoverable disposal. Do not touch unrelated drives, Downloads or projects.

## Code and tests

Default hardware tools to Preview. Prepare the exact observable, binding, error handling and restoration path before any device operation. Retain unknown/missing values; do not decode absent data as zero. Do not reuse generic vendor commands or another board's patch without a matching implementation.

The old role-policy filter, Rp-only test, mode-exit request and cold-start comparison are completed/inconclusive records. Do not reinstall or repeat them unchanged. The selected older OEM PDO getter is a firmware stub. Cached Parade status and updater output reports do not provide a qualified live mode read. Existing NACK/timeout attempts are not permission to retry.

Use explicit UTF-8 for text. Keep generated Linux payloads LF-only. Run checks appropriate to the changed behavior; mocks and VM startup do not certify a hardware fix. Generated evidence reports must match their source pins.

## GitHub publication

The local Git index is stale after API-published commits. Do not reset it or bulk commit. Read fresh remote main, verify exact preimages, and publish only a reviewed file allowlist on that parent. Verify every changed blob, tree, parent and final head. Preserve unrelated files/history. Keep private publication receipts locally.

Update current findings only for actual new results. Preserve dated evidence; add corrections rather than rewriting measured records to fit a hypothesis. Write plain language explaining what changed and what remains unknown. Tests, process labels and counts are not a hardware result.

## Useful checks

```text
python tools/analysis/Run-Investigation.py --check
python tools/analysis/Test-Investigation.py
python tools/analysis/Test-InvestigationAutomation.py
python tools/linux/test_capture_usb4.py
python tools/analysis/Check-Docs.py
```

Use [the tool guide](tools/README.md) for status and scope. Original hashes, code anchors and attempt records are in evidence/ and the private local/ corpus; keep source pins and case distinctions intact.
