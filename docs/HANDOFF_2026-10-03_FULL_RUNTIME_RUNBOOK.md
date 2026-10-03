# AUTHORITATIVE HANDOFF / FULL RUNTIME RUNBOOK
# Rahvin GearSwap 2.1.0 → Ashita v4 / LuAshitacast

**Date:** 2026-10-03  
**Repository:** `TGffxi/Gearswap`  
**Development branch:** `master` only  
**Purpose:** This is the authoritative operating handoff for a completely fresh ChatGPT chat. It supersedes the shorter `docs/HANDOFF_2026-10-03_RUNTIME_COMPOSITION.md` wherever this document is more specific.

---

# 0. MANDATORY FIRST READ / EXACT RESUME POINT

A fresh chat must read this document **completely before changing code, proposing architecture, or asking the user to repeat prior decisions**.

Then read, as needed for the active work, the already approved design and the Phase 3/4/5 plans:

- `docs/superpowers/specs/2026-10-03-rahvings-ashita-port-design.md`
- `docs/superpowers/plans/2026-10-03-03-special-systems.md`
- `docs/superpowers/plans/2026-10-03-04-display-settings-commands.md`
- `docs/superpowers/plans/2026-10-03-05-samples-release-upstream.md`

Do **not** re-audit completed Phase 1 or Phase 2. Do **not** restart architecture selection. Do **not** create branches or PRs.

## Last user-witnessed fully GREEN checkpoint

- commit: `7cb215acfbdabba02daf3e3cf108ccc0568185d6`
- targeted lifecycle-runtime test: **1/1 GREEN**
- targeted lifecycle test: **1/1 GREEN**
- full suite: **40 passed, 0 failed**

The user's actual output showed:

```text
PASS tests.ashita.test_lifecycle_runtime_events
RESULT 1 passed, 0 failed

PASS tests.ashita.test_lifecycle
RESULT 1 passed, 0 failed

...
RESULT 40 passed, 0 failed
```

This is the last fully verified GREEN product checkpoint. Never claim a later checkpoint is GREEN until the user has executed it and pasted the output.

## Current `master` is intentionally beyond that GREEN checkpoint

After `7cb215a`, the next TDD contract was committed to `master`:

- `4ae97ef4cfafaa9d6bf07ecdcd4cd506b8610dc4` — `test: require full production windower platform surface`
- file: `tests/ashita/test_platform_windower_surface.lua`
- `99d2686dd8b3a012ac55f90abb45a5158d73e593` — registers suite `platform_windower` in `tests/run.lua`
- `7819fc806085dd4d56cf3559075462b8ae205342` — shorter handoff documentation only

At the time this full runbook is created, **the user has not yet executed `platform_windower`**. Therefore the current state is:

- previous code checkpoint: 40/40 GREEN at `7cb215a`;
- current master: contains a new, intentionally unexecuted RED contract;
- next human action: run that RED test;
- next assistant action: only after seeing the actual RED output, root-cause it and implement the missing production platform surface.

## Exact next user command

```bash
cd ~/Gearswap
git pull --ff-only
luajit tests/run.lua platform_windower
```

The suite is expected to be RED because `ashita/platform.lua` currently provides only part of the Windower/runtime production surface. **Do not predict or invent the exact assertion text. Use the user's actual output as the witnessed RED.**

---

# 1. WHAT WE ARE BUILDING

We are porting **Rahvin GearSwap 2.1.0** from Windower/GearSwap to **Ashita v4 + LuAshitacast**, with **full functional parity**, while preserving an easy path for importing future Rahvin releases.

This is not a rewrite of Rahvin as a new native LAC project. The approved architecture is deliberately compatibility-oriented:

```text
LuAshitacast callbacks / Ashita events
          ↓
ashita/* production adapters
          ↓
compat/* GearSwap + Windower compatibility surface
          ↓
unchanged Rahvin engine/job semantics
          ↓
LAC equip/action backend
```

The objective is that Rahvin's engine continues to decide *what* should happen, while Ashita/LAC adapters provide the runtime primitives that Windower/GearSwap previously supplied.

This matters for future upstream updates: the closer `RahvinGS/` remains to upstream, the easier a new Rahvin version is to merge and regression-test instead of re-porting from scratch.

---

# 2. NON-NEGOTIABLE PROJECT DECISIONS

These decisions are already made. A fresh chat must not reopen them unless the user explicitly changes one.

