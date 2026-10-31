# Scripted UCSI / EC buffer examination

**The second attempt opened the LiveKD view but never executed the probe script. No firmware bytes were collected. An absolute-path correction has passed offline checks, including a changed-directory test; a live rerun is pending. This is an examination tool, not a fix.**

[Invoke-UcsiMemoryProbe.ps1](../tools/Invoke-UcsiMemoryProbe.ps1) wraps Microsoft's signed LiveKD and KD with [UcsiMemory.js](../tools/UcsiMemory.js). It tests whether a live kernel view exposes the two buffers omitted from the Task Manager dump. Microsoft describes LiveKD as a simulated kernel-debugging view; it does not promise access to these particular firmware pages.

## What it examines

The capture discovers `\_SB_.UBTC` from the current target's ACPI namespace, verifies its USBC000 hardware ID, and requires exactly these known SystemMemory mappings:

| Region | Bound | Interpretation |
| --- | ---: | --- |
| PM08 | 48 bytes | Raw UCSI block; version/CCI/control/message fields decoded only for implemented UCSI 1.0/1.1/1.2 layouts |
| EURM | 64 bytes | Raw vendor EC shadow bytes; no generic EC register interpretation assumed |

Addresses come from that session, never from the earlier dump. Physical offsets, ambiguous mappings, unexpected sizes, overlaps and address wrap are rejected before reads. Missing/partial reads remain unavailable, not zero-filled data. Unknown versions, including `0xffff`, remain raw. The CCI offsets were checked against the matching Microsoft UcmUcsiCx public type information.

The script sends no firmware writes, UCSI requests or AML method executions. It uses virtual reads only, not an arbitrary physical-memory or EC-port interface. LiveKD itself may temporarily load its Microsoft helper driver and create its working files/service; Capture accepts the Sysinternals EULA. This is not a claim of zero operating-system side effects. It makes no boot/security changes or controller/driver-binding resets. If Windows blocks the helper, preserve that result rather than disabling protections.

LiveKD's view and the separate buffer reads are **not an atomic firmware snapshot**. Receiving bytes does not prove their freshness, validity or that USB4 negotiation succeeded.

## Run

Use 64-bit Windows PowerShell 5.1 or later. The debugger must be an official x64 KD distribution containing JsProvider.dll. The default debugger path is the privately extracted copy used for the earlier dump analysis; elsewhere supply `-DebuggerPath`.

```powershell
# Default: describe the plan without loading a helper or writing output.
powershell.exe -NoProfile -File .\tools\Invoke-UcsiMemoryProbe.ps1

# Provision signed LiveKD and matching kernel/ACPI public PDBs; no helper loaded.
powershell.exe -NoProfile -File .\tools\Invoke-UcsiMemoryProbe.ps1 -Mode Prepare

# Administrator console; keep DEG2 connected in its failing state.
powershell.exe -NoProfile -File .\tools\Invoke-UcsiMemoryProbe.ps1 -Mode Capture -Label attached
```

The current owner's C-drive staging copy is already prepared. All Microsoft executable signatures and PDB identities are checked. Preparation can reuse the existing matching private symbol cache, or an explicitly supplied `-SymbolCache`; otherwise it downloads from Microsoft's symbol server. The managed Windows PowerShell process could not reach that server here, so existing verified symbols were reused. DbgEng additionally enforces strict symbol matching.

Each run creates a new ignored `local/UcsiMemoryProbe/Runs/` folder containing `status.json`, `probe.json` when available, and private debugger/launcher logs. It never uploads these files. The default launcher timeout is 120 seconds; an unnamed Windows job contains its processes. The timeout path was tested with a disposable child process, not LiveKD. Forced process cleanup does not establish that a loaded kernel helper was unloaded.

At 12:18:59 UTC on 31 October, the first Administrator run returned `NotCompleted`: KD opened a truncated log pathname and attempted COM1 instead of attaching to LiveKD's simulated dump. LiveKD returned exit code 0 despite that failure; the wrapper correctly rejected the missing transcript/result. This is a launch failure, not evidence about GPU compatibility or firmware-page readability. The logs do not establish whether the helper loaded or unloaded.

