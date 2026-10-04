# HANDOFF — Rahvin GearSwap 2.1.0 → Ashita v4 + LuAshitacast
## Full parity-audit continuation — 2026-10-04

This file is the authoritative continuation handoff for the next ChatGPT conversation.

The previous conversation reached the context limit while performing a deep, original-source-derived parity audit. **Do not jump to live testing and do not begin Phase 5.** Continue from the TDD parity-fix work described below.

---

# 0. Mandatory continuation instructions

Work exclusively in:

- Repository: `TGffxi/Gearswap`
- Branch: `master`

Do **not** create:
- feature branches;
- sync branches;
- RC branches;
- temporary branches;
- pull requests.

Development/test tooling such as Git, Termux and LuaJIT is allowed for development only and must never become a runtime dependency.

Before modifying an existing repository file:
1. fetch the latest version from GitHub;
2. use its current SHA for the update;
3. preserve the single `master` workflow.

Do not modify `RahvinGS/` or `Sample Job Files/` unless a later audit proves an adapter-only solution is impossible. The primary design objective remains full compatibility through `compat/` and `ashita/`.

Do not enter release/Phase 5 while parity blockers or live gates remain.

The user's actual game environment is the already-established **CachyOS + Ashita v4 + LuAshitacast** environment, not a Windows-PC setup. Windows semantics still matter where Wine/Ashita file replacement behavior is involved, but do not instruct the user to build a separate Windows installation.

---

# 1. Pinned upstream baselines

Rahvin GearSwap 2.1.0:
`f1cda1e41f567b16ec592e6598cda71bb04392d0`

Rahvin release SHA:
`0111cb34cdfb800f58ab495480b383d922f9e5846f41f40d7b39400432f2ab01`

LuAshitacast:
`7ed398edd3ebbdc8af86a79e5d3427da42e3a34a`

Ashita v4 beta source baseline:
`4171c74c8ddb2ca2a31654f199e6c1cee40d7256`

Original TGffxi fork snapshot:
`8bca6c48d437f93932ccf38313ae3d0a472b626e`

---

# 2. Current Git state

Current `master` immediately before creating this handoff:
`62553ef65d87ad93e9cde24fc295b6d182f2b908`
message: `test: require GearSwap item field normalization`

The **last user-witnessed fully GREEN product checkpoint** is:
`d47b144ea1559790c5c4aa958d7b01150d8303ad`

At `d47b144`, the user ran:

```text
luajit tests/run.lua texts_renderer
PASS tests.ashita.test_texts_renderer
RESULT 1 passed, 0 failed

luajit tests/run.lua all
...
RESULT 47 passed, 0 failed
```

This 47/47 result is real user evidence.

After `d47b144`, the repository received only deep-audit documentation and new TDD RED contracts. No product implementation fixing those new parity findings has been committed yet.

Post-GREEN commits currently on master:

- `2321bb9f2c64074acb4e9bad06c4ba3b7d5eb4c5` — docs: record deep Rahvin parity audit
- `cf47ba4601fc2a0a5ef1f22de46a216a509d70fa` — test: require GearSwap item metadata parity
- `8b9ba33db732775e1881fd733ebd70aff7ceacfb` — docs: add detailed Rahvin 2.1.0 port parity audit
- `62553ef65d87ad93e9cde24fc295b6d182f2b908` — test: require GearSwap item field normalization

**Do not call the current master GREEN.** The user has not run the two newest Wave-1 RED contracts yet.

---

# 3. Authoritative audit documents

Read these before implementing anything:

1. `docs/DEEP_PARITY_AUDIT_2026-10-04.md`
2. `docs/AUDIT_RAHVIN_2_1_0_PORT_PARITY_2026-10-04.md`
3. `docs/superpowers/specs/2026-10-03-rahvings-ashita-port-design.md`
4. `docs/HANDOFF_2026-10-03_RUNTIME_COMPOSITION.md`
5. `docs/HANDOFF_2026-10-03_FULL_RUNTIME_RUNBOOK.md`

The first two are the current deep audit authority. Older handoffs are useful architecture history only where they do not conflict with the 2026-10-04 audit or current master.

