"""Bounded offline cache recovery; synthetic bytes do not qualify hardware."""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("acpi_recovery", ROOT / "tools/analysis/Recover-USB4AcpiTables.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class RecoveryTests(unittest.TestCase):
    cache = "0: kd> !acpicache\n  SSDT @(ffff800000001000) Rev: 0x2 Len: 0x000024 TableID: TEST\n0: kd> q\n"

    def table(self):
        data = bytearray(36)
        data[:4] = b"SSDT"
        data[4:8] = (36).to_bytes(4, "little")
        data[8] = 2
        data[9] = (-sum(data)) % 256
        return bytes(data)

    def readout(self, data=None):
        data = self.table() if data is None else data
        lines = ["0: kd> db ffff800000001000 L24"]
        for offset in range(0, len(data), 16):
            address = f"{0xffff800000001000 + offset:016x}"
            encoded = " ".join(f"{b:02x}" for b in data[offset:offset + 16])
            lines.append(f"{address[:8]}`{address[8:]}  {encoded:<48}  ....")
        return "\n".join(lines + ["0: kd> q", ""])

    def test_valid_roundtrip(self):
        tables = module.inventory(self.cache)
        self.assertEqual(module.plan(tables), "db ffff800000001000 L24\nq\n")
        result = module.extract(tables, self.readout())
        self.assertEqual(result[0][1], self.table())
        self.assertTrue(result[0][0]["checksum_valid"])

    def test_bad_inventory(self):
        for text in ("", self.cache.replace("ffff8000", "00008000"), self.cache.replace("000024", "100001"), self.cache.replace("TEST", "../bad")):
            with self.subTest(text=text), self.assertRaises(ValueError):
                module.inventory(text)

    def test_fail_closed_readout(self):
        original = self.readout()
        cases = [original.replace("53 53", "?? 53"), original.replace("L24", "L25"), original.replace("00001010", "00001011"), original.rsplit("ffff8000`00001020", 1)[0], original.replace("53 53", "54 53")]
        tables = module.inventory(self.cache)
        for text in cases:
            with self.subTest(text=text), self.assertRaises(ValueError):
                module.extract(tables, text)

    def test_header_and_checksum(self):
        for offset in (4, 9):
            changed = bytearray(self.table())
            changed[offset] ^= 1
            with self.subTest(offset=offset), self.assertRaises(ValueError):
                module.extract(module.inventory(self.cache), self.readout(changed))


if __name__ == "__main__":
    unittest.main()
