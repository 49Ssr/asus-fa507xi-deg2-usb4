# Parade updater failure: registry, existing dump and native code

**The ASUS has a concrete Windows retimer-updater failure, separate from the still-unresolved DEG2 negotiation failure.** Read-only registry inspection records `Create SPB device fail` for PS8830 instance 18. The existing ASUS dump retains successful device-file opens followed by an attempt to reopen an already-open resource-hub target. No new capture, firmware command or driver change was needed to find this.

## Correcting the firmware-version coverage

Both firmware children report 1.3.0.2 through PnP. That remains an observed property, but does **not** establish an independent hardware-version read from both chips. The installed offer is also 1.3.0.2; these quantities must stay separate.

The current `PRHidDrv` service-parameter values are:

| Value prefix | Saved version word | Saved update status |
| --- | --- | --- |
| `PS8830_08` | `0x01030002` | `Skip Offer` |
| `PS8830_18` | `0x00000000` | `Create SPB device fail` |

These are retained values without a per-value event timestamp. They do not date the failure to today's connection. Offline native review shows the offer handler compares a registry-saved version with the offered version **before** opening the SPB path, and can skip the offer at that point. Consequently, a matching saved version need not imply a fresh hardware query. Zero on instance 18 is an unknown/unrecorded version in this evidence, not proof of blank flash or firmware version zero.

The firmware children's separate `PRCfuDrv` parameters also record CurrentFwVersion 0 and OfferFwVersion `0x01030002` for both children, with raw FirmwareUpdateStatus 1 and RejectReason 1/2. These are retained framework records, not physical flash measurements. Exact vendor-build semantics must be established before assigning a stronger interpretation.

## What the existing ASUS dump actually adds

The matched ASUS full snapshot already used for the Dell comparison was reopened offline. Its SHA-256 is `FA979A86E3A586CF17A9C04C41564526A1CC748B8F8182DF431EAF6A5773928C`, size 3,172,020,224 bytes. Nothing was attached to the live kernel.

Framework hierarchy and context reads distinguish `ACPI\VEN_PS88&DEV_3008` and `ACPI\VEN_PS88&DEV_3018`. Both contexts have component ID `0x30`; a friendly name is not evidence that one uses a different component ID. Their cached get-feature version fields are zero in this snapshot. The instance-18 context retains offered version `0x01030002`.

The retained framework recorder shows:

1. Two triplets of `PRHidDrv` device-file opens return `STATUS_SUCCESS`. Thus the generic error cannot simply be assumed to mean a missing DOS device link.
2. `PRSpbDrv` successfully opens resource-hub targets, then records `Opening an already open WDFIOTARGET`, open state 3, followed by target closures.
3. Inspecting retained target objects binds the first HID triplet to **instance 18** and aliases `PS88301A`, `PS88301F`, `PS883021`. Those outer targets remain Started, with zero pending/sent requests, while inspected inner resource-hub targets are Closed. Their framework objects remain parented to the instance-18 SPB devices.

This identifies retained target-lifetime/reinitialization state worth investigating. It does **not** establish whether the first failure was a race, an earlier incomplete transaction, or another failure, nor that the two retimer instances were confused. Microsoft's documented return for reopening an already-open target is `STATUS_INVALID_DEVICE_STATE`; that return is a source-supported inference here, rather than a numeric status printed by this particular recorder line. [WdfIoTargetOpen](https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/wdfiotarget/nf-wdfiotarget-wdfiotargetopen), [framework recorder](https://learn.microsoft.com/en-us/windows-hardware/drivers/debuggercmds/-wdfkd-wdflogdump).

These are historical recorder entries, not a new measurement of today's attachment. Framework messages decode; vendor-private WPP formats are unavailable, and debugger image-load warnings are preserved. The recorder reports 13 HID and 4 SPB error-level records; those counts are not an analysis assertion count or evidence of 17 distinct causes. Later command-file passes reach both markers and exit normally; an earlier private fields pass retained a trailing command syntax error and is not represented as error-free.

## Why the proposed bus-open probe was not executed

Current metadata-only `QueryDosDevice` checks find all six expected aliases. Static review of the pinned `PRHidDrv` path at RVA `0x19000` shows that its generic SPB-creation failure also covers initialization IOCTL `0x04001c00`, after the file opens. In `PRSpbDrv` this reaches RVA `0x3f68`: it evaluates an ACPI `_DSM` function before opening the resource-hub target. File cleanup reaches RVA `0x2ef0`, which can evaluate further `_DSM` functions before closing it.

Therefore even an open/initialize/close probe is not established as passive. The existing dump supplies useful evidence without executing it. No device handle, IOCTL, HID report or ACPI method was issued by this investigation.

## Firmware writes and recovery: an additional finding

The pinned native updater's routine at RVA `0x2d88` is called with physical address `0x20000` and size `0x10000`. It erases 4 KiB sectors and programs pages in that window. It also conditionally erases the separate sector `0x0f000`–`0x0ffff` and writes marker `0xff02aa55` if the existing marker differs. The marker's platform role is not yet proven.

Thus the recovered 64 KiB package payload does **not** cover every possible write made by this updater. Keeping that old payload or uninstalling the driver is not a demonstrated rollback. The routine labelled as a firmware dump also writes bridge registers before reading; it was not executed as a supposedly passive backup. Reviewed failure branches do not all traverse the success-path cleanup. No claim of automatic firmware recovery is justified.

Reviewed binaries: `PRHidDrv.sys` 1.0.11.0, SHA-256 `9B701E2BEF6411AC2ECB01CF9819DDEEDEFD0975A77863726E77009D89D4296C`; `PRSpbDrv.sys` 1.0.8.0, SHA-256 `A366FAFB3FE15F466D6CE0F302DCC5430B9964A6339CEAF10182AD0B94F8925C`. RVAs refer only to these binaries. Firmware and disassembly remain private.

## Next question and limits

Trace the first instance-18 initialization attempt and the ownership/cleanup of its retained targets, then map the related ACPI `_DSM` power/mux operations and physical port. That is the specific Windows-side lead. Any correction must distinguish bus initialization from offer/erase/program operations and establish recovery before execution.

This updater failure does not yet explain why Dell negotiates USB4 and ASUS does not. In particular, the separate Windows baseline also failed without the CFU updater, so simply removing that package is already an inadequate proposed fix. The [policy-only trial](role-policy-test-result.md) and [preconnected startup](cold-start-observation.md) likewise remain completed negative results. The [catalog candidates](parade-cfu-candidates.md) remain unqualified; no cache clearing, forced retry, package installation, security change or flash is queued on these findings alone.

[Structured evidence](../evidence/parade-updater-failure.json).