`docs/LIVE_TEST_PHASE4.md` exists, but **do not execute that live matrix yet**. The deeper audit discovered blockers that must be repaired first.

---

# 4. Upstream integrity — confirmed

Blob-level comparison was performed against the pinned Rahvin 2.1.0 baseline.

Confirmed:
- all **16/16** entries under `RahvinGS/` are SHA-identical to Rahvin baseline;
- all **22/22** files under `Sample Job Files/` are SHA-identical to Rahvin baseline.

Therefore the port is still upstream-clean:
- Rahvin engine unchanged;
- sample jobs unchanged;
- port behavior isolated to `compat/`, `ashita/`, tests and docs.

Preserve this.

---

# 5. Core architecture already established

Rahvin remains the semantic authority.

LuAshitacast is the equip/action backend.

Windower/GearSwap behavior is recreated at compatibility boundaries.

Preferred change classes:
- A — upstream clean;
- B — compatibility adapter;
- C — direct Ashita patch only where unavoidable.

One shared logical runtime graph is required:
- one scheduler;
- one event owner;
- one active IPC generation;
- one lifecycle;
- no duplicate startup scheduling.

The unchanged Rahvin root schedules exactly 11 deferred startup tasks. Composition captures those once and replays them through the lifecycle-owned scheduler.

The production graph currently consists of:
- native Ashita adapter;
- platform;
- GearSwap compatibility backend;
- Windower facade;
- resources;
- inventory;
- recasts;
- extdata;
- snapshot;
- unchanged Rahvin engine and job;
- action runtime;
- state runtime;
- runtime event bridge;
- lifecycle;
- LAC bootstrap/profile;
- settings/commands/keybind/display adapters.

---

# 6. Important already-fixed issues and witnessed gates

## Production fonts / composition
Earlier work established real fonts resolution and production composition.

## Settings
Settings store has deterministic serialization plus safer temp/rename replacement including Windows-style replacement fallback.

## Native production
Production native bridge exists and has been repeatedly regression-tested.

## Resources/extdata/snapshot
Production resource, extdata and snapshot services are implemented and previously user-confirmed.

## Keybind ownership
Rahvin logical keybinds remain authoritative.
Windower:
`bind <key> gs c <command>`
is bridged to Ashita:
`/bind <translated-key> /lac fwd <command>`

Shift `~` is translated to Ashita `+`.

Only bridge-owned keys are removed on teardown.

## Production profile root
`ashita/profile.lua` has `profile.production(job_path)`.

## Mob distance
Rahvin calls:
`get_mob_by_id(...).distance:sqrt()`

Ashita supplies squared distance.
The native adapter now exposes a Windower-compatible distance object with:
- `.squared`
- `:sqrt()`

Fix commit:
`ddf0cd0860f31e3abf72ab91aa8d499fbd168631`

User witnessed targeted native + full suite GREEN afterward.

## Real Ashita logout
A deep API check proved Ashita v4 has no native `logout` event matching the old adapter assumption.

Pinned Ashita detects logout through incoming packet:
- packet id `0x00B`;
- byte at offset `+0x04 == 1`.

The port now decodes that and routes it to the single lifecycle owner.

Relevant implementation commits:
- `694c2efdbe2e3d6930d80c5e06ef1a147cd165b4`
- `57a731e947aaf50d965bcd6123648c82c444e8dd`
- `88bc71938255bfe0c51797c3865d8be63601b981`
- `14396119513aa0c4399076013fd07c228e6b4456`
- `c9e5583361157018d487cb52420a3a594b49a199`
- test alignment `b7dd6ca...`, `6aca714...`

User then witnessed:
`RESULT 47 passed, 0 failed`

## LAC logout/login behavior
Pinned LAC source was inspected:
- on a new `0x00A` identity it auto-loads the profile;
- old profile receives `OnUnload`;
- new loaded profile receives `OnLoad`.

Therefore no custom login-rearm mechanism is required.

## Inline display colors
Rahvin produces Windower:
`\cs(r,g,b)...\cr`

Ashita fonts expect:
`|cAARRGGBB|...|r`

The renderer now translates only at the render boundary while preserving the original Rahvin-facing source text.

RED:
`735562af4504b7706257e98fe16a35baf4fc99d8`

