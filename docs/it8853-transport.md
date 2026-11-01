# IT8853 follow-up: OEM response wait isolated

**Subsequent firmware result:** the executable EC image was recovered from a different BIOS314 region. Table6 dispatches to a bare return without an output byte; capability17 and the literal `IT8853` reply reproduce offline. This explains the host response wait in this EC build and tightens the identity claim. The earlier ambiguity and placeholder search below record the preceding stage. [Firmware analysis and UCSI relay qualification](ec-firmware-decision.md).

**1 November 2026:** a short, trace-only replay recovered four retained ASUS driver messages, all message **19 (`0x13`)**. In the pinned driver this identifies the **EC response-ready wait after command/parameter transmission**. This narrows the earlier generic `0x102` completions. It does not establish a USB-PD rejection or prove IT8853 itself received and rejected a request. No new PDO request, reconnection, boot or repair attempt was made. Both owned trace sessions stopped and provider logging returned to disabled. [Structured evidence](../evidence/it8853-transport.json).

## What actually timed out

The existing [OEM reads](oem-pd-diagnostics.md) returned capability17 and `IT8853`, then failed on the dynamic source-PDO field. Their completion packets did not preserve the internal stage. The recovered messages supply that missing stage:

| Original driver path | Meaning |
| --- | --- |
| RVA `1828`, pre-command path | Drain old output, send `ff`, opcode, then parameters; check input readiness |
| RVA `1a70` / `17d8` | Wait for response-ready bit0 in the EC status byte, then read the response byte |
| RVA `1990`, message19 | That response-ready wait returned `0x102` |
| Same original transaction routine | Response timeout permits two internal command attempts; earlier-stage failures stop immediately |

The [original-code transaction test](../tools/analysis/Test-OemEcTransport.py) executes nine cases in RAM. The PDO-shaped request sends `ff dd 06 05 00`, reaches the response stage, and produces two message19 records when the response-ready test double never becomes ready. It performs **104 status reads** across those two attempts. A successful response and seven earlier failure positions are checked separately. I/O, logging and delays are explicit doubles; this does not measure hardware timing or firmware support.

Four retained message19 records are consistent with the two earlier failed application requests each taking that internal two-attempt path. **They carry neither command arguments nor original timestamps, so exact request attribution remains an inference.** Another caller could contribute records. The replay's event timestamps are capture/replay times, not the time of the original failure.

The strongest supported result is therefore: **the retained failures reached the response-ready stage of ASUS's EC interface**. Input readiness is a transport condition, not semantic acceptance of a table index. An unsupported/unavailable dynamic table, a missing prerequisite, an EC-to-PD problem or contention still needs discrimination. The records do not uniquely select one of these explanations.

## How the records were recovered

The existing ASUS dump contains a default ASUS recorder log. Recovering it through the driver's control-block pointer at offset `40` bypassed a debugger lookup failure caused by unavailable ASUS private symbols. Matching Microsoft recorder types verified ownership, replay-enabled state and sequence0: **that older snapshot's buffer was empty**, not proof that the driver lacks logging. No live debugger or memory-write helper was used.

The installed driver's WPP enable callback at RVA `1660` updates logging fields and calls `imp_WppRecorderReplay`; disabling clears those logging fields. Eleven [original-code replay cases](../tools/analysis/Test-OemRecorderReplay.py) cover callback enable/disable/unsupported controls and the recorder dependency's entry gate. They execute in RAM, with replay itself doubled at the ASUS callback boundary.

Crucially, the installed Windows recorder accepts replay only when flags equal **`40000000` exactly**. The common `ffffffff` setting returns immediately. This requirement was recovered from the actual dependency, not assumed from the presence of the ASUS callback.

| Component | Version | SHA-256 |
| --- | --- | --- |
| AsusSAIO.sys | 1.0.9.0 | `eef750c7fb515d162a76423531f4f6773bcf837d9607069e797a26d198edd892` |
| WppRecorder.sys | 10.0.26100.9818 | `8a9b253d4d45200b1f9362d3769aa63a1e01d12351f243524ff212f595a1ced4` |

Control GUID: `92ad1b60-2d31-485b-8b06-b5b27eec1baf`. Message GUID: `f0e2deec-5949-38ce-2ea2-6f135baafa99`. These are binary/provider identifiers, not machine-specific identifiers.

