# Pre-attachment role-policy experiment

**1 November 2026: private local test-signed copy prepared; hardware test not run.** This is a causal experiment for the ASUS FA507XI / DEG2 pairing. It is not a USB4 repair or a firmware patch. The [matched comparison](asus-dell-matched-comparison.md) remains the latest hardware result.

The proposed intervention changes the UCSI ACPI policy reply Windows reads during device initialization, before DEG2 attachment. The [source](../experimental/role-policy/) builds a small device lower filter, while Microsoft's UCSI client remains the base driver. A [guarded runner](../experimental/role-policy/Test-RolePolicy.ps1) separates installation, one attachment and rollback. Unsigned packages remain refused. The explicit [local test-signing route](local-test-signing.md) now has a cryptographically checked private package; its boot/security activation remains pending owner approval.

## What the policy actually does

Microsoft documents UCSI `_DSM` function 4, revision 0, UUID `6F8398C2-7CA4-11E4-AD36-631042B5008F`: integer 1 disables the OPM's automatic USB data-role correction. This addresses a host-to-host interaction; applying it to this failing accessory pairing is an experimental inference. It does not enable USB4 lanes or request native USB4 entry. [Microsoft's policy contract](https://learn.microsoft.com/en-us/windows-hardware/design/component-guidelines/usb4-acpi-requirements#device-specific-method-to-prevent-data-role-swap-for-host-to-host-connections).

Microsoft's sample queries supported functions, tries function 4 first, and maps a nonzero reply to `UsbDeviceControllerEnabled=true` so UcmUcsiCx skips its correction. Otherwise it considers function 3. That cached boolean is therefore not proof of an actual device controller. The sample sends the evaluation through an internal ACPI IOCTL. [Microsoft sample, policy consumer and evaluator](https://github.com/microsoft/Windows-driver-samples/blob/main/usb/UcmUcsiAcpiSample/UcmUcsiAcpiSample/Acpi.cpp).

The retained ASUS image, SHA-256 `436C580CE96861187A5299F00EAB9E852EFA6B33F127D59819C5283B6482EA4E`, was additionally disassembled as a file, without opening a live kernel. Its `_DSM` evaluator constructs the V1 complex request and sends `IOCTL_ACPI_EVAL_METHOD` (`0x32c004`) through WDF function-table index 188, the WDK's internal synchronous IOCTL entry. The actual client trace formats identify `QueryUcsiDsmForUsbDeviceControllerEnabled` and an explicit forced-policy-true message. The runner pins this image and matching trace-format hash.

**A pre-load implementation error was caught and corrected:** the client's request occupies 60 bytes, but `Size` is 44, counting argument bytes. The first native test fixture incorrectly put 60 in that field and therefore agreed with an incorrect parser. Inspection of the installed image and the sample's `inputArgumentBufferSize` assignment exposed it. The corrected shared parser/fixture accept the observed layout and reject the old layout. Earlier unsigned builds are retained privately and must not be installed. Compiler and self-consistency checks alone did not establish the interface contract.

## Exact change

The filter first forwards the ordinary function-0 support query to ACPI. Only a successful, correctly bounded 20-byte reply containing one one-byte buffer with mask `0x0f` is changed, to `0x1f`. It then answers function 4 with a correctly formed 20-byte integer-1 reply. The otherwise absent ASUS AML function 4 is not executed. Unknown UUIDs, revisions, functions, malformed layouts and unexpected support masks pass through unchanged.

Both external and internal device-control callbacks are present; a filter handling only ordinary IOCTLs would miss the verified path. The driver has no user control endpoint, arbitrary address access, UCSI command sender or persistent firmware write. Its model guard requires an ASUS FA507XI token and an `ACPI\USBC000` hardware ID. The extension INF uses a unique ExtensionId and adds this filter instead of replacing Microsoft's base package. [Extension INF behavior](https://learn.microsoft.com/en-us/windows-hardware/drivers/install/using-an-extension-inf-file), [filter ordering](https://learn.microsoft.com/en-us/windows-hardware/drivers/develop/device-filter-driver-ordering).

The policy covers that UCSI device and its connectors; it is not a DEG2-only or per-cable override. Keep other USB-C partners disconnected throughout the experiment.

UMDF is not an equivalent substitute here: Microsoft excludes internal-device-control requests from the kernel-client requests a UMDF driver may receive. [UMDF restriction](https://learn.microsoft.com/en-us/windows-hardware/drivers/wdf/supporting-kernel-mode-clients-in-umdf-drivers).

The offline audit of the retained UcmUcsiCx diagnostic dispatch found four supported operations: failure simulation, device information, command and extended command. No cached-policy setter was identified there. This and the scoped registry/string inspection do not prove that every private Windows path was exhaustively excluded. They provide no justification for another guessed registry value or diagnostic command.

## Controller and Windows boundaries

| Layer | Established here | Consequence |
| --- | --- | --- |
| ASUS AMD host router | Reported 40 Gbps peer connection works; DEG2 router remains absent. | Host-to-host success does not qualify accessory discovery or PCIe tunnelling. |
| DEG2 accessory controller | Intel identifies JHL9480 as a Thunderbolt 5 accessory controller with PCIe Gen 4 x4 capability. | Its advertised interface does not establish what this ASUS negotiated. [Intel specifications](https://www.intel.com/content/www/us/en/products/sku/225919/intel-jhl9480-thunderbolt-5-accessory-controller/specifications.html). |
| Retimer/mux path | The selected Parade package is part of the existing baseline; PS8830 is a high-speed retimer product. | A retimer is not automatically the PD policy controller, and an INF match alone does not identify every board component. [Parade product](https://www.paradetech.com/products/ps8830/). |
| UCSI/PD role policy | ASUS cache 0 and normal OS SET_UOR; Dell cache 1 and no corresponding correction. | This experiment isolates correction policy, not the whole firmware or PD sequence. |
| Windows USB4 connection manager | Microsoft describes it as independent of UCM/UCSI software; routers must implement discovery/entry. | Successful SET_UOR or a policy change is insufficient evidence of native USB4. [Windows requirements](https://learn.microsoft.com/en-us/windows-hardware/design/component-guidelines/usb4-design-details-and-general-requirements#usb-type-c-requirements). |

Dell's PD-time partner role and power contract already differ before the ASUS correction. Suppressing correction may leave ASUS in an unsuitable data role. A failed run with policy demonstrably changed would therefore reject only this intervention under these conditions. It would not prove that firmware intervention is impossible. Conversely, router/GPU enumeration after one change would be a useful causal lead requiring repeatability and rollback comparison, not immediate release certification.

Dell's raw function-3/function-4 return fields were not recovered. This experiment synthesizes the documented policy; it does not claim to reproduce a measured Dell function-4 return byte for byte.

## Controlled procedure

**Microsoft-signed mode remains the default. The prepared [LocalTest route](local-test-signing.md) additionally supports a pinned locally signed package in an explicitly prepared test boot.** The WDK catalog-generation check creates an unsigned catalog; it does not sign or certify the driver. The runner checks the reviewed SYS hash, exact INF bytes, catalog signature and `signtool verify /kp` for SYS and INF. Secure Boot must remain enabled in Microsoft mode. LocalTest mode requires the saved copied loader, actual test-signing/HVCI flags, exact local certificate and a matching same-boot fallback baseline. The capture runner never changes boot, trust or firmware settings; the separate preparation stages require the owner's explicit decision.

Microsoft's current attestation workflow requires Hardware Developer Program access and an EV certificate, and describes additional testing-scenario restrictions. No account enrollment, purchase or submission was performed. A signing route must be resolved rather than promised as a free automatic step. [Current signing requirements](https://learn.microsoft.com/en-us/windows-hardware/drivers/dashboard/code-signing-attestation). The repository's [maintenance rule](../AGENTS.md) also excludes routine Secure Boot/test-signing changes.

After signing and recovery readiness are resolved:

1. Start with responsive Windows and saved work. Use barrel power; unplug every ASUS USB-C cable, including DEG2. Keep the existing Ethernet/ICS configuration. Confirm the retained default-DRP restoration record and no other UCSI filters. Do not continue if the reported freezes return.
2. Run **Preflight** in 64-bit Administrator Windows PowerShell 5.1. It pins FA507XI, BIOS 314, Windows 26200.9818, the analysed Microsoft client and decoder. It makes no changes. New Windows/BIOS versions require review, not bypassing a check.
3. Run **Install** with the same reviewed package arguments. Before PnP installation it saves a flushed, atomic, machine/target-bound intent and full network snapshot. It traces startup, records the exact owned OEM INF alias, and restarts only that UCSI device. A reboot-required result stops the flow; no reboot is automatic. Windows may naturally issue UCSI commands during initialization; the filter supplies no command loop.
4. The Microsoft startup message must confirm forced policy true, with zero reported trace loss/format errors. Without that proof, **do not attach**; run Rollback. The driver's optional TraceLogging events are supplementary; the runner's gate uses the Microsoft client provider already present in the 27-provider profile.
5. Within 15 minutes and the same boot, **Observe** permits one attachment of powered DEG2 to the same port. It records 45 seconds, router/GPU binding and the owner's display answer. Both success and fallback are valid capture outcomes. A second Observe on that run is refused.
6. Disconnect DEG2 and run **Rollback** regardless of outcome. Retain all evidence. Analyse whether correction was suppressed, the PD-time role/power contract, USB4 detection/router/tunnels, NVIDIA binding and actual display output separately.

Commands below are templates for a future signed package; no signed package is currently supplied:

```powershell
$test = '.\experimental\role-policy\Test-RolePolicy.ps1'
& $test -Mode Preview
$reviewed = @{
    PackageDirectory = 'C:\USB4Research\reviewed-signed-package'
    ReviewedDriverSHA256 = '<reviewed signed SYS SHA-256>'
    SignTool = '<installed Microsoft signtool.exe>'
    TraceFmt = '<installed Microsoft tracefmt.exe>'
    TmfDirectory = '<private matching TMF directory>'
}
& $test -Mode Preflight @reviewed
$run = & $test -Mode Install @reviewed
& $test -Mode Observe -RunDirectory $run
# After disconnecting DEG2:
& $test -Mode Rollback -RunDirectory $run `
    -TraceFmt $reviewed.TraceFmt -TmfDirectory $reviewed.TmfDirectory
```

An installation failure may prevent assignment to `$run`. The recovery directory is displayed and saved before installation; use that exact directory, not a guessed latest run. No device operation above has been executed by this preparation.

## Rollback and interruption

Rollback verifies the saved machine, target, exact extension identity, original INF hash and reviewed SYS hash before removing its one `oemN.inf` with PnPUtil `/delete-driver ... /uninstall`. It never uses `/force`, subtree removal or broad controller reinstall. It remains reachable when the filtered UCSI device has an error. Missing trace/decoder support must not prevent package removal, although policy restoration then remains unverified. [PnPUtil semantics](https://learn.microsoft.com/en-us/windows-hardware/drivers/devtest/pnputil-command-syntax).

`PendingRollback` becomes false only after the owned package is absent, the driver is not running, original base/filter state is restored, Microsoft reports policy false, and enabled ICS bindings match. Reboot-required, interrupted, uncertain and failed verification results remain pending. A pending flag can mean verification is outstanding even after package removal. Preserve the saved logs; never blindly delete another OEM package to clear it.

An in-Windows rollback script cannot guarantee recovery from a kernel crash or an unbootable installation. Before any real load, keep a separate copy of the saved recovery record, ensure Windows Recovery is available, and have any required BitLocker recovery key available. If Windows cannot start, identify the Windows volume in Recovery and inspect its offline driver inventory; remove only the experiment's verified OEM INF with offline DISM. Do not copy an OEM number from another installation or remove Microsoft's UCSI/ACPI packages. That recovery path has not been exercised by this prototype.

## Qualification and current stability record

The final native core passes **4,631 assertions**, including the actual 44/60-byte convention, all support-mask byte values, truncation/mutation, exact output bounds and 4,000 malformed frames. The x64 KMDF 1.15 driver compiles/links with warnings as errors, includes private crash symbols, and passes WDK INF verification and catalog generation. [Structured qualification](../evidence/role-policy-experiment.json).

The PowerShell 5.1 runner now passes **64 checks**: actual Preview, real unsigned-catalog refusal, atomic state files, policy proof interpretation and scoped lifecycle doubles. Installation/restart, signing success, traces, attachment and rollback use mocks; no hardware or kernel-lifetime qualification is claimed. An additional 36 assertions execute the actual driver callbacks with DDI doubles; 41 signing/boot checks cover real signatures and mocked security transitions. Kernel static analysis has zero project results. It has not been loaded in a VM or on either laptop. Driver Verifier and actual recovery are untested. See the [readiness corrections and coverage](driver-readiness-review.md).

During preparation the owner reported 30-60-second input delays, ChatGPT freezes and unrecovered video playback, then reported improvement and authorized continuation. Read-only checks found Microsoft's original UCSI binding, no experimental filter/service, no remaining debugger/build process and no active logman session. Earlier quota/service-crash and absent-device disk events were retained privately. Cause is unresolved; the absence of the new driver does not exclude every effect of analysis workloads. No experimental policy was active during the reported instability.
