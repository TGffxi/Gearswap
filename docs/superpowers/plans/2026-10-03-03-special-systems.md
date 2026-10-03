# RahvinGS Ashita Phase 3 — Special Systems Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port Rahvin's Windower-dependent TH, SpellReceived/multibox, Hoxne, enchanted-item, packet, timer and recovery behavior to Ashita-native adapters.

**Architecture:** Isolate Ashita events/packets/transport behind testable services. Upstream modules continue calling Windower-shaped compatibility functions; adapters translate to `ashita.events` and Ashita/LAC data.

**Tech Stack:** LuaJIT, Ashita v4 events (`packet_in`, packet/outgoing equivalents, `d3d_present`, command/lifecycle events as verified), LuAshitacast.

**Spec:** `docs/superpowers/specs/2026-10-03-rahvings-ashita-port-design.md`

## Global Constraints

Master-only, upstream-clean-first, no external daemon requirement, no Termux dependency. Packet IDs/offsets must be sourced from Ashita v4 or verified live captures and documented next to tests.

## Review Focus

- Malformed or stale multibox messages never lock gear indefinitely.
- Zone/logout resets clear TH, timers, borrowed slots and transport state.
- Duplicate item instances remain distinguishable for Hoxne/enchant logic.
- Packet handlers ignore unrelated actors/events exactly where Rahvin does.
- Frame/timer callbacks are unregisterable and leave no handlers after reload.

---

### Task 1: Ashita event registry and scheduler

**Files:** `ashita/events.lua`, `ashita/scheduler.lua`, `tests/ashita/test_events.lua`, `tests/ashita/test_scheduler.lua`.

**Interfaces:** `events.register(event, alias, fn)`, `events.unregister_all()`, `scheduler.schedule(fn, delay)`, `scheduler.tick(now)`, `scheduler.clear()`.

- [ ] Test alias uniqueness, bulk cleanup, due-time ordering, same-time stable ordering, cancellation on unload, and callback-error isolation.
- [ ] Implement using injected event API; production binds to `ashita.events.register/unregister` and a frame event.
- [ ] Run `luajit tests/run.lua events scheduler`; PASS.
- [ ] Commit `feat: add ashita event and scheduler services`.

### Task 2: Packet/action bridge for TH and polling

**Files:** `ashita/packets.lua`, `tests/ashita/test_packets.lua`, `tests/parity/test_th.lua`.

**Interfaces:** `packets.on_incoming(e)`, `packets.on_outgoing(e)`, `packets.on_action(decoded)`, with decoder injected.

- [ ] Create fixtures for target change, player action, non-player action, zone reset and unrelated packet.
- [ ] Verify packet constants/fields against pinned Ashita source or live capture before implementation.
- [ ] Route only required normalized events to existing Rahvin TH/main-engine handlers.
- [ ] Run TH parity suite; PASS.
- [ ] Commit `feat: port treasure hunter packet bridge`.

### Task 3: Same-machine SpellReceived transport

**Files:** `ashita/ipc.lua`, `tests/ashita/test_ipc.lua`, `tests/parity/test_spellreceived.lua`.

**Interfaces:** `ipc.new(transport)`, `send(message)`, `subscribe(fn)`, `unsubscribe(fn)`, versioned payload `{v,sender,kind,phase,action,target,timestamp}`.

- [ ] Test encode/decode, sender/target identity, malformed payload rejection, stale-message rejection, duplicate message idempotence, subscribe/unsubscribe.
- [ ] Implement first-party same-machine transport without external service; if Ashita lacks native IPC, use a localhost-only LuaSocket transport behind this interface and document it as internal runtime dependency, not Termux/external daemon.
- [ ] Feed decoded messages into Rahvin SpellReceived handlers and test equip/borrow/release/failsafe flows.
- [ ] Run suites; PASS.
- [ ] Commit `feat: port spellreceived multibox transport`.

### Task 4: Inventory/recast/extdata adapters for enchant and Hoxne

**Files:** `ashita/inventory.lua`, `ashita/recasts.lua`, `compat/extdata.lua`, `tests/ashita/test_inventory.lua`, `tests/parity/test_enchant_hoxne.lua`.

**Interfaces:** `inventory.iter_bag(id)`, `inventory.find_all(descriptor)`, `recasts.abilities()`, `recasts.spells()`, `extdata.decode(item) -> augment metadata`.

- [ ] Test supported bags, duplicate same-name instances, augment/path/rank/trial identity, empty slots, cooldown units and unavailable recast data.
- [ ] Implement via LAC/Ashita data where public; do not duplicate LAC matching rules when `gFunc.CompareItem` or equivalent public behavior suffices.
- [ ] Run Hoxne/enchant fixtures including critical window release/retry; PASS.
- [ ] Commit `feat: port hoxne and enchanted item data services`.

### Task 5: Live integration checklist for special systems

**Files:** `docs/LIVE_TEST_SPECIAL_SYSTEMS.md`, `docs/PORTING_MATRIX.md`.

- [ ] Document exact live steps and expected output for TH, multibox SpellReceived, zone resets, Hoxne critical actions, enchanted-item cooldown, reload cleanup.
- [ ] Execute available tests on the Windows/Ashita client; record Ashita/LAC revisions and observed result.
- [ ] Any failure becomes a regression fixture before code change.
- [ ] Run full automated suite after live fixes.
- [ ] Commit `test: verify rahvin special systems on ashita` only when evidence is recorded.

## Phase 3 Exit Gate

All Windower-dependent gameplay systems have Ashita-native adapters, automated state/packet tests pass, and live special-system checks have no unresolved parity blocker.
