"""Offline tests: captured comparison and malformed-descriptor boundaries."""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("billboard", ROOT / "tools/analysis/Decode-USB4Billboard.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class BillboardTests(unittest.TestCase):
    def fixture(self, host="asus"):
        return bytes.fromhex((ROOT / f"evidence/fixtures/deg2-{host}-bos.hex").read_text())

    def test_recorded_comparison(self):
        self.assertEqual([i for i, (a, d) in enumerate(zip(self.fixture(), self.fixture("dell"))) if a != d], [40])
        asus, dell = (module.decode_bos(self.fixture(host)) for host in ("asus", "dell"))
        self.assertEqual([m["configuration_code"] for m in asus["modes"]], [1, 1, 3])
        self.assertEqual([m["configuration_code"] for m in dell["modes"]], [3, 1, 1])
        self.assertEqual(asus["modes"][0]["reported_vdo"], "0x2087e000")
        self.assertEqual(asus["modes"][0]["reported_eudo"], dell["modes"][0]["reported_eudo"])
        self.assertFalse(asus["additional_failure"]["insufficient_power_reported"])
        self.assertIsNone(dell["additional_failure"]["insufficient_power_reported"])

    def test_reject_malformed_input(self):
        original = self.fixture()
        cases = [original[:-1], original + b"\0", b""]
        # First capability length, count, preferred index, mode count, reserved
        # failure bits, AUM index, duplicate AUM index, unsupported revision.
        for offset, value in ((5, 0), (4, 5), (37, 3), (36, 53), (74, 4), (91, 3), (99, 0), (72, 0)):
            changed = bytearray(original)
            changed[offset] = value
            cases.append(bytes(changed))
        for data in cases:
            with self.subTest(data=data.hex()):
                with self.assertRaises(ValueError):
                    module.decode_bos(data)

    def test_missing_extension_is_not_zero(self):
        data = bytearray(self.fixture()[:88])
        data[2:4] = len(data).to_bytes(2, "little")
        data[4] = 3
        result = module.decode_bos(data)
        self.assertNotIn("reported_vdo", result["modes"][0])

    def test_other_states_and_no_preference(self):
        for code, name in ((0, "UnspecifiedError"), (2, "AttemptedUnsuccessfulNotEntered")):
            data = bytearray(self.fixture())
            data[40] = (data[40] & ~3) | code
            self.assertEqual(module.decode_bos(data)["modes"][0]["configuration"], name)
        data[37] = 255
        data[74] = 3
        result = module.decode_bos(data)
        self.assertFalse(result["additional_failure"]["valid_for_preferred_mode"])
        self.assertIsNone(result["additional_failure"]["no_pd_communication_reported"])


if __name__ == "__main__":
    unittest.main()
