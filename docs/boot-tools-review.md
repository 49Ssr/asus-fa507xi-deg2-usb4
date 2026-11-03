# UMAF and other boot tools

**Current result, 3 November 2026:** the ASUS Linux capture has run and reproduced the failure. The earlier tool review below explains why a settings browser or generic boot interface does not supply the missing PD/retimer record. [Linux result](linux-asus-result.md) · [Current diagnosis plan](investigation-plan.md).

## Smokeless UMAF

The [pinned repository](https://github.com/DavidS95/Smokeless_UMAF/tree/c003b126cab6e29b1d72d061d59cea9e721a6910) contains a README, photographs and two ZIP distributions, with no source files in that tree. Both archives were downloaded and inventoried without executing or deploying anything.

The normal package contains the boot loader, DisplayEngine, SetupBrowser and UiApp. The beta adds a separate loader, SREP configuration and SuppressIFPatcher. Its configuration starts SuppressIFPatcher and then Loader. The archive names and configuration do not qualify the patcher's full effects or ASUS compatibility.

The [author's explanation](https://github.com/DavidS95/Smokeless_UMAF/blob/c003b126cab6e29b1d72d061d59cea9e721a6910/README.md) describes replacing the boot's form browser to expose existing AMD PBS/CBS forms. We already extracted these forms from BIOS314 and read the relevant stored fields from Windows. A menu view could verify what a browser presents, but the known USB4/TBT3 toggles are enabled and the RT0 fields are Auto. No additional PD recorder or applicable USB4 repair was identified in this review.

## Related source worth studying

| Project | Useful part | Limit for ASUS-DEG2 |
| --- | --- | --- |
| [SmokelessRuntimeEFIPatcher](https://github.com/barlowhaydnb/SmokelessRuntimeEFIPatcher/tree/76f1fd7997a9750509c9906c1a7ffa86f64e26c1) | Source for finding loaded EFI images, loading modules from a filesystem or firmware volume, and starting an EFI image. This provides reference patterns for pre-OS instrumentation | It does not identify the failed ASUS instruction or implement an identified IT8857/PS8830 diagnostic transport. Menu patches for other laptops are not ASUS fixes |
| [setup_var.efi](https://github.com/datasone/setup_var.efi/tree/f36c98be3b2d8541bfb18800baaa734802fab888) | Source for reading named UEFI variables with offsets and sizes | It also writes variables and can reset the machine. A strict reader could reuse the GET logic, but our existing Windows reader already supplies the relevant stored values. It does not expose applied controller state |
| [Intel tbtools](https://github.com/intel/tbtools/tree/5de2ac9d5325c3746adbda7d9874b98397109ebb) | Linux router/adapter register inspection, topology and USB4 control-channel tracing. Its register descriptions are already useful offline | Access depends on the kernel and exposed hardware. USB4 control-channel tracing is not a CC/PD packet capture. Retimer access may require active enumeration, so it cannot be assumed passive or available before entry |

An important source check: the inspected [Type-C backend](https://github.com/intel/tbtools/blob/5de2ac9d5325c3746adbda7d9874b98397109ebb/src/typec.rs#L68-L81) opens only the ChromeOS EC implementation. The generic connector backend is still a TODO there. `tbpd` accepting a USB4-mode argument therefore does not make it a mode override for ASUS's ITE controller. It was not executed.

## What the Linux comparison answered

The subsequent ASUS run showed the host router and ordinary USB devices, but no external router or new PCIe device. It saved the capture to USB. This weakens an explanation specific to the original Windows installation; it does not establish a defective chip. [Full result](linux-asus-result.md).

Another boot would be useful only if it added a specific missing observation or changed a justified condition. The existing collector does not record physical PD packets or applied retimer configuration. Linux's optional offline retimer enumeration also changes port state and powers retimers; it is not a passive view of the failed attachment. [Kernel documentation](https://www.kernel.org/doc/html/latest/admin-guide/thunderbolt.html#upgrading-on-board-retimer-nvm-when-there-is-no-cable-connected).

A custom read-only EFI application could instead inventory installed firmware protocols and export identified handoff data before Windows. That is an engineering possibility, not an implemented collector. It becomes useful when we name a specific record absent from the current evidence. Neither a replacement form browser nor an EFI image loader automatically reaches the independently running PD/retimer firmware or recovers its past traffic.

[Archive inventories, immutable source pins and code locations](../evidence/boot-tools-review.json). Downloads and inspected source remain private. The original review did not execute these boot tools; the later Linux capture is recorded separately.

## Collector status

The [Linux kit](linux-capture.md) has progressed from VM checks to one completed ASUS hardware capture with working USB saving. Dell Linux boot is unavailable; use the existing Dell Windows control. Earlier preparation claims are preserved in [the prior revision](https://github.com/49Ssr/asus-fa507xi-deg2-usb4/blob/e90139bc0949b6488241f4e8a45b95ea22ff16c3/docs/boot-tools-review.md).
