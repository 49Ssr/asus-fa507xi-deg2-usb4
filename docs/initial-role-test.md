# One initial-role comparison with existing hardware

**Prepared, not run on hardware.** [Why this tests a new variable](negotiation-followup.md). This is an experiment, not a verified Windows fix. It changes connector 1's CC operating policy for one attachment using the existing documented UCSI interface; it does not flash firmware.

Entry point: [Test-USB4InitialRole.ps1](../tools/Test-USB4InitialRole.ps1). Default mode is Preview. It imports the existing exercised primitives without changing their ASUS model, native-tool or mode-exit guards. The new packet allowlist is separate; the earlier TestModeExit path is unchanged.

## Preconditions and run

- Exact ASUS FA507XI and the analyzed UCSI class-driver/native-tool hashes; existing prepared UCSI interface. No automatic enabling, driver restart or registry write.
- Laptop on its normal barrel charger. Keep the assembled DEG2/PSU powered and use its supplied cable at the same ASUS USB4 port.
- Start with DEG2 attached in its usual failing state. The tool requires the captured Billboard identity, connector state and source PDO bytes, then verifies advertised CC-mode/DRP/provider support. An already-enumerated DEG2 router stops the test.
- Use Administrator Windows PowerShell 5.1 and keep 3 GiB free. Raw traces and state stay under ignored `local/` storage.

From the repository folder:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-USB4InitialRole.ps1 -Mode Preview
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-USB4InitialRole.ps1 -Mode Test
```

The script first performs the target checks. It then asks for upstream-cable disconnection. It verifies connector 1 is disconnected, starts its own bounded ETW trace, durably saves pending restoration, and requests Rp-only once. **Reconnect at GREEN**, then keep the cable connected during the 30-second observation. The trace stops before the final interactive prompt. Disconnect again when asked so the script can request default DRP once and save its completion.

## Exact change and restoration

| Purpose | CONTROL high / low | Conditions |
| --- | --- | --- |
| Select connector-1 Rp-only CC mode | `00000000 / 00810008` | Advertised support, validated target beforehand, freshly disconnected status, saved pending-restoration state |
| Return connector 1 to reset/default DRP | `00000000 / 02010008` | Same validated host/interface and restoration record; freshly disconnected status |

The native request engine has five-second process limits and preserves each intent/reply. ETW uses a unique owned session with a 1 GiB sequential-file cap. A failed GET, rejected/uncertain SET or malformed reply stops further firmware requests in that run. No automatic role-swap cycle, PPM reset, mode entry/exit, power-contract command, reboot or Windows networking change is added. No live kernel helper is loaded.

**If restoration is pending:** disconnect DEG2, then use the separate recovery mode on the same Windows installation:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-USB4InitialRole.ps1 -Mode RestoreDrp
```

This mode refuses a missing/mismatched record or a connected port. A completed restoration record makes subsequent calls a no-op. Interrupted state is retained and blocks another Test. Exact pre-test CC policy is not queryable; the recovery requests the documented default DRP, not an asserted read-back of an unknown original value. The existing diagnostic-interface setting remains as it was.

## Interpreting the observation

| Observation | Meaning |
| --- | --- |
| Request rejected | Advertised support did not yield a usable Rp-only request. Preserve the reply; do not guess a different packet or repeat it. |
| No Type-C attachment | Changed power/CC arrangement did not establish attachment in that window. This does not isolate the original USB4 failure. |
| Attachment but still no external router | Decode whether it actually started as source/local DFP. If so, the later OS correction is not necessary for reproducing failure under that condition. |
| External router appears | A candidate ordering workaround was observed. GPU binding/output and restart/reconnect stability remain separate checks. |

The post-window status is supplementary; **ETW must confirm the initial role and whether SET_UOR was avoided** before interpreting the causal test. A successful command or an exit code is not a working USB4 measurement. Normal completion restores DRP, so this does not install a persistent workaround.

## Software validation

Windows PowerShell 5.1: actual Preview passes, and [74 assertions](../tests/Test-InitialRole.ps1) pass using retained ASUS replies plus mocked native/ETW operations. They check independent packet bytes, changed capabilities/target, disconnection, malformed/failed replies, saved-state-before-dispatch, failed preflight, rejected SET, post-GET failure, connected cleanup, unwritable state, trace ownership and preserving an already-working router. No hardware SET was performed by these tests. Dependencies remain private; this source is not a general-purpose installer.
