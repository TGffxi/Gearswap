# HANDOFF — Rahvin GearSwap 2.1.0 → Ashita v4 / LuAshitacast

**Date:** 2026-10-03  
**Purpose:** Exact continuation point for a new ChatGPT chat.  
**Repository:** `TGffxi/Gearswap`  
**Branch policy:** **MASTER ONLY. Do not create feature/sync/temp/RC/work branches or PRs unless the user explicitly changes this decision.**

---

## 0. READ THIS FIRST — exact continuation point

This document is the authoritative handoff for the current continuation.

The last user-witnessed fully GREEN product checkpoint is:

- commit: `7cb215acfbdabba02daf3e3cf108ccc0568185d6`
- command: `luajit tests/run.lua all`
- result: **40 passed, 0 failed**

After that GREEN checkpoint, the assistant added the next TDD RED contract directly to `master`:

- `4ae97ef4cfafaa9d6bf07ecdcd4cd506b8610dc4` — `test: require full production windower platform surface`
- `99d2686dd8b3a012ac55f90abb45a5158d73e593` — `test: register full platform windower surface suite`

At the moment this handoff is written, the user has **not yet pulled/run** that new `platform_windower` RED suite. The handoff commit itself only adds this documentation file; it is not product implementation.

### Immediate next user action

In Termux:

```bash
cd ~/Gearswap
git pull --ff-only
luajit tests/run.lua platform_windower
```

The expected TDD state is RED because `ashita.platform` does not yet provide the complete production Windower/runtime surface required by `compat.windower` and `compat.environment`. Do not guess the exact failing assertion: read the user's actual output first.

### Immediate next assistant action after the user pastes RED output

1. Treat that output as the witnessed RED gate.
2. Use systematic debugging: identify the exact missing methods/contracts from `tests/ashita/test_platform_windower.lua` and current `ashita/platform.lua`.
3. Fetch every file immediately before modifying it.
4. Implement the **smallest production surface necessary** in `ashita/platform.lua` and, only if required by the approved architecture, narrowly related Ashita adapter files.
5. Do **not** modify upstream `RahvinGS/` files just to accommodate Ashita API differences.
6. Ask the user to run:

```bash
luajit tests/run.lua platform_windower
luajit tests/run.lua all
```

7. Do not claim GREEN until the user supplies the output.

---

## 1. User workflow and hard project decisions

The user wants a tight implementation loop:

- assistant audits and implements independently;
- assistant writes directly to GitHub `master`;
- user executes Termux test commands and pastes output;
- assistant proceeds immediately from witnessed RED/GREEN evidence;
- no repetitive confirmation prompts;
- no Codex Cloud workflow;
- no PR workflow;
- no feature branches.

The user works in Android Termux for test execution:

- repo: `~/Gearswap`
- remote: HTTPS GitHub fork
- Git 2.56
- gh 2.102
- LuaJIT 2.1

Termux is **developer tooling only**. Shipped code must never depend on Termux.

Process rules:

- TDD: witness RED before implementation.
- On failure: root-cause investigation before fixing.
- Fetch current GitHub file immediately before modifying it.
- Master-only.
- Never fabricate live-client evidence.
- Do not claim a test passed without user output.
- Minimize direct edits to upstream Rahvin files.

---

## 2. Product goal

Port **Rahvin GearSwap 2.1.0** to **Ashita v4 + LuAshitacast** with full functional parity while preserving an easy path for future Rahvin releases.

Selected architecture:

- Rahvin engine semantics remain authoritative.
- Rahvin source paths remain intact wherever possible.
- LAC is the normal equip/action backend.
- GearSwap/Windower behavior is supplied by compatibility/platform adapters.
- Ashita-specific code stays under `ashita/` and compatibility code under `compat/`.
- Adapter first; direct Rahvin edit only when an adapter cannot preserve behavior.

Change classes:

- **A — UPSTREAM CLEAN**
- **B — COMPAT**
- **C — ASHITA PATCH**

