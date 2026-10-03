# RahvinGS Ashita Phase 2 — Core Gear Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Route normal player actions and default-state gear through LuAshitacast while preserving Rahvin's logical set decisions and weapon-lock semantics.

**Architecture:** A LAC bootstrap translates documented `gData` action/player/environment objects into GearSwap-shaped Rahvin inputs. Rahvin builds the logical set; a backend translates slots and submits the set through public `gFunc` calls. Because LAC has no `aftercast` profile callback, an explicit action-state machine owns exactly-once completion.

**Tech Stack:** LuaJIT 2.1, LuAshitacast public `gData`/`gFunc`, Ashita v4.

**Spec:** `docs/superpowers/specs/2026-10-03-rahvings-ashita-port-design.md`

## Global Constraints

Same repository/baseline/master-only/Termux/upstream-clean constraints as Phase 1. Normal equips use LAC buffering (`gFunc.EquipSet`, `gFunc.Disable`, `gFunc.Enable`, `gFunc.CancelAction`) rather than direct packets.

## Review Focus

- `aftercast` fires exactly once for success, interruption, cancellation, and action disappearance.
- WS never swaps protected main/sub/range slots contrary to Rahvin 2.1 rules.
- Ranged preshot/midshot ordering does not leak spell semantics.
- Duplicate augmented item descriptors survive slot translation unchanged.
- Default/status refresh never strips cast gear while Rahvin considers the character busy.

---

### Task 1: LAC action and entity translation

**Files:** `ashita/lac_data.lua`, `tests/ashita/test_lac_data.lua`.

**Interfaces:** `lac_data.action(gData) -> spellLike|nil`, `lac_data.player(gData)`, `lac_data.pet(gData)`, `lac_data.world(gData)`, `lac_data.target(gData)`.

- [ ] Write failing fixtures for Spell, Weaponskill, Ability, Ranged, Item, target distance/status, day/weather, and nil action.
- [ ] Run `luajit tests/run.lua lac_data`; expect FAIL.
- [ ] Implement mapping from documented LAC members (`ActionType`, `Name`, `Id`, `Skill`, `Type`, `CastTime`, `Recast`, target and environment fields) to Rahvin-facing fields including `english`, `name`, `id`, `type`, `action_type`, `target`, `element`, `skill`, `recast_id` where available.
- [ ] Run suite; expect PASS.
- [ ] Commit `feat: translate lac action data for rahvin`.

### Task 2: LAC equipment backend

**Files:** `ashita/equip_backend.lua`, `tests/ashita/test_equip_backend.lua`.

**Interfaces:** `backend.new(gFunc)`, methods `equip(set)`, `enable(slot)`, `disable(slot)`, `cancel_action()`, `flush()`.

- [ ] Write failing tests for slot translation, buffered multi-set precedence, enable/disable, cancel, and preservation of `{Name,Augment,AugPath,AugRank,AugTrial,Bag}` descriptors.
- [ ] Run `luajit tests/run.lua equip_backend`; expect FAIL.
- [ ] Implement using public `gFunc.EquipSet`, `gFunc.Enable`, `gFunc.Disable`, `gFunc.CancelAction`; no `ForceEquip` in this task.
- [ ] Run suite; expect PASS.
- [ ] Commit `feat: add luashitacast equip backend`.

### Task 3: Action lifecycle state machine

**Files:** `ashita/action_runtime.lua`, `tests/ashita/test_action_runtime.lua`.

**Interfaces:** `runtime.new(engine, clock)`, `begin(action)`, `midcast(action)`, `tick(currentAction)`, `cancelled()`, `reset()`.

- [ ] Write failing tests for `pretarget→precast`, spell `midcast`, ranged `preshot→midshot`, ability/WS/item single-phase handling, transition to nil causing one `aftercast`, interrupted/replaced action causing one old `aftercast`, and repeated nil ticks causing no duplicate completion.
- [ ] Run `luajit tests/run.lua action_runtime`; expect FAIL.
- [ ] Implement deterministic action identity (`ActionType+Id+target id/index+start generation`) and exactly-once completion.
- [ ] Run suite; expect PASS.
- [ ] Commit `feat: add rahvin action lifecycle adapter`.

### Task 4: Build LuAshitacast bootstrap profile

**Files:** `ashita/bootstrap.lua`, `ashita/profile.lua`, `tests/ashita/test_bootstrap.lua`.

**Interfaces:** `bootstrap.create(deps) -> profile`; profile exposes `OnLoad`, `OnUnload`, `HandleCommand`, `HandleDefault`, `HandleAbility`, `HandleItem`, `HandlePrecast`, `HandleMidcast`, `HandlePreshot`, `HandleMidshot`, `HandleWeaponskill`.

- [ ] Write failing callback-routing tests with mocked `gData`/`gFunc`.
- [ ] Run `luajit tests/run.lua bootstrap`; expect FAIL.
- [ ] Implement callback routing through snapshot + action runtime + Rahvin globals. `HandleDefault` owns action completion detection and normal-state rebuild requests.
- [ ] Run suite; expect PASS.
- [ ] Commit `feat: add luashitacast rahvin bootstrap`.

### Task 5: Default/status/buff transition bridge

**Files:** `ashita/state_runtime.lua`, `tests/ashita/test_state_runtime.lua`.

**Interfaces:** `state_runtime.new(engine)`, `update(snapshot)`.

- [ ] Write failing tests for Idle↔Engaged↔Resting status transitions, buff add/remove diffing by id/name, pet appear/disappear, and no duplicate events for unchanged snapshots.
- [ ] Run suite; expect FAIL.
- [ ] Implement diffs calling upstream globals `status_change`, `buff_change`, `pet_change`; defer buff-driven redress only according to Rahvin's own busy/cast guards.
- [ ] Run suite; expect PASS.
- [ ] Commit `feat: bridge lac state transitions to rahvin hooks`.

### Task 6: Decision-contract parity fixtures

**Files:** `tests/parity/test_core_sets.lua`, `tests/fixtures/core_cases.lua`, `docs/PORTING_MATRIX.md`.

**Interfaces:** Fixture runner returns final logical GearSwap-shaped set before LAC slot translation.

- [ ] Add failing cases for idle/engaged, TP/ACC/DT/PDL/SB/CRIT/MEVA where present, named Savage Blade overlay, ranged WS, Aftermath, weapon lock, Dual Wield/two-hand, movement, buff overlay, day/weather, Cure Light Bonus, BRD instrument and GEO handbell exceptions.
- [ ] Run `luajit tests/run.lua parity_core`; failures identify parity gaps.
- [ ] Fix adapters only; class-C upstream edits require ledger entry plus dedicated regression test.
- [ ] Run `luajit tests/run.lua all`; expect PASS.
- [ ] Commit `test: lock core rahvin gear parity`.

## Phase 2 Exit Gate

A representative LAC profile can execute normal spell/WS/JA/ranged/item/default flows through mocks with Rahvin-equivalent logical sets. Live-client timing remains a later integration gate.