Fix:
`d47b144ea1559790c5c4aa958d7b01150d8303ad`

User witnessed targeted renderer GREEN and full **47/47 GREEN**.

---

# 7. Deep parity-audit conclusion

The previous 47/47 suite proved many foundations, but **did not prove complete Rahvin/GearSwap semantic parity**.

The new source-derived audit therefore marks:

**AUTOMATED PRE-AUDIT SUITE GREEN; DEEP PARITY AUDIT RED.**

Do not live-test real jobs yet.

The following findings are confirmed unless explicitly marked otherwise.

---

# 8. CRITICAL finding — GearSwap item-table field semantics

Rahvin's real GearSwap item tables use lowercase GearSwap fields such as:

```lua
{
    name = "Rosmerta's Cape",
    priority = 80,
    augments = {...},
    bag = "wardrobe2",
}
```

Pinned LAC `MakeItemTable()` accepts case-sensitive:
- `Name`
- `Priority`
- `Augment`
- `Bag`
- `AugPath`
- `AugRank`
- `AugTrial`

Current production backend before Wave 1 simply copies inner item tables.

Impact:
- lowercase `name` can make table-form gear unresolvable;
- `priority` can be lost;
- augment identity can be lost;
- bag constraints can be lost.

This affects the central gear library broadly.

The audit counted approximately:
- ~935 lowercase `augments=` occurrences;
- ~77 lowercase `bag=` constraints.

Positive finding:
Pinned LAC **does** implement per-item `Priority` and sorts equip packets by:
1. descending priority;
2. slot order as tie breaker.

So Rahvin's HP/MP/weapon priority semantics can be preserved by proper normalization.

### Current Wave-1 RED contracts already committed

`tests/contract/test_gearswap_slots.lua` now requires:
- `name → Name`
- `priority → Priority`
- `augments → Augment`
- singular `augment → Augment`
- `bag → Bag`
- preserve already-LAC-shaped metadata;
- preserve AugPath/AugRank/AugTrial;
- do not mutate the original Rahvin item table;
- expose GearSwap `empty`;
- translate `empty` to LAC unequip semantics (`remove`).

`tests/ashita/test_equip_backend.lua` also contains a direct backend normalization RED for Rahvin-style lowercase fields.

### Important implementation warning

The audit documentation says item normalization should exist at **one clear adapter boundary**.

The two newest RED files currently exercise normalization at both:
- the GearSwap compatibility surface;
- the backend directly.

Before implementing, reconcile this deliberately.

Do not accidentally create two independent normalization implementations.

Preferred resolution:
- one shared idempotent item-normalization helper used by whichever public adapter layers need to accept both shapes;
- or adjust the over-broad RED if one layer should not promise that direct contract.

Do not patch blindly just to satisfy both tests.

---

# 9. HIGH finding — GearSwap `empty` sentinel missing

Rahvin uses global `empty` for deliberate slot clearing in:
- strip/naked modes;
- range yielding;
- weapon-lock/release paths;
- held-slot restoration;
- other rebuild/release paths.

Current compat environment does not define GearSwap `empty`.

Pinned LAC explicit unequip semantics are represented through `Name='remove'` / remove item handling.

Wave 1 must provide a stable GearSwap-facing `empty` sentinel and convert it at the LAC boundary without modifying Rahvin.

---

# 10. HIGH finding — wrapped vs raw Windower events collapsed

Rahvin deliberately distinguishes:
- `windower.register_event`
- `windower.raw_register_event`

GearSwap semantics differ:
- wrapped events see refreshed GearSwap globals and may commit gear;
- raw events intentionally do not automatically commit equip changes.

Current `compat.windower` maps both to the same platform event mechanism.

Current event emission also does not establish an explicit event-level equip transaction.

Consequences:
- target-change may build gear from stale globals and leave it pending;
- `ipc message` can build SpellReceived gear but leave it buffered until a later LAC callback;
- raw zone/action/prerender handlers may accidentally leave buffered gear that a later unrelated callback flushes.

Required later Wave:
- wrapped event = refresh snapshot → handlers → exactly one gear flush;
- raw event = handlers → discard any pending equip generated in that raw scope;
- no pending set may leak across event boundaries.

