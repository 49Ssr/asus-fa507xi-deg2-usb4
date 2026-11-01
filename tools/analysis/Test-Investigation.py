"""Evidence-boundary checks for the file-only USB4 investigation reader."""
import copy
from decimal import Decimal
import importlib.util
import json
from pathlib import Path
import unittest


HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("investigation", HERE / "Read-Investigation.py")
reader = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reader)


class EvidenceBoundaries(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.model = json.loads(reader.MODEL.read_text(encoding="utf-8"))

    def changed(self):
        return copy.deepcopy(self.model)

    def test_real_sources_and_committed_report_match(self):
        view = reader.Investigation(reader.ROOT, self.model)
        expected = (reader.ROOT / "docs/investigation-map.md").read_text(encoding="utf-8")
        self.assertEqual(view.render(), expected)
        self.assertEqual(view.render().count("## Connection stages"), 1)
        self.assertIn("NO_ROLE_CMD", view.render())
        self.assertIn("EC_SKIPPED", view.render())

    def test_changed_source_pin_stops_view(self):
        model = self.changed()
        model["sources"][0]["value_sha256"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "source value changed"):
            reader.Investigation(reader.ROOT, model)

    def test_missing_value_does_not_become_zero(self):
        model = self.changed()
        model["sources"][0]["pointer"] = "/missing-field"
        with self.assertRaises(KeyError):
            reader.Investigation(reader.ROOT, model)
        self.assertEqual(len({reader.value_hash(v) for v in (0, False, None)}), 3)

    def test_public_path_traversal_is_rejected(self):
        model = self.changed()
        model["sources"][0]["path"] = "evidence/../local/private.json"
        with self.assertRaises(ValueError):
            reader.Investigation(reader.ROOT, model)

    def test_code_cannot_be_presented_as_measured(self):
        model = self.changed()
        next(c for c in model["claims"] if c["id"] == "C07")["basis"] = "measured"
        with self.assertRaisesRegex(ValueError, "only by code/emulation"):
            reader.Investigation(reader.ROOT, model)

    def test_superseded_count_cannot_support_active_claim(self):
        model = self.changed()
        claim = next(c for c in model["claims"] if c["id"] == "C06")
        claim["basis"] = "unknown"
        claim["sources"] = ["OLD-GAPS"]
        with self.assertRaisesRegex(ValueError, "superseded"):
            reader.Investigation(reader.ROOT, model)

    def test_case_mismatch_is_rejected(self):
        model = self.changed()
        next(c for c in model["claims"] if c["id"] == "C01")["cases"] = ["ASUS-DEEP"]
        with self.assertRaisesRegex(ValueError, "another case"):
            reader.Investigation(reader.ROOT, model)
        model = self.changed()
        model["timelines"][1]["source"] = "ASUS-TIMELINE"
        with self.assertRaisesRegex(ValueError, "Timeline/case mismatch"):
            reader.Investigation(reader.ROOT, model)
        model = self.changed()
        next(c for c in model["claims"] if c["id"] == "C01")["cases"].append("ASUS-DEEP")
        with self.assertRaisesRegex(ValueError, "beyond its cited cases"):
            reader.Investigation(reader.ROOT, model)

    def test_timestamps_preserve_sub_microsecond_order(self):
        before = reader.timestamp("2026-11-01T00:52:17.0830516Z")
        after = reader.timestamp("2026-11-01T00:52:17.0830517Z")
        self.assertEqual(after - before, Decimal("0.0000001"))
        self.assertEqual(reader.timestamp("21:25:17.386", "2026-10-31"),
                         reader.timestamp("2026-10-31T21:25:17.386Z"))
        model = self.changed()
        model["timelines"][0]["indexes"] = [1, 0]
        with self.assertRaisesRegex(ValueError, "not chronological"):
            reader.Investigation(reader.ROOT, model)

    def test_hardware_ready_requires_an_observation_and_recovery_contract(self):
        model = self.changed()
        next(a for a in model["actions"] if a["id"] == "A-FLAG")["status"] = "ready_for_hardware"
        with self.assertRaisesRegex(ValueError, "contract"):
            reader.Investigation(reader.ROOT, model)
        action = next(a for a in model["actions"] if a["id"] == "A-FLAG")
        action.update(question="Which branch?", positive_control="", outcome_decisions={}, stop_condition="", recovery="")
        with self.assertRaisesRegex(ValueError, "empty or incomplete"):
            reader.Investigation(reader.ROOT, model)

    def test_diagram_edge_cannot_promote_a_gap_to_measurement(self):
        model = self.changed()
        next(e for e in model["architecture"]["edges"] if e["from"] == "PD" and e["to"] == "LINK")["basis"] = "measured"
        with self.assertRaisesRegex(ValueError, "requires a measured claim"):
            reader.Investigation(reader.ROOT, model)

    def test_pointer_escapes_and_invalid_array_indexes(self):
        self.assertIsNone(reader.pointer({"a/b": {"~key": [None]}}, "/a~1b/~0key/0"))
        with self.assertRaises(ValueError):
            reader.pointer({"a": [0, 1]}, "/a/01")
        with self.assertRaises(ValueError):
            reader.pointer({}, "/bad~2escape")


if __name__ == "__main__":
    unittest.main(verbosity=2)
