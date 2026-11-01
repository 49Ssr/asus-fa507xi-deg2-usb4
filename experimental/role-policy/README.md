# UCSI role-policy prototype

**Actual policy-1 load passed but the single USB4 attachment still failed. Driver rollback and owned boot/trust cleanup are verified; final original-security Verify is pending. No USB4 fix is validated.** Read the [research, controlled procedure and rollback](../../docs/role-policy-experiment.md) before using this source. The default runner and builder only print Preview.

`Driver.c` is an x64 KMDF 1.15 device lower filter. `Policy.c` is the shared bounded protocol parser tested by `TestPolicy.c`. `Usb4RolePolicy.inf` adds an independently removable extension; Microsoft's base UCSI driver is retained. The driver recognizes only the pinned UCSI UUID/revision and functions 0/4 on the guarded ASUS model. It changes a valid support mask and supplies the documented disable-correction reply before attachment.

Build with explicit local MSVC, matching SDK/WDK roots and a **new** output directory:

```powershell
.\Build.ps1 -Mode Preview
.\Build.ps1 -Mode Build -CompilerRoot '<MSVC toolset root>' `
    -WdkRoot '<extracted official WDK c root>' -SdkRoot '<Windows Kits 10 root>' `
    -OutputDirectory '<new private build directory>'
```

The qualified toolchain was MSVC 14.44.35207, SDK 10.0.26100.0 and official NuGet WDK x64 10.0.26100.6584. The builder runs the native parser tests, compiles/links, verifies the INF and generates an **unsigned** catalog. It does not install, sign or load anything. Keep build output and PDBs private under `local/`.

From the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-RolePolicyWorkflow.ps1 `
    -UnsignedPackage '<private unsigned package directory>'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\experimental\role-policy\Test-RolePolicy.ps1
```

The runner's Preflight/Install require an independently reviewed SYS hash and a valid Microsoft-signed catalog verified against Windows kernel policy. The unsigned build fails this gate before writes or device operations. Signing access, live installation, one-attachment behavior and real rollback remain unqualified. No security-setting change or general deployment tool is supplied.

Local signing and the staged test-boot workflow are in [local-test-signing.md](../../docs/local-test-signing.md). Microsoft signing remains the default. Explicit LocalTest mode requires owner-approved boot preparation, running HVCI and a same-boot baseline. The source callback harness is compiled only for user-mode tests; production builds always use actual WDK/WDF headers.
