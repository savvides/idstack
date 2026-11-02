## Manifest Schema Reference

The idstack manifest lives at `.idstack/project.json`. Schema version: **1.4**.

This is the canonical schema. Every skill writes to its own section using the shapes documented here; **all other sections must be preserved verbatim**. There is one source of truth — this file. If the schema ever needs to change, edit `templates/manifest-schema.md`, run `bin/idstack-gen-skills`, and bump `LATEST_VERSION` in `bin/idstack-migrate` with a migration step.

### Two outputs per skill: JSON manifest + Markdown report

Every skill that produces findings emits **both**:

- a **JSON section** in this manifest (system state — read by other skills, the pipeline orchestrator, and `bin/idstack-status`), and
- a **Markdown report** at `.idstack/exports/<course-slug>/<skill>.md` (the human view — read by the instructional designer).

The Markdown report follows the skeleton in `templates/report.md.tmpl` and the content contract in `templates/report-format.md` (observation → evidence → why-it-matters → recommendation, with severity and evidence tier on every finding). The skill writes the report's relative path back into its own section's `report_path` field so other skills can find it. (`bin/idstack-status` discovers reports independently by globbing `.idstack/exports/<course-slug>/*.md`, so the dashboard survives a stale `report_path`.)

`<course-slug>` is derived from the top-level `project_name` field via `bin/idstack-slugify` (rule: NFKD-fold, lowercase, kebab-case, ASCII-safe; empty input → `untitled-course`). The slug is computed deterministically — skills don't cache it in the manifest. All exports for a course — per-skill Markdown reports, the pipeline dashboard at `index.md`, and LMS packages (`course-export.imscc`, `scorm-export.zip`) — live under the same `.idstack/exports/<course-slug>/` folder so the deliverable is self-describing when zipped, emailed, or handed off.

`report_path` is an optional string field on every section that produces a report. It is a path relative to the project root (typically `.idstack/exports/<course-slug>/<skill>.md`). Empty string means the skill hasn't run yet, or ran in a mode that didn't produce a report. Renaming a course's `project_name` changes the slug, which moves future exports to a new folder; older folders are left in place.

### Two ways to write to the manifest

**1. Recommended — `bin/idstack-manifest-merge`:** write only your sections, the tool merges atomically.

```bash
# Run this in a block that starts with your skill's own idstack resolve lines,
# so $_IDSTACK is set. Pass your skill's section on stdin (a heredoc), not a /tmp file:
"$_IDSTACK/bin/idstack-manifest-merge" --create --section red_team_audit --payload - <<'PAYLOAD'
{ ...your section's JSON... }
PAYLOAD
```

(Skills also read this file raw, so it carries no `IDSTACK_RESOLVE` placeholder
and no copy of the resolve lines.)

The merge tool replaces only the named top-level sections, preserves every other section, updates the top-level `updated` timestamp, validates JSON on read, and rejects unknown sections. `--create` makes a canonical manifest first when there is none. Repeat `--section`/`--payload` to write several sections in one atomic write, and use `--set project_name=<value>` for the top-level name. Use this in preference to inlining the full manifest in `Edit` operations.

**2. Fallback — manual full-manifest write:** if the merge tool is unavailable for some reason, Read the full manifest, modify only your section, Write back. Preserve all other sections verbatim. Use the full schema below as reference.

### Top-level fields

| Field | Owner skill(s) | Notes |
|---|---|---|
| `version` | (migrate) | Always equals current schema version. Auto-managed by `bin/idstack-migrate`. |
| `project_name` | needs-analysis, course-import | `bin/idstack-migrate --init` writes `""`. needs-analysis or course-import sets it with `--set project_name=<v>`. Don't overwrite once set. |
| `created` | (any, once) | ISO-8601 timestamp of first creation. Don't overwrite. |
| `updated` | (any) | ISO-8601 of last write. Updated automatically by `bin/idstack-manifest-merge`. |
| `context` | needs-analysis, course-import | Modality, timeline, class size, etc. Edited by skills that learn new context. |
| `needs_analysis` | needs-analysis, course-import | Org context, task analysis, learner profile, training justification. |
| `learning_objectives` | learning-objectives, course-import, assessment-design | ILOs, alignment matrix, expertise-reversal flags. assessment-design reads the section, adds its fields and writes the whole section. |
| `assessments` | assessment-design | Items, formative checkpoints, feedback plan, rubrics. |
| `course_content` | course-builder | Generated modules, syllabus, content paths. |
| `import_metadata` | course-import | Source, source LMS, import time, items imported, and the count of approved quality flags. The flag details are in the course-import report. |
| `export_metadata` | course-export | Export destination, items exported, readiness check. |
| `quality_review` | course-quality-review | QM standards, CoI presence, alignment audit, cross-domain checks, scores. |
| `red_team_audit` | red-team | Confidence score, dimensions, findings (with stable ids), top actions. |
| `accessibility_review` | accessibility-review | WCAG / UDL scores, violations, recommendations, quick wins. |
| `preferences` | (user, by hand) | Verbosity, export format, preferred LMS, auto-advance. `bin/idstack-migrate` writes the defaults. No skill writes this section; the preamble reads `verbosity`. |

