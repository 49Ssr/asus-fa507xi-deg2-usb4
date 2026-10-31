# Live connection window: 31 October 2026

**The connection was recorded, but the firmware buffers remained unreadable and DEG2 did not become an external USB4 router. No targeted repair was identified.**

The guided run completed normally. The connection prompt appeared at 12:52:35.688 UTC; device enumeration and Billboard events followed within the recording. This was a test of insertion during capture, rather than another attached single reading.

| Measurement | Observed result |
| --- | --- |
| Firmware sampling window | 12:52:29.592-12:53:19.532 UTC; about 49.94 seconds |
| Samples / validated mappings | 80 / 80 |
| Samples before / at or after connect prompt | 9 / 71; prompt time is not the physical insertion time |
| PM08 / EURM readable samples | 0 / 80 for each region; 160 failed bounded read attempts total |
| Normal kernel build-number control | Readable in all 80 samples |
| KD cache | Disabled, confirmed in debugger output |
| First/last page-table metadata | Valid mappings; unchanged at the two observations |
| ETW window | 12:52:28.336-12:53:19.686 UTC; about 51.35 seconds |
| ETW events / reported lost events and buffers | 8,221 / 0 / 0 |
| TraceFmt formatting errors / unknown records | 0 / 2 |
| Post-capture external USB4 routers / external GPUs | 0 / 0 |
| Post-capture fallback | SuperSpeed hub and DEG2 Billboard present |

The optional tick-counter symbol was unavailable. Its false changing-clock flag does not prove a frozen target. Readable normal kernel memory and valid page tables distinguish this result from a general failure of the probe's memory provider; they do not identify why the firmware mappings cannot be read. Sampling can miss changes between attempts and remains non-atomic.

## Connection sequence

- 12:52:39.837673 UTC: the host driver reports `Succeeding D0Entry`.
- 12:52:39.891643 UTC: the root downstream port completes its plugged-state read successfully, then `IsUSB4PortPlugged` returns `No`.
- 12:52:39.891722 UTC: its router-detected read also completes successfully, then `IsRouterDetectedSet` returns `No`. The state machine reports nothing attached.
- 12:52:41.456298 UTC: the USB hub driver reports `Billboard Detected`.
- 12:52:41.459296 and .462296 UTC: Billboard alternate-mode entries with SVIDs `0xff00` and `0x8087` report configuration status `0x01` and are labelled `Alternate Mode Failed` by the decoder. The `0xff00` entry carries a Thunderbolt assistance string.
- 12:52:41.465296 UTC: the `0xff01` entry reports status `0x03`, labelled `Alternate Mode Entered`. This is not evidence of a working external USB4 router or GPU tunnel.
- 12:52:50.666840 UTC: another successful pair of root-port reads again yields plugged `No` and router-detected `No`.

Root DisplayPort input-adapter plug packets also appear. Their `PLUGGED` messages concern the root's DP inputs, not detection of DEG2 as an external USB4 router. A subsequent Billboard descriptor/control-transfer error is also present; its relationship to the original negotiation failure is unestablished.

This reproduces the previously observed failure stage before external-router/GPU enumeration. It does not isolate the ASUS hardware, its firmware, dock firmware, or cable-dependent interoperability. It supplies no firmware payload or justified register/firmware patch. No UCSI-labelled formatted records were observed in this ETL; the requested provider list must not be treated as proof that UCSI command traffic was captured.

## Method and retained evidence

TraceRpt failed with WMI-service availability in the managed reader. Installed Microsoft Xperf and TraceFmt successfully consumed the same ETL; TraceFmt used the retained matching TMF files. This reader failure did not invalidate the recording. Raw logs, inventories, pointers and identifiers remain private.

| Artifact | Bytes / SHA-256 |
| --- | --- |
| Raw ETL | 10,420,224 bytes; `40CB6A6C67E17417856C29ED13262B0C7D3B5E9EE542720CC90B79BD6C4E7307` |
| Private probe JSON | `C2C3C643DAB782CFBADD8620E474FE37F37EA3A299C852C794B7BDB10C032839` |

The subsequent [N0 ASUS-Dell peer comparison](peer-test.md) passed adapter/link checks, and a completed rundown confirms a reported 40 Gbps Gen 3 dual-lane link with the supplied cable. Payload transfer and GPU PCIe tunnelling remain untested. This strengthens the working host/cable control without identifying the ASUS-DEG2 negotiation defect. Another unchanged DEG2 memory window has no identified additional diagnostic benefit.
