# Useful boot tools for this investigation

The useful distinction is what each tool can expose. A bootable menu gives access to settings; it does not by itself expose PD packets or retimer training. No new boot or setting change is proposed by this review.

## Smokeless UMAF

The [pinned repository](https://github.com/DavidS95/Smokeless_UMAF/tree/c003b126cab6e29b1d72d061d59cea9e721a6910) contains a README, photographs and two ZIP distributions, with no source files in that tree. Both archives were downloaded and inventoried without executing or deploying anything.

The normal package contains the boot loader, DisplayEngine, SetupBrowser and UiApp. The beta adds a separate loader, SREP configuration and SuppressIFPatcher. Its configuration starts SuppressIFPatcher and then Loader. The archive names and configuration do not qualify the patcher's full effects or ASUS compatibility.

The [author's explanation](https://github.com/DavidS95/Smokeless_UMAF/blob/c003b126cab6e29b1d72d061d59cea9e721a6910/README.md) describes replacing the boot's form browser to expose existing AMD PBS/CBS forms. We already extracted these forms from BIOS314 and read the relevant stored fields from Windows. A menu view could verify what a browser presents, but the known USB4/TBT3 toggles are enabled and the RT0 fields are Auto. No additional PD recorder or applicable USB4 repair was identified in this review.

## Related source worth studying

| Project | Useful part | Limit for ASUS-DEG2 |
| --- | --- | --- |
| [SmokelessRuntimeEFIPatcher](https://github.com/barlowhaydnb/SmokelessRuntimeEFIPatcher/tree/76f1fd7997a9750509c9906c1a7ffa86f64e26c1) | Source for finding loaded EFI images, loading modules from a filesystem or firmware volume, and starting an EFI image. This provides reference patterns for pre-OS instrumentation | It does not identify the failed ASUS instruction or implement a qualified IT8853/PS8830 diagnostic transport. Menu patches for other laptops are not ASUS fixes |
| [setup_var.efi](https://github.com/datasone/setup_var.efi/tree/f36c98be3b2d8541bfb18800baaa734802fab888) | Source for reading named UEFI variables with offsets and sizes | It also writes variables and can reset the machine. A strict reader could reuse the GET logic, but our existing Windows reader already supplies the relevant stored values. It does not expose applied controller state |
| [Intel tbtools](https://github.com/intel/tbtools/tree/5de2ac9d5325c3746adbda7d9874b98397109ebb) | Linux router/adapter register inspection, topology and USB4 control-channel tracing. Its register descriptions are already useful offline | Access depends on the kernel and exposed hardware. USB4 control-channel tracing is not a CC/PD packet capture. Retimer access may require active enumeration, so it cannot be assumed passive or available before entry |

An important source check: the inspected [Type-C backend](https://github.com/intel/tbtools/blob/5de2ac9d5325c3746adbda7d9874b98397109ebb/src/typec.rs#L68-L81) opens only the ChromeOS EC implementation. The generic connector backend is still a TODO there. `tbpd` accepting a USB4-mode argument therefore does not make it a mode override for ASUS's ITE controller. It was not executed.

## What a later boot could actually answer

The strongest alternative-OS question is whether the same DEG2 connection enumerates an external USB4 router and PCIe GPU under Linux. Success would establish that this pairing can work in that session and direct attention toward the Windows/firmware interaction. Different boot and power history would remain a confound. Failure would leave the PD/retimer ambiguity unresolved rather than prove a hardware defect.

A useful capture would start kernel USB4/UCSI logging before attachment, record the mapped root adapter and RouterDetected state, retain topology and PCIe-enumeration evidence, and separate observation from register writes or retimer scans. This is a preparation target, not a ready image or instruction to reboot. No Linux image was built or booted here.

A custom read-only EFI application could instead inventory installed firmware protocols and export identified handoff data before Windows. That is an engineering possibility, not an implemented collector. It becomes useful when we name a specific record absent from the current evidence. Neither a replacement form browser nor an EFI image loader automatically reaches the independently running PD/retimer firmware or recovers its past traffic.

[Archive inventories, immutable source pins and code locations](../evidence/boot-tools-review.json). Downloads and inspected source remain private; no executable, driver, boot entry, setting or USB-drive content was installed or changed.