Architectural target: maximize A/B, minimize C.

No Class-C Rahvin engine patch has been required so far in the work covered by this handoff.

---

## 3. Pinned baselines

Rahvin upstream:

- repo: `RahvinCode/Gearswap`
- feature baseline: tag `2.1.0`
- commit: `f1cda1e41f567b16ec592e6598cda71bb04392d0`
- release asset: `Rahvin.GS.2.1.zip`
- asset SHA-256: `0111cb34cdfb800f58ab495480b383d922f9e5846f41f40d7b39400432f2ab01`

Fork:

- repo: `TGffxi/Gearswap`
- default branch: `master`
- public
- master-only development

Pinned runtime design baselines:

- LuAshitacast: `7ed398edd3ebbdc8af86a79e5d3427da42e3a34a`
- Ashita v4 beta: `4171c74c8ddb2ca2a31654f199e6c1cee40d7256`

Approved design/spec:

- `docs/superpowers/specs/2026-10-03-rahvings-ashita-port-design.md`

Plans:

- `docs/superpowers/plans/2026-10-03-01-foundation-compat.md`
- `docs/superpowers/plans/2026-10-03-02-core-gear-parity.md`
- `docs/superpowers/plans/2026-10-03-03-special-systems.md`
- `docs/superpowers/plans/2026-10-03-04-display-settings-commands.md`
- `docs/superpowers/plans/2026-10-03-05-samples-release-upstream.md`

Do not re-brainstorm the overall architecture; it is already approved.

---

## 4. Phase status

### Phase 1 — Foundation / compatibility

**Complete.**

Core GearSwap compatibility primitives, slots, sets, modes, include/environment surface and foundation contracts are implemented and tested.

### Phase 2 — Core gear parity

**Complete and previously accepted.**

Implemented/tested areas include:

- action normalization;
- spell/ability taxonomy;
- SELF/target semantics;
- recast semantics;
- action runtime;
- synthetic exactly-once aftercast behavior;
- resend behavior;
- selective busy gating;
- state runtime;
- merge/set parity;
- bootstrap fixtures.

Phase 2 user-witnessed suite previously reached 18/18 and has remained green in later full runs.

### Phase 3 — Special systems

**Automated implementation largely complete; live gate still outstanding.**

Implemented/tested:

- Ashita event registry;
- shared scheduler;
- packet bridge;
- Treasure Hunter parity;
- same-machine SpellReceived IPC;
- wall-clock IPC timestamps;
- inventory adapter;
- recast adapter;
- extdata behavior;
- enchanted-item/Hoxne parity;
- raw Ashita packet decoder;
- Windower-shaped runtime event bridge;
- event callback isolation;
- lifecycle integration of runtime events.

Still requires final live-client evidence for special systems.

### Phase 4 — Display / settings / commands / lifecycle

**Automated implementation substantially complete; live gate still outstanding.**

Implemented/tested:

- character-scoped settings store;
- command bridge;
- keybind adapter;
- display abstraction for classic/harness/lattice/halo;
- lifecycle teardown/reload behavior;
- bootstrap/lifecycle integration;
- single frame owner for scheduler;
- runtime events tied into lifecycle.

Still missing/unfinished before Phase 4 can be called release-complete:

- concrete production display renderer/live proof;
- repeated real Windows/Ashita settings save proof;
- live load→reload→zone→logout→login proof;
- complete production composition root.

### Phase 5 — samples / install / release / upstream maintenance

**Not started as a phase.**

Do not begin release/tag work before production composition and live gates are ready.

---

## 5. Last verified automated state

User-witnessed on local commit `7cb215acfbdabba02daf3e3cf108ccc0568185d6`:

```text
luajit tests/run.lua lifecycle_runtime_events
PASS tests.ashita.test_lifecycle_runtime_events
RESULT 1 passed, 0 failed

luajit tests/run.lua lifecycle
PASS tests.ashita.test_lifecycle
RESULT 1 passed, 0 failed

luajit tests/run.lua all
...
RESULT 40 passed, 0 failed
```

