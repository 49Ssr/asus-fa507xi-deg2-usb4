USB4 DEEP COMPARISON - RESUMABLE DUMP HANDOFF

The November 1 Dell V2 trace and separately returned full dump have already been recovered. Do not repeat that Dell capture for its failed handoff. This revision is for a future capture with a specific remaining question; keep existing kits/results intact.

1. Keep DEG2 powered with the same GPU, PSU, supplied upstream cable and known USB4 port. Use normal barrel power and default CC policy. Do not run the earlier role/mode experiments alongside this collector.
2. Right-click START-DELL.cmd -> Run as administrator on Latitude 5540. START-ASUS.cmd separately guards FA507XI. The source is verified/staged on the laptop SSD before collection. Existing USB files are preserved; FAT32 is supported without formatting.
3. Follow the disconnect/reconnect prompts once. Passive tracing and endpoint inventory stop before the snapshot step. Actual trace duration includes inventory/workflow overhead.
4. Leave DEG2 attached. Administrator Task Manager opens. Details -> right-click System (PID 4) -> Create live kernel memory dump file -> Full live kernel memory dump. Choose FULL, not Kernel stacks or a process dump. Leave optional user/hypervisor page additions off. Wait for completion.
5. Return to the capture window and press Enter: it searches the standard Task Manager dump folder automatically. B opens Browse. A quoted file path or folder containing one eligible dump also works. A repeated filename is tolerated. Invalid input can be retried without losing the trace.
6. P or cancelling Browse leaves a saved TraceCaptured_DumpPending run. FINISH-DUMP.cmd on the SAME laptop resumes that run without another attachment trace. Keep DEG2 connected in the expected state until completion. This resume launcher belongs to the revised kit; do not transplant it into an old kit.
7. Once accepted, endpoint inventory checks the expected state and asks about the GPU-connected display. Packaging streams on SSD and writes SHA-256/read-back-verified parts no larger than 1 GiB to RETURNED. Keep the USB connected until packaging completes. The original dump remains on the laptop.

If interrupted
- The launchers stay open. Keep the displayed error and all local/returned files.
- Pending dump: FINISH-DUMP.cmd resumes on the same laptop. RETURN.cmd only repackages the saved state; it does not collect a missing dump.
- Trace cleanup: STOP-TRACE.cmd only addresses the recorded owned session. It sends no UCSI request and does not reset a controller.
- If return files do not fit, they remain on SSD and the needed size is reported. No format, delete, silent dump omission or destructive cleanup occurs.
- A complete transfer may still describe a failed/pending collection; read the actual capture result and dump-included fields.

Scope
- Passive capped ETW, selected ACPI tables, 14 installed driver copies, metadata/network snapshots and an owner-generated full native kernel dump. Duplicate SSDTs and missing memory remain explicit coverage limits.
- No firmware/UCSI commands, live kernel helper, registry/boot/security/device/network setting changes or firmware flash.
- 183 PS5.1 software assertions pass, including actual read-only inventory/static inputs and mocked selection/resume cases. The new Browse/Task Manager UI and new hardware capture are not qualified by those tests.
- Full dumps/traces contain private data: keep raw files off public GitHub. The repository records sanitized results and the previous failed handoff's recovery.
