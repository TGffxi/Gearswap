# RahvinGS Ashita Phase 1 — Foundation and Compatibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make upstream RahvinGS load in a deterministic LuaJIT test harness with GearSwap/Windower compatibility primitives, without changing Rahvin product code.

**Architecture:** Keep `RahvinGS/` upstream-clean. New code in `compat/` emulates only the GearSwap/Windower surface Rahvin consumes; `ashita/` owns LAC/Ashita adapters. Pure tests run under LuaJIT without a live FFXI client.

**Tech Stack:** LuaJIT 2.1, Ashita v4, LuAshitacast, plain Lua test harness.

**Spec:** `docs/superpowers/specs/2026-10-03-rahvings-ashita-port-design.md`

## Global Constraints

- Repository: `TGffxi/Gearswap`.
- Development branch: `master` only; no temporary, feature, sync, or release branches.
- Feature baseline: Rahvin GearSwap `2.1.0`, commit `f1cda1e41f567b16ec592e6598cda71bb04392d0`.
- Fork starting snapshot: Rahvin master `8bca6c48d437f93932ccf38313ae3d0a472b626e`.
- LuAshitacast design baseline: `7ed398edd3ebbdc8af86a79e5d3427da42e3a34a`.
- Ashita v4 design baseline: `4171c74c8ddb2ca2a31654f199e6c1cee40d7256`.
- Termux is optional tooling only and must never be a runtime dependency.
- Upstream `RahvinGS/` files are not edited unless an adapter cannot provide parity; every such edit is class C and goes in the patch ledger.
- Every task lands directly on `master` only after its tests pass.

## Review Focus

- Slot aliases (`lear/rear/lring/rring`) must map deterministically without mutating upstream sets.
- `M{}` state objects must preserve `.value`, option order, cycling and explicit set behavior used by Rahvin/sample jobs.
- Includes must resolve Rahvin-relative modules without accidentally loading Windower modules from the host environment.
- Compatibility errors must be explicit; unsupported calls must not silently no-op.
- State snapshots must be internally consistent for the duration of one Rahvin callback.

---

### Task 1: Add test harness and baseline guard

**Files:**
- Create: `tests/run.lua`
- Create: `tests/lib/assertions.lua`
- Create: `tests/fixtures/baselines.lua`
- Create: `docs/RELEASE_BASELINES.md`
- Create: `docs/UPSTREAM_PATCH_LEDGER.md`
- Create: `docs/PORTING_MATRIX.md`

**Interfaces:**
- Produces: `tests/run.lua [suite]` runner with non-zero exit on failure; `assertions.equal`, `assertions.deep_equal`, `assertions.raises`.

- [ ] **Step 1: Write the failing baseline test** asserting the Rahvin/LAC/Ashita commit strings exactly match Global Constraints.
- [ ] **Step 2: Run** `luajit tests/run.lua baseline` and verify it fails because baseline modules do not exist.
- [ ] **Step 3: Implement the minimal runner, assertions, baseline fixture, and baseline documentation.** `UPSTREAM_PATCH_LEDGER.md` starts with no class-C patches; `PORTING_MATRIX.md` lists each file under `RahvinGS/` with initial status `UNAUDITED`.
- [ ] **Step 4: Run** `luajit tests/run.lua baseline` and verify PASS.
- [ ] **Step 5: Commit on `master`** with `test: add ashita port baseline harness`.

### Task 2: Implement set and slot compatibility

**Files:**
- Create: `compat/slots.lua`
- Create: `compat/sets.lua`
- Create: `tests/compat/test_slots.lua`
- Create: `tests/compat/test_sets.lua`

**Interfaces:**
- Produces: `slots.to_lac(name) -> string`, `slots.to_gearswap(name) -> string`, `sets.combine(base, ...) -> table`, `sets.copy(value) -> table`.

- [ ] **Step 1: Write failing tests** for all 16 GearSwap slots, especially `lear→Ear1`, `rear→Ear2`, `lring→Ring1`, `rring→Ring2`, precedence of later tables, nested item-table preservation, and no source mutation.
- [ ] **Step 2: Run** `luajit tests/run.lua compat_sets`; expected FAIL.
- [ ] **Step 3: Implement the four interfaces** with deterministic copy/merge semantics matching GearSwap `set_combine` for equipment-set use.
- [ ] **Step 4: Run** `luajit tests/run.lua compat_sets`; expected PASS.
- [ ] **Step 5: Commit** `feat: add gearswap set compatibility`.

### Task 3: Implement Modes-compatible state objects