This is structural and must be TDD'd.

---

# 11. HIGH finding — action callbacks can see stale globals

The full snapshot currently refreshes:
- initially;
- in `HandleDefault`.

It is not refreshed immediately before:
- `HandleAbility`
- `HandleItem`
- `HandlePrecast`
- `HandleMidcast`
- `HandlePreshot`
- `HandleMidshot`
- `HandleWeaponskill`

Pinned LAC action parsing can set `PlayerAction` and call these handlers directly without a guaranteed prior `HandleDefault`.

Therefore Rahvin action handlers may see stale:
- player;
- world/weather;
- buffs;
- pet;
- equipment;
- inventory;
- target/TP/movement state.

Fix must refresh GearSwap-facing state at the callback boundary while avoiding duplicate state-diff hooks.

---

# 12. HIGH finding — missing gain/lose buff Windower events

This is separate from GearSwap:
`buff_change(name, gain)`

Rahvin also registers:
- `gain buff`
- `lose buff`

The handlers consume numeric buff IDs.

Current state runtime only emits GearSwap buff_change.

Missing gain/lose impacts behavior including:
- Accession prediction cleanup;
- Divine Seal prediction cleanup;
- Remedy automation;
- Holy Water automation;
- Sleep hold;
- Doom/Cursna hold;
- release of Sleep/Doom holds;
- Corsair roll cleanup.

Required:
- derive gained/lost numeric IDs from the same state diff;
- emit the Windower events in the correct ordering;
- also preserve normal GearSwap `buff_change(name,gain)`.

---

# 13. HIGH finding — subjob callback missing

Rahvin defines GearSwap:
`sub_job_change(new, old)`

It:
1. invalidates display layout;
2. invalidates set-name index;
3. clears warnings;
4. schedules Dual Wield refresh;
5. schedules two-hand refresh;
6. schedules gear rebuild;
7. calls `sub_job_change_custom(new, old)`.

Pinned LAC does not automatically reload a profile for a simple subjob change.

All 22 supplied sample jobs define `sub_job_change_custom`.

Required:
- include subjob in state diff;
- invoke exactly once for real changes;
- use the existing one shared scheduler for Rahvin's deferred callbacks.

---

# 14. HIGH finding — pet runtime missing

Pinned LAC explicitly documents that pet actions are not automatically mapped to profile callbacks. Profiles are expected to inspect:
`gData.GetPetAction()`.

Current bootstrap never reads it.

Therefore these Rahvin callbacks currently do not run:
- `pet_midcast(spell)`
- `pet_aftercast(spell)`

All 22 shipped sample jobs define:
- `pet_midcast_custom`
- `pet_aftercast_custom`

Pinned `GetPetAction()` provides enough information for a translator:
- ActionType;
- spell CastTime/Element/Id/MpCost/Name/Recast/Skill/Type;
- ability Name/Id/Type;
- mob skill Id/Name.

Also missing:
`pet_midaction()`

Rahvin reads that GearSwap helper in several action, enchant and Hoxne timing decisions.

The future pet runtime and `pet_midaction()` must share a single state owner.

---

# 15. HIGH finding — Windower `string:unpack()` missing

Rahvin unchanged raw packet handlers call:
- `data:unpack('I', 0x09)`
- `data:unpack('H', 0x19)`
- `data:unpack('fff', 5)`

Used in raw packet paths including:
- TH / 0x029 death-message processing;
- outgoing movement / 0x015 parsing.

Pinned Ashita normally uses:
`struct.unpack(format, data, offset)`

Ashita string sugar provides `split` and `slice`, but not Windower's method-style `:unpack`.

Required:
- provide Windower-compatible method semantics;
- verify offsets carefully against every original call;
- use realistic raw buffers in RED tests.

Without this, matching live packets can crash with method-not-found.

---

# 16. HIGH finding — `windower.chat.input()` executes incorrectly

Rahvin uses `windower.chat.input('/...')` as an execution primitive.

Examples:
- Remedy;
- Holy Water;
- food;
- enchanted item use;
- Hoxne job abilities;
- Hoxne Ampulla.

Current native adapter maps it to Ashita `SetInputText()`, which fills the input field rather than reproducing Windower's execute-input behavior.

