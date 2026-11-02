"""Offline boundary tests: no Linux device, mount, trace or subprocess operation."""
import copy
import importlib.util
from pathlib import Path
import tempfile
import sys
import time
import unittest

spec = importlib.util.spec_from_file_location('capture', Path(__file__).with_name('capture_usb4.py'))
c = importlib.util.module_from_spec(spec); spec.loader.exec_module(c)


def empty():
    return {'thunderbolt': {}, 'typec': {}, 'usb': {}, 'pci': {}}


class Boundaries(unittest.TestCase):
    def test_capture_refuses_windows_before_any_hardware_or_output_operation(self):
        if sys.platform == 'linux':
            self.skipTest('Windows guard exercised on the preparation host')
        with self.assertRaises(RuntimeError): c.capture()

    def test_logger_supervisor_stops_its_own_real_child(self):
        with tempfile.TemporaryDirectory() as d:
            out = Path(d); logs = c.Logs(out)
            logs.start_process([sys.executable, '-c',
                'import time; print("ready",flush=True); time.sleep(30)'], 'child.log')
            try:
                deadline = time.monotonic() + 5
                while 'ready' not in (out / 'child.log').read_text() and time.monotonic() < deadline:
                    time.sleep(0.01)
                self.assertIn('ready', (out / 'child.log').read_text())
            finally:
                logs.stop()
            self.assertIsNotNone(logs.children[0].poll())

    def test_internal_gpu_is_not_new_external_gpu(self):
        before = empty(); before['pci']['0000:01:00.0'] = {
            'vendor': '0x10de', 'device': '0x2820', 'class': '0x030000'}
        out = c.classify(before, [copy.deepcopy(before)])
        self.assertEqual(out['new_display_endpoints'], [])
        self.assertEqual(out['status'], 'AttachmentNotEstablished')

    def test_pending_authorization_is_router_success_not_entry_failure(self):
        after = empty(); after['thunderbolt']['0-1'] = {'device': '0x1234', 'authorized': '0'}
        self.assertEqual(c.classify(empty(), [after])['status'], 'ExternalRouterPresentAuthorizationPending')

    def test_missing_authorization_is_not_zero(self):
        after = empty(); after['thunderbolt']['0-1'] = {'device': '0x1234', 'authorized': None}
        self.assertEqual(c.classify(empty(), [after])['status'], 'ExternalRouterPresentRequiresTopologyReview')

    def test_transient_router_is_retained_even_when_finally_absent(self):
        after = empty(); after['thunderbolt']['0-1'] = {'device': '0x1234'}
        out = c.classify(empty(), [after, empty()])
        self.assertTrue(out['external_router_observed'])
        self.assertEqual(out['status'], 'ExternalRouterObservedThenAbsent')

    def test_existing_other_router_does_not_establish_new_attachment(self):
        before = empty(); before['thunderbolt']['0-1'] = {'device': '0x1234'}
        self.assertFalse(c.classify(before, [copy.deepcopy(before)])['external_router_observed'])

    def test_root_domain_retimer_and_xdomain_do_not_become_external_router(self):
        after = empty(); after['thunderbolt'] = {'0-0': {'device': '0x1668'},
            'domain0': {}, '0-0:2.1': {'device': '0x8830'}, '0-1': {'device': None}}
        self.assertEqual(c.external_routers(after), {})

    def test_billboard_fallback_does_not_establish_usb4(self):
        after = empty(); after['usb']['1-1.4'] = {'idVendor': '041f', 'idProduct': 'd002'}
        self.assertEqual(c.classify(empty(), [after])['status'], 'DEG2FallbackObservedNoExternalRouter')

    def test_preconnected_history_is_explicit(self):
        before = empty(); before['thunderbolt']['0-1'] = {'device': '0x1234', 'authorized': '1'}
        self.assertTrue(c.classify(before, [copy.deepcopy(before)], True)['preconnected_without_fresh_attachment'])

    def test_missing_sysfs_values_remain_unknown(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d); p = root / 'bus/thunderbolt/devices/0-0'; p.mkdir(parents=True)
            (p / 'device').write_text('0x1668', encoding='ascii')
            s = c.snapshot(root)
            self.assertIsNone(s['thunderbolt']['0-0']['authorized'])

    def test_driver_exposed_partner_identity_is_retained_without_guessing(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d); p = root / 'class/typec/port0-partner/identity'; p.mkdir(parents=True)
            (p / 'id_header').write_text('0x12345678', encoding='ascii')
            s = c.snapshot(root)
            self.assertEqual(s['typec']['port0-partner']['identity']['id_header'], '0x12345678')
            self.assertIsNone(s['typec']['port0-partner']['identity']['product'])

    def test_exact_laptop_scope_accepts_asus_underscore_product(self):
        self.assertTrue(c.supported_product('ASUS TUF Gaming A15 FA507XI_FA507XI'))
        self.assertTrue(c.supported_product('Latitude 5540'))
        self.assertFalse(c.supported_product('FA507XIA'))
        self.assertFalse(c.supported_product('Latitude 5550'))

    def test_output_guard_rejects_internal_and_readonly_iso_filesystems(self):
        good = {'target': str(c.BOOT), 'source': '/dev/sda1', 'fstype': 'vfat'}
        script = (c.BOOT / 'usb4/capture_usb4.py').resolve()
        c.verify_media(good, '/sys/devices/pci/usb1/1-1/block/sda', c.MARKER, script)
        for mount, transport, marker, p in [
            (good, '/sys/devices/pci/ata1/block/sda', c.MARKER, script),
            ({**good, 'fstype': 'iso9660'}, '/sys/usb1/x', c.MARKER, script),
            ({**good, 'fstype': 'exfat'}, '/sys/usb1/x', c.MARKER, script),
            ({**good, 'source': '/dev/mapper/ventoy'}, '/sys/usb1/x', c.MARKER, script),
            ({**good, 'target': '/'}, '/sys/usb1/x', c.MARKER, script),
            (good, '/sys/usb1/x', 'wrong', script),
            (good, '/sys/usb1/x', c.MARKER, Path('/tmp/capture_usb4.py'))]:
            with self.subTest(mount=mount, transport=transport, marker=marker):
                with self.assertRaises(RuntimeError): c.verify_media(mount, transport, marker, p)


if __name__ == '__main__':
    unittest.main(verbosity=2)
