# MCU read prerequisites and the working-link counterexample

**Two questions now have firmer answers:** the version-read packet matches the stock transport, and the installed AMD driver maps address-not-acknowledged abort bits to the status that Windows translates into error 433. Separately, the retained retimer targets bookend a successful 40 Gbps ASUS–Dell peer link in the same kernel boot. The updater cleanup defect is therefore not established as the sole cause of the ASUS–DEG2 failure.

No hardware experiment, driver load, firmware write or replacement kit was performed during this follow-up. All debugger work used existing files. [Structured evidence](../evidence/i2c-read-prerequisites.json).

## What the native initialization actually does

The pinned `PRHidDrv.sys` 1.0.11.0 helper at RVA `0x19000` creates/opens three targets, then sends initialization IOCTL `0x04001c00` to each. For bank 08 these are `PS88300A`, `PS88300F`, `PS883011`. The version read uses only the third target, register byte `0x01`, output length four, through external IOCTL `0x04001c10`.

The pinned `PRSpbDrv.sys` 1.0.8.0 initialization routine at RVA `0x3f68` constructs a resource-hub name, invokes its reviewed ACPI helper and opens the resource-hub target. This reviewed path does **not** program retimer registers, toggle a documented chip-reset pin, run an SPI sequence or issue a firmware offer.

Actual ACPI names were resolved from device metadata: the two extra bank-08 endpoints are `PSXA` and `PSXF`, not guessed `PS0A`/`PS0F`. Their `_DSM` methods return a zero buffer. Their namespace entries contain HID, UID, CRS, STA and DSM, without a device-local `_PS0` or `_PR0` entry. `PS11`'s reviewed vendor DSM functions return constant support/success buffers, as recorded previously. None of these reviewed method bodies performs a hardware write or calls a rail/mux/power method.

This narrows the initialization difference: opening the other two targets is **not evidence of a missing retimer-programming sequence**. It does not prove that opening one rather than three has identical controller power/reference/ordering effects. The prior probe's simplification remains unqualified; merely changing it to open three targets is not a demonstrated fix and no repeat is queued.

## Read framing and completion were checked

The native version-read helper `0x31a8` supplies one input byte and a four-byte output buffer. SPB handler `0x4d58` constructs a write-then-read sequence, with the register-address byte as the write. The one-byte/four-byte framing in the probe matches this path.

The native SPB completion routine at `0x3c40` takes the lower request's completion status and passes it to completion helper `0x3070`. On successful combined transfers, it subtracts the register-address write count from the transferred-byte count before reporting output bytes. It does not turn a version mismatch, our readiness check or an arbitrary probe rule into error 433.

The owner's [actual probe](parade-lifecycle-test.md#actual-probe-result-control-failed-bank-18-not-reached) passed file opening and bus initialization, then failed at read completion. No version bytes or bank-18 result were obtained. Kernel/device state prerequisites and real bus acknowledgement remain unresolved despite matching packet framing.

## Error 433: a specific lower-driver path

The original exported and currently installed `amdi2c.sys` files match SHA-256 `D12C0EF69B3C3A7284ADE336404CECAAACC7029B8CDEB1891C873EE5F919FE82`.

Static review of that binary shows:

- At RVA `0x5ef2`, the driver reads MMIO offset `0x80` and saves the abort source in its device context at offset `0xa4`.
- At RVA `0x22a9`, it tests the saved value with mask `0x7`. A set bit in that mask assigns request status `0xc000000e`, `STATUS_NO_SUCH_DEVICE`.
- The DesignWare register map identifies offset `0x80` as TX abort source; bits 0–2 identify 7-bit/10-bit address acknowledgement failures. The separate data-NACK bit 3 takes a different path. [Linux v6.8 DesignWare definitions](https://github.com/torvalds/linux/blob/v6.8/drivers/i2c/busses/i2c-designware-core.h).
- Calling Windows' status-translation function with `0xc000000e` returns **433**. This is a pure status translation, with no device access. [Microsoft API](https://learn.microsoft.com/en-us/windows/win32/api/winternl/nf-winternl-rtlntstatustodoserror).

[Test-AmdI2cAbortMapping.py](../tools/analysis/Test-AmdI2cAbortMapping.py) executes this exact pinned AMD branch in an emulated CPU with seeded RAM. Twenty-two cases pass, covering address-NACK masks, data NACK, arbitration/other errors and abort-cache clearing. No controller is read or written and no driver is loaded. The source binary remains unchanged. An initial arbitration-loss expected value in the harness was corrected to the actual generic-failure branch before recording the passing result.

Microsoft's I2C compatibility tests likewise require `STATUS_NO_SUCH_DEVICE` for an unacknowledged slave address. [HLK I2C tests](https://learn.microsoft.com/en-us/windows-hardware/test/hlk/testref/ef0ce6f0-a8a7-42d0-b0b5-eb01532d6a6a).

**Interpretation:** address non-acknowledgement is a well-supported candidate for the observed error. The real probe's raw abort register was not captured, and Win32 error conversion is not a unique inverse mapping. This is not proof that the chip is absent or dead. An unpowered/reset/hidden MCU interface, address/access assumptions and other lower-stack failures remain possible. It is also separate from the USB4 wire negotiation itself.

## What the dump can and cannot recover

The existing dump maps these SPB targets to the AMD `AMDI0010` controller backing `I2CD`. The controller's abort caches are zero at snapshot time. Its 4 KiB framework recorder holds only 67 recent entries around 00:53:54, after millions of earlier records, not the original 04:11 MCU read. The actual earlier dump's recorder was checked too: its 67 retained entries are around 04:27:38, with the original fault already outside the retained window.

The retained bank-18 request object still exists, but its completion structure is reset: `WdfRequestTypeNoFormat`, status zero and no retained parameters. Bank 08 has no formatted request context. These are **not successful historical version reads** and do not recover the original error. The reviewed request-reuse path explains why a reset completion cannot be treated as preserved fault telemetry. Image-load warnings and initial namespace-lookup errors remain in the private logs.

## Same-boot counterexample: USB4 worked with the retained targets

| Time UTC | Existing evidence |
| --- | --- |
| 31 October 04:11:34 | Kernel boot; peer ETL header reports 04:11:34.500 |
| 31 October 04:11:53 | SPB recorder's already-open-target error |
| 31 October 04:27:38 | Actual earlier dump: original three bank-18 outer targets Started |
| 31 October 13:37:49–13:37:52 | ASUS–Dell peer ETL: Gen 3, two bonded lanes Up, reported 40 Gbps |
| 1 November 00:53:54 | Later dump: same three outer target identities still Started |

The peer trace's saved trace statistics contain its boot time. Both dump headers imply the same 04:11:34 boot to within one second, and retained System event 12 records no intervening boot in this interval. The small subsecond difference between dump-uptime-derived and ETL boot timestamps is retained, not silently forced to equality. [Peer result and rate limits](peer-test.md).

The earlier dump was **actually reopened and verified in this follow-up**, size 2,300,018,688 bytes, SHA-256 `7195F0B0799958785840226C5750700B49632CF932680AB976CC2BEEC0ED965B`. An earlier private script labelled as the older-dump review had accidentally reopened the later dump because a path substitution failed. That script is preserved as mislabelled; this correlation uses the explicit-path/hash-verified older input, not its earlier output. The later dump remains the previously recorded 3,172,020,224-byte snapshot.

The peer ETL is 524,288 bytes, SHA-256 `9A77EEFACB155F79585B536000347500133A61D5FD907AC28A4C4A5EA6BF6D77`. Raw object addresses, device-instance suffixes and peer identifiers remain private.

The target states were sampled before and after the successful peer interval, rather than directly inside its three-second trace. Combined with matching identities and the retained recorder history, this is strong counterevidence to a universal USB4-blocking explanation. A pairing-specific contribution is not excluded. The separate Windows baseline also reproduced DEG2 fallback without injecting CFU, independently weakening the claim that removing or fixing the updater alone is sufficient. [Baseline scope](fresh-windows.md).

## Consequence for the next intervention

The cleanup bug remains a valid software finding. Deploying a cleanup patch as the eGPU repair is not justified by these observations. It cannot supply a missing MCU response by itself, and the ASUS has demonstrably established a 40 Gbps peer link within the same boot history.

The useful remaining boundary is **ASUS–DEG2 entry/training and the firmware's report to Windows**, with Dell and ASUS–Dell retained as working controls. The captures show successful PD/data-role exchanges followed by failure to expose an external USB4 router on ASUS. They do not contain a raw PD/Enter_USB/link-training packet capture. The power/reset prerequisites for direct MCU access are also not independently established on this board. Upstream PS8830 code explicitly manages reset and supplies on other platforms, but copying that platform's GPIO/rail operations onto ASUS is not qualified. [Upstream PS8830 driver](https://github.com/torvalds/linux/blob/master/drivers/usb/typec/mux/ps883x.c).

No new test boot, live bus retry, cache clearing, controller reset, firmware candidate or experimental driver is queued. Preserve the failed probe and original captures. Any next hardware request must target a specific remaining distinction that these controls do not already answer.