1. **Full Rahvin 2.1.0 parity** is the target. No feature may be silently omitted because it is inconvenient on Ashita.
2. **LuAshitacast is the normal equipment/action backend.** Do not build a replacement gear engine.
3. **Rahvin engine semantics stay authoritative.** Adapter behavior is shaped to Rahvin where technically possible.
4. **Adapter first.** Ashita differences belong in `ashita/` and `compat/`, not in upstream Rahvin files.
5. Direct Rahvin edits are Class-C patches and must be exceptional, tested, and ledgered.
6. **Master-only development.** No feature branches, worktrees, temp branches, RC branches, sync branches or PRs unless the user explicitly changes this rule.
7. Assistant implements independently and writes directly to GitHub `master` in small test-gated increments.
8. User's Android Termux checkout is used to execute LuaJIT tests and provide witnessed output.
9. Termux is development tooling only and must never become a shipped runtime dependency.
10. Real Windows/Ashita/LAC behavior must be tested live where automation cannot prove it. Never fabricate live evidence.

Change classes:

- **A — UPSTREAM CLEAN:** Rahvin source remains upstream-clean.
- **B — COMPAT:** behavior supplied entirely by compatibility/adapters.
- **C — ASHITA PATCH:** direct Rahvin source modification is unavoidable.

Target: maximize A/B, minimize C. **No Class-C Rahvin product patch has been required so far for the port work covered here.**

---

# 3. PINNED BASELINES / PROVENANCE

## Rahvin upstream

- repository: `RahvinCode/Gearswap`
- target tag: `2.1.0`
- target commit: `f1cda1e41f567b16ec592e6598cda71bb04392d0`
- release date: 2026-09-24
- release asset: `Rahvin.GS.2.1.zip`
- asset SHA-256: `0111cb34cdfb800f58ab495480b383d922f9e5846f41f40d7b39400432f2ab01`

The upstream master at the initial design point had only README/report/license differences beyond tag 2.1.0; there were no newer RahvinGS product changes relevant to the initial port baseline.

## Fork

- repository: `TGffxi/Gearswap`
- default branch: `master`
- public
- development policy: master only

## Runtime design baselines

- LuAshitacast: `7ed398edd3ebbdc8af86a79e5d3427da42e3a34a`
- Ashita v4 beta: `4171c74c8ddb2ca2a31654f199e6c1cee40d7256`

A later release may move these baselines only after explicit regression/live validation. The first release manifest must record the exact tested revisions.

---

# 4. APPROVED REPOSITORY / RUNTIME ARCHITECTURE

The design keeps upstream paths in place and isolates port code:

```text
RahvinGS/                 # upstream Rahvin engine paths preserved
Sample Job Files/         # upstream sample paths preserved
ashita/
  bootstrap.lua
  platform.lua
  events.lua
  scheduler.lua
  packets.lua
  packet_decoder.lua
  ipc.lua
  inventory.lua
  recasts.lua
  display.lua
  settings.lua
  commands.lua
  keybinds.lua
  lifecycle.lua
  runtime_events.lua
  action_runtime.lua
  state_runtime.lua
  lac_data.lua
  equip_backend.lua
  profile.lua
  ...
compat/
  gearswap.lua
  windower.lua
  environment.lua
  slots.lua
  sets.lua
  modes.lua
  resources.lua
  extdata.lua
  config.lua
  include.lua
  ...
tests/
  ashita/
  compat/
  contract/
  parity/
  fixtures/
docs/
```

The future installable profile is intended to be thin. It should compose shared services rather than duplicate Rahvin engine logic into every character/job profile.

---

# 5. PHASE STATUS — WHAT IS FINISHED AND WHAT IS NOT

## Phase 1 — Foundation / compatibility

**Status: COMPLETE. Do not re-audit.**

Implemented and tested foundation includes:

- slot-name translation GearSwap ↔ LAC;
- set copy/combine semantics;
- Modes compatibility;
- include/environment loading;
- basic GearSwap globals;
- initial Windower compatibility contract;
- foundation primitives and baseline contracts.

Accepted end state was around commit `8070cc78234c37863253bbe78d7744ed92f37095` and has remained covered by later full-suite runs.

## Phase 2 — Core gear parity

**Status: COMPLETE AND ACCEPTED. Do not reopen.**

Implemented/tested:

- LAC action normalization;
- spells, abilities, WS, ranged, item action families;
- GEO/Trust details;
- ability/spell recast semantics;
- ability taxonomy required by Rahvin;
- SELF target semantics;
- Resend semantics;
- action runtime;
- synthetic exactly-once `aftercast` behavior;
- normal completion vs interrupt handling;
- selective busy gating rather than blanket suppression;
- status/buff/pet state runtime;
- LAC data snapshot fixtures;
- GearSwap slot behavior;
- set layering/merge precedence parity;
- upstream Rahvin engine load contracts.

