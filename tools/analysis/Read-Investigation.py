"""Read the curated USB4 evidence model. Files only; no hardware/network backend.

Pins identify exact JSON values, not the truth of the analyst's interpretation.
No repinning, capture, driver-loading or experiment execution is implemented.
"""
import argparse
import calendar
from datetime import datetime
from decimal import Decimal
import hashlib
import json
from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[2]
MODEL = ROOT / "evidence/investigation-model.json"


def value_hash(value):
    encoded = json.dumps(value, sort_keys=True, ensure_ascii=True,
                         separators=(",", ":"), allow_nan=False).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def pointer(document, path):
    if path == "":
        return document
    if not path.startswith("/"):
        raise ValueError("JSON pointer must start with /")
    value = document
    for raw in path[1:].split("/"):
        if re.search(r"~(?![01])", raw):
            raise ValueError("Invalid JSON pointer escape")
        token = raw.replace("~1", "/").replace("~0", "~")
        if isinstance(value, list):
            if not re.fullmatch(r"0|[1-9][0-9]*", token):
                raise ValueError("Invalid array index")
            value = value[int(token)]
        elif isinstance(value, dict):
            value = value[token]
        else:
            raise ValueError("Pointer traverses a scalar")
    return value


def timestamp(text, date=None):
    if date and re.fullmatch(r"\d{2}:\d{2}:\d{2}(?:\.\d+)?", text):
        text = date + "T" + text + "Z"
    match = re.fullmatch(r"(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(\.\d+)?Z", text)
    if not match:
        raise ValueError("Expected explicit UTC timestamp or dated time-of-day")
    seconds = calendar.timegm(datetime.strptime(match[1], "%Y-%m-%dT%H:%M:%S").timetuple())
    return Decimal(seconds) + Decimal(match[2] or "0")


def unique(rows, label):
    result = {row["id"]: row for row in rows}
    if len(result) != len(rows):
        raise ValueError("Duplicate " + label)
    return result


