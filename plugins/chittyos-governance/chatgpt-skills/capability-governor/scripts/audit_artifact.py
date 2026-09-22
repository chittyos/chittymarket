#!/usr/bin/env python3
"""Classify one capability artifact for the capability-governor skill.

Input: JSON object from --input or stdin.
Output: JSON object containing taxonomy_entry, decision_log, migration_queue_item.
No third-party dependencies.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import sys
from typing import Any, Dict, List, Tuple

JOB_KEYWORDS = {
    "verify": ["audit", "verify", "validate", "check", "proof", "contradiction", "fact", "citation"],
    "collect": ["collect", "ingest", "download", "stage", "extract", "preserve", "evidence"],
    "route": ["route", "dispatch", "gateway", "mcp", "adapter", "projection", "registry"],
    "generate": ["draft", "generate", "write", "create", "report", "document", "summary"],
    "govern": ["govern", "certify", "approve", "policy", "compliance", "canonical", "registration"],
    "operate": ["deploy", "monitor", "health", "cleanup", "sync", "machine", "service", "worker"],
    "resolve": ["dispute", "claim", "issue", "negotiation", "resolution", "insurance"],
    "remember": ["checkpoint", "handoff", "memory", "context", "resume", "state"],
}

ENTITY_KEYWORDS = {
    "person": ["person", "people", "individual", "agent", "owner", "executive", "user", "identity"],
    "location": ["location", "place", "address", "property", "venue", "court", "jurisdiction"],
    "thing": ["asset", "file", "document", "device", "machine", "artifact", "repo", "tool"],
    "event": ["event", "date", "timeline", "hearing", "meeting", "deadline", "timestamp"],
    "action": ["action", "approval", "removal", "filing", "execution", "signature", "dispatch"],
    "record": ["record", "ledger", "evidence", "audit", "log", "transaction", "valuation", "claim"],
}

LEGAL_TERMS = [
    "legal", "litigation", "court", "evidence", "custody", "forensic", "hash", "timestamp",
    "non-repudiation", "nonrepudiation", "claim", "filing", "motion", "affidavit", "dispute",
    "valuation", "removal", "governance", "sworn", "chain of custody", "bit-stream", "memory dump",
]

FOOTPRINT_RULES = [
    (6, "forensic-legal-grade", ["forensic", "custody", "bit-stream", "memory", "hash", "timestamp", "evidence"]),
    (5, "admin-system", ["admin", "secret", "auth", "token", "deploy", "wrangler", "config", "infra"]),
    (4, "filesystem-local", ["filesystem", "local", "path", "metadata", "file", "device", "machine"]),
    (3, "network-service", ["api", "mcp", "gateway", "webhook", "service", "worker", "network"]),
    (2, "write-capable", ["write", "update", "create", "delete", "modify", "send", "execute"]),
    (1, "read-only connector", ["read", "search", "fetch", "lookup", "connector", "drive", "github"]),
]

DISPOSITIONS = {
    "keep", "promote", "project", "merge", "gateway", "skill", "local-only", "legal-only", "retire", "hold"
}


def text_blob(artifact: Dict[str, Any]) -> str:
    parts: List[str] = []
    for value in artifact.values():
        if isinstance(value, str):
            parts.append(value)
        elif isinstance(value, list):
            parts.extend(str(x) for x in value)
        elif isinstance(value, dict):
            parts.extend(str(x) for x in value.values())
        else:
            parts.append(str(value))
    return " ".join(parts).lower()


def slugify(value: str) -> str:
    value = value.strip().lower()
    value = re.sub(r"[^a-z0-9]+", "-", value)
    return value.strip("-") or "unknown"


def classify_job(artifact: Dict[str, Any]) -> str:
    explicit = str(artifact.get("primary_job") or artifact.get("job_to_be_done") or "").strip().lower()
    if explicit in JOB_KEYWORDS:
        return explicit
    blob = text_blob(artifact)
    scores = {job: sum(1 for word in words if word in blob) for job, words in JOB_KEYWORDS.items()}
    best_job, best_score = max(scores.items(), key=lambda item: item[1])
    return best_job if best_score > 0 else "operate"


def classify_entities(artifact: Dict[str, Any]) -> List[str]:
    blob = text_blob(artifact)
    anchors = [entity for entity, words in ENTITY_KEYWORDS.items() if any(word in blob for word in words)]
    return anchors or ["record"]


def score_footprint(artifact: Dict[str, Any]) -> Tuple[int, str]:
    explicit = str(artifact.get("environmental_footprint") or artifact.get("footprint") or "").strip().lower()
    for score, label, _ in FOOTPRINT_RULES:
        if explicit == label or explicit == str(score):
            return score, label
    blob = text_blob(artifact)
    for score, label, words in FOOTPRINT_RULES:
        if any(word in blob for word in words):
            return score, label
    return 0, "context-only"


def score_evidentiary_risk(artifact: Dict[str, Any]) -> Tuple[int, str]:
    explicit = str(artifact.get("evidentiary_risk") or artifact.get("evidence_impact") or "").strip().lower()
    aliases = {
        "0": "none", "1": "low", "2": "medium", "3": "high", "4": "legal-grade",
        "none": "none", "low": "low", "medium": "medium", "high": "high", "legal": "legal-grade",
        "legal-grade": "legal-grade", "yes": "high", "no": "none", "unknown": "medium",
    }
    if explicit in aliases:
        label = aliases[explicit]
        return {"none": 0, "low": 1, "medium": 2, "high": 3, "legal-grade": 4}[label], label

    blob = text_blob(artifact)
    legal_hits = sum(1 for term in LEGAL_TERMS if term in blob)
    if legal_hits >= 2:
        return 4, "legal-grade"
    if legal_hits == 1:
        return 3, "high"
    if any(word in blob for word in ["business record", "decision", "valuation", "money", "compliance"]):
        return 2, "medium"
    return 0, "none"


def decide_disposition(artifact: Dict[str, Any], job: str, footprint_score: int, footprint: str, risk_score: int, risk: str) -> str:
    requested = str(artifact.get("requested_action") or artifact.get("requested_disposition") or "").strip().lower()
    if requested in DISPOSITIONS:
        return requested

    status = str(artifact.get("status") or "").lower()
    duplicate_values = artifact.get("known_duplicates") or artifact.get("duplicates") or []
    has_duplicates = bool(duplicate_values)
    platform_adapter_for = artifact.get("platform_adapter_for") or artifact.get("canonical_parent")
    needs_many_tools = bool(artifact.get("search_execute") or artifact.get("many_latent_tools"))

    blob = text_blob(artifact)
    if "obsolete" in blob or "unsafe" in blob or status in {"deprecated", "obsolete", "retired", "ownerless"}:
        return "retire"
    if has_duplicates:
        return "merge"
    if platform_adapter_for:
        return "project"
    if risk_score >= 3 or footprint_score >= 6:
        return "legal-only"
    if footprint_score >= 5:
        return "local-only"
    if footprint_score == 4:
        return "local-only"
    if needs_many_tools or "gateway" in blob or "mcp" in blob or footprint_score == 3:
        return "gateway"
    if "template" in blob or "runbook" in blob or "repeatable" in blob or "skill" in blob or footprint_score == 0:
        return "skill"
    if artifact.get("performs_new_job") is True or artifact.get("new_job") is True:
        return "promote"
    if artifact.get("canonical_id"):
        return "keep"
    return "hold"


def needs_migration(disposition: str) -> bool:
    return disposition in {"promote", "project", "merge", "gateway", "skill", "local-only", "legal-only", "retire"}


def migration_action(disposition: str) -> str:
    return {
        "promote": "document",
        "project": "reroute",
        "merge": "merge",
        "gateway": "reroute",
        "skill": "document",
        "local-only": "restrict",
        "legal-only": "restrict",
        "retire": "retire",
        "keep": "document",
        "hold": "document",
    }.get(disposition, "document")


def audit(artifact: Dict[str, Any], today: dt.date | None = None) -> Dict[str, Any]:
    today = today or dt.date.today()
    name = str(artifact.get("capability_name") or artifact.get("name") or artifact.get("display_name") or "unknown")
    slug = slugify(name)
    job = classify_job(artifact)
    entities = classify_entities(artifact)
    footprint_score, footprint = score_footprint(artifact)
    risk_score, risk = score_evidentiary_risk(artifact)
    disposition = decide_disposition(artifact, job, footprint_score, footprint, risk_score, risk)
    canonical_id = str(artifact.get("canonical_id") or f"capability.{slug}")
    source_links = artifact.get("source_links") or artifact.get("source_link") or artifact.get("sources") or []
    if isinstance(source_links, str):
        source_links = [source_links]
    duplicates = artifact.get("known_duplicates") or artifact.get("duplicates") or []
    if isinstance(duplicates, str):
        duplicates = [duplicates]

    allowed_projection = {
        "skill": ["skill"],
        "gateway": ["mcp-gateway", "search-execute"],
        "local-only": ["local-cli"],
        "legal-only": ["legal-space", "evidence-pipeline"],
        "project": [str(artifact.get("current_runtime") or "platform-projection")],
    }.get(disposition, [str(artifact.get("current_runtime") or "registry")])

    missing_evidence = []
    if not source_links:
        missing_evidence.append("source_links")
    if disposition in {"legal-only", "retire", "merge", "project"} and not duplicates and disposition == "merge":
        missing_evidence.append("duplicates")
    if disposition == "legal-only":
        for field in ["hash_policy", "timestamp_policy", "custody_policy"]:
            if not artifact.get(field):
                missing_evidence.append(field)

    decision_id = f"dec_{today.strftime('%Y%m%d')}_{slug}"
    migration_id = f"mig_{today.strftime('%Y%m%d')}_{slug}"

    taxonomy_entry = {
        "canonical_id": canonical_id,
        "display_name": name,
        "job_to_be_done": job,
        "entity_anchors": entities,
        "source_of_truth": source_links[0] if source_links else "missing",
        "allowed_projections": allowed_projection,
        "restricted_projections": ["public-gateway"] if disposition in {"local-only", "legal-only"} else [],
        "owner": str(artifact.get("owner") or "unknown"),
        "status": "hold" if disposition == "hold" else "active",
    }

    decision_log = {
        "decision_id": decision_id,
        "date": today.isoformat(),
        "capability_name": name,
        "canonical_id": canonical_id,
        "source_links": source_links,
        "current_state": str(artifact.get("current_state") or artifact.get("status") or "unknown"),
        "decision": disposition,
        "job_to_be_done": job,
        "environmental_footprint": footprint,
        "environmental_footprint_score": footprint_score,
        "evidentiary_risk": risk,
        "evidentiary_risk_score": risk_score,
        "rationale": build_rationale(disposition, job, footprint, risk),
        "duplicates_found": duplicates,
        "migration_required": needs_migration(disposition),
        "migration_owner": str(artifact.get("migration_owner") or artifact.get("owner") or "unknown"),
        "next_action": next_action(disposition, missing_evidence),
        "review_date": str(artifact.get("review_date") or (today + dt.timedelta(days=30)).isoformat()),
    }

    migration_queue_item = {
        "migration_item": migration_id,
        "from_artifact": name,
        "to_canonical_capability": canonical_id,
        "action": migration_action(disposition),
        "blocking_dependencies": missing_evidence,
        "risk_level": risk,
        "owner": decision_log["migration_owner"],
        "status": "blocked" if missing_evidence else "backlog",
        "completion_evidence": [],
    }

    return {
        "taxonomy_entry": taxonomy_entry,
        "decision_log": decision_log,
        "migration_queue_item": migration_queue_item,
        "missing_evidence": missing_evidence,
    }


def build_rationale(disposition: str, job: str, footprint: str, risk: str) -> str:
    return (
        f"Disposition '{disposition}' selected because the artifact's primary job is '{job}', "
        f"its environmental footprint is '{footprint}', and its evidentiary risk is '{risk}'."
    )


def next_action(disposition: str, missing: List[str]) -> str:
    if missing:
        return "resolve missing evidence before activation"
    return {
        "keep": "record canonical status and schedule normal review",
        "promote": "create canonical registry entry after approval",
        "project": "bind projection to canonical capability",
        "merge": "merge duplicate into canonical capability and update references",
        "gateway": "add route to search-and-execute gateway with authorization controls",
        "skill": "package repeatable workflow as skill and validate",
        "local-only": "restrict to local runtime and document privilege boundary",
        "legal-only": "route through legal/evidence workflow with non-repudiation controls",
        "retire": "publish retirement record with replacement and rollback path",
        "hold": "collect source links and canonical identity evidence",
    }[disposition]


def load_json(path: str | None) -> Dict[str, Any]:
    raw = sys.stdin.read() if not path or path == "-" else open(path, "r", encoding="utf-8").read()
    data = json.loads(raw)
    if not isinstance(data, dict):
        raise SystemExit("input must be a JSON object")
    return data


def main() -> int:
    parser = argparse.ArgumentParser(description="Audit one capability artifact.")
    parser.add_argument("--input", "-i", help="Path to artifact JSON. Use '-' or omit for stdin.")
    parser.add_argument("--pretty", action="store_true", help="Pretty-print JSON output.")
    args = parser.parse_args()
    result = audit(load_json(args.input))
    print(json.dumps(result, indent=2 if args.pretty else None, sort_keys=args.pretty))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