Required:
- route through Ashita's actual command execution path;
- test item and JA cases;
- never leave the command merely typed in the chat field.

---

# 17. HIGH finding — Windower command-language bridge incomplete

Current native send-command bridge only handles bind/unbind specially, then passes the rest to Ashita.

Rahvin internally emits Windower grammar including:
- `gs c ...`
- `gs validate`
- `wait ...; ...`
- `input ...`
- `cancel <buffid>`
- `exec ...`
- `terminate`
- broadcast/addon commands.

This is especially important because **all 22 sample jobs call `jobsetup(...)` at file scope**.

Rahvin jobsetup emits a normal load chain containing:
- wait;
- macro book;
- wait;
- macro set;
- GearSwap validate;
- wait;
- lockstyle;
- echo;
- `gs c update auto`.

Therefore the real sample-job load path is currently not parity-safe even if a minimal smoke profile loads.

Internal Rahvin self commands such as:
- `gs c update auto`
- `gs c enchrepair`
- `gs c hoxnerelock`
- `gs c hoxnerelease`

must route directly to the same Rahvin dispatcher as `/lac fwd` / `/rahvings`.

Buff cancel commands such as:
- `cancel 71`
- `cancel 37`
- delayed `cancel 66`

must not depend on an unrelated optional Ashita addon.

Other mappings requiring explicit decision:
- `gs validate`: do **not** blindly map to `/lac validate`; LAC validate has different Packer semantics;
- `profile` command / Windower `exec`: Ashita ChatManager script execution can potentially implement it;
- `shutdown` / `terminate`: no exact pinned Ashita mapping proven yet;
- external sample-job commands such as `aset` and COR `lua u autocor` require classification/pass-through/substitution policy.

Use the existing **shared scheduler** for any parsed wait chain; do not create another timer queue.

---

# 18. HIGH finding — GearSwap event-scoped cancel state missing

Rahvin reads:
`_global.cancel_spell`

GearSwap sets this event-scoped flag when `cancel_spell()` is called.

The port currently calls LAC:
`gFunc.CancelAction()`

but does not reproduce/reset:
`_global.cancel_spell`.

Rahvin uses that flag after pretarget/pretarget_custom for outgoing IPC debt and Hoxne critical-window decisions.

Must be reproduced as part of event-scope semantics, not as a sticky global.

---

# 19. HIGH finding — corrupted new settings can be overwritten

The **legacy Windower XML migration is an accepted non-requirement for Release 1**. Do not reopen that decision.

However the new Ashita settings store has a separate safety issue.

If new `rahvings/settings.lua` exists but cannot parse:
- current store returns defaults;
- Rahvin receives no `settings_refused`;
- default version stamps appear stale;
- scheduled reset/save can write defaults over the broken user file.

Rahvin's original safety contract is:
- run on defaults when settings are refused;
- report the refusal;
- **do not save over the unreadable file**.

This must be preserved for the new Ashita store.

---

# 20. MEDIUM/HIGH finding — action object fields

Rahvin reads fields including:
- action_type;
- element;
- element_id;
- english;
- id;
- name;
- prefix;
- recast_id;
- skill;
- skill_id;
- target;
- type.

Current normalizer supplies most.

Missing:
- `skill_id` — functional because Rahvin checks numeric Elemental Magic skill id `36` for Zodiac Ring eligibility;
- `prefix` — lower severity because current code already identifies Item by action_type, but should be supplied for API parity.

---

# 21. MEDIUM finding — pretarget second argument

Rahvin exposes:
`pretarget_custom(spell, action)`

Current composition invokes Rahvin pretarget with only one normalized object, making the second argument nil.

Shipped sample jobs currently do not dereference the second value, so this is not currently the top blocker, but it is API-parity debt.

---

# 22. Sample-job command exposure

Across the shipped sample set, direct command usage includes examples such as:

- BLU: chained `input //aset ...; input /macro ...; wait ...`
- PLD/RUN: delayed `aset set tanking`
- SMN: repeated macro book/set command chains
- COR: `lua u autocor`

This means generic command compatibility cannot be narrowly hardcoded only for engine commands.