Important semantic facts already settled:

- LAC has no GearSwap `aftercast` callback; the adapter synthesizes it exactly once when the active action disappears/changes.
- `Resend` makes only the same resent logical action idempotent; a new non-resend action with the same signature is still a new action.
- Rahvin's `status_change` and pet transitions are not blanket busy-gated.
- Buff-driven redress is the transition family deferred while the engine is truly busy.
- `aftercast` clears Rahvin's cast-in-flight state before post-action behavior.
- GearSwap SELF targeting must be reconstructed correctly from LAC/Ashita target/player data.
- Windower spell recast identity uses spell id semantics; abilities use their recast timer id semantics.

Phase 2 previously reached an 18/18 user-witnessed checkpoint and has stayed green in all later full runs.

## Phase 3 — Special systems

**Status: AUTOMATED PORT LARGELY COMPLETE; LIVE EXIT GATE NOT YET COMPLETE.**

Implemented and automated:

- Ashita event registry;
- scheduler;
- scheduler/lifecycle single frame ownership;
- packet bridge;
- TH parity;
- raw action packet decoder;
- zone decoder;
- target-index tracking;
- same-machine SpellReceived IPC;
- IPC malformed/stale/duplicate rejection;
- IPC subscriber isolation;
- IPC wall clock using `socket.gettime()*1000`;
- inventory adapter;
- recast adapter;
- extdata compatibility behavior;
- Hoxne / enchanted-item parity fixtures;
- runtime event bridge from Ashita packet/frame/logout events to unchanged Rahvin registrations;
- Windower-style event callback error isolation;
- runtime event integration into lifecycle.

Still required before Phase 3 is truly closed:

- actual two-client IPC live test on Windows/Ashita;
- live raw packet/TH evidence;
- live Hoxne/enchant evidence;
- live zone/reset evidence;
- record exact actual Ashita/LAC revisions used in the live client.

Do not call Phase 3 release-complete until those live gates are recorded.

## Phase 4 — Display / settings / commands / lifecycle

**Status: AUTOMATED IMPLEMENTATION SUBSTANTIALLY COMPLETE; PRODUCTION COMPOSITION + LIVE EXIT GATE STILL OPEN.**

Implemented and automated:

- character-scoped settings store;
- deterministic settings serialization/deep merge;
- corrupt settings fallback behavior;
- command bridge;
- `/rahvings` command handling and LAC forwarding semantics;
- keybind translation/ownership/collision handling;
- all four display model styles: classic, harness, lattice, halo;
- display abstraction lifecycle (`show/hide/move/destroy`);
- lifecycle load/logout/unload idempotence;
- startup sequencing;
- scheduler ownership;
- IPC generation renewal after logout/login;
- event teardown;
- runtime packet/prerender/logout integration.

Still open for Phase 4:

- complete production Windower/platform surface — **current active task**;
- actual production composition root;
- concrete real Ashita renderer and live proof;
- repeated settings save/replace proof on Windows (`ashita.fs.rename` replacement behavior must be verified in reality);
- live load → reload → zone → logout → login;
- verify no stale overlay, keybind, packet handler, scheduler callback, IPC listener or held slot survives teardown.

## Phase 5 — Sample jobs / installation / release / upstream maintenance

**Status: NOT STARTED AS A PHASE.**

Do not skip ahead to release/tagging.

Planned order is fixed by `docs/superpowers/plans/2026-10-03-05-samples-release-upstream.md`:

1. sample-job compatibility matrix;
2. installation layout + profile stub + manifest;
3. full automated regression gate and test matrix;
4. live release acceptance;
5. master-only upstream-sync dry run;
6. release metadata/tag only after all gates pass.

---

# 6. CURRENT MODULE RESPONSIBILITIES / IMPORTANT CONTRACTS

## `ashita/bootstrap.lua`

Translates LAC profile callbacks into the port runtime. Existing automated behavior includes:

- `OnLoad` → Rahvin engine load, equip flush, lifecycle load;
- `OnUnload` → action reset, Rahvin engine unload, flush, lifecycle unload;
- action callbacks → action runtime begin/midcast;
- `HandleDefault` → action completion detection + state update + Rahvin default when idle.

This module is a callback bridge, **not yet the final production dependency composer**.

## `ashita/profile.lua`

Currently only a configurable delegate wrapper:

```lua
profile.Configure(deps)
```

It is not yet a standalone installable production profile. This is an intentional unfinished point.