The 17:11 UTC first capture used the wrong flags and then stopped early because its guard counted the same logger in three returned instance blocks. It cannot establish an empty current recorder. Its original source, result and trace remain private and unchanged. Offline review identified the exact flag gate and duplicate logger ID. Microsoft's `PRE_ENABLE` flag denotes an unregistered placeholder; only one returned instance was the registered legacy kernel provider. [Microsoft structure definition](https://learn.microsoft.com/en-us/windows/win32/api/evntrace/ns-evntrace-trace_provider_instance_info).

The corrected **17:12:53-17:12:54 UTC** capture used the exact replay flag, checked unique logger IDs, and observed for750ms. It produced a 131,072-byte trace with **8 total events, 4 ASUS message19 records, zero event loss, zero format errors and zero unknown formats** using the explicit [analyst-labelled TMF](../tools/analysis/AsusSAIO-1.0.9.0-timeouts.tmf). The unavailable vendor-PDB warning is preserved; the TMF supplies only labels verified against this exact binary, not invented vendor source text. No firmware/device request was issued. Start/stop both returned0; no active provider logger remained afterward. [Microsoft IFR background](https://learn.microsoft.com/en-us/windows-hardware/drivers/devtest/using-wpp-recorder).

## Which negotiation data is already available

The retained ASUS attachment trace already contains successful **standard UCSI `GET_PDOS`** commands on connector1. It reports the same four advertised source profiles as Dell: `2f81912c`, `0002d12c`, `0004b12c`, `000641e0`. ASUS selects the 5V/3A profile; Dell selects20V/4.8A. These are firmware reports/requested contracts, not measured supply power. [Matched bytes and limits](billboard-comparison.md).

This separates two interfaces: the OEM dynamic telemetry field timed out, while the standard UCSI route returned power-profile data. Fixing the telemetry wait would improve diagnostics; it would not by itself repair native USB4 entry. Existing Windows traces also show the completed role correction and absent external-router discovery, while both dumps preserve the dock's differing cached USB4/DP result.

The missing measurement is still **the actual Enter_USB/response and subsequent mux/link-training decision**. A working recorder replay now exposes ASUS EC transport error stages without recreating those failed reads. It is not a raw PD-wire recorder.

## Prerequisites and unsuitable shortcuts

Further review of the pinned client found these concrete differences:

- `Adapter_Read_Power_Big_Data_Config` reads table6/offset00. It has not been invoked; whether this field gates telemetry on this board is unproved.
- `Adapter_Read_Power_Data_Flag` reads table6/offset01 **and then calls a clear routine**. `Adapter_Read_Charger_Interrupt` also calls a clear routine. Their exported names do not make them passive; neither was invoked.
- `Adapter_Set_Notify_Control` is a write and requires table version **23 or later**. Actual version17 does not pass that prerequisite. It was not attempted.
- The analysis-service switch has separate PD-charging and PDO cases. Their proximity does not prove that charging is a prerequisite for PDO reads. Port ownership remains unresolved.

ITE's own direct-I2C submission defines UCSI version/CCI/message/control registers and separate vendor interrupt/acknowledgement registers. Its later DisplayPort proposal queries current mode, CAM status and attention data, then configures the external mux/retimer. That is a useful mode-state reference; it does not supply a raw USB4 handshake log or establish that ASUS's EC bridge/firmware exposes those operations. No ITE register, acknowledgement, newer command or mux write was issued. [ITE base driver](https://lists.openwall.net/linux-kernel/2026/08/07/804), [ITE mode-state proposal](https://lists.openwall.net/linux-kernel/2026/09/18/1326).

## BIOS coverage and the Windows intervention boundary

The verified BIOS314 capsule was unpacked offline into **2,473 leaf bodies / 63,036,796 bytes**. A named-token database contains EC/USB-PD version and USB4 configuration names; names do not establish their values, live consumers or a Windows setting. No `IT8853` string was found in these leaf bodies; this is not proof the controller's firmware is absent elsewhere or inaccessible through another format.

A 266,240-byte area labelled `IT8987` contains262,096 bytes of `ff`,4,125 zero bytes and only19 other bytes: a48-byte header plus a4KiB mostly-zero placeholder area. It is **not recovered executable EC firmware** and supplies no command handler or valid rollback image. All original BIOS bytes and extracted evidence are preserved privately; nothing was executed or flashed.

There is still **no qualified Windows USB4 repair to deploy**. The completed controlled change here was temporary logging, with its own verified rollback. Increasing timeouts, enabling unsupported notification writes or patching a cached descriptor would not establish the missing USB4-entry behavior. The next intervention must reach an identified controller/EC mode-state consumer and preserve a measured recovery path. No additional test boot, repeated PDO request or state-changing probe is queued.
