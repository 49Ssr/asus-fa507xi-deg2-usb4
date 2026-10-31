# Scripted UCSI / EC buffer examination

**Retired during owner-requested cleanup on 31 October.** This page records a completed experiment. Source links identify the historical revision; the collector and its tests are no longer in current `tools/` or `tests/`. The invocation examples below are historical, not the current next action.

**The corrected live capture completed on 31 October at 12:35 UTC. Both mappings were validated, but LiveKD could read neither buffer. No firmware bytes or actionable repair were obtained.**

**The guided connection-window run is complete.** All 80 samples validated both mappings, but neither firmware buffer was readable. ETW captured the connection with 8,221 events and zero reported loss; external-router/GPU enumeration still failed. See the [measured result and decoded sequence](hotplug-window.md).

[Invoke-UcsiMemoryProbe.ps1](https://github.com/49Ssr/asus-fa507xi-deg2-usb4/blob/90ad1d612df03fef1875bcefebe554b1afab42a3/tools/Invoke-UcsiMemoryProbe.ps1) wraps Microsoft's signed LiveKD and KD with [UcsiMemory.js](https://github.com/49Ssr/asus-fa507xi-deg2-usb4/blob/90ad1d612df03fef1875bcefebe554b1afab42a3/tools/UcsiMemory.js). It tests whether a live kernel view exposes the two buffers omitted from the Task Manager dump. Microsoft describes LiveKD as a simulated kernel-debugging view; it does not promise access to these particular firmware pages.

## What it examines

The capture discovers `\_SB_.UBTC` from the current target's ACPI namespace, verifies its USBC000 hardware ID, and requires exactly these known SystemMemory mappings:

| Region | Bound | Interpretation |
| --- | ---: | --- |
| PM08 | 48 bytes | Raw UCSI block; version/CCI/control/message fields decoded only for implemented UCSI 1.0/1.1/1.2 layouts |
| EURM | 64 bytes | Raw vendor EC shadow bytes; no generic EC register interpretation assumed |

Addresses come from that session, never from the earlier dump. Physical offsets, ambiguous mappings, unexpected sizes, overlaps and address wrap are rejected before reads. Missing/partial reads remain unavailable, not zero-filled data. Unknown versions, including `0xffff`, remain raw. The CCI offsets were checked against the matching Microsoft UcmUcsiCx public type information.

The script sends no firmware writes, UCSI requests or AML method executions. It uses virtual reads only, not an arbitrary physical-memory or EC-port interface. LiveKD itself may temporarily load its Microsoft helper driver and create its working files/service; Capture accepts the Sysinternals EULA. This is not a claim of zero operating-system side effects. It makes no boot/security changes or controller/driver-binding resets. If Windows blocks the helper, preserve that result rather than disabling protections.

LiveKD's view and the separate buffer reads are **not an atomic firmware snapshot**. Receiving bytes does not prove their freshness, validity or that USB4 negotiation succeeded.

## Historical invocation

Use 64-bit Windows PowerShell 5.1 or later. The debugger must be an official x64 KD distribution containing JsProvider.dll. The default debugger path is the privately extracted copy used for the earlier dump analysis; elsewhere supply `-DebuggerPath`.

```powershell
# Default: describe the plan without loading a helper or writing output.
powershell.exe -NoProfile -File .\tools\Invoke-UcsiMemoryProbe.ps1

# Provision signed LiveKD and matching kernel/ACPI public PDBs; no helper loaded.
powershell.exe -NoProfile -File .\tools\Invoke-UcsiMemoryProbe.ps1 -Mode Prepare

# Administrator console; keep DEG2 connected in its failing state.
powershell.exe -NoProfile -File .\tools\Invoke-UcsiMemoryProbe.ps1 -Mode Capture -Label attached

# Administrator console; guided disconnect/baseline/connect window plus ETW.
powershell.exe -NoProfile -File .\tools\Invoke-UcsiMemoryProbe.ps1 -Mode Capture -Connection -Label hotplug
```

The staging copy used for the completed captures was prepared with checked Microsoft executable signatures and PDB identities. Preparation could reuse the existing matching private symbol cache, or an explicitly supplied `-SymbolCache`; otherwise it downloaded from Microsoft's symbol server. The managed Windows PowerShell process could not reach that server here, so existing verified symbols were reused. DbgEng additionally enforced strict symbol matching.

Each run creates a new ignored `local/UcsiMemoryProbe/Runs/` folder containing `status.json`, `probe.json` when available, and private debugger/launcher logs. It never uploads these files. The default launcher timeout is 120 seconds; an unnamed Windows job contains its processes. The timeout path was tested with a disposable child process, not LiveKD. Forced process cleanup does not establish that a loaded kernel helper was unloaded.

At 12:18:59 UTC on 31 October, the first Administrator run returned `NotCompleted`: KD opened a truncated log pathname and attempted COM1 instead of attaching to LiveKD's simulated dump. LiveKD returned exit code 0 despite that failure; the wrapper correctly rejected the missing transcript/result. This is a launch failure, not evidence about GPU compatibility or firmware-page readability. The logs do not establish whether the helper loaded or unloaded.

The first correction removed unnecessary quoting of simple arguments and used relative command/log filenames with inherited symbol/image paths. At 12:26:17 UTC, the next live run opened the simulated kernel dump and loaded kernel symbols, then waited at KD's initial command prompt until the 120-second timeout. The log was found in the debugger executable's directory, rather than the requested per-run directory. The probe script was absent from that changed working directory. Microsoft documents that `-cf` resolves relative paths there and silently ignores a missing file. No probe command or firmware read ran.

The correction passes an absolute command-file path and puts the absolute log path in the child environment, alongside symbol/image paths. The regression test deliberately changes directory before launching actual offline KD; the script executes and the log lands in the intended output directory. Full offline replay also passes. The exact internal cause of the first attempt's argument truncation remains unestablished.

The third live capture ran from 12:35:05.241 to 12:35:06.810 UTC. KD opened the current LiveKD view, executed the JavaScript probe, emitted one complete result and exited normally; LiveKD returned 0. Discovery was `Validated` and the result was `RegionsUnavailable`: the 48-byte PM08 and 64-byte EURM virtual reads each returned an unable-to-read-memory error. No complete or partial buffer contents were returned to the probe. Its private result SHA-256 is `5C942C82FC093430D3CBE61AC9EE09AF2DE65AC602616CF7E6249A726C4AFB5E`.

This establishes that the tested LiveKD view could not expose these mappings. It does not establish why those reads are unavailable, whether the firmware state is faulty, or a GPU defect. There is no firmware payload to compare or basis for a targeted patch from this result. No firmware write, AML execution, explicit physical-memory command or security change occurred. An identical rerun has no identified new variable to test.

| Result | Meaning |
| --- | --- |
| BothRegionsReadable / OneRegionReadable | The provider returned complete byte buffers; inspect raw values and version before inferring firmware state |
| RegionsUnavailable | Discovery succeeded, but the view could not supply the bytes; this is not a hardware-fault verdict |
| DiscoveryFailed | Expected namespace, symbol support or mapping could not be validated |
| NotCompleted | Launcher, permission, helper, timeout or report-generation failure; inspect the private logs |

## Guided connection window

1. Run `-Mode Capture -Connection`. Disconnect DEG2's upstream USB-C cable from ASUS when asked, leave the dock/PSU powered, and press Enter.
2. ETW starts before LiveKD. Wait while the first validated sample and a five-second disconnected baseline are recorded.
3. Connect only when the green **CONNECT DEG2 NOW** message appears. Keep it attached until completion; no second Enter press is needed.
4. Preserve the private output directory. The default is 80 samples with a requested 500 ms pause between them, plus read/diagnostic overhead: approximately a minute in total. The existing 120-second launcher timeout remains active.

Every sample rediscovers and validates the current mappings, records UTC read times and attempts the same two bounded firmware reads. KD's memory cache is disabled and flushed before sampling. First/last samples include `!pte` mapping metadata, not explicit physical firmware reads. A four-byte `nt!NtBuildNumber` read checks normal kernel-memory access. An optional twelve-byte `nt!KeTickCount` control checks for changing values when its public symbol is available; that symbol is absent from the prepared symbols here. Unavailable/static control data does not verify freshness or imply a fault.

The same fifteen USB4/UCSI/PnP/USB providers used by earlier connection traces run concurrently in a uniquely named, 256 MiB capped circular ETW session. The script stops only that session in `finally`; stop status and any failure are retained. USB packet-header/payload keywords remain excluded. Before/after inventories are restricted to USB4, display and known fallback-device rows. All raw output stays under ignored `local/`.

The wrapper reads a streamed readiness marker while KD is still running. It requests connection only after the baseline and while at least ten seconds of requested sampling pauses remain. `connection-markers.json` records the prompt time; it is **not a verified physical insertion timestamp**. Actual transitions must be correlated with ETW. A missed prompt or incomplete sample set is rejected. Partial sample lines remain in the logs if a timeout prevents the final report.

This is periodic sampling, not continuous capture of every firmware register change. Read overhead changes the cadence; transitions between samples can be missed. Disabling KD's cache does not guarantee firmware freshness or an atomic snapshot. If all reads remain unavailable, the result still cannot identify firmware contents or justify a patch. ETW loss/decoding must be assessed separately; no zero-loss claim is made at recording time.

`source: OfflineReplay` must never be presented as live access. If live bytes become available, a separately labelled disconnected/attached comparison can test whether firmware and OS caches disagree. A specific mismatch could justify a targeted recovery or vendor investigation; buffer access alone does not establish a repair.

## Validation actually completed

- Windows PowerShell 5.1: 37 checks, including actual PE/PDB identity matching, invalid inputs, native argument quoting, report framing, window bounds, phase timing, duplicate/late prompts and owned-process timeout cleanup. Actual offline KD is launched through a test launcher that changes its directory; absolute script/log paths and inherited symbol/image paths work across that change.
- Actual WinDbg JavaScript engine: 27 checks covering mapping/length/address guards, unavailable and partial reads, legacy decoding, unknown versions, bounded controls, sample ordering and incomplete windows.
- Real KD executed a six-sample window, rediscovered both mappings six times and retained first/last page-table metadata. Normal kernel control reads succeeded while firmware reads remained unavailable. The live readiness marker was readable before that debugger exited; `.cache 0`, decimal `.sleep` intervals and a large chunked JSON result were exercised. This was OfflineReplay, not a hardware connection test.
- End-to-end replay of the retained Task Manager dump with the absolute script path and inherited log/symbol/image paths: discovery validated, both regions unavailable, correctly labelled OfflineReplay. No LiveKD helper was loaded during these checks.
- LiveKD 5.65 signature: Valid, Microsoft Corporation. The third live attempt completed with validated mappings and both reads unavailable. The debugger and launcher exited normally; helper unloading was not independently verified.

The [test script](https://github.com/49Ssr/asus-fa507xi-deg2-usb4/blob/90ad1d612df03fef1875bcefebe554b1afab42a3/tests/Test-UcsiMemoryProbe.ps1) operates on an existing offline dump. It does not perform firmware or live-kernel tests.

The guided combined live run and ETW start/stop have now completed normally. Normal kernel controls were readable in all 80 samples; firmware reads were unavailable in all samples with KD's cache disabled. This does not rule out changes between samples or establish the cause of the unavailable reads. No UCSI-labelled records were observed in the decoded ETL. No controller reset, driver replacement, boot/security edit or firmware write was part of the run.

## Interface choice and sources

An Administrator PowerShell process does not gain a general kernel-memory mapping API. GetSystemFirmwareTable retrieves firmware tables, not these current ACPI/EC buffer contents. The UCSI GET-data IOCTL is a driver-to-driver transport interface requiring a PPM object. On this BIOS, disassembly of its receive method also shows writes clearing shadow notification bytes. Direct command injection is therefore not used for this examination.

Primary references: [Microsoft LiveKD](https://learn.microsoft.com/en-us/sysinternals/downloads/livekd), [KD command-line options and missing command files](https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/kd-command-line-options), [debugger environment variables](https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/general-environment-variables), [local kernel debugging and LiveKD limitations](https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/performing-local-kernel-debugging), [GetSystemFirmwareTable](https://learn.microsoft.com/en-us/windows/win32/api/sysinfoapi/nf-sysinfoapi-getsystemfirmwaretable), [UCSI client architecture](https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/write-a-ucsi-driver), [UCSI GET-data IOCTL](https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/ucmucsippmrequests/ni-ucmucsippmrequests-ioctl_ucmucsi_ppm_get_ucsi_data_block), and [WinDbg JavaScript host memory API](https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/native-objects-in-javascript-extensions-debugger-objects).

Connection-window commands: [KD cache controls](https://learn.microsoft.com/en-us/windows-hardware/drivers/debuggercmds/-cache--set-cache-size-), [decimal sleep intervals](https://learn.microsoft.com/en-us/windows-hardware/drivers/debuggercmds/-sleep--pause-debugger-) and [page-table metadata](https://learn.microsoft.com/en-us/windows-hardware/drivers/debuggercmds/-pte).