External-addon commands must be classified:
- pass through if a valid Ashita equivalent exists;
- translate where syntax differs;
- document truly external dependencies;
- never silently pretend success.

---

# 23. Confirmed-good findings from deep audit

Do not regress these.

## LAC profile loader
Pinned LAC does:
- `loadfile(profilePath)`
- `gProfile = chunk()`

Therefore:
`return require('ashita.profile').production(...)`
is structurally correct.

## LAC priority
LAC truly supports per-item `Priority` and ordered equip packets.

## Slot normalization
GearSwap aliases and canonical slot names are correctly mapped.

## Cancel primitive
LAC `CancelAction()` is a valid low-level primitive.

## Resources
Current port supplies core Rahvin-used resource families and `res.items:with(...)`.

## Inventory
Container indexing matches pinned LAC's 1..max scan convention.

## Extdata/recasts
Core augmented-instance and enchant/Hoxne data paths are implemented and previously targeted by tests.

## Packets
- 0x028 action decode is structurally good;
- 0x00A zone decode is good;
- 0x00B logout detection is now pinned to real Ashita semantics.

## Party / IPC
- Windower party key shape is present;
- IPC time base is milliseconds as Rahvin expects;
- localhost transport ownership is per runtime generation.

## Display
Text object method surface and LATTICE primitive methods are all represented.

## Inline colors
Fixed at `d47b144`.

## Reload architecture
No confirmed require-cache ownership bug was found:
- scheduler queue is cleared;
- events are deregistered/reset;
- IPC is closed;
- command handler unregisters;
- bridged keys clear;
- Rahvin includes use loadfile, not require caching.

Still add a same-process reload regression before live.

## GearSwap internals optimization
Rahvin's optional `build_is_worn()` use of GearSwap internal tables is not emulated, but missing internals fall back to normal equip. This is optimization/performance parity debt, not a known correctness failure.

## Addon-command warning event
Rahvin's native GearSwap addon-command advisory warning need not be artificially emulated because Ashita has no equivalent native GearSwap disable/enable surface.

---

# 24. Required TDD fix order

Follow this order unless new evidence proves a dependency requires a change.

## Wave 1 — equipment contract

RED first:
- GearSwap item-field normalization;
- `empty` sentinel;
- preserve LAC-shaped metadata;
- preserve priority/AugPath/AugRank/AugTrial;
- no source-table mutation.

**Current repo is already at the beginning of this Wave with two committed RED tests.**

First action in the next chat:
1. inspect the two current RED tests and the one-boundary normalization design;
2. resolve whether both tests intentionally require the same shared idempotent normalizer or one test should be narrowed;
3. ask user to run the targeted RED(s) only after the intended contract is coherent;
4. then implement the fix;
5. targeted GREEN;
6. full suite GREEN.

Do not claim RED/GREEN without user output.

## Wave 2 — GearSwap event primitives

RED first:
- event-scoped `_global.cancel_spell`;
- `string:unpack`;
- `skill_id` and prefix;
- snapshot refresh before each action boundary.

## Wave 3 — raw/wrapped event ownership

RED first:
- wrapped = refresh → handler(s) → one flush;
- raw = handler(s) → discard buffered equip;
- target and IPC wrapped semantics;
- zone/action/outgoing/prerender raw semantics;
- no cross-event pending-buffer leakage.

## Wave 4 — state events

RED first:
- gain/lose buff numeric-ID events;
- ordinary buff_change still fires correctly;
- exact ordering;
- subjob diff and callback;
- shared scheduler preservation.

## Wave 5 — pet runtime

RED first:
- pet_midaction;
- GetPetAction translator;
- one pet_midcast on start;
- one pet_aftercast on completion;
- simultaneous player action safety;
- no duplicate callbacks on repeated default ticks.

## Wave 6 — command compatibility

RED first:
- internal `gs c`;
- semicolon chain parser;
- wait on shared scheduler;
- `input` execution;
- cancel mapping;
- real sample `jobsetup`;
- explicit validate/exec/terminate decisions;
- external addon command classification.

## Wave 7 — settings corruption safety

RED first:
- malformed new settings detected/refused;
- defaults allowed only in memory;
- no overwrite of broken source;
- precise user-facing refusal;
- repeated reload safe.