That is the **last fully verified GREEN checkpoint**.

Current `master` after that checkpoint includes the intentional next RED test (`platform_windower`) and this handoff documentation. Do not describe current `master` as 40/40 until the new test has been implemented and a fresh full run proves it.

---

## 6. Important recent implementation details

### Scheduler/lifecycle ownership

Resolved issue: `ashita.scheduler` previously had its own hidden frame binding while lifecycle also owned a `d3d_present` handler.

Final architecture:

- lifecycle is the sole frame owner;
- scheduler is event-agnostic;
- lifecycle drives `scheduler.tick()`;
- later lifecycle integration also drives IPC polling and Rahvin prerender through the same frame.

This was user-witnessed green before subsequent work.

### IPC

`ashita/ipc.lua`:

- versioned `RGSIPC` wire format;
- same-machine UDP multicast;
- group `239.255.82.71`;
- port `38471`;
- multicast TTL 0;
- LuaSocket wall clock uses `socket.gettime()*1000`;
- malformed, stale and duplicate messages are rejected;
- subscribers are isolated;
- `send_rahvin`/`to_rahvin` bridge unchanged Rahvin message semantics.

Actual two-client Windows/Ashita live proof is still pending.

### Raw packet decoder

`ashita/packet_decoder.lua` now handles:

- incoming `0x028` action packet into Rahvin/GearSwap-shaped action structure;
- category/param/targets/actions;
- add-effect/skillchain fields;
- spike/react fields;
- `0x00A` zone id from offset `0x30`;
- target index from Ashita target manager.

`ashita/packets.lua` uses this decoder by default in production.

Automated packet decoder tests were user-witnessed green and remained green in the 40/40 run.

### Runtime events

`ashita/runtime_events.lua` bridges:

- Ashita `packet_in` → Rahvin `incoming chunk`, `action`, `zone change`;
- Ashita `packet_out` → Rahvin `outgoing chunk` and target change tracking;
- frame → Rahvin `prerender`;
- IPC → Rahvin `ipc message`;
- logout → Rahvin `logout`;
- unload → clear Windower-shaped Rahvin event handlers and packet target baseline.

`ashita.platform:emit()` isolates handler failures with `pcall`, so an error in one `prerender` handler does not block later handlers.

### Lifecycle/runtime-events integration

`ashita/lifecycle.lua` at `7cb215a`:

- opens fresh IPC on load;
- registers runtime packet hooks;
- attaches the same fresh IPC service to runtime events;
- one frame drives exactly: scheduler → IPC poll → Rahvin prerender;
- Rahvin logout handler runs before teardown;
- runtime IPC listener detaches before socket close;
- logout→load creates and attaches a new IPC generation;
- unload clears the completed Rahvin Windower-shaped handler generation.

---

## 7. Current blocking problem — the exact place to continue

`ashita/profile.lua` is currently only a configured delegate wrapper around `ashita.bootstrap`:

```lua
profile.Configure(deps)
```

It is **not yet** the final installable production composition root.

Before constructing that composition root, the current audit found a concrete prerequisite:

`compat.windower.new(platform)` and `compat.environment.install_runtime(env, platform)` expect a broader production platform surface than `ashita/platform.lua` currently supplies.

The new test is:

- `tests/ashita/test_platform_windower.lua`
- registered as suite `platform_windower`

The intended contract includes the production-facing methods required by Rahvin/Windower compatibility, covering at least:

- chat output;
- queued commands;
- chat/input;
- Windower event registration surface;
- `get_info`;
- `get_items`;
- `get_abilities`;
- ability recasts;
- spell recasts;
- party;
- player;
- mob/entity lookup by id/index;
- window settings;
- wildcard matching (`wc_match`);
- outgoing packet injection;
- scheduler integration;
- wall clock;
- config load/save bridge;
- extdata/decode bridge;
- file bridge;
- resource collections;
- primitive operations used by the legacy Rahvin rendering surface where still required by compatibility.

