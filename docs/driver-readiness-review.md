# Driver readiness review, 1 November 2026

**Local test signing is prepared; no driver has been loaded.** The parser tests were useful but did not establish that the complete filter was ready. This review found and corrected additional kernel-framework and workflow defects before a live load. [Signing route and controlled activation](local-test-signing.md).

## What the retained dumps and traces establish

The existing exact-symbol transcripts were rechecked, without opening another live kernel or collecting another dump. ASUS has both cached and PPM-config `UsbDeviceControllerEnabled=0`; Dell has 1 in both places. The loaded ASUS support mask is `0x0f`, compared with Dell `0x1f`. The installed ACPI client's file disassembly supplies the actual internal-IOCTL layout and its policy consumer. [Matched evidence](asus-dell-matched-comparison.md).

| Captured behaviour | What this filter must preserve or change | Review result |
| --- | --- | --- |
| Microsoft UCSI client transports normal commands through `_DSM` functions 1/2; firmware notifications and ACK ordering belong to the existing stack. | Forward these requests without another firmware read, ACK, queue or timeout loop. | Functions 1/2/3 and unrelated IOCTLs are passed through. Actual callback tests cover this path. The filter generates no UCSI control packet. |
| Policy is consumed during client initialization. | Be available before DEG2 attachment and before the policy is cached. | Device lower-filter position and a non-power-managed queue cover startup IOCTLs. A Microsoft startup trace, not installation success, gates attachment. |
| The actual client uses an internal ACPI IOCTL and a 60-byte complex input with Size=44. | Handle the internal callback and the measured format. | Pinned static image/WDK layout, native parser tests and callback tests agree. The previous Size=60 error remains recorded. |
| Other ACPI requests include connector enumeration and `_PLD` evaluation. | Retain existing request type, buffers, status and completion information. | Unknown methods/UUIDs, enumeration and extended ACPI requests pass through. Completion interception is limited to the exact support query. |
| ASUS completes normal SET_UOR; detection is negative before and after it. Dell's PD-time role already differs earlier. | Treat suppression as one causal intervention, not a complete Dell handshake implementation. | No claim that the later OS correction explains the earlier detection failure. Native USB4 discovery/entry is still performed by the existing controller/firmware. |
| Both snapshots include idle power states. | Avoid adding an independent power policy or making D3 itself the diagnosis. | WDF retains PnP/power handling; no power ownership, wake policy, controller reset or retimer command is introduced. Actual idle/resume/removal qualification remains outstanding. |
| ASUS failure also occurs with USB flag 1, not only alternate-mode-only flag 2. | Avoid a repair that depends on one fallback flag. | This experiment changes the startup correction policy; it does not force a partner-mode report. |

The dumps do **not** contain a physical PD/Enter_USB/link-training capture or every mapped firmware page. Dell's raw function-3/4 return values remain unavailable. Its power contract and early role ordering differ. This small filter cannot reproduce unknown Dell firmware behaviour or guarantee that ASUS will autonomously reach the correct host role after correction is suppressed.

The filter retains Microsoft's client, UcmUcsiCx, UcmCx and USB4 connection manager. It does not replace their state machines. Reimplementing charging, connector notifications, tunnel setup or GPU enumeration in this shim would greatly widen the experiment and is not supported by the evidence. [Microsoft's UCSI sample transport and consumer](https://github.com/microsoft/Windows-driver-samples/blob/main/usb/UcmUcsiAcpiSample/UcmUcsiAcpiSample/Acpi.cpp), [USB4 software boundary](https://learn.microsoft.com/en-us/windows-hardware/design/component-guidelines/usb4-design-details-and-general-requirements#usb-type-c-requirements).

## Defects corrected during this review

1. **Filter identification came too late.** The earlier code returned success for an excluded model before calling `WdfFdoInitSetFilter`. That call must also precede an early successful return without creating a device. It now runs before the guards. [WDF requirement](https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/wdffdo/nf-wdffdo-wdffdoinitsetfilter).
2. **Registry reads lacked type checking.** The bounded model/manufacturer reads now require REG_SZ with `TYPECHECK` and `NOEXPAND`; an unexpected type cannot be interpreted as the expected string buffer. [Registry API requirements](https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/wdm/nf-wdm-rtlqueryregistryvalues).
3. **One callback had two incompatible function-class annotations.** Static analysis caught the shared callback declaration being assigned to the internal-IOCTL slot. There are now correctly declared thin callbacks feeding one common dispatcher. No warning was suppressed to hide the mismatch.
4. **The saved-run CLI argument was overwritten during import.** The shared collector has its own parameter block, including RunDirectory. The runner now saves its argument before imports; a real PS5.1 subprocess checks that the supplied path reaches the recovery guard.
5. **A helper parameter shadowed the caller's capture directory.** An actual-file baseline test caught inventories being written under the trace subdirectory while later validation expected the run root. The trace owner's parameter was renamed, and real private file/hash checks now cover the baseline path.

These were preparation defects, not hardware failures or owner mistakes. None was exercised by a loaded experimental driver. Earlier private builds, failed checks and publication history are preserved.

## Qualification boundary

Subsequent read-only readiness check: the live device advertises the filter's required ACPI hardware ID, remains healthy on Microsoft's original binding with no filter properties, and all signed package hashes still match. BIOS/Windows remain the analysed versions. An original-state boot snapshot is now saved privately; no activation was performed. A focused static scan found one direct read and one direct write of the cached policy field, consistent with the previously analysed correction gate/configuration copy. This is not an exhaustive proof against indirect or aliased accesses.

- **4,631** shared-parser assertions pass, including the measured layout and malformed buffers.
- **36** assertions execute the actual Driver.c callbacks in user mode with WDF, registry and lower transport doubled. They cover excluded devices, creation failure, internal/external callbacks, pass-through, cancellation/send failure, support-mask arming, short buffers, buffered input/output aliasing and fresh object state.
- **64** PS5.1 workflow checks pass, including same-boot fallback baseline binding and refusal of changed/expired controls.
- **41** signing/boot checks pass. Signature mathematics, signed-catalog membership, corruption rejection, key cleanup, production refusal and CLI argument preservation are real. BCD, trust-store mutation and reboot context are mocked.
- MSVC kernel static analysis reports **zero project results**; SDK/WDK implementation bodies are excluded as external code. The initial pass emitted warnings from obsolete WDK header allocator bodies; these are not project allocation calls. INF verification/catalog generation also pass.

This is not a VM, Driver Verifier, real PnP removal, cancellation-race, sleep/resume or HVCI load result. Kernel object lifetime is still delegated to WDF and must be exercised on Windows. The first hardware stage therefore verifies loading and Microsoft policy acceptance with **all USB-C partners disconnected**. There is no connection prompt if that stage fails. The eventual 45-second attachment is a narrow laboratory experiment, not evidence of release readiness.
