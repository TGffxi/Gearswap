# RahvinGS Ashita Phase 5 — Sample Jobs, Release and Upstream Maintenance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Verify all shipped Rahvin 2.1 sample jobs, package an installable Ashita/LAC release, and prove the future Rahvin-update workflow works on `master` only.

**Architecture:** Preserve upstream sample files wherever compatibility can make them run. Installation adds a small LAC bootstrap plus the port's compat/ashita modules. Release metadata records upstream and tested Ashita/LAC revisions independently.

**Tech Stack:** LuaJIT, Ashita v4, LuAshitacast, Git/GitHub `master` only.

**Spec:** `docs/superpowers/specs/2026-10-03-rahvings-ashita-port-design.md`

## Global Constraints

Full parity release requires no silently omitted Rahvin feature. Every sample job has a status. Direct upstream edits are ledgered. Release metadata includes Rahvin upstream version/commit, Ashita-port version, tested LAC commit and tested Ashita commit.

## Review Focus

- A sample job that loads but skips a custom hook is not counted as compatible.
- Install docs must not require repository layout knowledge or Termux.
- Upstream update procedure must never create a non-`master` branch.
- Existing user gear files must have a deterministic migration/use path.
- Release claims distinguish automated parity from live-client verification.

---

### Task 1: Sample-job compatibility matrix

**Files:** `tests/parity/test_sample_jobs.lua`, `docs/SAMPLE_JOB_MATRIX.md`, compatibility modules as required.

**Interfaces:** Harness loads every `Sample Job Files/*.lua` in a mocked character/job environment and reports load/custom-hook/decision status.

- [ ] Enumerate sample files from repository, not a hard-coded subset.
- [ ] Add failing load test for every sample job.
- [ ] Fix compatibility adapters first; any required sample/upstream edit gets a ledger entry and per-job regression fixture.
- [ ] Add at least idle, engaged, one spell/ability/WS path per applicable job.
- [ ] Run `luajit tests/run.lua sample_jobs`; PASS.
- [ ] Commit `test: verify all rahvin sample jobs on ashita`.

### Task 2: Installation layout and bootstrap generator

**Files:** `install/README.md`, `install/profile_stub.lua`, `ashita/manifest.lua`, `tests/install/test_layout.lua`.

**Interfaces:** `manifest` exposes version fields; profile stub loads the shared RahvinGS Ashita bootstrap without copying engine logic into each job profile.

- [ ] Test manifest exact fields and install-tree completeness.
- [ ] Define copy locations for shared port files and per-character LAC profile stub.
- [ ] Document manual install with Windows paths; Termux may be mentioned only as optional developer tooling.
- [ ] Run layout tests; PASS.
- [ ] Commit `docs: add ashita installation layout`.

### Task 3: Full automated regression gate

**Files:** `tests/run.lua`, `docs/TEST_MATRIX.md`.

- [ ] Add `all` suite ordering: baseline→compat→core parity→special systems→settings/display/commands→sample jobs→install layout.
- [ ] Ensure any failure returns non-zero and names suite/test.
- [ ] Run `luajit tests/run.lua all`; PASS from clean checkout.
- [ ] Record command and result in `TEST_MATRIX.md`.
- [ ] Commit `test: establish full rahvings ashita regression gate`.

### Task 4: Live release acceptance

**Files:** `docs/LIVE_ACCEPTANCE.md`, `docs/RELEASE_BASELINES.md`.

- [ ] Run representative mage, melee, ranged, pet, BRD/GEO, TH, SpellReceived, Hoxne/enchant, display/settings/lifecycle cases in live Ashita.
- [ ] Verify callback/equip timing, cancel/interrupt, duplicate augmented items and zoning/logout.
- [ ] Record exact Ashita and LAC revisions plus pass/fail evidence.
- [ ] Any failure first becomes an automated regression fixture, then is fixed and re-tested.
- [ ] Commit `test: complete ashita live acceptance` after all required cases pass.

### Task 5: Master-only upstream-sync dry run

**Files:** `docs/UPSTREAM_UPDATE.md`, `docs/UPSTREAM_PATCH_LEDGER.md`, `tests/maintenance/test_upstream_metadata.lua`.

**Interfaces:** Documented procedure uses local `upstream` remote when available and never creates another branch.

- [ ] Document exact sequence: clean `master` → `git fetch upstream --tags` → inspect diff → `git merge --no-commit --no-ff <ref>` on `master` → test → commit or `git merge --abort`.
- [ ] Enable/document `git rerere`, with explicit rule that reused resolutions still require full affected tests.
- [ ] Perform a dry run against a harmless/synthetic upstream delta or next Rahvin release without publishing an untested merge.
- [ ] Verify the patch ledger and porting matrix make every conflict attributable.
- [ ] Commit `docs: prove master-only upstream update workflow`.

### Task 6: First Ashita release

**Files:** `CHANGELOG-ASHITA.md`, `ashita/manifest.lua`, release notes.

- [ ] Set `rahvin_upstream_version`, `rahvin_upstream_commit`, `ashita_port_version`, `luashitacast_tested`, `ashita_v4_tested` from verified baselines.
- [ ] Run `luajit tests/run.lua all` and live acceptance again from the release tree.
- [ ] Confirm `docs/PORTING_MATRIX.md` has no required feature silently omitted and no unledgered class-C patch.
- [ ] Tag only after all gates pass; release naming follows `RahvinGS-Ashita 2.1.0+a<port-version>` or the final agreed equivalent.
- [ ] Commit release metadata on `master` before tag.

## Phase 5 Exit Gate

The fork has an installable, tested Ashita/LAC release with full Rahvin 2.1 feature accounting and a proven master-only process for importing future Rahvin changes.