### Full schema (canonical shape)

```json
{
  "version": "1.4",
  "project_name": "",
  "created": "",
  "updated": "",
  "context": {
    "modality": "",
    "timeline": "",
    "class_size": "",
    "institution_type": "",
    "available_tech": []
  },
  "needs_analysis": {
    "mode": "",
    "report_path": "",
    "organizational_context": {
      "problem_statement": "",
      "stakeholders": [],
      "current_state": "",
      "desired_state": "",
      "performance_gap": ""
    },
    "task_analysis": {
      "job_tasks": [],
      "prerequisite_knowledge": [],
      "tools_and_resources": []
    },
    "learner_profile": {
      "prior_knowledge_level": "",
      "motivation_factors": [],
      "demographics": "",
      "access_constraints": [],
      "learning_preferences_note": "idstack does NOT use learning styles to differentiate instruction because the evidence does not support them. Prior knowledge is the primary differentiator."
    },
    "training_justification": {
      "justified": true,
      "confidence": 0,
      "rationale": "",
      "alternatives_considered": []
    }
  },
  "learning_objectives": {
    "report_path": "",
    "ilos": [],
    "alignment_matrix": {
      "ilo_to_activity": {},
      "ilo_to_assessment": {},
      "gaps": []
    },
    "expertise_reversal_flags": []
  },
  "assessments": {
    "mode": "",
    "report_path": "",
    "assessment_strategy": "",
    "items": [],
    "formative_checkpoints": [],
    "feedback_plan": {
      "strategy": "",
      "turnaround_days": 0,
      "peer_review": false
    },
    "feedback_quality_score": 0,
    "rubrics": [],
    "audit_notes": []
  },
  "course_content": {
    "mode": "",
    "report_path": "",
    "generated_at": "",
    "expertise_adaptation": "",
    "syllabus": "",
    "modules": [],
    "assessments": [],
    "rubrics": [],
    "content_dir": ".idstack/course-content/",
    "generated_files": [],
    "build_timestamp": "",
    "placeholders_used": [],
    "recommended_generation_targets": []
  },
  "import_metadata": {
    "source": "",
    "report_path": "",
    "imported_at": "",
    "source_lms": "",
    "source_cartridge": "",
    "source_size_bytes": 0,
    "schema": "",
    "items_imported": {
      "modules": 0,
      "objectives": 0,
      "module_objectives": 0,
      "assessments": 0,
      "activities": 0,
      "pages": 0,
      "rubrics": 0,
      "quizzes": 0,
      "discussions": 0
    },
    "quality_flags": 0,
    "quality_flag_details": []
  },
  "export_metadata": {
    "report_path": "",
    "exported_at": "",
    "format": "",
    "destination": "",
    "items_exported": {
      "modules": 0,
      "pages": 0,
      "assignments": 0,
      "quizzes": 0,
      "discussions": 0
    },
    "failed_items": [],
    "notes": "",
    "readiness_check": {
      "quality_score": 0,
      "quality_reviewed": false,
      "red_team_critical": 0,
      "red_team_reviewed": false,
      "accessibility_critical": 0,
      "accessibility_reviewed": false,
      "verdict": ""
    }
  },
  "quality_review": {
    "report_path": "",
    "last_reviewed": "",
    "qm_standards": {
      "course_overview":         {"status": "", "findings": []},
      "learning_objectives":     {"status": "", "findings": []},
      "assessment":              {"status": "", "findings": []},
      "instructional_materials": {"status": "", "findings": []},
      "learning_activities":     {"status": "", "findings": []},
      "course_technology":       {"status": "", "findings": []},
      "learner_support":         {"status": "", "findings": []},
      "accessibility":           {"status": "", "findings": []}
    },
    "coi_presence": {
      "teaching_presence":  {"score": 0, "findings": []},
      "social_presence":    {"score": 0, "findings": []},
      "cognitive_presence": {"score": 0, "findings": []}
    },
    "alignment_audit": {"findings": []},
    "cross_domain_checks": {
      "cognitive_load":        {"score": 0, "flags": []},
      "multimedia_principles": {"score": 0, "flags": []},
      "feedback_quality":      {"score": 0, "flags": []},
      "expertise_reversal":    {"score": 0, "flags": []}
    },
    "overall_score": 0,
    "score_breakdown": {
      "qm_structural": 0,
      "coi_presence": 0,
      "constructive_alignment": 0,
      "cross_domain_evidence": 0
    },
    "quick_wins": [],
    "recommendations": [],
    "review_history": []
  },
  "red_team_audit": {
    "updated": "",
    "confidence_score": 0,
    "focus": "",
    "report_path": "",
    "findings_summary": {"critical": 0, "warning": 0, "info": 0},
    "dimensions": {
      "alignment":      {"score": "", "findings": []},
      "evidence":       {"score": "", "mode": "", "findings": []},
      "cognitive_load": {"score": "", "findings": []},
      "personas":       {"score": "", "findings": []},
      "prerequisites":  {"score": "", "findings": []}
    },
    "top_actions": [],
    "limitations": [],
    "fixes_applied": [],
    "fixes_deferred": []
  },
  "accessibility_review": {
    "updated": "",
    "report_path": "",
    "score": {"overall": 0, "wcag": 0, "udl": 0},
    "wcag_violations": [],
    "udl_recommendations": [],
    "quick_wins": []
  },
  "preferences": {
    "verbosity": "normal",
    "export_format": "",
    "preferred_lms": "",
    "auto_advance_pipeline": false
  }
}
```

