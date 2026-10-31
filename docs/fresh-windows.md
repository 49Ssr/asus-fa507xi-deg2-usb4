# Separate full-Windows result, 31 October 2026

**Result: the same pre-router failure was reproduced.** The owner returned to the original Windows after completing the local recorder. The shared report, inventories and ETL were read directly from the secondary drive; no manual transfer was needed.

## What actually ran

| Item | Observed value |
| --- | --- |
| Environment | A separate full Windows installation, native boot from VHDX on the real ASUS hardware |
| Windows | Windows 11 Pro, 26200.8037 |
| USB4 host and root-router driver | 10.0.26100.7920 |
| UCSI driver | 10.0.26100.1882 |
| AMD I2C driver | 1.2.0.121 |
| Parade SPB / HID | 1.0.8.0 / 1.0.11.0 |
| Other staged System packages | AMD GPIO, Micro PEP, PPM provisioning, ASUS System Control Interface |
| Comparison hardware | Same FA507XI, DEG2, RTX 4080 SUPER, PSU and original DEG2 cable |
| Recorder connection window | Approximately 03:16:25-03:17:19 UTC |
| Recorder errors | None recorded |
| Essential preflight issues | Empty list; host, root router, UCSI, three I2C devices and eight Parade peripherals were present/Started with problem code zero |
| External USB4 router after connection | None |
| New display adapter after connection | None |
| Ordinary USB fallback | Intel USB hub `8087:5787` and DEG2 Billboard `041F:D002`, both Started |

The native boot entry was created and the test Windows reached Audit Mode. This moves preparation and first boot from planned/mocked behaviour to observed execution on this machine. It does not establish that the VHDX toolkit works on every computer or that its cleanup path has been tested.

## Trace quality and interpretation

TraceFmt read 7,720 events with zero reported lost events and zero formatting errors. There were 2,441 unknown-format events because matching WPP TMFs for this older driver build were not supplied. TMFs from the newer original-Windows driver were not forced onto the old binary. TraceLogging and standard events plus the independent before/after PnP inventories provide the result reported here; a complete WPP diagnosis is not claimed.

At 03:16:34 the standard USB hub provider recorded a Billboard detection, two Alternate Mode Failed events, and a DisplayPort-mode success event. The inventories independently show no external USB4 router. The host/root remained present and healthy. As in the original capture, event titles do not by themselves prove that a USB4 mode request was transmitted and rejected; the earlier Billboard-status caveat still applies.

## What this changes

Reproducing the symptom in another full Windows installation substantially weakens the hypothesis that the main installation's registry, application cleanup, GHelper state within Windows, or a single damaged/newest driver file is the sole cause. This test used an older Microsoft USB4 driver, not simply the same binary under another enablement-package label.

It strengthens the case for a physical/firmware negotiation problem involving this host, this dock and this cable. It does not distinguish a general ASUS USB4 hardware/firmware fault from a DEG2-specific compatibility issue or a cable-dependent interaction. The same complete eGPU assembly still works on the Intel Dell comparison host.

## Limits of the baseline

This was a scoped driver baseline, not an ASUS factory recovery image. The fresh environment had nine other PnP problem entries: missing PSP/encryption, audio, SMBus, NVIDIA platform, AMD IPU/PCI and Wi-Fi bindings, plus a Bluetooth error. The measured USB4/UCSI/I2C/Parade path passed the explicit checks, but claiming every OEM driver or every Windows configuration was validated would be too strong.

The original installation's INF covering AMD PCI `14EC` and SMBus `790B` uses a null-service binding; missing labels in the fresh inventory alone are not proof of a failed active PCIe tunnel driver. Possible platform configuration interactions are not comprehensively excluded.

Both environments share the physical laptop firmware and the selected OEM driver versions. A common driver/firmware interaction remains possible. No new host or dock firmware was flashed by this experiment.

## Practical next discriminator

A second suitable cable, or a separate known-working USB4/TB peripheral on this ASUS, is still missing from the evidence. A controlled lower-speed USB4 cable test is supported as a hypothesis by other-model DEG2 reports, not as an established FA507XI fix. If a different peripheral works while the DEG2 continues to fail, a host-DEG2 compatibility issue becomes more specific. If a suitable cable changes the result, its specification and negotiated link need recording before drawing a conclusion about speed or cable failure.

Further changes to the original Windows installation have lower diagnostic value than these missing comparisons. No claim of a dead GPU, universal AMD incompatibility, or guaranteed weekend firmware fix follows from this result.
