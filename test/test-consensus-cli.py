#!/usr/bin/env python3
"""Tests for bin/idstack-consensus client and caching engine."""

import hashlib
import importlib.machinery
import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
CLI_PATH = os.path.join(REPO_ROOT, "bin", "idstack-consensus")
STE_CHECK_PATH = os.path.join(REPO_ROOT, "bin", "idstack-ste-check")
JS_CLIENT_PATH = os.path.join(REPO_ROOT, "extension", "shared", "consensus-client.js")
MYTH_TYPES = ["learning_styles", "hemisphere_learning", "ten_percent_brain", "dales_cone_percentages"]


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

    def test_verify_known_reference_passes_free(self):
        input_file = os.path.join(self.test_dir, "staged.json")
        output_file = os.path.join(self.test_dir, "verified.json")
        findings = [
            {
                "severity": "warning",
                "tier": "T1",
                "citation": "[Assessment-8] Wisniewski et al. (2020)",
                "observation": "Assessments lack rubrics.",
                "evidence": "Elaborated feedback improves learning gains.",
                "recommendation": "Add rubrics with elaborated feedback.",
            }
        ]
        with open(input_file, "w") as f:
            json.dump({"findings": findings}, f)

        proc = self.run_cli(["verify", "--findings", input_file, "--output", output_file])
        self.assertEqual(proc.returncode, 0)
        with open(output_file, "r") as f:
            verified = json.load(f)
        self.assertEqual(len(verified["findings"]), 1)
        self.assertEqual(verified["findings"][0]["tier"], "T1")
        self.assertTrue(verified["findings"][0]["qa_verified"])

    def test_verify_neuromyth_contradiction_auto_corrected(self):
        input_file = os.path.join(self.test_dir, "neuromyth.json")
        output_file = os.path.join(self.test_dir, "corrected.json")
        findings = [
            {
                "severity": "suggestion",
                "tier": "T1",
                "citation": "[Novel-Claim]",
                "observation": "Students have varied learning styles.",
                "evidence": "Audit course to match visual and auditory learning styles.",
                "recommendation": "Separate students by visual vs auditory learning styles.",
            }
        ]
        with open(input_file, "w") as f:
            json.dump({"findings": findings}, f)

        proc = self.run_cli(["verify", "--findings", input_file, "--output", output_file])
        self.assertEqual(proc.returncode, 0)
        with open(output_file, "r") as f:
            corrected = json.load(f)
        finding = corrected["findings"][0]
        self.assertIn("multimodal", finding["recommendation"].lower())
        self.assertTrue(finding.get("auto_corrected"))

    def test_verify_tier_calibration_downgrades_observational(self):
        input_file = os.path.join(self.test_dir, "observational.json")
        output_file = os.path.join(self.test_dir, "calibrated.json")
        findings = [
            {
                "severity": "suggestion",
                "tier": "T1",
                "citation": "Smith et al. (2023)",
                "observation": "Student engagement was reported high in discussion forums.",
                "evidence": "An observational survey of 45 students in an online seminar.",
                "recommendation": "Use discussion forums for engagement.",
            }
        ]
        with open(input_file, "w") as f:
            json.dump({"findings": findings}, f)

        proc = self.run_cli(["verify", "--findings", input_file, "--output", output_file])
        self.assertEqual(proc.returncode, 0)
        with open(output_file, "r") as f:
            calibrated = json.load(f)
        finding = calibrated["findings"][0]
        self.assertIn(finding["tier"], ("T3", "T4"))
        self.assertEqual(finding["tier"], "T4")

    def test_verify_cached_novel_claim_enriched(self):
        os.makedirs(self.cache_dir, exist_ok=True)
        claim = "microlearning retention gains"
        norm = "microlearning retention gains"
        q_hash = hashlib.sha256(norm.encode("utf-8")).hexdigest()
        cached_record = {
            "query": norm,
            "query_hash": q_hash,
            "cached_at": "2026-09-12T00:00:00Z",
            "consensus_meter": {"yes_pct": 85, "possibly_pct": 10, "no_pct": 5, "total_papers": 14},
            "top_papers": [
                {
                    "title": "Microlearning in Digital Education",
                    "authors": ["Chen et al."],
                    "year": 2024,
                    "study_design": "Meta-analysis",
                    "tier": "T1",
                    "doi_url": "https://doi.org/10.1000/microlearning-meta",
                }
            ],
        }
        with open(os.path.join(self.cache_dir, q_hash + ".json"), "w") as f:
            json.dump(cached_record, f)

        input_file = os.path.join(self.test_dir, "novel_cached.json")
        output_file = os.path.join(self.test_dir, "novel_verified.json")
        findings = [
            {
                "severity": "suggestion",
                "tier": "T1",
                "citation": "Chen et al. (2024)",
                "observation": "Lessons are too long.",
                "evidence": "Microlearning retention gains.",
                "recommendation": "Chunk content into 5-minute modules.",
            }
        ]
        with open(input_file, "w") as f:
            json.dump({"findings": findings}, f)

        proc = self.run_cli(["verify", "--findings", input_file, "--output", output_file])
        self.assertEqual(proc.returncode, 0)
        self.assertIn("Evidence QA:", proc.stdout)
        self.assertIn("1 cached", proc.stdout)
        with open(output_file, "r") as f:
            verified = json.load(f)
        finding = verified["findings"][0]
        self.assertTrue(finding.get("qa_verified"))
        self.assertEqual(finding.get("doi_url"), "https://doi.org/10.1000/microlearning-meta")
        self.assertEqual(finding.get("consensus", {}).get("yes_pct"), 85)

    def test_verify_direct_array_input(self):
        input_file = os.path.join(self.test_dir, "array.json")
        output_file = os.path.join(self.test_dir, "out_array.json")
        findings = [
            {
                "severity": "info",
                "tier": "T1",
                "citation": "[Assessment-8] Wisniewski et al. (2020)",
                "observation": "Feedback timing is immediate.",
                "evidence": "Immediate feedback guides correction.",
                "recommendation": "Maintain immediate feedback.",
            }
        ]
        with open(input_file, "w") as f:
            json.dump(findings, f)

        proc = self.run_cli(["verify", "--findings", input_file, "--output", output_file])
        self.assertEqual(proc.returncode, 0)
        with open(output_file, "r") as f:
            verified = json.load(f)
        self.assertIn("findings", verified)
        self.assertEqual(len(verified["findings"]), 1)
        self.assertTrue(verified["findings"][0]["qa_verified"])

    def test_verify_hemisphere_neuromyth_auto_corrected(self):
        input_file = os.path.join(self.test_dir, "hemisphere.json")
        output_file = os.path.join(self.test_dir, "hemisphere_out.json")
        findings = [
            {
                "severity": "suggestion",
                "tier": "T1",
                "citation": "[Novel-Claim]",
                "observation": "Lessons should cater to right-brain learners.",
                "evidence": "Right-brained students need intuitive creative tasks.",
                "recommendation": "Tailor assignments for right-brain learners.",
            }
        ]
        with open(input_file, "w") as f:
            json.dump({"findings": findings}, f)

        proc = self.run_cli(["verify", "--findings", input_file, "--output", output_file])
        self.assertEqual(proc.returncode, 0)
        with open(output_file, "r") as f:
            corrected = json.load(f)
        finding = corrected["findings"][0]
        self.assertTrue(finding.get("auto_corrected"))
        self.assertIn("multimodal", finding["recommendation"].lower())

    def test_verify_tier_calibration_controlled_downgrades_to_t2(self):
        input_file = os.path.join(self.test_dir, "controlled.json")
        output_file = os.path.join(self.test_dir, "controlled_out.json")
        findings = [
            {
                "severity": "suggestion",
                "tier": "T1",
                "citation": "Taylor & White (2023)",
                "observation": "Interactive quizzes improved mastery.",
                "evidence": "Quasi-experimental study with matched comparison group in two chemistry classes.",
                "recommendation": "Incorporate interactive quizzes.",
            }
        ]
        with open(input_file, "w") as f:
            json.dump({"findings": findings}, f)

        proc = self.run_cli(["verify", "--findings", input_file, "--output", output_file])
        self.assertEqual(proc.returncode, 0)
        with open(output_file, "r") as f:
            calibrated = json.load(f)
        finding = calibrated["findings"][0]
        self.assertEqual(finding["tier"], "T2")

    def test_verify_tier_calibration_systematic_review_downgrades_to_t3(self):
        input_file = os.path.join(self.test_dir, "sysrev.json")
        output_file = os.path.join(self.test_dir, "sysrev_out.json")
        findings = [
            {
                "severity": "suggestion",
                "tier": "T1",
                "citation": "Miller et al. (2022)",
                "observation": "Peer grading needs calibration.",
                "evidence": "A systematic review of peer grading across 40 universities.",
                "recommendation": "Calibrate peer graders.",
            }
        ]
        with open(input_file, "w") as f:
            json.dump({"findings": findings}, f)

        proc = self.run_cli(["verify", "--findings", input_file, "--output", output_file])
        self.assertEqual(proc.returncode, 0)
        with open(output_file, "r") as f:
            calibrated = json.load(f)
        finding = calibrated["findings"][0]
        self.assertEqual(finding["tier"], "T3")

    def test_verify_missing_file_fails(self):
        proc = self.run_cli([
            "verify",
            "--findings",
            os.path.join(self.test_dir, "nonexistent.json"),
            "--output",
            os.path.join(self.test_dir, "out.json"),
        ])
        self.assertEqual(proc.returncode, 1)

    def test_sync_dry_run_all_domains(self):
        proc = self.run_cli(["sync", "--dry-run"])
        self.assertEqual(proc.returncode, 0)
        self.assertIn("- [Assessment-", proc.stdout)
        self.assertIn("- [ID-", proc.stdout)
        self.assertIn("- [Alignment-", proc.stdout)
        self.assertIn("- [CogLoad-", proc.stdout)
        self.assertIn("- [Access-", proc.stdout)
        self.assertIn("Dry run", proc.stdout)
        self.assertIn("check-evidence-cards", proc.stdout)

    def test_sync_domain_specific(self):
        proc = self.run_cli(["sync", "--domain", "Assessment", "--dry-run"])
        self.assertEqual(proc.returncode, 0)
        self.assertIn("- [Assessment-", proc.stdout)
        self.assertIn("Assessment", proc.stdout)
        self.assertNotIn("- [CogLoad-", proc.stdout)
        self.assertNotIn("- [Access-", proc.stdout)

    def test_sync_invalid_domain_fails(self):
        proc = self.run_cli(["sync", "--domain", "InvalidDomain", "--dry-run"])
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("Unknown domain", proc.stderr + proc.stdout)

    def test_sync_default_is_dry_run(self):
        proc = self.run_cli(["sync", "--domain", "Models"])
        self.assertEqual(proc.returncode, 0)
        self.assertIn("- [ID-", proc.stdout)
        self.assertIn("Dry run", proc.stdout)

    def test_sync_evidence_cards_compatibility(self):
        proc = self.run_cli(["sync", "--dry-run"])
        self.assertEqual(proc.returncode, 0)
        self.assertIn("check-evidence-cards.py found 0 mismatches", proc.stdout)

    def test_sync_uses_cached_papers_when_available(self):
        os.makedirs(self.cache_dir, exist_ok=True)
        query = "formative assessment feedback higher education meta-analysis 2024..2026"
        norm = "formative assessment feedback higher education meta-analysis 2024..2026"
        q_hash = hashlib.sha256(norm.encode("utf-8")).hexdigest()
        cached_record = {
            "query": norm,
            "query_hash": q_hash,
            "cached_at": "2026-09-12T00:00:00Z",
            "top_papers": [
                {
                    "title": "Custom Cached Formative Feedback Review",
                    "authors": ["CachedAuthor, A."],
                    "year": 2025,
                    "journal": "Journal of Cached Studies",
                    "study_design": "Meta-analysis",
                    "tier": "T1",
                }
            ],
        }
        with open(os.path.join(self.cache_dir, q_hash + ".json"), "w") as f:
            json.dump(cached_record, f)

        proc = self.run_cli(["sync", "--domain", "Assessment", "--dry-run"])
        self.assertEqual(proc.returncode, 0)
        self.assertIn("Custom Cached Formative Feedback Review", proc.stdout)
        self.assertIn("CachedAuthor", proc.stdout)

    # The text that verify writes goes into HTML reports and the manifest, so it
    # must obey the writing standard. The input fields are empty or in STE, and
    # the trigger is in the recommendation, which verify replaces. Thus a problem
    # that the checker finds comes from idstack's own text.
    def run_verify(self, findings):
        input_file = os.path.join(self.test_dir, "ste-in.json")
        output_file = os.path.join(self.test_dir, "ste-out.json")
        with open(input_file, "w", encoding="utf-8") as f:
            json.dump({"findings": findings}, f)
        proc = self.run_cli(["verify", "--findings", input_file, "--output", output_file])
        self.assertEqual(proc.returncode, 0, proc.stderr)
        with open(output_file, "r", encoding="utf-8") as f:
            return json.load(f)["findings"]

    def assert_ste_clean(self, text):
        proc = subprocess.run(
            [sys.executable, STE_CHECK_PATH, "-"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            input=text,
            cwd=REPO_ROOT,
        )
        self.assertEqual(proc.returncode, 0, "idstack-ste-check found problems:\n" + proc.stdout + proc.stderr)

    def test_verify_neuromyth_text_obeys_ste(self):
        triggers = {
            "learning_styles": "Cater to visual learners.",
            "hemisphere_learning": "Give tasks to right-brain learners.",
            "ten_percent_brain": "Learners use 10% of their brain.",
            "dales_cone_percentages": "Learners remember 10% of what they read.",
        }
        findings = [
            {"severity": "warning", "tier": "T1", "citation": "[Novel-Claim]",
             "observation": "", "evidence": "", "recommendation": triggers[t]}
            for t in MYTH_TYPES
        ]
        texts = []
        for finding in self.run_verify(findings):
            self.assertTrue(finding.get("auto_corrected"))
            self.assertIn("[Auto-Corrected Neuromyth]", finding["evidence"])
            self.assertIn("[Note:", finding["observation"])
            texts += [finding["recommendation"], finding["evidence"], finding["observation"]]
        self.assertEqual(len(texts), 12)
        self.assert_ste_clean("\n\n".join(texts) + "\n")

    def test_verify_tier_calibration_text_obeys_ste(self):
        evidence = [
            "A quasi-experimental study with a comparison group.",
            "A systematic review of peer grading.",
            "An observational survey of 45 students.",
            "A study of 30 students in one class.",
        ]
        findings = [
            {"severity": "warning", "tier": "T1", "citation": "Zzyzx (2021)",
             "observation": "", "evidence": e, "recommendation": "Add a rubric."}
            for e in evidence
        ]
        result = self.run_verify(findings)
        self.assertEqual([f["tier"] for f in result], ["T2", "T3", "T4", "T4"])
        for finding in result:
            self.assertIn("[Tier calibrated:", finding["evidence"])
        self.assert_ste_clean("\n\n".join(f["evidence"] for f in result) + "\n")

    # The extension has a copy of the neuromyth text. The two copies must stay
    # the same, word for word.
    @unittest.skipUnless(shutil.which("node"), "node is not installed")
    def test_neuromyth_text_matches_extension_copy(self):
        script = (
            "import { autoCorrectNeuromyth } from %s;\n"
            "const out = {};\n"
            "for (const t of %s) {\n"
            "  out[t] = autoCorrectNeuromyth({ observation: '', evidence: '', recommendation: '' }, t);\n"
            "}\n"
            "console.log(JSON.stringify(out));\n"
        ) % (json.dumps(Path(JS_CLIENT_PATH).as_uri()), json.dumps(MYTH_TYPES))
        proc = subprocess.run(
            ["node", "--input-type=module", "-e", script],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        js = json.loads(proc.stdout)

        loader = importlib.machinery.SourceFileLoader("idstack_consensus", CLI_PATH)
        spec = importlib.util.spec_from_loader(loader.name, loader)
        module = importlib.util.module_from_spec(spec)
        loader.exec_module(module)
        for myth_type in MYTH_TYPES:
            finding = {"observation": "", "evidence": "", "recommendation": ""}
            module.auto_correct_neuromyth(finding, myth_type)
            for key in ("recommendation", "evidence", "observation"):
                self.assertEqual(js[myth_type][key], finding[key], "%s %s" % (myth_type, key))


if __name__ == "__main__":
    unittest.main()



