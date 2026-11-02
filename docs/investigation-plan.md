# Current investigation plan

**Goal:** determine why DEG2 enters a usable USB4 connection on Dell but fails on ASUS, then identify a specific repair that can be tested and undone.

## 1. Compare another OS with the existing hardware

The [first ASUS Linux run](linux-asus-result.md) reproduced USB fallback with no observed external router or new PCIe device. USB saving worked, the host router was present and OS PCIe control was granted. No unchanged ASUS repeat is selected.

If the owner collects a working Dell Linux run using the [same observer](linux-capture.md), compare attachment order and router discovery against that control. A Dell Linux result is not yet available. The ASUS failure leaves entry, routing and training unresolved; it does not establish a failed chip.

## 2. Trace the applied ASUS policy

Follow the original RT0 and PBS PD USB4-control consumer into the code that actually communicates a controller decision. Stored USB4/TBT3 enable values are known; their applied effect remains unknown. Keep this independent of RT1 and unrelated setup fields. [Original-code research](capture-paths-and-hidden-settings.md), [RT0 mapping](rt0-attachment-order.md).

## 3. Find the missing controller record

Qualify a log/state interface by matching its actual implementation and reply semantics. The useful record must distinguish an omitted entry request, rejection, accepted entry with failed training, or a later exit. A non-unique WinUSB GUID, cached HID field or generic Billboard string does not qualify a vendor command. [Available Windows routes](windows-repair-route.md).

## Choosing a repair

A proposed change needs a named consumer, an expected observable effect and a verified way to restore the prior state. Test the smallest supported change against a known baseline. Preserve every original result, including failed conditions. A partial multi-write rollback is not proven by restoring one software flag.

No new experimental driver, BIOS setting, firmware flash, generic full dump or unchanged role trial is selected. The original [working-method notes](history.md) remain available for their source trail.

[Current findings](status.md) · [Research handoff](handoff.md)
