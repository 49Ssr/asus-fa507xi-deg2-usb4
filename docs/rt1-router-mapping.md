# What RT1 controls on this ASUS

RT1 is the **second integrated USB4 host router, NHI1**, behind PCI function6. It is separate from the Parade PS8830 retimer. The failed DEG2 capture uses the RT0/NHI0 side. The current evidence does not support enabling RT1 as a repair for this connection.

## Mapping from original firmware and the saved capture

| BIOS router instance | Original firmware/ACPI mapping | Saved ASUS observation |
| --- | --- | --- |
| RT0 | GP19 child device0/function5; NHI0; XHC3 USB4 companion | Host1022:1668 enumerated here. DEG2 USB2 fallback is under XHC3/function3 |
| RT1 | GP19 child device0/function6; NHI1; XHC4 USB4 companion | No second host in the saved enumerated-host inventory/topology. XHC4 exists as an ordinary xHCI controller |

This is supported by three different artifacts, rather than the similarity of the names:

- Original `AmdUsb4Dxe` code indexes two11-byte connection records and prints RT0 for the function5 entry, RT1 for function6.
- The checksum/hash-verified DSDT from the failed dump defines NHI0 `_ADR=5` and NHI1 `_ADR=6`. Its companion SSDT associates XHC3 with NHI0 and XHC4 with NHI1 through `usb4-host-interface` properties.
- The matched capture's PnP locations put the active host at NHI0/function5 and DEG2 fallback under XHC3/function3. The retained dump's USB4KD summary lists that same1668 host and no external DEG2 router.

The USB2 route and companion properties support the tested-port association. They do not measure the high-speed lane switch or prove that a second USB4 connector is fitted or wired. [Original-code anchors and sanitized capture](../evidence/rt1-router-mapping.json).

## What Disabled actually does

The setting is meaningful. The original CBS boot code copies the RT1-enable byte at offset1aa into native PCD token2a3 when its value is not Auto15. RT0 uses a different token29a. The original FCH code reads those separate Boolean tokens into separate router policy bytes,1d7 and1b7 respectively. Its initialization-message code has distinct RT1 and RT0 branches.

For RT1=0, the selected CBS transfer writes false to the second-router token. RT1 PCIe Tunnel=Auto does not override this: the tunnel-setting branch only applies an explicit tunnel override when RT1 Router=1. The native PCD [primary interface definition](https://github.com/tianocore/edk2/blob/496fd85f26d40871c97c5835bf5ed849b6eb8a70/MdePkg/Include/Ppi/Pcd.h) and original PPI GUIDs identify these calls as Boolean configuration access, not a live retimer command.

These are code rules. We have not read every later platform override or the final historical boot's PCD state. The owner-approved stored-settings read happened later than the failed capture. Those evidence classes remain separate.

## Does RT1 Disabled explain DEG2 failing?

It targets the other host-router instance. The saved failed connection's fallback and active host are on RT0/NHI0; that host was already enabled and discoverable. RT1 also matches its image default. There is no evidence here that turning on the second instance repairs the first instance's missing DEG2 detection.

This resolves the identity of RT1 and substantially weakens this toggle as a fix candidate. It does not explain why RT0 never reports the external router at the sampled checks, or establish that RT0's PD entry, retimer routing or physical link was correct.

## Windows repair search

No Windows repair follows from these findings yet. The identified transfer happens in PEI boot code. A runtime variable write would not, by itself, demonstrate that the controller reapplies that configuration. No setter, reset or boot was attempted.

The relevant work remains the actual RT0 PD/retimer entry decision, the PBS9c consumer and a qualified controller status/log interface. Existing captures remain the starting point; another generic dump would not supply missing CC-wire packets automatically.

The owner has asked to leave restarts alone while remote. Scheduled runs remain paused. No BIOS, cable, driver, network or boot change was made for this analysis.

## Additional Windows-only capture

After the mapping, a standard USB information read succeeded on the existing DEG2 connection without UAC or reconnection. It returned generic help/placeholder strings and a different first mode VDO from the earlier ASUS fixture. The reason for that metadata difference is unverified. No logging interface or PD packet capture was obtained. [Captured result](../evidence/billboard-strings-result.json).
