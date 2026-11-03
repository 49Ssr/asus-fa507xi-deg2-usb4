# What the IT8857 version-only tool actually does

**The advertised version-only mode skips firmware updating, but still reconfigures the host I²C controller. It is not a ready Windows reader for this laptop.** This was established from the acquired program's instructions and saved ASUS ACPI tables. The program was not run and no hardware request was sent.

The audit also recovered a useful address convention: with IT8857 selected, update address `80` maps to normal address `98`, the address byte already found in ASUS's EC relay. That match helps interpret the interface; it does not establish that the tool reaches the same physical bus.

[Hashes, code offsets and verification](../evidence/it8857-version-path.json) · [Original package and version-cache result](pd-firmware-version.md)

## The selected version-only path

1. Parse the options, including the supplied chip ID, address and I²C channel. The selected chip ID is an input, not a hardware identification result.
2. Identify the platform through PCI configuration I/O. On AMD, select a host-controller base from a fixed six-entry table.
3. Run controller initialization. The AMD branch first modifies two fixed platform bytes. The common code then disables/enables the I²C controller and programs its configuration, timing, FIFO thresholds and interrupt handling.
4. Translate the configured update address to the normal controller address.
5. Select register `B6`, then read two bytes. The tool prints those bytes in hexadecimal, first byte followed by second.
6. If the read succeeded and version-only is selected, return before the update sequence. A read failure takes the error return.

The selected application return does not restore the previous host-controller configuration. Several initialization loops wait for hardware state without a local timeout. Those findings explain why the version-only label is insufficient reason to execute the tool on an unverified bus. The audit did not certify every option combination or all UEFI library startup/cleanup routines.

The register layout agrees with the [DesignWare I²C definitions](https://github.com/torvalds/linux/blob/46fec1c3029b552ec63b2d01af9d43a386f043ea/include/linux/designware_i2c.h). This identifies the transport's programming model; it is not a measurement of the laptop controller.

## Address mapping recovered

These are decoded reference-tool values, **not commands to run**:

| Configured IT8857 update address byte | Normal address byte used for the version read | 7-bit target programmed into the host controller |
| --- | --- | --- |
| `80` | `98` | `4C` |
| `84` | `9C` | `4E` |

The supplied add-in-card recipe uses the second pair. ASUS's recovered EC code uses normal address byte `98`; its bus engine also treats `80` separately. The first pair therefore corroborates the address convention. It does not prove a shared transport, wiring, firmware image or reset implementation.

## Why it does not directly become a Windows tool

The utility drives a CPU-visible I²C controller through direct I/O and memory-mapped registers. The laptop's recovered UCSI relay uses an **EC-internal bus engine**. Their channel numbers belong to different controllers.

The first four entries in the tool's AMD controller table match the I2CA–I2CD resource buffers in the retained ASUS DSDT. This is useful confirmation of the host-controller address layout. It does not establish that the PD chip is wired to one of those buses, or that those devices are currently enabled. No ACPI method was executed for this comparison.

Windows' standard SPB route requires a peripheral driver with an assigned connection resource. An ordinary application cannot directly open that connection, and only one driver can own it at a time. The audit has not identified an existing Windows connection to this PD target. [Microsoft's SPB connection documentation](https://learn.microsoft.com/en-us/windows-hardware/drivers/spb/connection-ids-for-spb-connected-peripheral-devices).

## What this changes

We now have the reference tool's exact version transaction and address conversion. We also know that transplanting its initialization would change the host bus and would not demonstrate access to ASUS's EC-controlled PD connection.

The next software question is in the **FA507XI EC host-command dispatcher**: does an implemented host command expose a current PD read through the known EC bus engine, or are the useful reads only internal periodic routines? The existing signed ASUS driver reaches that EC command path, but its demonstrated version getters return a cache. The already-stubbed table 6 getter is not a candidate to retry.

Even a fresh B6 read would identify version metadata, not the failed handshake. A subsequent state/log read would still need its own meaning and side effects established. The actual laptop Data_Reset handler remains unknown.

[Diagnosis plan](investigation-plan.md) · [Windows interfaces](windows-repair-route.md)
