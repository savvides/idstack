# Documentation Accuracy Audit & Automated Verification Design

**Date:** 2026-08-12  
**Status:** Approved  
**Target Component:** Repository Documentation (`README.md`, `docs/index.html`, `CLAUDE.md`, `DESIGN.md`, `CONTRIBUTING.md`, `TODOS.md`, `ROADMAP.md`, `PRIVACY.md`, `skills/*/SKILL.md`) & Test Suite Integration

---

## 1. Executive Summary

This design specifies a comprehensive audit and automated verification framework for all documentation surfaces in the `idstack` repository. The goal is twofold:
1. Immediately reconcile and correct all text inaccuracies across public, developer, planning, and skill documentation surfaces.
2. Build an automated verification gate (`test/check-doc-accuracy.py`) integrated into `test/smoke-test.sh` and guarded by `test/mutation-test.sh` to ensure documentation never drifts from code implementation in future releases.

---

## 2. Scope of Audit & Reconciliations

### 2.1 Public & User Documentation (`README.md`, `docs/index.html`, `PRIVACY.md`)
- **Setup & Installation**: Verify that installation steps in `README.md` match actual behavior in `setup` (WSL / Git Bash instructions for Windows, single-host Claude Code setup, removal of any legacy flags).
- **CLI Options**: Audit all documented commands (`bin/idstack-status`, `bin/idstack-doctor`, `bin/idstack-manifest-merge`, `bin/idstack-gen-skills`) to ensure flags like `--readiness`, `--help`, and `--version` match source implementation.
- **Privacy Disclosures**: Confirm Privacy FAQ and `PRIVACY.md` accurately disclose local storage defaults and network endpoints (Canvas API POSTs for import/export and hourly `git fetch` update checks).

### 2.2 Developer & Architecture Documentation (`CLAUDE.md`, `DESIGN.md`, `CONTRIBUTING.md`)
- **Workflow & Testing Commands**: Ensure test execution instructions (`bash test/smoke-test.sh`, `bash test/mutation-test.sh`, `python3 test/check-evidence-cards.py`) are accurate.
- **Architecture Model**: Reconcile architecture diagrams and layout descriptions in `DESIGN.md` with the single-host Claude Code plugin structure (`.claude-plugin/plugin.json`, `skills/<name>/SKILL.md`).
- **Contributing Guidelines**: Ensure contributing steps align with current versioning practices.

### 2.3 Planning & Backlog Documentation (`TODOS.md`, `ROADMAP.md`, `CHANGELOG.md`)
- **Status Alignment**: Audit `TODOS.md` and `ROADMAP.md` against current code state to ensure completed features are marked as complete and quantitative metrics (e.g. mutation suite count) reflect actual counts.
- **Changelog**: Verify `CHANGELOG.md` versioning matches `VERSION` (`3.4.0.1`).

### 2.4 Skill & Template Documentation (`skills/*/SKILL.md`, `templates/`)
- **Schema & Preamble**: Ensure all generated skill files in `skills/*/SKILL.md` inline the canonical Manifest Schema (version 1.4) and preamble resolution snippets without legacy path fallbacks.

---

## 3. Automated Verification Gate (`test/check-doc-accuracy.py`)

A new Python script `test/check-doc-accuracy.py` will be created to validate documentation integrity automatically.

### 3.1 Validator Checks
1. **Version Parity**:
   - Asserts exact string match for version numbers across `VERSION`, `.claude-plugin/plugin.json`, `README.md` (badges/text), and `docs/index.html`.
2. **Binary & Flag Validation**:
   - Parses markdown code blocks across `README.md`, `CLAUDE.md`, and `CONTRIBUTING.md`.
   - Verifies that all referenced `bin/*` or `./setup` binaries exist and are executable.
   - Asserts that CLI flags mentioned in docs (e.g., `--readiness`, `--help`) are valid options in the script `--help` output or source script definitions.
3. **Skill Template & Directory Parity**:
   - Verifies that every directory in `skills/` contains a valid `SKILL.md` with auto-generated headers matching `templates/preamble.md` and `bin/idstack-gen-skills`.
4. **Local Link Integrity**:
   - Parses all relative file links in markdown (`[text](file.md)`) and verifies that target files exist in the repository.

### 3.2 Test Suite Integration (`test/smoke-test.sh`)
- `test/smoke-test.sh` will invoke `test/check-doc-accuracy.py` as a core check:
  ```bash
  check "documentation accuracy validator passes" python3 test/check-doc-accuracy.py "$REPO_ROOT"
  ```

---

## 4. Mutation Testing & Self-Healing Protections (`test/mutation-test.sh`)

To prove `test/check-doc-accuracy.py` actively catches documentation regressions, `test/mutation-test.sh` will be expanded with two new mutation test cases:
1. **Version Mismatch Mutation**: Mutate version in `VERSION` vs `README.md` and assert that `smoke-test.sh` fails.
2. **Hallucinated Flag Mutation**: Inject an invalid CLI flag (e.g. `--invalid-fake-flag`) into `README.md` command examples and assert that `smoke-test.sh` fails.

---

## 5. Verification Plan

1. Execute `python3 test/check-doc-accuracy.py .` to ensure the validator runs cleanly.
2. Execute `bash test/smoke-test.sh` to verify all 355+ smoke test assertions pass.
3. Execute `bash test/mutation-test.sh` to verify all 26 mutation suites pass with 0 unguarded cases.
