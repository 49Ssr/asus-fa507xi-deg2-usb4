# Contributing

Useful contributions explain a reproducible observation or a specific code path. Start with [current findings](docs/status.md) so completed tests and corrected assumptions are not presented as new work.

## Report compatibility

Include the host model/CPU, BIOS version, OS build, dock model, GPU, and cable rating/length. State whether the identical assembled hardware works on another host. Report each milestone separately:

1. Ordinary USB devices work.
2. An external USB4/Thunderbolt router appears.
3. A PCIe GPU appears.
4. The GPU driver produces output.
5. A workload runs stably at measured performance.

Unknown is a useful answer. Include the exact before/after for a changed condition, and say when the intended condition was not achieved. Do not assume USB4 mode or bandwidth from a connector label or endpoint PCIe reading.

## Contribute a finding or change

Link the original source and identify its model/version/date. Separate actual measurements, original-code behavior and hypotheses. For a proposed command or patch, identify the consumer and expected result; another board's register value or a generic interface GUID is insufficient.

Keep code changes small and explain how they were checked. [The tool guide](tools/README.md) lists the public-file checks. The Linux observer is currently restricted to the documented laptops; do not remove its scope/output guards just to make it run elsewhere.

## Share evidence safely

Do not post raw memory dumps, firmware, serials, router UUIDs, support case numbers or unreviewed logs. Kernel traces and inventories may contain private identifiers and addresses. Prefer a short reviewed observation with source/version information. [Publication policy](docs/privacy.md).

Historical procedures are retained for review. They are not a request to flash firmware, install the retired filter or repeat old role/reset tests. [Experiment results](docs/experiments.md).
