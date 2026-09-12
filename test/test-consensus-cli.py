#!/usr/bin/env python3
"""Tests for bin/idstack-consensus client and caching engine."""

import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
CLI_PATH = os.path.join(REPO_ROOT, "bin", "idstack-consensus")


class TestConsensusCLI(unittest.TestCase):
    def setUp(self):
        self.test_dir = tempfile.mkdtemp(prefix="idstack-test-consensus-")
        self.cache_dir = os.path.join(self.test_dir, "cache")
        self.home_dir = os.path.join(self.test_dir, "home")
        os.makedirs(self.home_dir, exist_ok=True)
        self.env = dict(os.environ)
        self.env["IDSTACK_CONSENSUS_CACHE_DIR"] = self.cache_dir
        self.env["HOME"] = self.home_dir
        self.env.pop("CONSENSUS_API_KEY", None)

    def tearDown(self):
        shutil.rmtree(self.test_dir, ignore_errors=True)

    def run_cli(self, args, env=None, cwd=None, input_data=None):
        cmd = [sys.executable, CLI_PATH] + args
        proc = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            input=input_data,
            env=env or self.env,
            cwd=cwd or REPO_ROOT,
        )
        return proc

    def test_status_no_key(self):
        proc = self.run_cli(["status"])
        self.assertEqual(proc.returncode, 0)
        data = json.loads(proc.stdout)
        self.assertEqual(data["api_key_configured"], False)
        self.assertEqual(data["cached_queries_count"], 0)
        self.assertEqual(data["cache_dir"], self.cache_dir)

    def test_status_with_env_key(self):
        env = dict(self.env)
        env["CONSENSUS_API_KEY"] = "test-env-key-123"
        proc = self.run_cli(["status"], env=env)
        self.assertEqual(proc.returncode, 0)
        data = json.loads(proc.stdout)
        self.assertEqual(data["api_key_configured"], True)

    def test_byok_resolution_profile_yaml(self):
        profile_dir = os.path.join(self.home_dir, ".idstack")
        os.makedirs(profile_dir, exist_ok=True)
        profile_file = os.path.join(profile_dir, "profile.yaml")
        with open(profile_file, "w", encoding="utf-8") as f:
            f.write('experience_level: intermediate\nconsensus_api_key: "profile-key-abc"\n')

        proc = self.run_cli(["status"])
        self.assertEqual(proc.returncode, 0)
        data = json.loads(proc.stdout)
        self.assertEqual(data["api_key_configured"], True)

    def test_byok_resolution_project_json(self):
        proj_dir = os.path.join(self.test_dir, "project_root")
        dot_idstack = os.path.join(proj_dir, ".idstack")
        os.makedirs(dot_idstack, exist_ok=True)
        manifest_file = os.path.join(dot_idstack, "project.json")
        with open(manifest_file, "w", encoding="utf-8") as f:
            json.dump({"preferences": {"consensus_api_key": "manifest-key-xyz"}}, f)

        proc = self.run_cli(["status"], cwd=proj_dir)
        self.assertEqual(proc.returncode, 0)
        data = json.loads(proc.stdout)
        self.assertEqual(data["api_key_configured"], True)

    def test_cache_hit_avoids_network(self):
        os.makedirs(self.cache_dir, exist_ok=True)
        claim = "elaborated feedback boosts learning gains"
        norm = "elaborated feedback boosts learning gains"
        q_hash = hashlib.sha256(norm.encode("utf-8")).hexdigest()
        cached_record = {
            "query": norm,
            "query_hash": q_hash,
            "cached_at": "2026-09-12T00:00:00Z",
            "consensus_meter": {"yes_pct": 92, "possibly_pct": 5, "no_pct": 3, "total_papers": 28},
            "top_papers": [
                {
                    "title": "Feedback Meta-Analysis",
                    "authors": ["Wisniewski et al."],
                    "year": 2020,
                    "study_design": "Meta-analysis",
                    "tier": "T1",
                    "doi_url": "https://doi.org/10.3389/fpsyg.2019.03087",
                }
            ],
        }
        with open(os.path.join(self.cache_dir, q_hash + ".json"), "w") as f:
            json.dump(cached_record, f)

        # Query with extra whitespace and varied case to also test normalization
        proc = self.run_cli(["query", "--claim", "  Elaborated  FEEDBACK boosts learning gains "])
        self.assertEqual(proc.returncode, 0)
        data = json.loads(proc.stdout)
        self.assertTrue(data["from_cache"])
        self.assertEqual(data["consensus_meter"]["yes_pct"], 92)
        self.assertEqual(data["top_papers"][0]["title"], "Feedback Meta-Analysis")

    def test_query_no_key_unambiguous_fallback(self):
        proc = self.run_cli(["query", "--claim", "unseen claim without key"])
        self.assertEqual(proc.returncode, 0)
        data = json.loads(proc.stdout)
        self.assertEqual(data["from_cache"], False)
        self.assertEqual(data["api_key_configured"], False)
        self.assertIn("note", data)

    def test_configure_subcommand(self):
        proc = self.run_cli(["configure", "--key", "configured-key-789"])
        self.assertEqual(proc.returncode, 0)
        profile_path = os.path.join(self.home_dir, ".idstack", "profile.yaml")
        self.assertTrue(os.path.isfile(profile_path))
        with open(profile_path, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("configured-key-789", content)

        # Status should now report api_key_configured: True
        status_proc = self.run_cli(["status"])
        self.assertEqual(status_proc.returncode, 0)
        status_data = json.loads(status_proc.stdout)
        self.assertEqual(status_data["api_key_configured"], True)


if __name__ == "__main__":
    unittest.main()
