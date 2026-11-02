# Finding a Windows repair: the missing decision

**New source available:** [SDK 3.9.0 has been acquired and inspected](infineon-sdk-review.md). The missing AMD headers and compiled functions are now available for comparison. No equivalence to the ASUS transport or a ready Windows logger is established.

The repair is uncertain because the first failed RT0 transition is unobserved. The investigation can still have a specific target: recover that decision and identify a Windows operation that controls the affected state. Existing host-router samples locate the failure before usable external-router discovery; they do not distinguish all earlier causes.

The [saved attachment sequence](rt0-attachment-order.md) now ties connector1 to RT0 and places successful DEG2 SuperSpeed-hub enumeration after the Windows role correction. This narrows the failure beyond a permanently wrong USB host/device role; actual USB4 entry and retimer/training state remain missing.

## A specific reset hypothesis

[USB-PD Data_Reset](ucsi-data-reset.md) could restart USB4 discovery after ASUS has corrected the data role, without undoing that role. This is not the older connector reset. The saved ASUS version is anomalous and a compatible data-reset command is unproven; no executable repair or hardware test is prepared. Follow the actual controller command handler before sending anything.

## The records that choose the repair

| What actually happened | Record needed | What a repair would need to change |
| --- | --- | --- |
| ASUS did not send Enter_USB | Discovery results and the controller's entry decision | The specific host policy, capability interpretation or ordering that prevented entry. The completed Windows role-policy trial alone was insufficient |
| DEG2 received entry and rejected it | The request and response, with their context | The request or compatibility condition responsible for rejection, if the host exposes control of it |
| Entry was accepted but the link failed | Applied retimer mode/orientation and first training result | The affected routing/training decision through an identified interface |
| A link/router appeared and was lost | The first successful state followed by the exit/power event | The specific later transition. Final absence alone does not prove that a link never existed |

Changing a GPU driver or later PCIe tunnel setting cannot answer those earlier questions. RT1 targets the other router. PD USB4/TBT3 stored settings are already enabled. These facts narrow the candidates without proving that a Windows repair exists or is impossible.

## What the present Windows interfaces actually expose

| Interface | Proven access | Missing information |
| --- | --- | --- |
| Stored UEFI settings | Successful two-variable read | Whether the controller consumed/applied them during failure |
| Standard DEG2 USB descriptors | Successful exact-device BOS/string read | PD request/response and applied retimer/training state |
| Windows USB4/UCSI evidence | Existing traces, dump and native register samples | Controller-private negotiation and complete earlier physical history |
| DEG2 WinUSB vendor interface | Enumerated transport and matching reference GUID | A matching, versioned command implementation and useful log/state payload |
| Existing ASUS OEM/Parade route | Reviewed implementations and retained failures | An implemented live read for the relevant controller state; the PDO stub and cached HID status do not provide it |

## Three findings that change how we use those routes

**The matching WinUSB GUID is not a protocol fingerprint.** DEG2's current registry value matches the public Infineon Griffin Creek descriptor. An independent Bridgetek SDK also uses it as an example. The Infineon application conditionally dispatches DMC requests, and its wrapper calls the application handler before optional log handling. This does not qualify D6/D7/DE commands for DEG2. The documented D6/D7 fields concern component identity, image status and versions; they are not themselves the missing PD exchange.

**The reported mode word is not a success certificate.** In the inspected Infineon reference, BOS can start from a configuration template. Saved EUDO replaces its word only under a build option and runtime USB4-support condition. The data-status function also saves EUDO before calling the mux setter and returning its result. DEG2's zero/nonzero difference remains a real observation, but we cannot use it alone to label a failed request or successful retimer configuration. DEG2's exact implementation remains unproven.

**The identified BIOS setter is broader than USB4.** The complete selected Quanta function contains five variable-write sites across PBS, network stack, Setup and ASUS setup-item data, plus a fixed MMIO-byte update. Its early PBS write precedes other operations that can fail. It is not an established atomic port-only operation, and a Windows runtime caller is unqualified. This function was not invoked.

[Source pins, original-byte checks, registry observation and limits](../evidence/windows-repair-route-review.json).

## Work that can continue without physical access

Follow the original RT0/PBS9c dataflow into the controller-facing code. Separately identify the DEG2 firmware/diagnostic implementation before sending a vendor request. A useful new read must supply one of the missing records in the first table; another unchanged descriptor read or generic dump is insufficient by itself.

SDK source can help identify control ordering and status interfaces. A matching DEG2 firmware package could identify the dock command handler. Neither package is a ready-made capture or a repair merely because it can be downloaded. The official support root's meta-refresh was followed; the exact DEG2 card presently exposes a manual and installation video, without a firmware link in that card. This is not proof that firmware is unavailable elsewhere.

Scheduled runs remain paused. No BIOS, cable, driver, restart or network change was made for this review. The only new local observation was existing Windows registry metadata; no new USB/EC/I2C/vendor request was sent.
