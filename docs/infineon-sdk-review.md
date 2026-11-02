# What SDK 3.9.0 adds to the investigation

The owner supplied the EZ-PD Host SDK 3.9.0 Windows installer on 2 November 2026. Its Infineon signature is valid. It was copied, verified and unpacked without running setup. No driver, firmware or host security setting was changed.

**The package supplies missing AMD/PS8830 definitions and compiled implementations. It does not establish a Windows repair or an ASUS-compatible controller command.**

## Material recovered

| Item | What it supplies |
| --- | --- |
| `cy_pdaltmode_amd.h` | APU mode-setting, interrupt/status handling and EC-facing update interfaces |
| `cy_pdaltmode_amd_mtk_retimer.h` | PS8830-specific selection value and retimer/I2C wrapper declarations |
| `libpdaltmode_host_amd.a` | ARM objects implementing the APU and AMD/MTK retimer functions; the missing routines are not supplied as matching plaintext C files |
| AMD notebook `src/amd_wrapper.c` | I2C transport wrappers and a conditional HPI read/write tunnel |
| AMD notebook `main.c` | Conditional registration of the tunnel callback with HPI |
| `amd_cfg_settings_t` | Separate configurable APU address/index, retimer type/address and host/USB4 capability fields |

These are Infineon reference-controller implementations. ASUS's inspected firmware uses an ITE interface. The correspondence between their wire formats, registers and failure behavior remains unproven.

## A concrete status-read path

The compiled `Cy_PdAltMode_Amd_GetApuStatus` routine is 80 bytes of Thumb code. In its selected configuration mode it sends index byte `0x80` to the configured APU address and requests three bytes through the combined write/read wrapper. A failed transport returns zero. A successful transport returns 2 or 3 according to bit 6 of the first returned byte.

The original function bytes were executed in an isolated emulator with the external transport replaced by fixture data. Seven cases checked the configuration guard, failed transport and status-bit combinations. No hardware request was sent. This verifies the reference reader's behavior; it does not acquire ASUS status or establish the physical meaning of every status bit.

The same object contains a separate interrupt-source reader using index `0xa2`. The status and interrupt paths provide concrete formats to compare against the original ASUS firmware. **They are APU-interface operations, not a recovered PS8830 register map.**

## Mode setting involves later work

The objects retain symbols and relocations for mode setting, a periodic task, retimer updates, timers and failure handling. `Cy_PdAltMode_Amd_SetMux` can reject work while a retimer firmware update is active, and the associated task performs later transport and status handling. A mode-setting return value alone does not establish a trained USB4 link.

Disassembly separates Thumb code from ARM ELF data-mapping ranges and retains relocation targets. The full mode-setting state machine has not yet been mapped to ASUS.

## What the HPI tunnel does and does not provide

The notebook reference contains a conditional tunnel that forwards read/write requests through its I2C master. Its read branch uses the combined write/read wrapper, which checks both the transport result and transferred byte counts. The callback is conditionally registered in the reference application's HPI table.

Two other wrappers are less strict: the retimer write branch and standalone read wrapper return false only for arbitration loss or bus-busy results. Other error results can therefore produce a true Boolean. This is a warning about interpreting that reference code, not evidence that ASUS executes it or suffers the same behavior.

HPI is the reference controller's host interface. No equivalence to DEG2's WinUSB vendor interface or ASUS's EC transport has been established. The SDK does not make those endpoints interchangeable and does not provide a ready Windows PD packet recorder.

## Next work

Compare the reference APU status/interrupt transactions and configuration fields against the original ASUS controller-facing code. Keep APU requests, retimer requests and device-provided status separate. Continue identifying DEG2's actual diagnostic command handler independently.

No live tunnel request, register write, new driver, boot or flash is selected from this review. A test requires an identified operation in the actual ASUS or DEG2 implementation and a defined observation/restoration path.

Installer, extracted files, object code, disassembly and failed extraction attempt remain private. Public records contain hashes, relative SDK paths and reviewed descriptions. [Evidence and validation](../evidence/infineon-sdk-review.json) · [Official SDK catalog](https://softwaretools.infineon.com/tools/com.ifx.tb.tool.ezpdhostsdk) · [Current findings](status.md)
