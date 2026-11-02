"""Offline boundary tests: no Linux device, mount, trace or subprocess operation."""

import copy
import importlib.util
from pathlib import Path
import tempfile
import sys
import time
import unittest
from unittest import mock
from contextlib import ExitStack, redirect_stdout
import io
import hashlib
import json
from types import SimpleNamespace

spec = importlib.util.spec_from_file_location(
    "capture", Path(__file__).with_name("capture_usb4.py")
)
c = importlib.util.module_from_spec(spec)
spec.loader.exec_module(c)


def empty():
    return {"thunderbolt": {}, "typec": {}, "usb": {}, "pci": {}}


class Boundaries(unittest.TestCase):
    def test_capture_refuses_windows_before_any_hardware_or_output_operation(self):
        if sys.platform == "linux":
            self.skipTest("Windows guard exercised on the preparation host")
        with self.assertRaises(RuntimeError):
            c.capture()

    def test_logger_supervisor_stops_its_own_real_child(self):
        with tempfile.TemporaryDirectory() as d:
            out = Path(d)
            logs = c.Logs(out)
            logs.start_process(
                [
                    sys.executable,
                    "-c",
                    'import time; print("ready",flush=True); time.sleep(30)',
                ],
                "child.log",
            )
            try:
                deadline = time.monotonic() + 5
                while (
                    "ready" not in (out / "child.log").read_text()
                    and time.monotonic() < deadline
                ):
                    time.sleep(0.01)
                self.assertIn("ready", (out / "child.log").read_text())
            finally:
                logs.stop()
            self.assertIsNotNone(logs.children[0].poll())

    def test_one_log_write_failure_does_not_skip_the_other_handles(self):
        with tempfile.TemporaryDirectory() as d:
            out = Path(d)
            logs = c.Logs(out)
            failed = SimpleNamespace(
                name="full.log",
                flush=mock.Mock(side_effect=OSError("fixture disk full")),
                close=mock.Mock(side_effect=OSError("fixture close error")),
            )
            healthy = (out / "healthy.log").open("wb")
            logs.files = [failed, healthy]
            logs.stop()
            self.assertTrue(healthy.closed)
            self.assertTrue(any("close_error" in note for note in logs.notes))

    def test_internal_gpu_is_not_new_external_gpu(self):
        before = empty()
        before["pci"]["0000:01:00.0"] = {
            "vendor": "0x10de",
            "device": "0x2820",
            "class": "0x030000",
        }
        out = c.classify(before, [copy.deepcopy(before)])
        self.assertEqual(out["new_display_endpoints"], [])
        self.assertEqual(out["status"], "AttachmentNotEstablished")

    def test_pending_authorization_is_router_success_not_entry_failure(self):
        after = empty()
        after["thunderbolt"]["0-1"] = {"device": "0x1234", "authorized": "0"}
        self.assertEqual(
            c.classify(empty(), [after])["status"],
            "ExternalRouterPresentAuthorizationPending",
        )

    def test_missing_authorization_is_not_zero(self):
        after = empty()
        after["thunderbolt"]["0-1"] = {"device": "0x1234", "authorized": None}
        self.assertEqual(
            c.classify(empty(), [after])["status"],
            "ExternalRouterPresentRequiresTopologyReview",
        )

    def test_transient_router_is_retained_even_when_finally_absent(self):
        after = empty()
        after["thunderbolt"]["0-1"] = {"device": "0x1234"}
        out = c.classify(empty(), [after, empty()])
        self.assertTrue(out["external_router_observed"])
        self.assertEqual(out["status"], "ExternalRouterObservedThenAbsent")

    def test_existing_other_router_does_not_establish_new_attachment(self):
        before = empty()
        before["thunderbolt"]["0-1"] = {"device": "0x1234"}
        self.assertFalse(
            c.classify(before, [copy.deepcopy(before)])["external_router_observed"]
        )

    def test_root_domain_retimer_and_xdomain_do_not_become_external_router(self):
        after = empty()
        after["thunderbolt"] = {
            "0-0": {"device": "0x1668"},
            "domain0": {},
            "0-0:2.1": {"device": "0x8830"},
            "0-1": {"device": None},
        }
        self.assertEqual(c.external_routers(after), {})

    def test_billboard_fallback_does_not_establish_usb4(self):
        after = empty()
        after["usb"]["1-1.4"] = {"idVendor": "041f", "idProduct": "d002"}
        self.assertEqual(
            c.classify(empty(), [after])["status"],
            "DEG2FallbackObservedNoExternalRouter",
        )

    def test_preconnected_history_is_explicit(self):
        before = empty()
        before["thunderbolt"]["0-1"] = {"device": "0x1234", "authorized": "1"}
        self.assertTrue(
            c.classify(before, [copy.deepcopy(before)], True)[
                "preconnected_without_fresh_attachment"
            ]
        )

    def test_missing_sysfs_values_remain_unknown(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            p = root / "bus/thunderbolt/devices/0-0"
            p.mkdir(parents=True)
            (p / "device").write_text("0x1668", encoding="ascii")
            s = c.snapshot(root)
            self.assertIsNone(s["thunderbolt"]["0-0"]["authorized"])

    def test_driver_exposed_partner_identity_is_retained_without_guessing(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            p = root / "class/typec/port0-partner/identity"
            p.mkdir(parents=True)
            (p / "id_header").write_text("0x12345678", encoding="ascii")
            s = c.snapshot(root)
            self.assertEqual(
                s["typec"]["port0-partner"]["identity"]["id_header"], "0x12345678"
            )
            self.assertIsNone(s["typec"]["port0-partner"]["identity"]["product"])

    def test_exact_laptop_scope_accepts_asus_underscore_product(self):
        self.assertTrue(c.supported_product("ASUS TUF Gaming A15 FA507XI_FA507XI"))
        self.assertTrue(c.supported_product("Latitude 5540"))
        self.assertFalse(c.supported_product("FA507XIA"))
        self.assertFalse(c.supported_product("Latitude 5550"))

    def test_output_guard_rejects_internal_and_readonly_iso_filesystems(self):
        good = {"target": str(c.BOOT), "source": "/dev/sda1", "fstype": "vfat"}
        script = (c.BOOT / "usb4/capture_usb4.py").resolve()
        c.verify_media(good, "/sys/devices/pci/usb1/1-1/block/sda", c.MARKER, script)
        for mount, transport, marker, p in [
            (good, "/sys/devices/pci/ata1/block/sda", c.MARKER, script),
            ({**good, "fstype": "iso9660"}, "/sys/usb1/x", c.MARKER, script),
            ({**good, "fstype": "exfat"}, "/sys/usb1/x", c.MARKER, script),
            ({**good, "source": "/dev/mapper/ventoy"}, "/sys/usb1/x", c.MARKER, script),
            ({**good, "target": "/"}, "/sys/usb1/x", c.MARKER, script),
            (good, "/sys/usb1/x", "wrong", script),
            (good, "/sys/usb1/x", c.MARKER, Path("/tmp/capture_usb4.py")),
        ]:
            with self.subTest(mount=mount, transport=transport, marker=marker):
                with self.assertRaises(RuntimeError):
                    c.verify_media(mount, transport, marker, p)


class CaptureWorkflow(unittest.TestCase):
    """Exercise the real capture flow with fixture observations and fake controls.

    No hardware, mount command or Linux logging operation is performed.
    Real files below a temporary directory verify the returned evidence.
    """

    def run_flow(
        self, states, interrupt=False, preparation_error=False, logger_error=False
    ):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            out = root / "run"
            out.mkdir()
            product = root / "product"
            product.write_text("FA507XI", encoding="ascii")
            cmdline = root / "cmdline"
            cmdline.write_text("fixture-boot", encoding="ascii")
            lock = root / "capture.lock"
            events = []
            real_path = Path

            def path(value):
                return {
                    "/sys/class/dmi/id/product_name": product,
                    "/proc/cmdline": cmdline,
                    "/run/usb4-research-capture.lock": lock,
                }.get(str(value), real_path(value))

            class FakeLogs:
                def __init__(self, directory):
                    self.notes = []

                def start(self):
                    if logger_error:
                        raise RuntimeError("fixture logger failure")

                def stop(self):
                    events.append("loggers stopped")

            terminal = io.StringIO()
            with ExitStack() as stack:
                stack.enter_context(mock.patch.object(c.sys, "platform", "linux"))
                stack.enter_context(
                    mock.patch.object(c.os, "geteuid", return_value=0, create=True)
                )
                stack.enter_context(
                    mock.patch.object(
                        c.os,
                        "uname",
                        return_value=SimpleNamespace(release="fixture-kernel"),
                        create=True,
                    )
                )
                stack.enter_context(
                    mock.patch.object(
                        c.os,
                        "sync",
                        side_effect=lambda: events.append("synced"),
                        create=True,
                    )
                )
                stack.enter_context(mock.patch.object(c, "Path", side_effect=path))
                stack.enter_context(
                    mock.patch.dict(
                        sys.modules,
                        {
                            "resource": SimpleNamespace(
                                RLIMIT_FSIZE=1, setrlimit=lambda *a: None
                            )
                        },
                    )
                )
                stack.enter_context(
                    mock.patch.object(
                        c,
                        "prepare_output",
                        side_effect=RuntimeError("fixture preparation failed")
                        if preparation_error
                        else None,
                        return_value=(out, True),
                    )
                )
                stack.enter_context(mock.patch.object(c, "Logs", FakeLogs))
                stack.enter_context(
                    mock.patch.object(c, "snapshot", side_effect=copy.deepcopy(states))
                )
                stack.enter_context(
                    mock.patch.object(
                        c.time,
                        "monotonic",
                        side_effect=[0, KeyboardInterrupt()] if interrupt else [0, 46],
                    )
                )
                control = stack.enter_context(
                    mock.patch.object(c, "command", return_value="")
                )
                prompt = stack.enter_context(
                    mock.patch("builtins.input", return_value="")
                )
                stack.enter_context(redirect_stdout(terminal))
                if preparation_error:
                    with self.assertRaisesRegex(RuntimeError, "preparation failed"):
                        c.capture()
                    return {
                        "lock_exists": lock.exists(),
                        "prompts": prompt.call_count,
                        "controls": control.call_count,
                    }
                rc = c.capture()
            result = __import__("json").loads((out / "result.private.json").read_text())
            manifest = __import__("json").loads(
                (out / "manifest.private.json").read_text()
            )
            self.assertIn("result.private.json", manifest)
            self.assertIn("loggers stopped", events)
            self.assertIn("synced", events)
            control.assert_called_once_with(
                ["mount", "-o", "remount,ro", "--", str(c.BOOT)]
            )
            return {
                "result": result,
                "returncode": rc,
                "prompts": prompt.call_count,
                "terminal": terminal.getvalue(),
            }

    @staticmethod
    def host():
        state = empty()
        state["thunderbolt"]["0-0"] = {"device": "0x1668"}
        return state

    def test_full_capture_preserves_pending_authorization_and_writes_manifest(self):
        before = self.host()
        after = self.host()
        after["thunderbolt"]["0-1"] = {"device": "0x1234", "authorized": "0"}
        out = self.run_flow([before, before, after])
        self.assertEqual(
            out["result"]["status"], "ExternalRouterPresentAuthorizationPending"
        )
        self.assertEqual(out["returncode"], 0)
        self.assertIn("awaiting authorization", out["terminal"])

    def test_interrupted_preconnected_capture_keeps_its_history_label(self):
        state = self.host()
        state["thunderbolt"]["0-1"] = {"device": "0x1234", "authorized": "1"}
        out = self.run_flow([state, state, state], interrupt=True)
        partial = out["result"]["partial_observation"]
        self.assertTrue(partial["preconnected_without_fresh_attachment"])
        self.assertTrue(partial["external_router_observed"])
        self.assertEqual(out["result"]["error"], "KeyboardInterrupt")

    def test_no_host_stops_before_any_connection_prompt(self):
        out = self.run_flow([empty()])
        self.assertEqual(out["prompts"], 0)
        self.assertEqual(out["result"]["status"], "StoppedRequiresReview")
        self.assertNotIn("GREEN", out["terminal"])

    def test_early_attachment_is_retained_without_requesting_a_reconnect(self):
        after = self.host()
        after["usb"]["1-1"] = {"idVendor": "041f", "idProduct": "d002"}
        out = self.run_flow([self.host(), after, after])
        self.assertEqual(
            out["result"]["status"], "DEG2FallbackObservedNoExternalRouter"
        )
        self.assertEqual(out["result"]["attachment_timing"], "connected_before_prompt")
        self.assertTrue(out["result"]["preconnected_without_fresh_attachment"])
        self.assertNotIn("GREEN: connect", out["terminal"])

    def test_failed_logger_start_still_saves_result_and_restores_mount(self):
        out = self.run_flow([], logger_error=True)
        self.assertEqual(out["result"]["error"], "fixture logger failure")
        self.assertEqual(out["prompts"], 0)

    def test_preparation_error_does_not_force_another_boot(self):
        out = self.run_flow([], preparation_error=True)
        self.assertFalse(out["lock_exists"])
        self.assertEqual(out["prompts"], 0)
        self.assertEqual(out["controls"], 0)


class DeliveryRecord(unittest.TestCase):
    def test_exported_local_guide_keeps_working_links(self):
        spec = importlib.util.spec_from_file_location(
            "bundle", Path(__file__).with_name("build_bundle.py")
        )
        b = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(b)
        guide = b.portable_guide(
            "[Details](linux-capture-internals.md#checks) [Tools](../tools/README.md) [External](https://example.org/page)"
        )
        self.assertIn("/blob/main/docs/linux-capture-internals.md#checks", guide)
        self.assertIn("/blob/main/tools/README.md", guide)
        self.assertIn("[External](https://example.org/page)", guide)

    def test_current_source_matches_the_published_audit_record(self):
        root = Path(__file__).resolve().parents[2]
        audit = json.loads(
            (root / "evidence/linux-kit-audit.json").read_text(encoding="utf-8")
        )
        for source in audit["collector_review"]["sources"]:
            with self.subTest(path=source["path"]):
                data = (root / source["path"]).read_bytes()
                self.assertEqual(hashlib.sha256(data).hexdigest(), source["sha256"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
