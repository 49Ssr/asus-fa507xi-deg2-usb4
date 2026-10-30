# Research and maintenance rules

This is an unresolved hardware compatibility investigation, not a published fix.
Keep confirmed observations, hypotheses, ineffective tests, and unperformed tests distinct.
Record meaningful mistakes and corrections. Never claim that successful driver installation proves a firmware update or working USB4 link.

`local/` contains private evidence, signed third-party driver copies, and temporary operating-system files. It is excluded from Git. Do not publish its contents or raw ETL/XML/PnP inventories. Public evidence must remove serial numbers, computer/user names, account addresses, device instance suffixes, MAC addresses, router/domain UUIDs, private paths, and support case identifiers.

Use original FA507XI driver packages for the temporary Windows baseline. Never inject a Firmware-class package, cross-flash another model's firmware, alter Secure Boot/test-signing, or patch Windows binaries as a routine troubleshooting step.

The native boot toolkit must default to Preview. It may initialize/format only a newly created, exactly associated file-backed virtual disk, and must never clean, resize, format, or repartition a physical disk. Keep the original Windows default and UEFI boot order. Do not automatically reboot. Delete only the toolkit's verified boot entry during cleanup; retain results and the VHDX for explicit review.

Validate scripts under Windows PowerShell 5.1. Test safety guards and command plans without executing disk, boot, driver-installation, or firmware operations in tests. Hardware results must be recorded separately from mocked tests.
