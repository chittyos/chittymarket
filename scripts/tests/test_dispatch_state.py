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

    def test_unchanged_dispatch_is_true_noop_and_preserves_verification(self):
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "skills" / "foo.json"
            payload = state.dispatch_state(
                "abc123",
                {"codex": "deadbeef"},
                "2026-09-22T12:00:00Z",
            )
            payload["verification"]["projection"] = {
                "status": "passed",
                "verified_at": "2026-09-22T12:01:00Z",
                "method": "dispatch-audit",
                "findings": [],
            }
            state.write_json(path, payload)
            before = path.read_text()
            rc = state.record_dispatch(
                path,
                "abc123",
                '{"codex":"deadbeef"}',
                "2026-09-22T13:00:00Z",
            )
            self.assertEqual(rc, 0)
            self.assertEqual(path.read_text(), before)
            saved = json.loads(path.read_text())
            self.assertEqual(saved["dispatch"]["projected_at"], "2026-09-22T12:00:00Z")
            self.assertEqual(saved["verification"]["projection"]["status"], "passed")

    def test_changed_dispatch_invalidates_global_runtime_receipt_in_scope(self):
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
            state.write_json(
                state_dir / "_verification.json",
                {
                    "scope": ["all"],
                    "projection": {
                        "status": "passed",
                        "verified_at": "2026-09-22T12:01:00Z",
                    },
                    "runtime": {
                        "status": "passed",
                        "verified_at": "2026-09-22T12:02:00Z",
                        "method": "native-codex",
                        "targets": {"codex": "deadbeef"},
                    },
                },
            )
            rc = state.record_dispatch(
                path,
                "def456",
                '{"codex":"feedface"}',
                "2026-09-22T13:00:00Z",
            )
            self.assertEqual(rc, 0)
            global_state = json.loads((state_dir / "_verification.json").read_text())
            self.assertEqual(global_state["projection"]["status"], "pending")
            self.assertEqual(global_state["runtime"]["status"], "not_run")
            self.assertEqual(global_state["runtime"]["invalidated_by"], "foo")

    def test_changed_dispatch_preserves_unrelated_scoped_global_receipt(self):
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
            receipt = {
                "scope": ["bar"],
                "projection": {
                    "status": "passed",
                    "verified_at": "2026-09-22T12:01:00Z",
                },
                "runtime": {
                    "status": "passed",
                    "verified_at": "2026-09-22T12:02:00Z",
                    "method": "native-codex",
                    "targets": {"codex": "cafebabe"},
                },
            }
            state.write_json(state_dir / "_verification.json", receipt)
            before = (state_dir / "_verification.json").read_text()
            rc = state.record_dispatch(
                path,
                "def456",
                '{"codex":"feedface"}',
                "2026-09-22T13:00:00Z",
            )
            self.assertEqual(rc, 0)
            self.assertEqual((state_dir / "_verification.json").read_text(), before)

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

    def test_projection_verification_preserves_global_runtime_receipt(self):
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
            state.write_json(
                state_dir / "_verification.json",
                {
                    "scope": ["all"],
                    "projection": {"status": "passed"},
                    "runtime": {
                        "status": "passed",
                        "verified_at": "2026-09-22T12:02:00Z",
                        "method": "native-codex",
                        "targets": {"codex": "deadbeef"},
                    },
                },
            )
            rc = state.record_projection_verification(
                state_dir,
                {"summary": {"total_findings": 0}, "findings": []},
                "2026-09-22T12:03:00Z",
                ["foo"],
            )
            self.assertEqual(rc, 0)
            global_state = json.loads((state_dir / "_verification.json").read_text())
            self.assertEqual(global_state["projection"]["status"], "passed")
            self.assertEqual(global_state["runtime"]["status"], "passed")
            self.assertEqual(global_state["runtime"]["method"], "native-codex")

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