### Per-section item shapes

These document the **shape of array elements and dictionary values** that the canonical schema leaves as `[]` or `{}`. Skills should produce items in these shapes; downstream skills can rely on them.

**`learning_objectives.alignment_matrix.ilo_to_activity`** — keyed by ILO id, values are arrays of activity names:
```json
{ "ILO-1": ["Module 1 case study", "Discussion 2"], "ILO-2": [] }
```

**`learning_objectives.alignment_matrix.ilo_to_assessment`** — same shape. `/idstack:learning-objectives` writes arrays of assessment titles. `/idstack:assessment-design` replaces them with arrays of assessment IDs (`"A-1"`). A skill that reads this map must accept both.

**`learning_objectives.alignment_matrix.gaps[]`** — `/idstack:assessment-design` writes each item as the object below. `/idstack:learning-objectives` writes each item as a string that describes the gap. A skill that reads `gaps[]` must accept both forms.
```json
{
  "ilo": "ILO-1",
  "type": "untested|orphaned|underspecified|bloom_mismatch",
  "description": "ILO-1 has no matching assessment in the active modules.",
  "severity": "critical|warning|info"
}
```

**`learning_objectives.ilos[]`** — each item:
```json
{
  "id": "ILO-1",
  "objective": "Analyze competitive forces in...",
  "knowledge_dimension": "factual|conceptual|procedural|metacognitive",
  "cognitive_process": "remember|understand|apply|analyze|evaluate|create"
}
```
`/idstack:course-import` can also add `"confidence": "high|ambiguous"` and `"alignment_status": "imported-unverified"`. `/idstack:learning-objectives` checks these items again.

**`assessments.items[]`** — `/idstack:assessment-design` writes each item (`/idstack:course-import` does not write this array):
```json
{
  "id": "A-1",
  "title": "Module 1 Quiz",
  "type": "quiz|essay|project|case-study|peer-review|portfolio|presentation",
  "format": "formative|summative",
  "aligned_ilos": ["ILO-1", "ILO-3"],
  "rubric": {
    "criteria": [
      { "name": "Criterion name", "weight": 40,
        "levels": { "exceeds": "...", "meets": "...", "approaching": "...", "below": "..." } }
    ],
    "levels": ["exceeds", "meets", "approaching", "below"],
    "total_points": 100
  },
  "feedback_strategy": {
    "type": "elaborated|correctness|peer|self-assessment",
    "timing": "immediate|delayed|iterative",
    "principles_applied": [1, 2, 3, 5, 6]
  },
  "evidence_tier": "T1"
}
```
The audit of an imported course (Mode 3) also adds `"alignment_status": "weak|moderate|strong"`.

