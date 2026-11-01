"""Enumerate a small declared milestone model; this does not emulate USB hardware.

True/false facts require an explicit source rule. Unknown stays unconstrained.
Implications are reviewable model assumptions, never newly measured events.
"""
from collections import Counter
import hashlib
from itertools import product
import json


def fingerprint(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, ensure_ascii=True,
                                    separators=(",", ":"), allow_nan=False).encode()).hexdigest()


def strict_equal(a, b):
    return type(a) is type(b) and a == b


def evaluate(term, view):
    actual = view.values[term["source"]]
    actual = view_pointer(actual, term.get("pointer", ""))
    op = term["op"]
    if op == "boolean":
        if not isinstance(actual, bool):
            raise ValueError("Expected a boolean source value")
        return actual
    if op == "positive_count":
        if type(actual) is not int or actual < 0:
            raise ValueError("Expected a nonnegative integer count")
        return actual > 0
    if op == "equals":
        return strict_equal(actual, term["value"])
    if op == "same_as":
        other = view_pointer(view.values[term["other_source"]], term.get("other_pointer", ""))
        return strict_equal(actual, other)
    raise ValueError("Unknown source-rule operation: " + str(op))


def view_pointer(value, path):
    # The shared reader supplies its strict JSON-pointer implementation.
    return POINTER(value, path)


POINTER = None


def facts_for(case, variables, view):
    if case["id"] not in view.cases or set(case["facts"]) != set(variables):
        raise ValueError("Every variable must be explicitly assigned or marked unknown in a known case")
    facts, provenance = {}, {}
    for key, spec in case["facts"].items():
        if spec.get("value") == "unknown":
            if not spec.get("reason"):
                raise ValueError("Unknown fact requires a stated gap")
            facts[key] = None
            provenance[key] = spec["reason"]
            continue
        terms = spec["terms"]
        if not terms:
            raise ValueError("A concrete fact requires source evidence")
        for term in terms:
            ids = [term["source"]] + ([term["other_source"]] if "other_source" in term else [])
            for sid in ids:
                if sid not in view.sources or case["id"] not in view.sources[sid]["cases"]:
                    raise ValueError("Source rule/case mismatch")
                if view.sources[sid].get("superseded_by"):
                    raise ValueError("Source rule cites superseded evidence")
        passed = all(evaluate(t, view) for t in terms)
        value = spec["when_true"] if passed else spec["when_false"]
        if value not in {"true", "false", "unknown"}:
            raise ValueError("Invalid three-valued fact")
        facts[key] = {"true": True, "false": False, "unknown": None}[value]
        provenance[key] = spec["reason"]
    return facts, provenance


def valid(world, rules):
    return all(not world[r["if"]] or world[r["then"]] for r in rules)


def frontier(world):
    if world["F"]:
        return "ROUTER_PRESENT"
    if not world["E"]:
        return "ENTRY_NOT_ESTABLISHED"
    if not world["L"]:
        return "LINK_NOT_ESTABLISHED"
    if not world["R"]:
        return "ROUTER_NOT_ESTABLISHED"
    return "ROUTER_NOT_RETAINED"


def enumerate_worlds(variables, rules, facts):
    worlds = []
    for bits in product((False, True), repeat=len(variables)):
        world = dict(zip(variables, bits))
        if valid(world, rules) and all(v is None or world[k] == v for k, v in facts.items()):
            worlds.append(world)
    return worlds


def solve(model, view, pointer):
    global POINTER
    POINTER = pointer
    if model["schema"] != 1:
        raise ValueError("Unsupported logic schema")
    variables = [v["id"] for v in model["variables"]]
    if len(variables) != len(set(variables)) or set(variables) != {"E", "L", "R", "F", "X", "C"}:
        raise ValueError("This bounded model requires exactly E,L,R,F,X,C")
    for rule in model["implications"]:
        if rule["if"] not in variables or rule["then"] not in variables or not rule["assumption"]:
            raise ValueError("Invalid implication")
    results = []
    case_ids = [c["id"] for c in model["cases"]]
    if len(case_ids) != len(set(case_ids)):
        raise ValueError("Duplicate logic case")
    for case in model["cases"]:
        facts, why = facts_for(case, variables, view)
        worlds = enumerate_worlds(variables, model["implications"], facts)
        implied = {k: next(iter(values)) if len(values) == 1 else None
                   for k in variables for values in [{w[k] for w in worlds}]}
        groups = Counter(frontier(w) for w in worlds)
        observations = []
        for key in variables:
            if facts[key] is not None or implied[key] is not None or not worlds:
                continue
            split = {}
            for value in (False, True):
                subset = [w for w in worlds if w[key] is value]
                split[str(value).lower()] = dict(worlds=len(subset), frontiers=sorted({frontier(w) for w in subset}))
            observations.append(dict(variable=key, outcomes=split,
                                     worst_remaining_frontiers=max(len(x["frontiers"]) for x in split.values()),
                                     caveat=next(v for v in model["variables"] if v["id"] == key)["observation_limit"]))
        observations.sort(key=lambda x: (x["worst_remaining_frontiers"], x["variable"]))
        results.append(dict(case=case["id"], observed_facts=facts, fact_provenance=why,
                            model_implied_not_measured=implied, consistent=bool(worlds),
                            abstract_worlds=worlds, frontier_counts=dict(sorted(groups.items())),
                            ideal_observations=observations,
                            action="Review source alignment/model if inconsistent; otherwise qualify a discriminating observer. No automatic hardware action."))
    return dict(schema=1, logic_model_sha256=fingerprint(model), evidence_model_sha256=fingerprint(view.model),
                scope=model["scope"], probabilities_assigned=False, physical_simulation=False,
                cases=results)


