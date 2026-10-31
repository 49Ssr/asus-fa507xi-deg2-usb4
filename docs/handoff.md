# Current state / next-session handoff

Last documented: 31 October 2026. The eGPU remains unresolved on ASUS and works on the Dell comparison host.

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

1. Corrected image preparation, driver injection and native boot completed after the initial guard failure was preserved. State is BootEntryCreated. The owner reached Audit Mode, completed the recorder and returned to original Windows.
2. Fresh Windows 26200.8037 with USB4 driver 10.0.26100.7920 reproduced the failure. Essential host/root/UCSI/I2C/Parade preflight passed. No external USB4 router or new display adapter; ordinary hub/Billboard fallback only. See fresh-Windows results for missing non-baseline drivers and decode limits.
3. One suitable alternate cable, or another known-working USB4/TB peripheral on this ASUS, remains the next useful discriminator. No new verified applicable FA507XI/dock firmware fix has been found.
4. The temporary image and boot entry remain available; removal has not been tested. Do not automatically delete them or discard private evidence.
5. Keep the experiment ledger honest about image version, missing drivers, lost events, and untested configurations. Further repeated driver/registry changes to the main installation have lower diagnostic value than the missing hardware comparisons.

## Repository request

The owner explicitly requested a GitHub repo documenting the investigation and research for community benefit, stored in the existing projects area on the secondary drive. Intended local location: `D:\Projects\GitHub\asus-fa507xi-deg2-usb4`.

The owner copied the folder and refreshed their GitHub login, then created/pushed the public repository at `https://github.com/49Ssr/asus-fa507xi-deg2-usb4`. Connected GitHub tools can update it. The restricted process's local CLI credentials still returned 401, while the owner's terminal succeeded; do not ask the owner to repeat authentication for that process limitation.

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