## `ashita/platform.lua`

Already provides:

- Windower-shaped logical event registration/dispatch;
- callback isolation;
- IPC attach/detach/send;
- inventory bag access;
- ability recasts;
- spell recasts.

It does **not yet** expose the complete production runtime surface expected by `compat.windower` and `compat.environment`. That is the current task.

## `compat/windower.lua`

Exposes the Windower-shaped API consumed by unchanged Rahvin code and expects the platform to provide methods such as:

- chat;
- send_command;
- send_ipc;
- register_event;
- window_settings;
- wc_match;
- input;
- get_info;
- get_items;
- get_abilities;
- get_ability_recasts;
- get_spell_recasts;
- get_party;
- get_mob_by_id;
- get_mob_by_index;
- get_player;
- inject_outgoing;
- primitive operations.

## `compat/environment.lua`

Builds the GearSwap-like execution environment and installs runtime libraries. It expects platform support for:

- `resources`;
- config load/save;
- extdata decode;
- wall clock;
- file objects;
- global `send_command`;
- shared scheduler via `coroutine.schedule`.

It also supplies string/table helpers Rahvin expects.

## `ashita/scheduler.lua`

Event-agnostic queue only. **Lifecycle is the sole frame owner.**

Critical invariant: `platform:schedule()` must feed the exact scheduler queue that lifecycle ticks. Creating a second queue means Rahvin's startup/deferred callbacks never run.

## `ashita/events.lua`

Owns native Ashita registration/unregistration and cleanup.

Critical invariant: production runtime hooks must use one coherent event registry. Do not create parallel hidden native handlers that lifecycle cannot unregister.

## `ashita/packets.lua` + `ashita/packet_decoder.lua`

- production default decoder is active;
- `0x028` action packets are converted to Rahvin/GearSwap-shaped action data;
- `0x00A` carries zone id at offset `0x30`;
- target index comes from Ashita target manager;
- outgoing chunks drive Rahvin main engine cadence and target-change detection;
- `0x029` is routed for Rahvin TH death/action-message handling.

Packet offsets/semantics must remain tied to pinned Ashita source or live captures, never guessed.

## `ashita/runtime_events.lua`

Bridges native runtime events into the same Windower-shaped platform event registry:

- `packet_in` → incoming chunk / action / zone change;
- `packet_out` → outgoing chunk / target change;
- frame → Rahvin `prerender`;
- IPC → Rahvin `ipc message`;
- logout → Rahvin `logout`;
- unload → clears Rahvin event generation + packet target baseline.

## `ashita/ipc.lua`

Current design:

- wire prefix `RGSIPC`;
- version 1;
- multicast group `239.255.82.71`;
- port `38471`;
- TTL 0, same-machine intent;
- wall clock `socket.gettime()*1000`;
- non-blocking polling;
- exact Rahvin message conversion for SPELL, ABILITY, COMPLETE, ROLLQ, ROLL.

Automated tests are green. Two real local clients are still required for live proof.

## `ashita/inventory.lua` / `ashita/recasts.lua` / `compat/extdata.lua`

Automated special-system behavior is green, including duplicate item handling and cooldown units.

Production composition still needs the platform to expose the required extdata/native decoding boundary cleanly.

## `ashita/settings.lua`

Character-scoped persisted settings. Automated behavior is green. Windows repeated replacement semantics still need live verification.

## `ashita/commands.lua` / `ashita/keybinds.lua`

Automated command/keybind semantics are green. Lifecycle owns registration/cleanup.

## `ashita/display.lua`

Only the renderer-independent display service/model is finished. A concrete Ashita renderer is still required and must be live-proven before Phase 4 exit.

## `ashita/lifecycle.lua`

At verified commit `7cb215a`:

- releases stale held slots on load;
- creates a fresh IPC generation;
- registers command/key surfaces;
- registers native runtime packet hooks through runtime events;
- attaches the same IPC instance that lifecycle polls;
- owns the single d3d frame driver;
- frame ordering is exactly: scheduler → IPC poll → Rahvin prerender;
- runs delayed Rahvin startup sequence;
- Rahvin logout handler executes before teardown;
- IPC listener detaches before socket close;
- scheduler/action/special/keybind/display/events/slots teardown is ordered;
- logout → load creates a new transport and re-registers hooks;
- unload permanently destroys the display generation.

This behavior was directly user-witnessed GREEN in the 40/40 run.

---

# 7. IMPORTANT RAHVIN / LAC SEMANTICS ALREADY ESTABLISHED

Do not rediscover or casually change these facts.