The first correction removed unnecessary quoting of simple arguments and used relative command/log filenames with inherited symbol/image paths. At 12:26:17 UTC, the next live run opened the simulated kernel dump and loaded kernel symbols, then waited at KD's initial command prompt until the 120-second timeout. The log was found in the debugger executable's directory, rather than the requested per-run directory. The probe script was absent from that changed working directory. Microsoft documents that `-cf` resolves relative paths there and silently ignores a missing file. No probe command or firmware read ran.

The current correction passes an absolute command-file path and puts the absolute log path in the child environment, alongside symbol/image paths. The regression test deliberately changes directory before launching actual offline KD; the script executes and the log lands in the intended output directory. Full offline replay also passes. This tests the observed path-resolution failure without loading LiveKD; the current live invocation still awaits a rerun. The exact internal cause of the first attempt's argument truncation remains unestablished.

| Result | Meaning |
| --- | --- |
| BothRegionsReadable / OneRegionReadable | The provider returned complete byte buffers; inspect raw values and version before inferring firmware state |
| RegionsUnavailable | Discovery succeeded, but the view could not supply the bytes; this is not a hardware-fault verdict |
| DiscoveryFailed | Expected namespace, symbol support or mapping could not be validated |
| NotCompleted | Launcher, permission, helper, timeout or report-generation failure; inspect the private logs |

`source: OfflineReplay` must never be presented as live access. If live bytes become available, a separately labelled disconnected/attached comparison can test whether firmware and OS caches disagree. A specific mismatch could justify a targeted recovery or vendor investigation; buffer access alone does not establish a repair.

## Validation actually completed

- Windows PowerShell 5.1: 20 checks, including actual PE/PDB identity matching, invalid inputs, native argument quoting, report framing and owned-process timeout cleanup. Actual offline KD is launched through a test launcher that changes its directory; absolute script/log paths and inherited symbol/image paths work across that change.
- Actual WinDbg JavaScript engine: 20 checks covering mapping/length/address guards, unavailable and partial reads, legacy decoding, unknown versions and native byte-provider types.
- End-to-end replay of the retained Task Manager dump with the absolute script path and inherited log/symbol/image paths: discovery validated, both regions unavailable, correctly labelled OfflineReplay. No LiveKD helper was loaded during these checks.
- LiveKD 5.65 signature: Valid, Microsoft Corporation. The second attempt opened its live view, but the automated firmware reads never executed. The timeout wrapper confirms its launcher stopped; it does not verify helper unloading or live firmware-page visibility.

The [test script](../tests/Test-UcsiMemoryProbe.ps1) operates on an existing offline dump. It does not perform firmware or live-kernel tests.

## Interface choice and sources

An Administrator PowerShell process does not gain a general kernel-memory mapping API. GetSystemFirmwareTable retrieves firmware tables, not these current ACPI/EC buffer contents. The UCSI GET-data IOCTL is a driver-to-driver transport interface requiring a PPM object. On this BIOS, disassembly of its receive method also shows writes clearing shadow notification bytes. Direct command injection is therefore not used for this examination.

Primary references: [Microsoft LiveKD](https://learn.microsoft.com/en-us/sysinternals/downloads/livekd), [KD command-line options and missing command files](https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/kd-command-line-options), [debugger environment variables](https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/general-environment-variables), [local kernel debugging and LiveKD limitations](https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/performing-local-kernel-debugging), [GetSystemFirmwareTable](https://learn.microsoft.com/en-us/windows/win32/api/sysinfoapi/nf-sysinfoapi-getsystemfirmwaretable), [UCSI client architecture](https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/write-a-ucsi-driver), [UCSI GET-data IOCTL](https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/ucmucsippmrequests/ni-ucmucsippmrequests-ioctl_ucmucsi_ppm_get_ucsi_data_block), and [WinDbg JavaScript host memory API](https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/native-objects-in-javascript-extensions-debugger-objects).