The implementation must use real Ashita/LAC APIs behind the adapter, not fake/no-op production behavior. Unsupported behavior must fail loudly with a precise compatibility error unless the approved design intentionally maps it another way.

### Critical shared-service rule

The production platform scheduler must use the **same scheduler queue identity** that lifecycle ticks. Do not accidentally create a separate scheduler instance/queue for `coroutine.schedule`; otherwise Rahvin startup/deferred work will be queued but never executed.

Likewise, Windower-shaped `register_event` must register Rahvin handlers into the same platform event surface consumed by `ashita.runtime_events`; do not bypass it with a separate event registry.

---

## 8. Files to fetch before implementing the current RED

Fetch current versions immediately before modifying:

- `tests/ashita/test_platform_windower.lua`
- `ashita/platform.lua`
- `compat/windower.lua`
- `compat/environment.lua`
- `ashita/scheduler.lua`
- `ashita/inventory.lua`
- `ashita/recasts.lua`
- `ashita/settings.lua`
- `ashita/events.lua`
- `ashita/runtime_events.lua`
- `ashita/lifecycle.lua`
- `ashita/profile.lua`

Also inspect pinned Ashita/LAC source when an API name or return shape is uncertain. Do not invent an Ashita API.

---

## 9. Production composition work after `platform_windower` is GREEN

Once `platform_windower` and the full suite are green, the next implementation target is the **actual production composition root**.

Required high-level assembly:

1. Create one production `ashita.platform` instance/shared service surface.
2. Create/install the GearSwap compatibility environment.
3. Install `compat.gearswap` using the LAC equip backend.
4. Install `compat.windower` backed by the same platform instance.
5. Install runtime compatibility modules (`config`, `resources`, `extdata`, `socket`, files).
6. Load unchanged Rahvin engine/job logic in that environment.
7. Build the action/state runtimes and LAC bootstrap callbacks.
8. Build `ashita.runtime_events` against the same platform.
9. Build lifecycle using the same scheduler/events/platform/IPC services.
10. Ensure settings, commands, keybinds and display services are character-scoped and lifecycle-owned.
11. Expose a thin LuAshitacast profile entry/stub suitable for real installation.

Do this via a new RED integration test first. Do not jump directly to an install stub without proving the composition contract.

---

## 10. Known live gates that must not be faked

Before first release/tag, real Windows/Ashita/LuAshitacast evidence is still needed for at least:

- profile load under pinned/recorded Ashita + LAC revisions;
- melee/spell/ability/WS/ranged action timing;
- synthetic aftercast on normal completion and interrupt;
- TH target/action/death behavior;
- actual raw packet behavior against live client;
- SpellReceived with two actual local clients/instances;
- Hoxne critical windows;
- enchanted-item cooldown and duplicate item handling;
- zoning resets;
- logout/login/reload cleanup;
- no duplicate/stale event handlers;
- no stale display overlay;
- concrete display renderer;
- repeated settings save/replace behavior on Windows;
- sample jobs in Phase 5.

Any live failure must first become a regression fixture before code is changed.

---

## 11. Phase 5 later — do not skip ahead

After composition root and live-capable runtime are ready:

1. sample-job compatibility matrix;
2. install layout/profile stub/manifest;
3. full regression gate from clean checkout;
4. live release acceptance;
5. master-only upstream-sync dry run;
6. release metadata/tag only after every required gate passes.

Plan file:

- `docs/superpowers/plans/2026-10-03-05-samples-release-upstream.md`

---

## 12. New-chat operating instruction

The new chat should start by reading this file fully, then the approved design and the relevant Phase 3/4/5 plans as needed. It must continue from the explicit resume point rather than re-auditing completed Phases 1–2 or re-opening approved architectural decisions.

**Resume point:** witness `platform_windower` RED from the user, implement the full production Windower platform surface via adapters, re-run focused test + full suite, then move to a RED test for the real production composition root.