## LAC callbacks in use

Relevant LAC callbacks include:

- `OnLoad`
- `OnUnload`
- `HandleCommand`
- `HandleDefault`
- `HandleAbility`
- `HandleItem`
- `HandlePrecast`
- `HandleMidcast`
- `HandlePreshot`
- `HandleMidshot`
- `HandleWeaponskill`

There is no direct GearSwap-style `aftercast`, hence the synthetic action-runtime solution.

## Action semantics

- `gData.GetAction()` returns nil when no active action.
- LAC action values include action type, id/name/resource, cast time, element, recast and Resend data.
- LAC clears its player action on completion/interrupt packet handling.
- Spell flow is precast → inject → midcast.
- Ranged flow is preshot → midshot.
- `HandleDefault` alone is not relied upon as the only native activity clock; lifecycle frame/packet systems cover the required runtime drivers.

## Target semantics

Rahvin builders expect GearSwap target types such as SELF/MONSTER. SELF can be reconstructed when the action target is player-like and its name matches the local player.

## Recast semantics

- abilities: Ashita/LAC recast timer ids;
- spells: spell id semantics matching Windower's `recast_id = spell.id` behavior;
- Ashita recast ticks are converted from 1/60 second units where required.

## Busy/state semantics

Do not introduce a blanket busy gate. Rahvin intentionally allows immediate status/pet transitions and only defers the specific buff redress behavior already modeled/tested.

## GearSwap event handler behavior

Multiple handlers registered for the same logical event must be isolated: failure of one handler must not prevent the next. This is especially important for Rahvin's two separate `prerender` registrations (Hoxne and SpellReceived failsafe).

---

# 8. RECENT TEST/IMPLEMENTATION CHRONOLOGY — DO NOT LOSE THIS CONTEXT

This is the recent path from the stable scheduler work to the current task.

## Scheduler single-owner correction

- RED proved duplicate frame ownership.
- `92c80dc94daa4fe1d9c6a6590dfa8f0482afb88b` made scheduler event-agnostic and lifecycle sole owner.
- follow-up `0195c85483f1d157c54e17951e2f45c4faab4be3` was subsequently user-tested.
- user observed **35/35 GREEN**.

## Initial production platform composition

- RED platform composition tests added.
- `335bdf0380a29847b4288b3bae9b76111c776692` added `ashita/platform.lua` partial composition service.
- user observed targeted platform test GREEN and **36/36 full GREEN**.

## Raw packet production decoder

- RED added for production packet decoder.
- `7aa93d910659df6c65a1b85a3258b8ba15bcd07b` implemented raw action/zone decoder.
- `2faa495bce383e92aee135d6a1ed75bdf0a309b7` made packets use it by default.
- user observed targeted packet tests GREEN and **37/37 full GREEN**.

## Runtime event bridge + callback isolation

- RED added for native packet/frame/logout bridge and same-event callback isolation.
- `104450bf6ff38000f4f706fcc6de62017b311b29` added platform event callback isolation.
- `4fa79dc7ad30e8cec41a5c24e2b6949110922136` added `ashita/runtime_events.lua`.
- one subsequent failure was traced to the **test fixture itself** (Lua local initializer self-reference), not product code.
- `7d3e10f79cdf6202975f147cde759cebee8cc519` corrected that test.
- user observed **39/39 full GREEN**.

## Lifecycle ↔ runtime-events composition

- RED: `948c15f5e24c1d41ef0ce1888ef5fe9776d4274f` + suite registration `1b8d29cced156b4f00bd5364762731b73d85d6de`.
- `7cb215acfbdabba02daf3e3cf108ccc0568185d6` wired runtime events into lifecycle.
- user observed targeted lifecycle tests GREEN and **40/40 full GREEN**.

## Current RED contract awaiting user execution

- `4ae97ef4cfafaa9d6bf07ecdcd4cd506b8610dc4`
- actual file: `tests/ashita/test_platform_windower_surface.lua`
- `99d2686dd8b3a012ac55f90abb45a5158d73e593` registers `platform_windower`.

The current test asks `ashita.platform.new({native=...})` to expose/delegate the complete Windower/runtime surface while continuing to use the existing inventory/recast services.

---

# 9. EXACT CURRENT RED CONTRACT: `platform_windower`

The current test requires the produced platform object to expose functions for:

```text
chat
send_command
input
window_settings
wc_match
get_info
get_items
get_abilities
get_ability_recasts
get_spell_recasts
get_party
get_mob_by_id
get_mob_by_index
get_player
inject_outgoing
schedule
gettime
load_config
save_config
decode_item
new_file
prim_create
prim_delete
prim_set_position
prim_set_size
prim_set_color
prim_set_visibility
```

