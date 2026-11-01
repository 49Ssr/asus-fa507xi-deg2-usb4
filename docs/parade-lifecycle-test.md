# Retimer target leak: reproduced code path and controlled next test

**The original driver has a reproducible missing-cleanup path after a failed MCU-version read.** The candidate cleanup corrects that path in offline emulation. It is not an installed Windows patch or a demonstrated USB4 fix. The separate cause of the first failed I2C read remains unresolved.

## Why the target is left open

The pinned `PRHidDrv.sys` 1.0.11.0 offer callback executes this sequence:

1. Open three outer targets for instance 18 and initialize their inner SPB/resource-hub targets (RVA `0x19000`).
2. Store the active handles in shared transport globals (RVA `0x2eec`).
3. Read four MCU-version bytes at register 1 using the third target (`0x1b6c` -> `0x2d6c` -> `0x31a8`, IOCTL `0x04001c10`).
4. If the transport read fails, the helper returns false and sets offer status/reason to zero. The caller stores version zero in the reviewed zero-buffer case, records the offered version and sends **SKIP**. It bypasses the cleanup routine at `0x19438`.
5. CFU requires the host to offer a skipped image again. The retry allocates three new outer targets and overwrites the context's saved handles. The first initialization attempts to reopen the still-open inner target and fails.
6. The failure branch invokes cleanup, but it now closes the **new** triplet. The original triplet remains Started, parented to the HID device, with its context handles lost. The transport globals still reference that original triplet.

That accounts for the combination in the [existing dump](parade-updater-failure.md): context target fields zero, original outer targets Started, inner resource-hub targets Closed, offered version retained, MCU version buffer zero and an already-open recorder error. It is a code-path reproduction consistent with the dump, not a recovered packet-by-packet trace proving every original callback.

An earlier ASUS full snapshot was also reopened. It contains the same object identities and already-open recorder entry. Both snapshots belong to the **same kernel boot**; this corroborates retained history, not an independent boot reproduction. Dell has a different Intel controller/retimer path, so this ASUS-only driver test cannot establish the Dell handshake's physical difference.

