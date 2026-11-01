"""One offline refresh: validate sources, solve the declared milestone table, write reports.

No hardware, network, scheduler or driver backend. Existing-source changes fail
validation until reviewed; this runner never repins evidence automatically.
"""
import argparse
import importlib.util
import json
from pathlib import Path
import sys


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, HERE / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def prepare(root=ROOT):
    reader = load("investigation_reader", "Read-Investigation.py")
    truth = load("investigation_truth", "Truth-Investigation.py")
    model = json.loads((root / "evidence/investigation-model.json").read_text(encoding="utf-8-sig"))
    logic = json.loads((root / "evidence/investigation-logic.json").read_text(encoding="utf-8-sig"))
    view = reader.Investigation(root, model)
    results = truth.solve(logic, view, reader.pointer)
    # Compute everything before replacing any existing report.
    outputs = {
        "docs/investigation-map.md": view.render(),
        "docs/investigation-truth-table.md": truth.render(logic, results),
        "evidence/investigation-logic-results.json": json.dumps(results, ensure_ascii=False, indent=2) + "\n"
    }
    return outputs, results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Verify existing outputs match; do not write")
    args = parser.parse_args()
    try:
        outputs, results = prepare()
        changed = []
        for rel, text in outputs.items():
            path = ROOT / rel
            encoded = text.encode("utf-8")
            if not path.is_file() or path.read_bytes() != encoded:
                changed.append(rel)
        if args.check and changed:
            parser.exit(2, "Generated outputs require refresh: " + ", ".join(changed) + "\n")
        if not args.check:
            for rel in changed:
                path = ROOT / rel
                # Same-directory temporary file; an interrupted write cannot truncate the old report.
                temporary = path.with_name(path.name + ".refresh-tmp")
                if temporary.exists():
                    raise ValueError("An interrupted refresh needs review: " + str(temporary))
                try:
                    with temporary.open("xb") as f:
                        f.write(outputs[rel].encode("utf-8"))
                    temporary.replace(path)
                finally:
                    if temporary.exists():
                        temporary.unlink()
        for case in results["cases"]:
            print(case["case"] + ": " + ", ".join(case["frontier_counts"]) +
                  ("" if case["consistent"] else "SOURCE/MODEL CONFLICT"))
        print(("Verified" if args.check else "Refreshed") + " offline reports; " +
              str(len(changed)) + " changed outputs. No device actions.")
        if any(not case["consistent"] for case in results["cases"]):
            return 2
        return 0
    except (OSError, ValueError, KeyError, IndexError, TypeError) as exc:
        parser.exit(2, "Offline investigation stopped: " + str(exc) + "\n")


if __name__ == "__main__":
    sys.exit(main())