It also requires `platform.resources` to expose the same shared resource surface supplied by the native provider rather than an unrelated copy.

The test injects:

- `inventory.iter_bag()` for `get_items`;
- `recasts.abilities()` / `recasts.spells()` for recasts;
- a `native` provider for the remaining runtime methods/resources.

This is a boundary test. It does **not** by itself prove the real production Ashita implementation of every native method. The implementation must not stop at a test-only fake. The production path must map these methods to real Ashita/LAC facilities, or fail loudly where a capability has not yet been legitimately mapped.

## Critical identity rules while implementing

1. `schedule` must feed the **same scheduler queue lifecycle ticks**.
2. `register_event` remains the logical Rahvin/Windower event surface already owned by the platform; do not replace it with separate native registrations.
3. runtime packet/frame hooks remain in `ashita.runtime_events` / `ashita.events`; do not duplicate them.
4. inventory/recast calls keep using the existing tested adapters.
5. `resources` must be one coherent source used by `compat.resources`.
6. config/settings responsibilities must not accidentally create two conflicting persistence systems.
7. do not implement primitive/display methods as silent no-ops merely to satisfy the test.

---

# 10. PRECISE WORKING METHOD FOR THE NEW CHAT

The user expects the assistant to work, not merely advise. Follow this loop exactly.

## A. Before each code change

1. Read this runbook and the active plan section.
2. Read the user's latest test output literally.
3. Fetch the **current version** of every file to be changed from GitHub immediately before writing it.
4. If Ashita/LAC API behavior is uncertain, inspect the pinned upstream source; do not invent API names/signatures.
5. Identify the smallest root cause and smallest adapter-level change.

## B. TDD gate

For new behavior:

1. Write/commit the RED contract to `master`.
2. Ask the user for the exact Termux command.
3. Wait for the user's actual failing output.
4. Only then implement the production change.
5. Ask for targeted GREEN + `luajit tests/run.lua all`.
6. Only call the checkpoint GREEN after the user pastes successful output.

The current `platform_windower` RED was already written, so do **not** write a replacement RED. The next step is to witness it.

## C. Failure handling

On any unexpected failure:

1. Read the exact error and line.
2. Determine whether the failure is product code, test contract, stale checkout, or wrong assumption.
3. Inspect the changed boundary and recent commits.
4. Trace the value/call backward to its source.
5. Fix the source cause, not the symptom.
6. If a test itself is wrong, say so explicitly and fix only the test; do not distort production code to satisfy a broken fixture.

## D. Git/GitHub rules

- direct writes to `master` only;
- no branch creation;
- no PR creation;
- small, descriptive commits;
- no parallel writes to the same file;
- fetch current blob/file before update;
- preserve upstream paths;
- no direct Rahvin patch merely because Ashita calls something differently.

## E. User interaction

The user runs commands because this chat cannot directly operate the user's Termux/Ashita machine.

Do not ask the user to perform work the assistant can perform through GitHub. The user should normally only need to:

- `git pull --ff-only`;
- run the exact LuaJIT suite(s);
- paste output;
- later perform exact Windows/Ashita live steps that truly require the client.

Avoid unnecessary check-ins such as “should I continue?”. If the prior gate is satisfied, continue automatically until another human-execution gate is reached.

---

# 11. WHAT TO DO IMMEDIATELY AFTER THE USER POSTS `platform_windower` RED

Do not brainstorm. Execute this sequence.

1. Treat the pasted output as the witnessed RED.
2. Fetch:
   - `tests/ashita/test_platform_windower_surface.lua`
   - `ashita/platform.lua`
   - `compat/windower.lua`
   - `compat/environment.lua`
   - `ashita/scheduler.lua`
   - `ashita/inventory.lua`
   - `ashita/recasts.lua`
   - `ashita/settings.lua`
   - relevant resource/extdata/config/file/renderer adapter files
3. Identify exactly which required method fails first and how the current platform factory is structured.
4. Implement the injected native delegation contract while preserving existing event/IPC/inventory/recast behavior.
5. Build or connect the real production native provider using verified Ashita/LAC APIs. Do not ship a test-only provider.
6. Preserve shared scheduler/event/resource identities.
7. Commit directly to master.
8. Ask the user to run:

```bash
cd ~/Gearswap
git pull --ff-only
luajit tests/run.lua platform_windower
luajit tests/run.lua all
```

