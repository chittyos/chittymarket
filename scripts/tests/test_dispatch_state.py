#!/usr/bin/env python3
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STATE_PATH = ROOT / "plugins/chittyagent-dispatch/scripts/lib/state.py"
SPEC = importlib.util.spec_from_file_location("dispatch_state", STATE_PATH)
state = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(state)


class DispatchStateTests(unittest.TestCase):
    def test_dispatch_does_not_claim_verification(self):
        payload = state.dispatch_state(
            "abc123",
            {"codex": "deadbeef"},
            "2026-09-22T12:00:00Z",
        )
        self.assertEqual(payload["dispatch"]["status"], "projected")
        self.assertEqual(payload["verification"]["projection"]["status"], "pending")
        self.assertEqual(payload["verification"]["runtime"]["status"], "not_run")

    def test_projection_pass_keeps_runtime_not_run(self):
        with tempfile.TemporaryDirectory() as td:
            state_dir = Path(td)
            path = state_dir / "skills" / "foo.json"
            state.write_json(
                path,
                state.dispatch_state(
                    "abc123",
                    {"codex": "deadbeef"},
                    "2026-09-22T12:00:00Z",
                ),
            )
            report = {
                "summary": {"total_findings": 0},
                "findings": [],
            }
            rc = state.record_projection_verification(
                state_dir,
                report,
                "2026-09-22T12:01:00Z",
                ["foo"],
            )
            self.assertEqual(rc, 0)
            saved = json.loads(path.read_text())
            self.assertEqual(saved["verification"]["projection"]["status"], "passed")
            self.assertEqual(saved["verification"]["runtime"]["status"], "not_run")

    def test_failed_projection_is_persisted(self):
        with tempfile.TemporaryDirectory() as td:
            state_dir = Path(td)
            path = state_dir / "skills" / "foo.json"
            state.write_json(
                path,
                state.dispatch_state(
                    "abc123",
                    {"codex": "deadbeef"},
                    "2026-09-22T12:00:00Z",
                ),
            )
            report = {
                "summary": {"total_findings": 1},
                "findings": [
                    {
                        "cls": "PROJ_DRIFT",
                        "canonical": "skills/foo",
                        "runtime": "codex",
                        "detail": "projection edited directly",
                    }
                ],
            }
            rc = state.record_projection_verification(
                state_dir,
                report,
                "2026-09-22T12:01:00Z",
                ["foo"],
            )
            self.assertEqual(rc, 1)
            saved = json.loads(path.read_text())
            self.assertEqual(saved["dispatch"]["status"], "projected")
            self.assertEqual(saved["verification"]["projection"]["status"], "failed")
            self.assertEqual(saved["verification"]["runtime"]["status"], "not_run")
            global_state = json.loads((state_dir / "_verification.json").read_text())
            self.assertEqual(global_state["projection"]["status"], "failed")

    def test_legacy_state_is_normalized_without_false_verification(self):
        legacy = {
            "canonical_sha": "abc123",
            "targets": {"codex": "deadbeef"},
        }
        normalized = state.normalize_state(legacy)
        self.assertEqual(normalized["dispatch"]["status"], "projected")
        self.assertEqual(normalized["verification"]["projection"]["status"], "pending")
        self.assertEqual(normalized["verification"]["runtime"]["status"], "not_run")


if __name__ == "__main__":
    unittest.main()
