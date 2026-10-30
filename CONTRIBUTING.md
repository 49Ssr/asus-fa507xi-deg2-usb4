# Contributing a useful compatibility report

Open a report with the exact host model/CPU, BIOS version, Windows build, dock/controller model, reported router firmware, and cable model/data rating/length. Explain whether an external router appears under Windows USB4 settings, whether the GPU enumerates, and whether the identical assembled hardware works on another host.

Distinguish these milestones:

1. Ordinary USB hubs/mouse/Ethernet operate.
2. External USB4 router enumerates.
3. PCIe GPU enumerates.
4. GPU driver operates and produces output.
5. Workload runs stably at measured performance.

Include a precise before/after for any change. Say when a test was not performed or its prerequisites were incomplete. Link to original documentation or your firsthand observations; label other people's reports as such.

Do not attach raw traces or inventories until their identifying fields have been reviewed. Do not submit cross-model firmware binaries or universal "registry fix" instructions without a verified applicability argument and reproducible results. See [privacy guidance](docs/privacy.md) and [the experiment ledger](docs/experiments.md).