**`assessments.rubrics[]`** — each item:
```json
{
  "id": "rubric-1",
  "title": "SM Project Rubric",
  "criteria": [{"name": "...", "blooms_level": "...", "weight": 0}],
  "applies_to": ["A-3"]
}
```

**`import_metadata.quality_flag_details[]`** — each item. No skill writes this array. `bin/idstack-migrate` creates it empty, or fills it when it moves a legacy `_import_quality_flags` root field. `/idstack:course-import` writes only the `quality_flags` count. The flag details are in its report (Import quality triage section):
```json
{
  "key": "orphan_module_8",
  "description": "Module 8 wiki content exists in the cartridge but is not referenced in <organizations>.",
  "severity": "warning|critical|info",
  "evidence": "Optional citation tag, e.g. [Alignment-1] [T5]"
}
```

**`red_team_audit.dimensions.<name>.findings[]`** — each item (matches the `<dimension>-<n>` id convention from the red-team orchestrator):
```json
{
  "id": "alignment-1",
  "description": "ILO-2 (vision/mission) has no matching assessment.",
  "module": "Module 4",
  "severity": "critical|warning|info"
}
```

**`accessibility_review.wcag_violations[]`** — each item:
```json
{
  "id": "wcag-1",
  "criterion": "1.3.1 Info and Relationships",
  "level": "A|AA|AAA",
  "description": "All cartridge HTML pages lack <h1> elements.",
  "affected": ["page1.html", "page2.html"],
  "severity": "critical|warning|info"
}
```

**`accessibility_review.udl_recommendations[]`** — each item:
```json
{
  "id": "udl-1",
  "principle": "engagement|representation|action_expression",
  "description": "Add transcripts to all videos.",
  "status": "fully_met|partial|not_met"
}
```

**`quality_review.qm_standards.<standard>.findings[]`**, **`quality_review.coi_presence.<presence>.findings[]`** and **`quality_review.alignment_audit.findings[]`** — each item is a plain string. `/idstack:course-quality-review` writes one short finding sentence per item, for example `"findings": ["Syllabus has no course-level objectives."]`. **`quality_review.cross_domain_checks.<check>.flags[]`** has no fixed item shape. The skill writes a list of flags, or `[]` when the check found nothing. The severity and evidence tier of quality-review findings are in `quality_review.recommendations[]` and `quality_review.quick_wins[]`, not in these arrays.

### Mode field — design-new vs audit-existing

`needs_analysis.mode` and `course_content.mode` record which operating mode the corresponding skill ran in. Trigger: `import_metadata.source` ∈ `{cartridge, scorm, canvas-api}` plus the relevant section being non-empty (skill-specific check). `assessments.mode` is in the schema, but `/idstack:assessment-design` does not write it. The skill records its mode (Mode 1, Mode 2 or Mode 3) only in the report's header metadata line under the title, as `mode: Mode N` (`idstack-report-section init --mode`).

Allowed values per skill:
- `needs_analysis.mode`: `"design-new"` or `"audit-existing"`
- `assessments.mode`: not written by the current skill. The report records the mode: `"Mode 1"` = full upstream data, `"Mode 2"` = ILOs-from-scratch, `"Mode 3"` = audit existing assessments
- `course_content.mode`: `"build-new"` or `"gap-fill"`

Empty string means the skill hasn't run yet or didn't record the mode (legacy manifests).

**`assessments.audit_notes[]`** — only populated in Mode 3. Records which audit findings the user chose to act on:
```json
{
  "target_id": "A-3",
  "action": "applied|deferred|declined",
  "description": "Rubric criterion for ILO-2 added: 'Synthesis depth (1-4 scale)'.",
  "reason": "Optional — only meaningful for deferred/declined."
}
```

**`course_content.recommended_generation_targets[]`** — populated in `gap-fill` mode. Lists artifacts upstream skills flagged as missing, with status:
```json
{
  "description": "Discussion rubric for Module 5",
  "source": "red-team:alignment-3 | quality-review:learner_support-2 | user-request",
  "status": "generated|deferred|declined",
  "output_path": "Optional — set when status=generated, points to the generated file."
}
```
