# Current state / next-session handoff

Last documented: 30 October 2026. The eGPU remains unresolved on ASUS and works on the Dell comparison host.

## State to preserve

- Target: FA507XI, Ryzen 9 7940HS, internal RTX 4070 Laptop; DEG2 with RTX 4080 SUPER WINDFORCE V2 and original supplied cable.
- Exact-model BIOS 314; Windows currently 25H2 26200.9818 after removal of the 26H2 enablement package.
- Original Parade SPB 1.0.8 and HID 1.0.11 restored; trial related-model packages removed.
- Private v2 registry override absent. Test-signing was disabled and Secure Boot retained. The intended override was never active.
- USB4 root initializes and `_OSC` grants `0xf`, but no external USB4 router appears; fallback Billboard/USB hubs do.
- Both internal drives are fully decrypted, with ample space for the proposed VHDX. The secondary volume is the intended project location.
- An all-vendor applicable driver update search succeeded and returned zero packages.
- Owner wants Windows-based diagnosis and prefers using existing hardware. A second suitable cable or USB4 peripheral is not confirmed available.
- A detailed ASUS report was already sent with the owner's explicit authorization. Its public copy omits account and case identifiers. Later driver/registry results were not included in the initial message.

## Immediate work

1. Native-boot toolkit is written; Windows PowerShell 5.1 parser/guard checks pass. Keep mock validation separate from real disk/boot operations and rerun the tests after edits.
2. Obtain the owner's Windows installer image by connecting the existing USB media; no ISO or installer was visible at the last local check.
3. Prepare the VHDX with baseline drivers, review result, then add its separate boot entry. Neither has been executed as of this handoff.
4. Run the fresh-Windows connection test and inspect the results after returning to the original OS.
5. Keep the experiment ledger honest about image version, missing drivers, lost events, and untested configurations.

## Repository request

The owner explicitly requested a GitHub repo documenting the investigation and research for community benefit, stored in the existing projects area on the secondary drive. Intended local location: `D:\Projects\GitHub\asus-fa507xi-deg2-usb4`.

The connected GitHub account is `49Ssr`. The connector can read/write repository contents but does not expose repository creation. The local GitHub CLI's configured account returned 401/invalid-token status. Remote creation/publication is pending working authentication; do not describe a local commit as a published repository.

The restricted execution session cannot write directly to the requested secondary-drive projects folder. Its request for elevated filesystem permission was rejected by the session approval policy. The complete staged folder must be copied there by the owner, unless a later session has direct access. This is a tool permission boundary, not lack of owner authorization.

## Avoid repeated mistakes

- Do not call the GPU dead because fans are stopped, or assert that this exact card must briefly spin at startup.
- Do not claim ordinary USB hub operation proves USB4/PCIe tunneling.
- Do not blame the internal GPU's lane usage without evidence.
- Do not repeat EC reset, device reseating, mode switching, security toggles or registry guesses without a new reason.
- Do not claim firmware was updated merely because an INF installed.
- Do not treat the v2 override attempt as a valid enabled-path test.
- Do not claim the user skipped a reboot: the restart after the override was verified.
- Do not use WinPE as a conclusive substitute for full Windows hardware validation.
- Do not invent an applicable FA507XI PD firmware or flash another product's image.
- Do not assume an assistant/local agent will automatically run inside the temporary Windows. Its collector is prepared ahead of time and returns files to the shared project.