With the current suite roster, if no additional test module is added in the implementation, the full expected count after this contract goes GREEN is **41/41**. If new regression tests are added, use the actual higher count instead.

---

# 12. WHAT HAPPENS AFTER `platform_windower` IS GREEN

The next task is **not Phase 5 yet**. It is the real production composition root.

## Step 12.1 — RED production-composition integration test

Write a new integration contract that proves one coherent production object graph rather than isolated modules.

The contract should prove at minimum:

- one platform instance backs Windower compatibility and runtime events;
- one scheduler queue is used by both `coroutine.schedule` and lifecycle frame ticking;
- one event registry owns native lifecycle registrations;
- the same IPC instance is polled by lifecycle and attached to platform/Rahvin IPC dispatch;
- GearSwap environment + Windower compatibility install into the Rahvin execution environment;
- unchanged Rahvin engine loads through that environment;
- resources/config/extdata/files resolve through the production platform;
- LAC equip backend is installed;
- action runtime and state runtime are the ones used by bootstrap;
- lifecycle receives runtime events/platform/shared services;
- profile callbacks are exposed and unload tears the same graph down.

Witness RED before implementation.

## Step 12.2 — Implement production composition root

The exact filename may be chosen consistently with the existing architecture, but responsibilities must stay clear. `ashita/profile.lua` should remain thin; a production composition module may own dependency creation if that keeps testability clean.

The resulting real profile path must no longer require a test harness to manually call `profile.Configure(deps)` with fabricated services.

## Step 12.3 — Full automated GREEN

Run targeted composition test and full suite. Record the new user-witnessed count.

---

# 13. LIVE VALIDATION AFTER PRODUCTION COMPOSITION

Once a real LAC profile can be assembled, perform a **minimal live smoke early**, before stacking the entire release phase on unverified API assumptions.

The live procedure must be exact and documented. At minimum first prove:

1. profile loads under actual Ashita + LuAshitacast;
2. no immediate compatibility error from platform/resource/config/extdata/files bindings;
3. idle/default equip path works;
4. one representative action goes through precast/midcast/aftercast restoration;
5. unload/reload does not leave duplicate handlers.

If live behavior fails:

- capture the actual error/behavior;
- add an automated regression fixture first where possible;
- witness RED;
- then fix;
- rerun automation + live case.

Do not patch live failures without regression coverage when the behavior is automatable.

---

# 14. REMAINING PHASE-3 / PHASE-4 LIVE GATES

After production composition is viable, close the existing live gates instead of declaring those phases done from unit tests alone.

## Special systems

- TH actual target/action/death path;
- live raw `0x028`/`0x00A` behavior;
- SpellReceived between two real local client instances;
- malformed/stale IPC must not lock gear;
- Hoxne critical action windows;
- enchanted-item cooldown and instance selection;
- duplicate item behavior;
- zoning resets all special state.

## Lifecycle

Run and document:

```text
load → use → reload → zone → logout → login → use → unload
```

Verify:

- one frame owner only;
- no duplicate packet handlers;
- no stale scheduler callbacks;
- no stale IPC socket/listener;
- no stale keybinds;
- no held equipment slots;
- no stale action state;
- no stale overlay at character selection;
- fresh IPC generation after login/load.

## Settings

Perform repeated saves on Windows/Ashita and verify atomic replacement behavior, especially the real behavior of `ashita.fs.rename` when the target settings file already exists.

## Display

The current `ashita/display.lua` is renderer-independent. A concrete backend must still be chosen/implemented against a verified Ashita rendering API and live-checked for all four Rahvin styles plus cleanup.

---

# 15. PHASE 5 — EXACT ORDER AFTER PHASE 3/4 PRODUCTION/LIVE BLOCKERS ARE CLOSED

Follow the existing Phase-5 plan. Do not improvise a different release sequence.

## Task 1 — Sample-job compatibility matrix

- enumerate actual `Sample Job Files/*.lua`, not a hand-picked list;
- load every sample in harness;
- verify custom hooks are not silently skipped;
- exercise idle/engaged and applicable spell/ability/WS paths;
- fix adapters first;
- any necessary upstream/sample edit requires ledger + regression.

## Task 2 — Installation layout and bootstrap generator

- `install/README.md`;
- thin per-character LAC profile stub;
- shared port files;
- manifest with exact Rahvin/Ashita-port/LAC/Ashita revisions;
- no Termux requirement for users.

## Task 3 — Full automated regression gate

Order should cover foundation → compat → core parity → special systems → settings/display/commands/lifecycle → sample jobs → install layout.

A failure must produce nonzero exit and identify the failing test.

