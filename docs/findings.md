# What the traces say

## Failure stage

On the ASUS, the host and root router initialize. The root's downstream adapter remains disconnected; no external router is enumerated. Ordinary USB hubs and the dock's Billboard interface appear through the native xHCI path instead.

The useful sequence is:

1. USB-C attachment and power/data-role handling occur.
2. The host/root USB4 stack is present and firmware grants USB controls.
3. The trace does not show an established external USB4 router.
4. Billboard/USB fallback reports the unsuccessful advanced connection.
5. There is consequently no external PCIe GPU to hand to NVIDIA's display driver.

This locates a boundary. It does not identify which cable, mux/retimer, PD controller, host firmware, dock firmware, or Windows interaction caused it.

## `_OSC` result `0xf`

The host restart trace records `_OSC USB4 capabilities granted: 0xf`. The four low control bits are granted, including PCIe tunneling control. This rules out the specific claim that firmware is withholding that `_OSC` permission in the captured initialization.

It does not establish signal integrity, successful USB4 mode entry, a downstream router, PCIe link training, or GPU operation. A root PCIe downstream adapter reaching `WaitForTunnelRequestFromChild` means the state machine is ready for a child request; it is not proof that a child exists.

## Router versions

The ASUS trace reports root router USB4 version `0x20` and connection manager version `0x10`. These fields must not be converted into a claim that the laptop provides an 80 Gbps physical port. The model's documented port is 40 Gbps.

The working Dell reports a host USB4 version of 1.0 while the external DEG2 router reports 2.0 and runs a 40/40 Gbps link. Therefore a device's v2 descriptor does not, by itself, establish that Windows must enable its v2 connection-manager path for any backward-compatible connection.

## Billboard status nuance

The fallback Billboard data includes SVIDs `FF00` (USB4) and `8087` (Thunderbolt), each with status 1, and DisplayPort SVID `FF01` with status 3.

For the relevant Windows notification interpretation, status 1 means the mode was not attempted or was exited. It is **not** evidence that a particular Enter_USB/Enter Mode request was sent and explicitly rejected. The log's event title `Alternate Mode Failed` is less precise than the underlying status. DisplayPort mode success also does not prove USB4 mode success.

The notification "Use different USB port" is a symptom reported from this fallback path; it is not an instruction that proves the owner used the wrong physical port.

## UCSI and power roles

UCSI commands complete. The trace includes a `SET_UOR(Dfp)` operation and a subsequent partner-role change. Such a correction can be normal when a powered dock initially advertises a different data role. Completion of the command does not prove that the whole negotiation completed, nor does its presence prove the command is the defect.

USB Power Delivery values describe the Type-C power relationship, not the desktop GPU's separately wired PSU power. Host/router idle after failure is also a consequence of no connected USB4 device, rather than proof that a power-saving timer caused the failure.

## Public trace excerpts

These are exact diagnostic message text with timestamp/thread/address and identifying prefixes removed. They are excerpts from local observations, not a complete trace or a replacement for raw evidence:

```text
[usb4hrd] Disabling USB4 v2 support due to OS policy.
[usb4hrd] _OSC USB4 capabilities granted: 0xf
[usb4drd] IsUSB4PortPlugged ---(No)---> ShouldCheckRouterDetectedBit
[usb4drd] IsRouterDetectedSet ---(No)---> WaitingForRouterConnect
[USBHUB3] Billboard Detected
[USBHUB3] Alternate Mode Failed
[USBHUB3] Alternate Mode Entered
[usb4hrd] No devices connected
```

Some lines above shorten state-transition prefixes for readability; the message meaning and state names are preserved. The per-run manifest identifies which capture contains the relevant observations.

## Capture quality

| Local run label | Events | Lost events | Notes |
| --- | ---: | ---: | --- |
| Initial WPR run, 20:01 | 253 | Not used as a connection test | Metadata-only; inadequate |
| Direct 20:08:03 | 8,403 | 0 | Useful direct trace |
| Direct 20:47:54 | 6,500 | 0 | Valid trace despite later wrapper error |
| Direct 21:06:31 | 9,876 | 0 | Longer connection window |
| Direct 21:07:44 | 12,787 | 0 | Included host restart and `_OSC` grant |
| Direct 22:12:23 | 9,229 | 0 | Included host restart; zero WPP formatting errors; policy still default |

Matching Microsoft public PDBs were used to generate TMFs and decode WPP. Successful decoding is not proof that firmware had no problem. Similarly, event-loss count zero means the recording did not report lost events, not that every physical-layer transaction was observable.
