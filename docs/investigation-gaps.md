# What we know, what we are missing, and what can be tested without another boot

**Completed follow-up:** the data fields in all342 previously unread trace records have now been decoded. They do not supply the USB-C entry exchange. Ten original EC bus-engine scenarios also pass with modeled peripherals; this includes the code previously replaced by a whole-call test double. [What those records and tests actually show](trace-gaps-and-ec-bus.md).

**1 November 2026: the failure is unresolved, not proved impossible to fix.** We have narrowed several explanations. We have not observed the whole connection attempt, recovered all firmware involved, or identified a working Windows repair. Test counts below describe software checks, not thousands of real connection attempts.

## The connection in plain language

1. The laptop, cable and dock identify what they support through small control messages on the USB-C connection.
2. For native USB4, the host sends an `Enter_USB` message. The devices then have to establish the fast electrical connection.
3. The motherboard's signal-routing hardware must connect the USB-C pins to the correct circuitry. A **mux** is a signal switch; a **retimer** reconstructs the fast signals as they pass through the board.
4. Windows must discover the dock's USB4 controller and make its PCIe connection available before it can discover the graphics card.

This is a simplified sequence, not a recovered timeline of the ASUS failure. USB4 entry through USB-PD and subsequent link training are separate operations. See the [USB-IF system overview](https://www.usb.org/sites/default/files/D1T1-2%20-%20USB%20Type-C%20System%20Overview.pdf). Microsoft's USB4 connection manager operates separately from its Type-C software stack; completing a Type-C command is not proof of a USB4 link. [Microsoft's requirements](https://learn.microsoft.com/en-us/windows-hardware/design/component-guidelines/usb4-design-details-and-general-requirements).

## What the saved evidence actually establishes

| Evidence | What it establishes | What it leaves open |
| --- | --- | --- |
| DEG2, the same graphics card and supplied cable work on Dell | This equipment can form a working connection in that pairing | An ASUS-specific compatibility or signal problem |
| ASUS and Dell form a USB4 peer link through the supplied cable | ASUS's USB4 path can establish a reported 40 Gbps link with that peer | Reliable operation with DEG2, PCIe tunnelling, signal margin in the failing pairing |
| ASUS's saved attachment trace has 10 ordinary Windows commands and 10 terminal completions without CCI error/busy/unsupported | The normal command path was functioning for those captured requests | The actual control messages exchanged on the cable, or all controller behavior |
| ASUS detects DEG2's fallback USB devices but no external USB4 controller or GPU | The captured failure occurs before Windows discovers the dock as a USB4 device | Whether entry was skipped, failed, or briefly succeeded and then exited |
| The dock's cached status differs between ASUS and Dell | It reports different USB4/DisplayPort outcomes | A fresh wire-level history, exact event order, or a uniquely identified cause |
| The pre-attachment Windows role-policy change was accepted but did not restore USB4 | That tested change is ineffective | Other Windows commands, firmware settings, timing problems or hardware interactions |
| BIOS314 EC table6 returns without a reply | The OEM diagnostic feature is unimplemented in that EC build | The cause of USB4 failure; this telemetry timeout is not a captured dock-handshake timeout |

The memory dumps were useful: they preserved device state, driver history, cached descriptors and firmware tables. **They are not a recording of every USB-C message, nor a dump of the PD controller's private firmware and memory.** More analysis can recover additional retained state; it cannot reconstruct an event that was never retained.

## Three possibilities we still cannot separate

| Possibility | Missing observation | What it would direct us toward |
| --- | --- | --- |
| ASUS never sends the USB4 entry request | A fresh record of cable/device discovery and the entry request | Controller policy, capability interpretation or ordering/timing |
| Entry is requested but a usable USB4 connection is not established | The response plus the routing and link-training result | Controller compatibility, board routing/retimer setup, timing or electrical conditions |
| USB4 starts briefly and then exits | A timestamped record of successful entry followed by exit/failure | An interoperability or recovery problem after initial entry |

These are hypotheses, not diagnoses. No evidence currently establishes that a firmware patch is necessary, that a Windows workaround must exist, or that software repair is impossible.

## What the contained tests do

The previous 69 PMC tests execute the original firmware's diagnostic-command handling. The 2,306 relay combinations execute its command/data copying and response handling. The real PD controller and electrical bus are replaced by memory buffers and supplied results. **Those tests cannot demonstrate a successful hardware handshake or validate a proposed hardware repair.**

The new test mode, `Test-EcPmcFirmware ... --service`, exercises the surrounding original command-service code at bank3 address `c89a` in 15 targeted scenarios. [Results](../evidence/ec-command-service.json).

- A new command is forwarded; a failed send is retained and retried on a later service call.
- An inactive interrupt input or an unset internal gate can prevent a controller read. These are synthetic states, not measured ASUS failure states.
- A normal controller reply is copied, acknowledged, and followed by an OS-notification request.
- Failures of the interrupt read, response read and acknowledgement produce distinct stop paths.
- A busy reply and a previously retained reply take different counter paths. Comparisons use the old counter value, post-increment it, and trigger strictly above450 or600 respectively. **Those numbers are service-call counts; wall-clock durations have not been established.**

The bus, debug logger and OS-event delivery are explicit test doubles. A notification request in this test does not prove that Windows received an event on the real machine. The first two counter assertions were corrected after original-instruction execution exposed post-increment and strict-greater-than comparison behavior; failed reports remain private. All15 scenarios pass; the previous PMC and relay cases also pass with the revised harness.

These checks expand coverage of a previously skipped caller. They do not reproduce the ASUS-DEG2 hardware failure. In particular, the ten completed real Windows commands argue against describing the captured session as a wholly broken or permanently blocked EC command service.

## Useful work that can continue without owner actions

The next offline checks should connect a specific failure hypothesis to actual code and retained data:

1. Extend the now-exercised original bus engine to the remaining runtime callers and state-restoration paths. Its internal gate and bus-status conditions are known in code; their values during the real failure are not measured. Do not treat successful simulated transfers as physical bus validation.
2. Find the firmware or diagnostic interface that records the PD controller's discovery, entry and exit decisions. The neighboring PS8830 retimer image is not identified IT8853 PD firmware. The recovered main EC image alone is not all firmware involved in USB4.
3. Find which component programs the board's signal routing and retimer, and how its state could be read from Windows. A readable field, a writable field and a verified restoration procedure are three separate questions.
4. The342 formerly unread ASUS records now have decoded fields. Keep the remaining capture limitations explicit: those records do not contain the entry/exit exchange. Seek an understood way to obtain the controller's actual history or routing state; do not repeat unchanged decoding and call it a new measurement.

A live experiment becomes useful when it answers a named question and captures the result. A repair test additionally needs a specific change and a way to undo it. Neither requires another blind boot. If the needed controller state is not exposed in existing files or through an understood software interface, identifying that missing measurement is the next result; repeating the same dump or counting more simulated packet combinations will not supply it.