def tfu(value):
    return "?" if value is None else ("T" if value else "F")


def render(model, results):
    out = ["# USB4 constraint table and next observations", "",
           "Generated by the offline investigation runner. T = true, F = false, ? = unknown. "
           "This is an abstract milestone model, not a USB port or controller emulator.", "",
           model["scope"], "", "[Architecture/control flow](investigation-map.md) · [Working plan](investigation-plan.md)", "",
           "## Variables and observation limits", "",
           "| Variable | Meaning | What a real observation must establish |", "| --- | --- | --- |"]
    for v in model["variables"]:
        out.append(f"| {v['id']} | {v['meaning']} | {v['observation_limit']} |")
    out += ["", "## Declared assumptions", ""]
    for r in model["implications"]:
        out += [f"- `{r['if']} ⇒ {r['then']}`: {r['assumption']}"]
    out += ["", "C is deliberately independent of the USB4 milestone chain. "
            "X is a cross-cutting exit/history event: it is not a mutually exclusive failure stage, and later re-entry is not forbidden.", "",
            "The chain describes successful domain-mode/link/router milestones, including a compatible mode where applicable. "
            "It does not equate an inferred milestone with a recorded native Enter_USB packet. "
            "No probabilities are assigned to enumerated combinations.", "", "## Cases", ""]
    variables = [v["id"] for v in model["variables"]]
    for case in results["cases"]:
        out += ["### " + case["case"], "",
                "**Measured/source-derived facts:** " + ", ".join(f"{k}={tfu(case['observed_facts'][k])}" for k in variables) + ".", "",
                "**Implied by this model, not new measurements:** " + ", ".join(f"{k}={tfu(case['model_implied_not_measured'][k])}" for k in variables) + ".", ""]
        if not case["consistent"]:
            out += ["**No consistent combination. Check case/clock alignment, source meaning and model assumptions. This is not proof of impossible hardware.**", ""]
            continue
        out += ["| " + " | ".join(variables) + " | Unfinished milestone |",
                "| " + " | ".join(["---"] * (len(variables) + 1)) + " |"]
        for world in case["abstract_worlds"]:
            out.append("| " + " | ".join(tfu(world[k]) for k in variables) + " | " + frontier(world) + " |")
        out += ["", "Counts represent logical combinations, not likelihood, prevalence or repeated hardware tests.", "",
                "| Ideal missing observation | Remaining stages if false | Remaining stages if true | Worst remaining stage count |",
                "| --- | --- | --- | ---: |"]
        for obs in case["ideal_observations"]:
            out.append(f"| {obs['variable']} | {', '.join(obs['outcomes']['false']['frontiers'])} | {', '.join(obs['outcomes']['true']['frontiers'])} | {obs['worst_remaining_frontiers']} |")
        out += ["", "These are ideal qualified results. A negative current-state sample cannot establish that a transient milestone never occurred. "
                "Unreadable, unqualified or coverage-limited values leave the fact unknown.", "",
                "Source rules:", ""]
        for key, why in case["fact_provenance"].items():
            out += [f"- {key}: {why}"]
        out.append("")
    out += ["## Automation boundary", "",
            "The runner validates pinned evidence, applies explicit source rules, enumerates consistent milestone combinations, "
            "ranks ideal discriminating observations and refreshes the reports. It cannot supply an unrecorded PD exchange or electrical measurement. "
            "A Device Manager disable/enable, a synthesized PnP notification and a physical cable insertion are different interventions. "
            "No hotplug simulation, reset, driver load or capture session is part of this pipeline.", ""]
    return "\n".join(out)