**Files:**
- Create: `compat/modes.lua`
- Create: `tests/compat/test_modes.lua`

**Interfaces:**
- Produces: global-compatible constructor `M{...}` and object methods `options(...)`, `cycle()`, `set(value)`, `toggle()` where applicable; `.value` always contains the active option.

- [ ] **Step 1: Write failing tests** for declared option order, wraparound cycling, explicit set, invalid set rejection, boolean toggle, and deterministic string conversion.
- [ ] **Step 2: Run** `luajit tests/run.lua modes`; expected FAIL.
- [ ] **Step 3: Implement only operations observed in `RahvinGS/` and `Sample Job Files/`; unsupported methods raise a named compatibility error.**
- [ ] **Step 4: Run** `luajit tests/run.lua modes`; expected PASS.
- [ ] **Step 5: Commit** `feat: add rahvin mode compatibility`.

### Task 4: Implement controlled include/module environment

**Files:**
- Create: `compat/include.lua`
- Create: `compat/environment.lua`
- Create: `tests/compat/test_include.lua`

**Interfaces:**
- Produces: `include.load(path, env) -> any`, `environment.new(platform) -> table`, `environment.install_globals(env)`.

- [ ] **Step 1: Write failing tests** that `RahvinGS/interface` resolves from repository paths, repeated includes follow Rahvin/GearSwap expectations, missing modules name the requested path, and host `package.path` cannot shadow compatibility modules.
- [ ] **Step 2: Run** `luajit tests/run.lua include`; expected FAIL.
- [ ] **Step 3: Implement path normalization and sandboxed loading.** Install `sets`, `set_combine`, `M`, and compatibility placeholders into the environment, but no Ashita globals in pure tests.
- [ ] **Step 4: Run** `luajit tests/run.lua include`; expected PASS.
- [ ] **Step 5: Commit** `feat: add controlled rahvin include environment`.

### Task 5: Implement snapshot provider contract

**Files:**
- Create: `ashita/snapshot.lua`
- Create: `tests/ashita/test_snapshot.lua`

**Interfaces:**
- Produces: `snapshot.new(provider) -> object`; `object:capture() -> {player, world, buffactive, pet, equipment, inventory}`.
- Provider methods are injected so tests do not require Ashita.

- [ ] **Step 1: Write failing tests** proving one `capture()` uses one provider generation, preserves both buff-name and buff-id lookup, retains duplicate inventory instances, and maps status/day/weather without partial refresh.
- [ ] **Step 2: Run** `luajit tests/run.lua snapshot`; expected FAIL.
- [ ] **Step 3: Implement immutable-per-callback snapshot construction.**
- [ ] **Step 4: Run** `luajit tests/run.lua snapshot`; expected PASS.
- [ ] **Step 5: Commit** `feat: add coherent ashita state snapshots`.

### Task 6: Add minimal GearSwap/Windower compatibility shells and upstream load gate

**Files:**
- Create: `compat/gearswap.lua`
- Create: `compat/windower.lua`
- Create: `compat/resources.lua`
- Create: `compat/config.lua`
- Create: `compat/extdata.lua`
- Create: `tests/contract/test_upstream_load.lua`

**Interfaces:**
- Produces: `gearswap.install(env, backend)`, `windower.new(platform)`, resource/config/extdata adapter tables.
- Backend contract: `equip(set)`, `enable(slot)`, `disable(slot)`, `cancel_action()`, `send_command(text)`, `chat(color,text)`, `schedule(fn,delay)`.

- [ ] **Step 1: Write failing contract test** that loads `RahvinGS/interface.lua` and then the Rahvin composition root far enough to identify every missing compatibility symbol; unsupported APIs must raise `RahvinCompatError:<name>`.
- [ ] **Step 2: Run** `luajit tests/run.lua upstream_load`; expected FAIL listing missing symbols.
- [ ] **Step 3: Implement the minimum compatibility shells required for a complete construction pass under mocked platform services.** Do not edit `RahvinGS/`.
- [ ] **Step 4: Run** `luajit tests/run.lua upstream_load`; expected PASS with no direct upstream modifications.
- [ ] **Step 5: Update** `docs/PORTING_MATRIX.md` for modules proven A/B and commit `feat: load rahvin engine in ashita compatibility harness`.

## Phase 1 Exit Gate

Run `luajit tests/run.lua all`. PASS means the upstream engine can construct in the compatibility harness, all new compatibility code is testable without FFXI, and `RahvinGS/` remains upstream-clean.