## Task 4 — Live release acceptance

Representative coverage must include mage, melee, ranged, pet, BRD/GEO, TH, SpellReceived, Hoxne/enchant, display, settings and lifecycle.

## Task 5 — Master-only upstream-sync dry run

Document/test the actual master-only process. Never create a temporary merge branch.

## Task 6 — First release

Only after:

- automated regression fully GREEN from release tree;
- live acceptance fully recorded;
- no required feature omitted;
- no unledgered Class-C patch;
- exact baselines recorded.

Only then set final release metadata/tag.

---

# 16. THINGS A NEW CHAT MUST NOT DO

Do **not**:

- re-audit Phase 1 or Phase 2;
- propose rewriting Rahvin natively in LAC;
- replace LAC with a custom gear engine;
- move upstream Rahvin code into a vendor subtree;
- create a branch or PR;
- use an old Rahvin payload as implementation basis;
- silently stub missing production APIs with no-ops;
- create separate hidden scheduler/event instances;
- invent Ashita API names or packet offsets;
- claim current master is 40/40 after the new RED suite was added;
- claim live functionality from automated tests;
- start Phase 5 release/tag work before composition and live gates;
- ask the user to re-explain architecture/history already captured here.

---

# 17. SOURCE OF TRUTH / PRECEDENCE WHEN INFORMATION CONFLICTS

Use this precedence:

1. **User's latest actual test/live output** — authoritative evidence of what ran.
2. **Current GitHub `master` contents** — authoritative code state.
3. **This full runbook** — authoritative workflow/resume interpretation.
4. Approved design spec and phase plans — architecture/acceptance intent.
5. Older chat summaries/handoffs — historical support only.

If current code has moved beyond this runbook because work continued in another chat, inspect current master and latest user evidence before acting; do not overwrite newer work based on stale documentation.

---

# 18. NEW-CHAT SELF-CHECK BEFORE CONTINUING

After reading this file, a fresh chat should be able to state all of the following correctly before it changes product code:

1. Product: Rahvin GearSwap 2.1.0 → Ashita v4/LuAshitacast full-parity port.
2. Architecture: unchanged Rahvin semantics behind compat/platform adapters, LAC backend.
3. Workflow: master-only, direct GitHub commits, user runs Termux tests.
4. Last verified GREEN: `7cb215a`, 40/40.
5. Current master has a newer unexecuted TDD suite, so master itself must not yet be called 40/40.
6. Current suite: `platform_windower`.
7. Actual test file: `tests/ashita/test_platform_windower_surface.lua`.
8. Immediate command: `luajit tests/run.lua platform_windower` after pull.
9. No implementation until that RED is witnessed.
10. After it goes GREEN: full suite, then RED production-composition test, then composition root, then live gates, then Phase 5.

If a new chat cannot accurately state those ten points, it has not finished onboarding.

---

# 19. COPY/PASTE RESUME INSTRUCTION FOR A FRESH CHAT

The user can paste the following message:

```text
Wir setzen den Rahvin GearSwap 2.1.0 → Ashita v4 / LuAshitacast Port exakt am aktuellen Stand fort.

Lies zuerst VOLLSTÄNDIG und behandle als autoritativen Arbeits-Handoff:
docs/HANDOFF_2026-10-03_FULL_RUNTIME_RUNBOOK.md

Danach beachte die dort referenzierte freigegebene Design-Spec und die Phase-3/4/5-Pläne. Phase 1 und 2 sind abgeschlossen und werden nicht erneut auditiert. Architektur nicht neu aufrollen.

Arbeitsweise ist verbindlich: master-only, keine Branches/PRs, direkte kleine GitHub-Commits, TDD mit von mir in Termux tatsächlich beobachtetem RED/GREEN, vor jeder Änderung aktuelle Dateien fetchten, bei Fehlern Root Cause statt Symptompflaster, keine erfundenen Live-Nachweise.

Bevor du irgendetwas implementierst, bestätige mir in deiner ersten Antwort knapp aber konkret diese zehn Punkte aus Abschnitt 18 des Runbooks und nenne den exakten nächsten Termux-Befehl. Ändere bis zum beobachteten platform_windower-RED noch keinen Produktcode.
```

---

# 20. CURRENT ONE-LINE STATUS

**Rahvin core parity and most special/lifecycle adapters are automated GREEN; last witnessed full suite is 40/40 at `7cb215a`; current master contains the not-yet-run RED contract `platform_windower`; next work is the complete production Windower/platform surface → production composition root → live Phase-3/4 gates → Phase 5.**