class Investigation:
    def __init__(self, root, model):
        self.root = Path(root).resolve()
        self.model = model
        if model["schema"] != 1:
            raise ValueError("Unsupported model schema")
        self.cases = unique(model["cases"], "case")
        self.stages = unique(model["stages"], "stage")
        self.sources = unique(model["sources"], "source")
        self.claims = unique(model["claims"], "claim")
        self.hypotheses = unique(model["hypotheses"], "hypothesis")
        unique(model["actions"], "action")
        self.values = {}
        documents = {}
        for sid, source in self.sources.items():
            path = (self.root / source["path"]).resolve()
            path.relative_to((self.root / "evidence").resolve())  # Rejects traversal/symlink escapes.
            if not source["path"].startswith("evidence/") or path.suffix != ".json":
                raise ValueError(sid + ": source must be a public evidence JSON file")
            self.require_cases(source["cases"])
            if path not in documents:
                documents[path] = json.loads(path.read_text(encoding="utf-8-sig"))
            value = pointer(documents[path], source["pointer"])
            if value_hash(value) != source["value_sha256"]:
                raise ValueError(sid + ": source value changed; review before updating its pin")
            self.values[sid] = value
        for claim in self.claims.values():
            self.require_cases(claim["cases"])
            if claim["stage"] not in self.stages:
                raise ValueError("Unknown claim stage")
            if claim["basis"] not in {"measured", "code_fact", "inference", "unknown"}:
                raise ValueError("Unknown claim basis")
            if not claim["sources"] or any(s not in self.sources for s in claim["sources"]):
                raise ValueError("Claim has missing evidence")
            kinds = {self.sources[s]["kind"] for s in claim["sources"]}
            if claim["basis"] == "measured" and not kinds.intersection({"capture", "intervention"}):
                raise ValueError("Measured claim cannot be supported only by code/emulation")
            if claim["basis"] == "code_fact" and "code" not in kinds:
                raise ValueError("Code claim requires an implementation source")
            if claim["basis"] == "inference" and not claim.get("reason"):
                raise ValueError("Inference requires an explicit reason")
            for sid in claim["sources"]:
                if self.sources[sid].get("superseded_by"):
                    raise ValueError("Active claim cites a superseded source: " + sid)
                if not set(self.sources[sid]["cases"]).issubset(claim["cases"]):
                    raise ValueError("Claim silently mixes evidence from another case")
            evidence_cases = {case for sid in claim["sources"] for case in self.sources[sid]["cases"]}
            if evidence_cases != set(claim["cases"]):
                raise ValueError("Claim extends beyond its cited cases")
        for source in self.sources.values():
            for sid in source.get("superseded_by", []):
                if sid not in self.sources:
                    raise ValueError("Missing replacement source")
        for stage in self.stages.values():
            if any(c not in self.claims for c in stage["claims"]):
                raise ValueError("Missing stage claim")
        for hyp in self.hypotheses.values():
            for field in ("support", "counterevidence"):
                if any(c not in self.claims for c in hyp[field]):
                    raise ValueError("Missing hypothesis evidence")
        for action in model["actions"]:
            if any(h not in self.hypotheses for h in action["distinguishes"]):
                raise ValueError("Unknown hypothesis in action")
            if action["status"] == "ready_for_hardware":
                needed = {"question", "positive_control", "outcome_decisions", "stop_condition", "recovery"}
                if not needed.issubset(action) or not action["distinguishes"]:
                    raise ValueError("Hardware action lacks a discriminating observation/recovery contract")
                text_fields = needed - {"outcome_decisions"}
                decisions = action["outcome_decisions"]
                if (any(not isinstance(action[k], str) or not action[k].strip() for k in text_fields)
                    or not isinstance(decisions, dict)
                    or not {"positive", "negative", "unreadable", "ambiguous"}.issubset(decisions)
                    or any(not isinstance(v, str) or not v.strip() for v in decisions.values())):
                    raise ValueError("Hardware action has an empty or incomplete outcome/recovery contract")
        for timeline in model["timelines"]:
            sid = timeline["source"]
            if sid not in self.sources or timeline["case"] not in self.sources[sid]["cases"]:
                raise ValueError("Timeline/case mismatch")
            self.timeline(timeline)  # Check timestamps/order before any rendering.
        architecture = model["architecture"]
        nodes = unique(architecture["nodes"], "architecture node")
        standards = unique(model["standards"], "standard")
        for node in nodes.values():
            if not re.fullmatch(r"[A-Z][A-Z0-9_]*", node["id"]):
                raise ValueError("Invalid architecture node ID")
        for edge in architecture["edges"]:
            if edge["from"] not in nodes or edge["to"] not in nodes:
                raise ValueError("Missing architecture endpoint")
            if edge["basis"] not in {"measured", "traced_code", "documented", "unknown"}:
                raise ValueError("Unknown architecture edge basis")
            if any(c not in self.claims for c in edge["claims"]):
                raise ValueError("Architecture edge has missing evidence")
            if any(s not in standards for s in edge.get("standards", [])):
                raise ValueError("Architecture edge has missing standard")
            if edge["basis"] != "unknown" and not (edge["claims"] or edge.get("standards")):
                raise ValueError("Known architecture edge has no evidence")
            bases = {self.claims[c]["basis"] for c in edge["claims"]}
            if edge["basis"] == "measured" and "measured" not in bases:
                raise ValueError("Measured architecture edge requires a measured claim")
            if edge["basis"] == "traced_code" and "code_fact" not in bases:
                raise ValueError("Traced architecture edge requires a code claim")
            if edge["basis"] == "documented" and not edge.get("standards"):
                raise ValueError("Documented architecture edge requires a standard reference")
        for intervention in architecture["interventions"]:
            if intervention["node"] not in nodes or any(c not in self.claims for c in intervention["claims"]):
                raise ValueError("Intervention is detached from architecture/evidence")

    def require_cases(self, cases):
        if not cases or any(c not in self.cases for c in cases):
            raise ValueError("Missing or unknown case")

    def timeline(self, spec):
        rows = self.values[spec["source"]]
        anchor = timestamp(rows[spec["anchor_index"]][spec["time_field"]], spec.get("date"))
        result, previous = [], None
        for index in spec["indexes"]:
            row = rows[index]
            utc = row[spec["time_field"]]
            now = timestamp(utc, spec.get("date"))
            if previous is not None and now < previous:
                raise ValueError("Timeline source order is not chronological")
            previous = now
            result.append((utc, now - anchor, row[spec["event_field"]]))
        return result

    def cite(self, ids):
        return ", ".join("[" + sid + "](../" + self.sources[sid]["path"] + ") `" +
                         self.sources[sid]["pointer"] + "`" for sid in ids)

    def show_claim(self, cid):
        claim = self.claims[cid]
        lines = [f"{cid} [{claim['basis']}] {claim['statement']}",
                 "Cases: " + ", ".join(claim["cases"]), "Limit: " + claim["limit"]]
        if claim.get("reason"):
            lines.append("Reason: " + claim["reason"])
        for sid in claim["sources"]:
            source = self.sources[sid]
            lines.append(f"{sid}: {source['path']} {source['pointer']}")
            lines.append(json.dumps(self.values[sid], ensure_ascii=True, sort_keys=True))
        return "\n".join(lines)

    def render(self):
        m = self.model
        out = ["# USB4 investigation: current evidence map", "",
               "Generated from `evidence/investigation-model.json` by `tools/analysis/Read-Investigation.py`. "
               "This report checks source pins and relationships; interpretations remain analyst judgments.", "",
               "**Current goal:** " + m["goal"]["current"], "",
               "**Working repair:** " + m["goal"]["eventual"], "",
               m["frontier"], "", "[Working method and experiment rules](investigation-plan.md).", ""]
        architecture = m["architecture"]
        out += ["## Architecture and control-flow branches", "", architecture["scope"], "",
                "Solid arrows identify documented, traced-code or measured relationships. Dashed arrows mark an unobserved or untraced relationship. Edge labels preserve that distinction.", "",
                "```mermaid", "flowchart TD"]
        for node in architecture["nodes"]:
            label = node["label"].replace('"', '&quot;')
            if node.get("decision"):
                out.append('    ' + node["id"] + '{"' + label + '"}')
            else:
                out.append(f'    {node["id"]}["{label}"]')
        for edge in architecture["edges"]:
            label = (edge["basis"] + ": " + edge["label"]).replace('"', '&quot;')
            arrow = "-.->" if edge["basis"] == "unknown" else "-->"
            out.append(f'    {edge["from"]} {arrow}|"{label}"| {edge["to"]}')
        out += ["```", "", "### Who owns each part", "",
                "| Node | Owner / responsibility | Input and output | Known limit |", "| --- | --- | --- | --- |"]
        for node in architecture["nodes"]:
            out.append(f"| {node['id']} | {node['owner']} | {node['interface']} | {node['limit']} |")
        out += ["", "### Branch evidence", "",
                "| From → to | Branch / message | Basis | Evidence |", "| --- | --- | --- | --- |"]
        for edge in architecture["edges"]:
            evidence = ", ".join(edge["claims"] + edge.get("standards", [])) or "Explicit gap"
            out.append(f"| {edge['from']} → {edge['to']} | {edge['label']} | {edge['basis']} | {evidence} |")
        out += ["", "### Candidate intervention locations", "",
                "| Location | What a change would affect | Evidence / current decision |", "| --- | --- | --- |"]
        for item in architecture["interventions"]:
            out.append(f"| {item['node']} | {item['effect']} | {item['decision']} ({', '.join(item['claims'])}) |")
        out += ["", "## Connection stages", "",
               "These stages can overlap. Windows report order is not a recovered sequence of wire messages.", "",
               "| Stage | ASUS failed pairing | Dell working control | Still missing |",
               "| --- | --- | --- | --- |"]
        for s in m["stages"]:
            out.append(f"| {s['name']} | {s['asus']} | {s['dell']} | {s['missing']} |")
        out += ["", "## What backs the map", "",
                "Measured = retained real observation; code_fact = implementation in a pinned image; "
                "inference = interpretation with a stated reason; unknown = identified missing observation.", ""]
        for claim in m["claims"]:
            out += [f"**{claim['id']} — {claim['basis']}:** {claim['statement']}", "",
                    "Scope: " + ", ".join(claim["cases"]) + ". " + claim["limit"], ""]
            if claim.get("reason"):
                out += ["Reason: " + claim["reason"], ""]
            out += [self.cite(claim["sources"]), ""]
        out += ["## Separate runs and observation limits", "",
                "| Case | Meaning | Important limit |", "| --- | --- | --- |"]
        for c in m["cases"]:
            out.append(f"| {c['id']} | {c['label']} | {c['limit']} |")
        out += ["", "## Software-report timelines", "", m["timeline_limit"], ""]
        for spec in m["timelines"]:
            out += ["### " + spec["case"], "", "Source: " + self.cite([spec["source"]]), "",
                    "| Recorded UTC | Seconds from first recorded attachment report | Report |",
                    "| --- | ---: | --- |"]
            for utc, elapsed, event in self.timeline(spec):
                out.append(f"| {utc} | {elapsed:.7f} | {event.replace('|', '/')} |")
            out.append("")
        out += ["## Explanations still requiring a distinguishing observation", "",
                "These explanations can occur together; this is not a probability ranking or an exhaustive fault list.", ""]
        for h in m["hypotheses"]:
            out += [f"**{h['id']} — {h['status']}:** {h['statement']}", "",
                    "Evidence to consider: " + (", ".join(h["support"]) or "No direct observation") +
                    ". Counterevidence: " + (", ".join(h["counterevidence"]) or "None directly discriminating") + ".", "",
                    "Needed: " + h["needed"], ""]
        out += ["## Next actions ranked by useful information and disruption", "",
                "| Action | Decision | Information gained | Owner disruption |", "| --- | --- | --- | --- |"]
        for a in m["actions"]:
            out.append(f"| {a['name']} | {a['status']} | {a['information']} | {a['cost']} |")
        out += ["", "**New live experiments queued: zero. New observer drivers approved by this plan: zero.**", "",
                "## Corrections and historical traps", ""]
        for item in m["corrections"]:
            out += ["- " + item["explanation"] + " Sources: " + self.cite(item["sources"]) + "."]
        out += ["", "## Documentation used for architecture", ""]
        for source in m["standards"]:
            out += ["- [" + source["title"] + "](" + source["url"] + "): " + source["scope"]]
        return "\n".join(out) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", type=Path, default=MODEL)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--check", action="store_true")
    group.add_argument("--write-report", action="store_true",
                       help="After validation, write docs/investigation-map.md as UTF-8")
    group.add_argument("--claim")
    group.add_argument("--stage")
    args = parser.parse_args()
    try:
        view = Investigation(ROOT, json.loads(args.model.read_text(encoding="utf-8-sig")))
        if args.check:
            print(f"Verified {len(view.sources)} pinned source values, {len(view.claims)} claims and {len(view.model['timelines'])} separate timelines. No hardware access.")
        elif args.write_report:
            (ROOT / "docs/investigation-map.md").write_text(view.render(), encoding="utf-8", newline="\n")
            print("Wrote docs/investigation-map.md; no hardware access.")
        elif args.claim:
            print(view.show_claim(args.claim))
        elif args.stage:
            for cid in view.stages[args.stage]["claims"]:
                print(view.show_claim(cid) + "\n")
        else:
            sys.stdout.buffer.write(view.render().encode("utf-8"))
    except (OSError, ValueError, KeyError, IndexError, TypeError) as exc:
        parser.exit(2, "Evidence check failed: " + str(exc) + "\n")


if __name__ == "__main__":
    main()
