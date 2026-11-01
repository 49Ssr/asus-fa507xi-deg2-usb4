# Offline analysis and the saved router-detection difference

**1 November 2026.** The existing captures supply a concrete Windows branch difference. Both hosts initially report `USB4 plugged: No`; Dell's following router-detection read is set, while ASUS's is clear. The decoded values agree with the original driver's decisions. This explains what Windows did with these samples; it does not yet explain why ASUS returned the clear bit or establish a repair.

## One offline command

From the repository root, with ordinary Python and no extra packages:

```text
python tools/analysis/Run-Investigation.py
```

The runner validates the [curated evidence](../evidence/investigation-model.json), evaluates the [declared constraints](../evidence/investigation-logic.json), and refreshes only changed outputs: the [architecture map](investigation-map.md), [truth table](investigation-truth-table.md) and [machine-readable results](../evidence/investigation-logic-results.json). `--check` verifies those outputs without writing. It stops on changed source pins rather than silently accepting or repinning evidence. Reports are computed before writing, with atomic replacement per file; a multi-file refresh is not a filesystem transaction.

This **offline runner** has no hardware, network, scheduler or driver-loading backend. It neither simulates cable insertion nor invents controller responses. The optional saved-log extractor described below is also offline. The owner initially chose the runner alone and has now separately authorized [recurring offline research intervals](ps8830-investigation-intervals.md); scheduling does not add device access to this tool.

The truth table separates an event that happened at least once from a final snapshot. Successful host UCSI exchanges do not imply successful USB4 entry or a usable link. Exit can occur before a later re-entry, so it is a separate history variable rather than an exclusive failure stage. Unknown values remain unknown.

ASUS's final absence is consistent with four unfinished milestones: entry, usable link, router establishment, or retaining an established router. A fully qualified observation of whether a usable link **ever** existed would split those four possibilities into two groups. That is an information requirement, not an available safe interface or a selected experiment. A clear current-state bit cannot prove a link never existed without adequate history coverage. Logical combination counts are neither probabilities nor hardware-test counts.

## The branch already recorded in the captures

The [sanitized readbacks and native-code offsets](../evidence/router-detection-branch.json) retain the exact selected decoded-log hashes, timestamps, source line numbers and separate cases. These are driver-initialisation samples, not a complete physical attachment history.

| Saved case | Initial ADP_CS_4 / bit30 | Following USB4 port CS18 / bit13 | Recorded next state |
| --- | --- | --- | --- |
| ASUS-DEEP, 00:52:17 UTC | `88000000` / clear: Plugged No | `00010400` / clear: RouterDetected No | `WaitingForRouterConnect` |
| DELL-DEEP, 00:17:45 UTC | `83c00000` / clear: Plugged No | `00003510` / set: RouterDetected Yes | `RequestingPollLane0ForCL0` |

The second ASUS pass at 00:52:27 returns the same two values and decisions. Later Dell CS4 values belong to later states and must not replace its initial sample. This later Dell deep capture is separate from the earlier successful Dell control used in the truth table.

In the pinned `Usb4DeviceRouter.sys`, native `Port::IsAdpCs4PluggedSet` (RVA `677a8`) tests mask `40000000` in the cached CS4 DWORD. `Port::IsRouterDetected` (RVA `68754`) tests mask `2000` in a different cached DWORD. `Port::ReadPortCS18` (RVA `6e7dc`) obtains that DWORD at the port capability base plus 18 DWORDs. The observed absolute offsets differ: ASUS `d2`, Dell `a2`. Logical root adapters also differ, ASUS 2 and Dell 1; these numbers are not assumed to be UCSI connector numbers or identical board wiring.

The driver separately selects a legacy Thunderbolt path. It reads region157 and compares a cached byte with `31`; applying these native USB4 masks to that layout would be wrong. Original code was inspected offline, not patched or executed on the laptop for this work.

`Extract-USB4PortStatus.py CASE decoded-log` replays the two hash-pinned private logs. It pairs response headers and scalar payloads by provider/controller/response tag, then requires a unique read in the corresponding state-machine phase on the exact route, adapter and register. Missing, ambiguous, wrong-index or conflicting results fail instead of borrowing a nearby line. The ordinary runner needs only the public sanitized summaries.

**Implication:** Plugged No alone is not the failed transition; working Dell takes that branch too. The next recorded native router-detection branch differs, and its returned bits explain the No/Yes choices. Upstream Windows policy or configuration, PD decisions, board routing and physical link behaviour remain candidates for why the input differs. Forcing the decision to Yes would not establish a link.

## What the PS8830 reference adds

The owner's [Parade product page](https://www.paradetech.com/products/ps8830/) and [block diagram](https://www.paradetech.com/products/ps8830/ps8830-block-diagram/) show a retimer in the fast signal path, an integrated sideband/AUX switch, host-facing SMBus, and a separate I2C connection to the PD controller that handles CC1/CC2. These are reference connections, not a verified schematic of this ASUS motherboard.

The [pinned upstream Linux PS883x driver](https://github.com/torvalds/linux/blob/46fec1c3029b552ec63b2d01af9d43a386f043ea/drivers/usb/typec/mux/ps883x.c) provides a concrete programming example: software sets mode/orientation through I2C. Its `USB4_CONNECTED` configuration bit is written by software when selecting USB4 mode. Its name therefore does not make it an independent measurement of electrical link readiness. A Qualcomm-specific incomplete-stack restriction in that source is not evidence of the same restriction on ASUS Windows.

The [reference evidence](../evidence/retimer-control-reference.json) is kept separate from ASUS measurements. Still missing are ASUS's runtime mode writer, physical-port mapping, control-bus ownership and a safely readable link/training observation with understood side effects. No new I2C request, mode write, driver installation or boot was performed. The next offline target is the code and ownership feeding that configuration and port-status boundary; a new live test needs a useful observation and exact recovery first.

## Contained cleanup

The authorized project cleanup moved **35 redundant files, 1,531,932,479 bytes**, to the Recycle Bin: one multiarchitecture debugger download, one validated duplicate compressed dump, 28 byte-identical malformed AML exports and five rebuildable compiler objects. Retained copies/originals were verified before moving them; all 35 recovery items were then verified in the bin. Original captures, dumps, firmware, symbols and recovery packages remain.

The private receipt maps original names to the staged names used for recycling. It remains private because it contains user paths and recovery locations. Verification confirms recovery items exist; a full restore was not performed. The Recycle Bin was not emptied, so this is not a claim of reclaimed disk space. [Sanitized cleanup receipt](../evidence/cleanup-summary-20261101.json).

## Verification

The evidence reader has 11 boundary tests and the new automation/extractor has 13 tests, including unknown versus false, case separation, conflicting facts, deterministic reports and ambiguous/interleaved log records. These validate analysis behaviour; they are not new USB4 connection trials.

```text
python tools/analysis/Test-Investigation.py
python tools/analysis/Test-InvestigationAutomation.py
python tools/analysis/Run-Investigation.py --check
```
