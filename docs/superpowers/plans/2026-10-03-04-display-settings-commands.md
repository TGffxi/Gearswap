# RahvinGS Ashita Phase 4 — Display, Settings and Commands Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reproduce Rahvin 2.1 character settings, commands, keybind behavior, status display styles and lifecycle cleanup on Ashita.

**Architecture:** Keep Rahvin command/display state computation intact where possible. Persist settings in character-scoped Ashita/LAC paths; render via an Ashita renderer adapter; route `gs c` semantics through `/lac fwd` plus optional `/rahvings` convenience command.

**Tech Stack:** LuaJIT, Ashita v4 filesystem/settings/font or ImGui APIs, LuAshitacast.

**Spec:** `docs/superpowers/specs/2026-10-03-rahvings-ashita-port-design.md`

## Global Constraints

Master-only; no Termux dependency; per-character persistence; four Rahvin display styles; cleanup on unload/logout; Rahvin command arguments remain authoritative.

## Review Focus

- Two characters on one PC never overwrite each other's settings.
- Reload/unload does not duplicate keybinds or event handlers.
- Corrupt settings recover predictably without deleting a valid prior file silently.
- Display teardown leaves no stale object at character selection.
- Invalid commands never fall through to unrelated job-file commands when Rahvin would reject them.

---

### Task 1: Character-scoped settings store

**Files:** `ashita/settings.lua`, `tests/ashita/test_settings.lua`.

**Interfaces:** `settings.path(identity)`, `settings.load(identity, defaults)`, `settings.save(identity, value)`.

- [ ] Test character name+id isolation, round-trip of display/chat/debug/warn/info/gearreporting/keybind fields, missing-file defaults, corrupt-file recovery and atomic replacement.
- [ ] Implement under `ashita/config/addons/luashitacast/<CharacterName>_<CharacterId>/rahvings/settings.lua` or equivalent resolved from runtime install/config path.
- [ ] Run suite; PASS.
- [ ] Commit `feat: persist rahvin settings per ashita character`.

### Task 2: Command bridge

**Files:** `ashita/commands.lua`, `tests/parity/test_commands.lua`.

**Interfaces:** `commands.forward(args)`, `commands.register()`, `commands.unregister()`.

- [ ] Add fixtures for `help`, `version`, `display`, `displaymode`, `displaystyle`, `displaypos`, `displaycells`, `debug`, `warn`, `info`, `gearreporting`, `keybind`, mode commands and invalid arguments.
- [ ] Route `/lac fwd ...` to the same Rahvin self-command parser; optional `/rahvings ...` must be a thin alias.
- [ ] Verify save-as-you-change settings behavior.
- [ ] Run suite; PASS.
- [ ] Commit `feat: bridge rahvin commands to ashita`.

### Task 3: Keybind adapter

**Files:** `ashita/keybinds.lua`, `tests/ashita/test_keybinds.lua`.

**Interfaces:** `keybinds.apply(settings)`, `keybinds.clear()`, `keybinds.rebind(action,key)`.

- [ ] Test load, rebind, persistence handoff, collision handling, reload idempotence and unload cleanup.
- [ ] Implement through Ashita command/keybind facilities behind injected command executor.
- [ ] Run suite; PASS.
- [ ] Commit `feat: port rahvin keybind management`.

### Task 4: Renderer abstraction and four display styles

**Files:** `ashita/display.lua`, `tests/ashita/test_display.lua`, `tests/fixtures/display_states.lua`.

**Interfaces:** `display.new(renderer)`, `show(model)`, `hide()`, `move(x,y)`, `destroy()`; renderer owns concrete font/primitive/ImGui objects.

- [ ] Test model-to-render operations for all four styles, visibility, coordinates, cell settings, mode/status changes and destroy idempotence.
- [ ] Implement using one Ashita rendering backend chosen after a minimal live proof; keep rendering API isolated from Rahvin display state.
- [ ] Live-check no stale overlay on logout/character select.
- [ ] Run automated suite; PASS.
- [ ] Commit `feat: port rahvin status display to ashita`.

### Task 5: Lifecycle teardown and reload recovery

**Files:** `ashita/lifecycle.lua`, `tests/ashita/test_lifecycle.lua`, `docs/LIVE_TEST_LIFECYCLE.md`.

**Interfaces:** `lifecycle.load()`, `lifecycle.logout()`, `lifecycle.unload()`, each safe to call once or repeatedly.

- [ ] Test cleanup of events, scheduler, IPC, display, keybinds, held slots and in-flight action state.
- [ ] Verify startup sequencing reproduces Rahvin delayed discovery/display/weapon checks without relying on Windower `coroutine.schedule`.
- [ ] Run live load→reload→zone→logout→login test.
- [ ] Run full suite; PASS.
- [ ] Commit `feat: complete ashita lifecycle parity`.

## Phase 4 Exit Gate

Rahvin's persistent user-facing controls and display work character-by-character under Ashita and survive repeated reload/logout cycles without leaked state.