## Wave 8 — integration/reload/sample jobs

- same process generation A → load → activity → unload → generation B → load;
- no scheduler/events/IPC/keybind/primitives/action state leakage;
- load all 22 unchanged sample jobs through the real compatibility environment;
- full suite.

Only after Waves 1–6 are GREEN should Phase-4 real client live testing resume.

---

# 25. Current live-test status

No full real-client parity acceptance has been performed yet.

A live smoke runbook exists:
`docs/LIVE_TEST_PHASE4.md`

However the deep audit supersedes the previous intention to begin live testing immediately.

**Do not run real-job live tests now.**

After blocker waves are fixed, live gates still required include:

- actual profile load/reload;
- all four display styles;
- drag/save/reload;
- zone cleanup/recovery;
- logout/login;
- unload/reload;
- real melee/spell/JA/WS/ranged/item flows;
- interrupted actions;
- TH raw packet evidence;
- Hoxne;
- enchanted item use;
- Sleep/Doom/Remedy/Holy Water behavior;
- pet action behavior;
- subjob change;
- real command chains/jobsetup;
- 2-client IPC / SpellReceived;
- no stale held slots/events/scheduler/IPC/display/keybind state;
- exact installed Ashita and LuAshitacast revisions recorded.

---

# 26. User interaction / evidence rules

The user runs LuaJIT tests in Termux and pastes output.

Never claim a user-side RED or GREEN before they paste it.

When a user-confirmed GREEN arrives:
- immediately continue to the next TDD gate when possible;
- do not stop merely to restate success;
- only stop when a genuine user-run/live gate is necessary.

The user explicitly asked for a full original-vs-port detail audit because they do not want live testing to be used to discover avoidable compatibility mistakes. Continue that philosophy.

---

# 27. Exact next-chat resume point

Start by reading:
- this handoff;
- `docs/DEEP_PARITY_AUDIT_2026-10-04.md`;
- `docs/AUDIT_RAHVIN_2_1_0_PORT_PARITY_2026-10-04.md`.

Then inspect current:
- `tests/contract/test_gearswap_slots.lua`
- `tests/ashita/test_equip_backend.lua`
- `compat/gearswap.lua`
- `ashita/equip_backend.lua`
- `compat/environment.lua`

Current Wave-1 RED intent is:
- normalize true GearSwap item metadata to LAC semantics;
- add the GearSwap `empty` sentinel;
- preserve source immutability.

Before implementing, reconcile the fact that the two current REDs both demand normalization at different adapter layers even though the architectural intention is one normalization contract. Prefer a shared, idempotent normalizer or narrow the redundant test — do not create divergent duplicate logic.

After the contract is coherent, have the user run the targeted RED tests. Only then implement and continue Wave 1.

---

# 28. Suggested prompt for the next chat

Use:

> Wir setzen den Rahvin GearSwap 2.1.0 → Ashita v4 + LuAshitacast Port fort. Lies zuerst vollständig `docs/HANDOFF_2026-10-04_FULL_PARITY_AUDIT.md`, danach `docs/DEEP_PARITY_AUDIT_2026-10-04.md` und `docs/AUDIT_RAHVIN_2_1_0_PORT_PARITY_2026-10-04.md`. Arbeite ausschließlich in `TGffxi/Gearswap` auf `master`, keine Branches/PRs. Der letzte von mir bestätigte GREEN-Stand ist `d47b144` mit 47/47. Current master enthält danach Audit-Doku und Wave-1-RED-Verträge, aber noch keinen Produktfix. Fahre exakt am Wave-1-Resume-Punkt der Übergabe fort: GearSwap Item-Metadaten + empty-Sentinel, TDD, RahvinGS/Sample Jobs unverändert lassen. Noch keine Live-Tests und keine Phase 5.

---

# 29. Final status at handoff creation

- Rahvin source integrity: **PASS**
- 22 sample jobs source integrity: **PASS**
- last user-witnessed automated suite: **47/47 GREEN at d47b144**
- current deep parity gate: **RED**
- current work phase: **Wave 1 RED contract**
- live acceptance: **NOT STARTED / intentionally deferred**
- Phase 5/release: **FORBIDDEN until parity + live gates complete**
