# One initial-role comparison with existing hardware

**Run once on hardware, 31 October 2026: no reported attachment under Rp-only; default DRP restored.** [Why this tested a new variable](negotiation-followup.md). No working Windows fix was established. Do not repeat the same test unchanged. The historical procedure below is retained for reproducibility and recovery.

Entry point: [Test-USB4InitialRole.ps1](../tools/Test-USB4InitialRole.ps1). Default mode is Preview. It imports the existing exercised primitives without changing their ASUS model, native-tool or mode-exit guards. The new packet allowlist is separate; the earlier TestModeExit path is unchanged.

## Measured result, 23:03-23:04 UTC

The owner followed the cable prompts. [Structured result and capture hash](../evidence/initial-role-result.json).

| Check | Recorded result |
| --- | --- |
| Target and capabilities | Known ASUS/DEG2 fallback and PDOs matched; disconnected status verified before both SETs |
| Rp-only request | `00810008`, accepted; ETW completion at 23:03:26.4478701, ACK at .4650836; Error/Busy/NotSupported all zero |
| Observation | 23:03:26.3771574-23:03:57.2632432 UTC, 30.8860858 seconds; 238,588 events; zero reported lost events/buffers and format errors; 118 unknown records |
| Decoded UCSI | 86 class-driver lines and four ACPI-client lines; no reported attachment, PD contract or SET_UOR; only the diagnostic CC request/status read and their ACKs |
| End status / enumeration | Nine zero status bytes: disconnected, no partner; no Billboard, external router or new display adapter |
| Default-DRP restoration | Separate native `02010008` reply completed at 23:04:06.5161941; durable record says `DefaultDrpRestored`, `RestoreRequired=false` |
| Networking | Retained adapter/settings rows and active Internet-sharing bindings match; the disconnected dock Ethernet adapter and its rows disappear as expected |

This attempt did not establish the requested source/DFP PD connection, so it cannot determine whether avoiding ASUS's later role correction fixes USB4. It also does not establish what prevented attachment, whether physical Rp signaling changed, or that the port is damaged. A source/source incompatibility is a possible explanation, not a captured CC-wire finding. Normal reconnection after restoration was not recorded; restoration proof is the completed native command and saved state, after ETW stopped.

No additional RestoreDrp call is needed for this completed run. Reconnect normally to return to the existing baseline. The unresolved comparison remains Dell's role change during PD without an OS request versus ASUS's later correction/alternate-mode-only path.

### Follow-up control audit

Pre-arming `SET_UOR` while disconnected would not test a valid substitute. [UCSI 1.22 section 4.5.9](https://www.intel.com/content/dam/www/public/us/en/documents/technical-specifications/usb-type-c-ucsi-spec.pdf) specifies that it applies to the current active connection; a disconnected request has no effect and should fail, and its policy resets on detach. No such request was sent. Another connected `SET_UOR` would repeat a transition already completed in the original failing captures unless a new timing/control variable is independently justified.

## Historical preconditions and run

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