Leaving targets open after a valid **ACCEPT** is intentional while waiting for firmware data. Closing every accepted session would break legitimate updates. The proposed correction is narrowly to clean up on the failed-read/SKIP path before returning the response. [Microsoft CFU status and retry rules](https://learn.microsoft.com/en-us/windows-hardware/drivers/cfu/cfu-specification), [KMDF already-open rejection implementation](https://github.com/microsoft/Windows-Driver-Frameworks/blob/main/src/framework/shared/targets/general/fxiotargetremote.cpp).

## What was executed and verified

[Test-ParadeLifecycle.py](../tools/analysis/Test-ParadeLifecycle.py) executes the original pinned driver bytes in an emulated x64 CPU. WDF, I2C, registry, HID delivery and allocation behaviour are explicitly substituted. No Windows device or kernel interface is opened.

| Scenario | Original code | Candidate cleanup in emulator |
| --- | --- | --- |
| Version transport read fails | SKIP, three outer/inner targets left active | SKIP, own targets closed |
| Next offer after that failure | Already-open error; original triplet remains active; no second version read | Second version read proceeds; matching version rejects and closes targets |
| Successful matching / zero / all-ones version read | Rejects and closes targets | Same observed outcome |
| Successful different version read | Accepts, preserves targets for payload | Same observed outcome |
| Registry cache already equals offer | No targets opened | Unmodified cache control |

Eleven scenarios pass. A fresh original emulator instance reproduces the original failure after the candidate run, and the source driver hash is unchanged. The candidate is an injected call to the **existing cleanup routine inside the emulator**; no binary file is patched and no installable patch is produced. Payload entry is prohibited and emulated IOCTLs are limited to initialization and register-1 version reads. [Structured results](../evidence/parade-lifecycle-emulation.json).

The test doubles deliberately provide the I2C failure and resource-open state. They validate the driver's response and target lifetime, **not** why the hardware read failed or actual cancellation/power/firmware behaviour. During harness development, a security-cookie stub initially clobbered RAX and masked the error return; it was corrected to preserve RAX before recording the passing result. Successful invalid-version reads also reject rather than skip; the final controls retain that actual behaviour.

For reproduction, install the pinned [Unicorn dependency](../tools/analysis/requirements-parade-emulation.txt) in a private environment and pass a private driver copy with SHA-256 `9B701E2BEF6411AC2ECB01CF9819DDEEDEFD0975A77863726E77009D89D4296C` using `--driver`, plus a new private JSON path using `--output`. The harness refuses another binary or overwriting a result. [Unicorn documentation](https://www.unicorn-engine.org/docs/).

## First-read question: ACPI and MCU banks

Offline AML inspection identifies the MCU endpoints as I2C addresses `0x11` and `0x21`, at 400 kHz on the same declared controller. Instance 08's ACPI name is `PSX8`, not `PS08`; the initial guessed `PS08` lookup failed and was corrected using actual PnP location metadata.

Both HID devices have `_STA` returning constant `0x0f`, so ACPI presence/healthy binding does not prove a chip answers I2C. The MCU endpoint at `PS11` has a vendor `_DSM` returning constant support/success buffers for the reviewed functions; `PS21` returns a zero buffer. Reviewed initialization/cleanup branches in these methods perform no hardware writes or calls to power/mux methods. This disproves the earlier concern **for these exact methods and BIOS**, not for arbitrary ACPI methods or other boards. It does not establish that bank 18 is physically populated or identify its physical USB-C port.

## Prepared hardware test and rollback boundary

**Prepared at 14:33 UTC, not executed:** the existing test image was checked for the reviewed SPB binary and absence of a Parade CFU package. The kit was copied with verified hashes to its Administrator desktop folder **USB4 Retimer Version Test**, then the image was detached. The original-Windows Preview correctly refuses Test. Windows PowerShell 5.1 parsing, seven readiness refusals and transport compilation/unknown-endpoint refusal pass without opening an allowed device. An actual Preview also caught an empty `$PSScriptRoot` default-parameter issue in PS5.1; initialization was moved after parameter binding before the final kit was staged. Earlier failed preparation logs were retained. [Preparation receipt](../evidence/parade-version-probe-preparation.json).

[Test-ParadeMcuVersion.ps1](../tools/analysis/Test-ParadeMcuVersion.ps1) with its pinned [C# transport](../tools/analysis/ParadeVersionProbe.cs) tests the first read without the CFU offer/retry path. It defaults to Preview. Actual Test requires:

- ASUS FA507XI BIOS 314 and the exact reviewed original SPB binary/bindings.
- The **existing** `USB4 test - temporary Windows` native boot, within 30 minutes of startup.
- No installed Parade CFU package or bound Parade Firmware-class updater, no connected DEG2 and no active physical network adapter.
- Owner confirmation that USB-C cables are disconnected; unchanged transport hash and no prior attempted result in the output folder.

It opens only `PS883011`, then `PS883021`, exclusively. Each endpoint receives one bus initialization and one four-byte version read at fixed register 1. That read includes an I2C register-address write, but no register-data, CFU offer/payload, SPI erase/program, firmware-dump or reset operation. The first failed operation stops the run. There is no retry, driver install, package removal, registry edit, security change or reboot.

Each owned handle closes in `finally`, invoking the reviewed stock file-cleanup path. Per-request waits are bounded and request cancellation is attempted on timeout; unresolved asynchronous buffers are retained until process exit. A userspace timeout cannot guarantee recovery from a hung kernel driver. The tool records errors and handle-close results, rather than claiming a physical-state rollback it cannot observe.

**Rollback:** this probe changes no persistent Windows setting. Close its own handles, preserve the result, and manually return to normal Windows. The original boot default/security state is unchanged. The prepared desktop kit adds only test/evidence files to the existing test image; it installs nothing. No new clean-Windows deployment or repeat DEG2 attachment test is required.

If control bank `0x11` answers but bank `0x21` does not, the cleanup bug is secondary to that failed read; investigate board population/address/port mapping before any firmware update. If both return usable versions, a transient or transaction-order problem becomes a stronger target for a narrowly scoped Windows correction. Zero/all-ones replies are retained as invalid/unknown versions. A control-bank failure stops the test and is inconclusive about bank 18; power gating in the disconnected condition remains possible. Neither outcome alone establishes a USB4 fix. No live version probe or patch has yet been executed.
