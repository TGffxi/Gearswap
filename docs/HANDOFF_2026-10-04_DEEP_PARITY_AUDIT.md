# HANDOFF — Rahvin GearSwap 2.1.0 → Ashita v4 + LuAshitacast
## Deep parity audit / pre-live hardening
Date: 2026-10-04

---

# 0. READ THIS FIRST

This handoff is the authoritative resume point for the next ChatGPT conversation.

Work exclusively in:

- repository: TGffxi/Gearswap
- branch: master

Do NOT create feature, sync, RC or temporary branches. Do not create pull requests.

Do not patch RahvinGS/ or Sample Job Files/ unless a future audit proves that an adapter solution is impossible.

Port strategy remains:

- Rahvin GearSwap 2.1.0 semantics are authoritative.
- Rahvin source layout stays upstream-clean.
- LuAshitacast is the equip/action backend.
- Windower/GearSwap behavior is reproduced through compat/ and ashita/.
- Prefer adapters over direct upstream changes.
- Keep one shared scheduler/event/lifecycle/IPC ownership graph.
- No second scheduler queue.
- The eleven Rahvin startup schedules must not be registered twice.
- No new architecture unless the current design is proven unable to express an original Rahvin behavior.
- No Phase 5 / release packaging before deep parity fixes and live gates are complete.

Before modifying an existing repository file, fetch latest GitHub content and SHA.

The user runs LuaJIT tests and provides authoritative observed GREEN/RED output. Never claim a user-side test is GREEN until the user has pasted the result.

---

# 1. CURRENT REPOSITORY STATE

Current master HEAD before this handoff commit:

62553ef65d87ad93e9cde24fc295b6d182f2b908

Recent commits after the last user-confirmed full GREEN:

- 2321bb9f2c64074acb4e9bad06c4ba3b7d5eb4c5
  - docs: record deep Rahvin parity audit
  - adds docs/DEEP_PARITY_AUDIT_2026-10-04.md

- cf47ba4601fc2a0a5ef1f22de46a216a509d70fa
  - test: require GearSwap item metadata parity
  - extends tests/contract/test_gearswap_slots.lua

- 8b9ba33db732775e1881fd733ebd70aff7ceacfb
  - docs: add detailed Rahvin 2.1.0 port parity audit
  - adds docs/AUDIT_RAHVIN_2_1_0_PORT_PARITY_2026-10-04.md

- 62553ef65d87ad93e9cde24fc295b6d182f2b908
  - test: require GearSwap item field normalization
  - extends tests/ashita/test_equip_backend.lua

These four commits are audit documentation and intentional RED contracts.
No parity finding has yet been fixed after d47b144.

---

# 2. LAST USER-CONFIRMED AUTOMATED GREEN

Last user-confirmed complete suite:

d47b144ea1559790c5c4aa958d7b01150d8303ad

Observed result:

RESULT 47 passed, 0 failed

At that checkpoint:
- inline Windower color tags were translated correctly for Ashita fonts;
- the real Ashita logout packet path had already been fixed;
- production composition, native adapters, resources, extdata, settings, keybinds, display, IPC and prior parity tests were GREEN.

Important:

Do NOT describe current HEAD as 47/47 GREEN.

The two new Wave-1 tests have not yet been run by the user. They are intentionally written to expose a known blocker and are expected RED until Wave 1 is implemented.

---

# 3. PINNED BASELINES

Rahvin GearSwap 2.1.0:
f1cda1e41f567b16ec592e6598cda71bb04392d0

Rahvin release SHA:
0111cb34cdfb800f58ab495480b383d922f9e5846f41f40d7b39400432f2ab01

LuAshitacast baseline:
7ed398edd3ebbdc8af86a79e5d3427da42e3a34a

Ashita v4 beta source baseline:
4171c74c8ddb2ca2a31654f199e6c1cee40d7256

Original TGffxi fork snapshot:
8bca6c48d437f93932ccf38313ae3d0a472b626e

---

# 4. REQUIRED DOCUMENTS TO READ IN THE NEXT CHAT

Read before implementation:

1. docs/HANDOFF_2026-10-04_DEEP_PARITY_AUDIT.md
2. docs/DEEP_PARITY_AUDIT_2026-10-04.md
3. docs/AUDIT_RAHVIN_2_1_0_PORT_PARITY_2026-10-04.md
4. docs/HANDOFF_2026-10-03_FULL_RUNTIME_RUNBOOK.md
5. docs/HANDOFF_2026-10-03_RUNTIME_COMPOSITION.md
6. docs/superpowers/specs/2026-10-03-rahvings-ashita-port-design.md
7. phase plans under docs/superpowers/plans/
8. docs/LIVE_TEST_PHASE4.md

If older handoffs conflict with current evidence, precedence is:

1. current user-observed evidence;
2. current master;
3. this handoff + 2026-10-04 audit documents;
4. older handoffs/plans.

---

# 5. USER ENVIRONMENT / LIVE TARGET

The actual live environment is not a separate Windows PC.

FFXI runs in the user's existing CachyOS environment with Ashita already installed.

Known paths:

Ashita:
/home/stevel/Games/FFXI/ashita

LuAshitacast character profile:
/home/stevel/Games/FFXI/ashita/config/addons/LuAshitacast/Thegrouch_42221

When live testing eventually resumes, planned isolated port copy:

/home/stevel/Games/FFXI/ashita/config/addons/LuAshitacast/Thegrouch_42221/rahvings-port

with RAHVIN-SMOKE.lua beside it.

Do not start the real-job live test now. Deep parity audit is RED. Waves 1–6 must be fixed and GREEN first.

---

# 6. UPSTREAM INTEGRITY

Direct comparison against Rahvin baseline f1cda1e... confirmed:

- RahvinGS/: 16/16 entries SHA-identical.
- Sample Job Files/: 22/22 entries SHA-identical.
- No Rahvin engine source patch required so far.
- No shipped sample-job source patch required so far.

Preserve this.

---

# 7. IMPORTANT COMPLETED FIXES / EVIDENCE

## Windower mob distance

Rahvin calls get_mob_by_id(...).distance:sqrt().
Ashita exposes squared entity distance.

Commit ddf0cd0860f31e3abf72ab91aa8d499fbd168631 added a Windower-compatible distance object with:
- squared
- sqrt()

User confirmed full suite GREEN after this.

## Real Ashita logout

Pinned Ashita v4 has no matching native logout event.

Real logout criterion:
- incoming 0x00B
- byte at +0x04 == 1

Port now routes this packet into the one lifecycle owner.

Key commits:
- 694c2efdbe2e3d6930d80c5e06ef1a147cd165b4
- 57a731e947aaf50d965bcd6123648c82c444e8dd
- 88bc71938255bfe0c51797c3865d8be63601b981
- 14396119513aa0c4399076013fd07c228e6b4456
- c9e5583361157018d487cb52420a3a594b49a199
- test alignment b7dd6ca... and 6aca714...

User confirmed all targeted tests and full 47/47 GREEN.

## Inline display colors

Rahvin emits Windower tags like:
\cs(r,g,b)...\cr

Ashita fonts require:
|cAARRGGBB|...|r

RED:
735562af4504b7706257e98fe16a35baf4fc99d8

Fix:
d47b144ea1559790c5c4aa958d7b01150d8303ad

Conversion happens only at the Ashita renderer boundary. Rahvin-facing getters retain original source strings.

User confirmed texts_renderer and full suite GREEN.

---

# 8. DEEP PARITY AUDIT CONCLUSION

Audit derived directly from:
- all 16 RahvinGS Lua files;
- all 22 sample job files;
- pinned LuAshitacast source;
- pinned Ashita v4 source;
- current compat/ and ashita/ code.

Conclusion:

AUTOMATED HISTORICAL SUITE GREEN, DEEP PARITY AUDIT RED.

The port is not ready for a real-job feature-parity claim or final live acceptance.

---

# 9. CRITICAL FINDING — GEAR ITEM METADATA

Rahvin/GearSwap item tables use lowercase fields:
- name
- priority
- augments
- augment
- bag

Pinned LuAshitacast MakeItemTable consumes:
- Name
- Priority
- Augment
- Bag
- AugPath
- AugRank
- AugTrial

Current adapter before Wave 1:
- normalizes equipment slot names;
- copies item tables;
- does not normalize GearSwap item metadata spelling.

Breadth:
- central builders use lowercase name/priority;
- roughly 935 lowercase augments entries;
- roughly 77 lowercase bag constraints.

Real table-form gear can therefore fail to resolve or lose:
- item identity;
- priority ordering;
- augment identity;
- bag identity.

Positive fact:
Pinned LAC does correctly support Priority and sorts equip operations by descending Priority, then slot order.

---

# 10. CURRENT WAVE-1 RED CONTRACTS ON MASTER

tests/contract/test_gearswap_slots.lua now requires:
- name → Name
- priority → Priority
- augments → Augment
- singular augment → Augment
- bag → Bag
- preserve already-LAC-shaped fields
- preserve AugPath/AugRank/AugTrial
- do not mutate original Rahvin item tables
- stable GearSwap-compatible env.empty sentinel
- empty → LAC explicit unequip/remove semantics

tests/ashita/test_equip_backend.lua now additionally requires direct backend normalization of a real Rahvin-shaped lowercase item object.

Recommended implementation pattern:
- one shared item-spec normalizer module;
- same helper used by compat.gearswap and ashita.equip_backend;
- no duplicated mapping logic.

No implementation has been committed yet.

---

# 11. HIGH-SEVERITY FINDINGS

## Missing gain buff / lose buff

Current state_runtime generates GearSwap buff_change(name,gain), but Rahvin separately registers Windower:
- gain buff
- lose buff

Those handlers need numeric buff IDs.

Affected behavior:
- Accession prediction cleanup;
- Divine Seal prediction cleanup;
- Remedy auto-use;
- Holy Water auto-use;
- Sleep hold;
- Doom/Cursna hold;
- Sleep/Doom release;
- Corsair roll cleanup.

Need both GearSwap buff_change by name and Windower gain/lose by numeric ID with correct ordering.

## Missing pet runtime

Pinned LAC requires profiles to inspect gData.GetPetAction() manually.

Current bootstrap never reads it.

Therefore:
- pet_midcast never fires;
- pet_aftercast never fires;
- shipped pet custom hooks are unreachable.

Need:
- pet-action normalizer;
- identity/state tracking;
- one midcast on start;
- one aftercast on completion/disappearance;
- coexist safely with player actions.

## Missing pet_midaction()

Rahvin calls global pet_midaction() in:
- action refusal;
- precast;
- midcast;
- aftercast;
- enchant timing;
- Hoxne timing.

Compat does not define it.

It must share state with the pet runtime.

## Missing sub_job_change(new,old)

Rahvin uses this callback to:
- invalidate layout;
- invalidate set index;
- reset warnings;
- schedule Dual Wield refresh;
- schedule two-hand refresh;
- schedule rebuild;
- call sub_job_change_custom.

Pinned LAC does not replace this for simple subjob change.

All 22 sample jobs define sub_job_change_custom.

## Action-time state freshness

Snapshot is refreshed initially and during HandleDefault, but not immediately before:
- HandleAbility
- HandleItem
- HandlePrecast
- HandleMidcast
- HandlePreshot
- HandleMidshot
- HandleWeaponskill

Pinned LAC can call these with no preceding HandleDefault.

Rahvin can see stale:
- player
- world
- buffactive
- pet
- equipment
- inventory
- target
- movement/TP/weather state

## Wrapped/raw event semantics collapsed

Rahvin deliberately uses both windower.register_event and windower.raw_register_event.

GearSwap semantics differ:
- wrapped events refresh globals and can commit gear;
- raw events do not automatically commit gear.

Current adapter maps both to one event surface.

Potential consequences:
- target-change builds from stale globals and leaves gear buffered;
- IPC SpellReceived gear stays pending until an unrelated callback;
- raw zone/action/prerender handlers leave accidental pending gear.

Need:
- wrapped = refresh → handlers → one flush
- raw = handlers → discard pending gear
- no pending set crossing event boundaries

## Windower send_command grammar not mapped

Current native adapter only special-cases bind/unbind.

Rahvin emits:
- gs c ...
- gs validate
- wait ...; ...
- input ...
- cancel <buffid>
- exec ...
- terminate
- optional broadcast/addon commands

Every sample job calls jobsetup at file scope, and Rahvin jobsetup emits a chain with wait/input/gs validate/gs c update auto.

This is a normal job-load blocker.

## windower.chat.input currently does not execute

Current mapping uses Ashita SetInputText.

Windower chat.input('/...') executes.

Rahvin uses this for:
- Remedy
- Holy Water
- food
- enchanted items
- Hoxne abilities/items

## Missing string:unpack

Rahvin uses:
- data:unpack('I', 0x09)
- data:unpack('H', 0x19)
- data:unpack('fff', 5)

for TH/raw movement paths.

Pinned Ashita uses struct.unpack(format,data,offset) and does not supply string:unpack.

## Missing GearSwap empty

Rahvin uses global empty for:
- naked/strip modes;
- range yielding;
- held-slot restoration;
- weapon lock;
- release/rebuild.

Pinned LAC explicit unequip sentinel is remove.

Wave 1 RED already covers this.

## Missing _global.cancel_spell

Rahvin reads event-scoped _global.cancel_spell after cancellation paths.

Current adapter calls LAC CancelAction but never sets/resets this GearSwap flag.

Affected:
- outgoing IPC debt settlement;
- Hoxne critical-window behavior;
- cancellation parity.

## New settings corruption safety

Legacy Windower XML migration is an accepted Release-1 difference.

But the new Ashita settings store can silently fall back to defaults on parse failure without giving Rahvin settings_refused.

Default version stamps can then trigger save/reset and overwrite the damaged user file.

Need original Rahvin safety:
- defaults may run in memory;
- source marked refused;
- no save while refused.

---

# 12. MEDIUM FINDINGS

## Missing spell.skill_id

Rahvin checks spell.skill_id == 36 for Zodiac Ring Elemental Magic eligibility.

Pinned LAC underlying spell resource has numeric Skill data.
Current lac_data does not expose it.

## Pretarget second argument

Rahvin supports pretarget_custom(spell, action).

Current composition gives only one normalized object, so second argument is nil.

Shipped sample jobs do not currently dereference it, but this remains API parity debt.

## Command-family decisions

Need explicit decisions/mappings for:
- profile → Windower exec
- shutdown → terminate
- gs validate
- sample-job aset
- sample-job lua u autocor
- broadcasts such as send @others ...

Do not claim support just because QueueCommand accepts a string.

---

# 13. LOW / ACCEPTED DIFFERENCES

Not blockers:
- no automatic migration of legacy Windower XML settings in Release 1;
- no full GearSwap internal build_is_worn optimization surface;
- no native GearSwap addon-command advisory event under Ashita;
- missing spell.prefix is currently redundant because item routing uses action_type == Item.

---

# 14. CONFIRMED-GOOD FOUNDATIONS

Still sound:
- RahvinGS upstream-clean;
- all 22 sample jobs upstream-clean;
- deterministic include environment;
- M/T/S primitives;
- set_combine;
- slot aliases;
- Spell/JA/WS/Ranged/Item action categories;
- LAC CancelAction primitive;
- LAC per-item Priority capability;
- resource collections;
- res.items:with;
- inventory iteration/index basis;
- recasts;
- extdata foundations;
- Hoxne/enchant decoding foundations;
- 0x028 action packet decoder;
- 0x00A zone decoder;
- 0x00B logout decoder;
- target diffing;
- mob squared-distance → Windower sqrt surface;
- party shape;
- IPC translation;
- IPC millisecond time base;
- localhost transport ownership;
- text API;
- primitive API;
- inline colors;
- settings atomic write/replace mechanics;
- keybind syntax translation;
- bridge-owned key cleanup;
- LAC profile return contract;
- lifecycle ownership;
- unload/logout cleanup architecture.

---

# 15. SAMPLE JOB AUDIT

All 22 sample jobs expose the broad common hooks:
- sub_job_change_custom
- pretarget_custom
- precast_custom
- midcast_custom
- aftercast_custom
- buff_change_custom
- status_change_custom
- pet_change_custom
- pet_midcast_custom
- pet_aftercast_custom
- self_command_custom
- user_file_unload

Thus pet/subjob gaps are broad failures.

Observed sample command usage:
- BLU: input //aset ...; input /macro ...; wait ...
- PLD/RUN: delayed aset set tanking
- SMN: macro book/set chains
- COR: lua u autocor
- BLM/RNG: direct windower.add_to_chat

---

# 16. REQUIRED FIX WAVES

Do not skip ahead.

## Wave 1 — equipment contract

RED already partially committed.

Required:
- lowercase GearSwap metadata normalization;
- singular/plural augment mapping;
- bag mapping;
- preserve LAC fields;
- preserve AugPath/AugRank/AugTrial;
- no mutation;
- stable empty sentinel;
- empty → remove;
- one shared normalization helper preferred.

After implementation:
- targeted tests
- full suite
- user must paste GREEN

Expected full test count remains 47 because existing modules were extended.

## Wave 2 — GearSwap event primitives

RED first:
- event-scoped _global.cancel_spell;
- Windower string:unpack;
- spell.skill_id;
- spell.prefix;
- snapshot refresh before each action boundary.

## Wave 3 — wrapped/raw event ownership

RED first:
- wrapped refresh → handlers → one flush;
- raw handlers → pending equip discard;
- IPC wrapped behavior;
- target-change wrapped behavior;
- zone/action/outgoing/prerender raw behavior;
- no buffered gear leak.

## Wave 4 — state events

RED first:
- numeric gain buff;
- numeric lose buff;
- ordinary buff_change(name,gain);
- exact ordering;
- subjob diff;
- one sub_job_change(new,old);
- shared scheduler retained.

## Wave 5 — pet runtime

RED first:
- GetPetAction normalization;
- pet_midaction;
- one pet_midcast;
- one pet_aftercast;
- no duplicate callbacks;
- player/pet concurrency.

## Wave 6 — command compatibility

RED first:
- internal gs c dispatch;
- semicolon command chains;
- wait on shared scheduler;
- input executes;
- cancel mapping;
- full jobsetup;
- define gs validate;
- define exec/profile;
- define terminate/shutdown;
- classify aset, lua u, broadcasts;
- unsupported Windower commands fail precisely.

## Wave 7 — settings corruption safety

RED first:
- malformed new settings detected;
- defaults in memory allowed;
- source refused;
- save blocked;
- one precise recovery message;
- repeated reload preserves damaged source.

## Wave 8 — integration/reload

Same Lua process:
- production A
- OnLoad
- activity
- OnUnload
- production B
- OnLoad
- OnUnload

Assert no carryover:
- scheduler tasks
- event aliases
- IPC
- command alias
- bridge-owned keys
- primitive/font
- pending equip
- player action state
- pet state

Then load all 22 sample jobs through real compat environment.

---

# 17. LIVE TEST STATUS

Live testing was postponed after deep audit blockers were found.

Existing runbook:
docs/LIVE_TEST_PHASE4.md

It covers:
- load
- version command
- reload x3
- four display styles
- settings/drag/save/reload
- zone
- logout/login
- unload

After that:
- melee
- spell
- JA
- WS
- ranged
- aftercast/interruption
- raw packet evidence
- TH
- Hoxne
- enchanted item
- two-client IPC / SpellReceived

Do not resume until Waves 1–6 are GREEN.

---

# 18. LIVE EVIDENCE STILL OUTSTANDING

Still outstanding:
- two-client IPC
- raw 0x028/0x029 + TH evidence
- Hoxne live evidence
- enchant live evidence
- zone/reset live evidence
- exact installed Ashita/LAC revisions
- repeated settings saves/renames
- full load → use → reload → zone → logout → login → use → unload
- no stale overlay/keybind/packet/scheduler/IPC/held slot/action state
- all display styles
- real sample jobs

---

# 19. EXACT RESUME POINT

Next chat must NOT redo the audit.

Do:

1. Read section 4 documents.
2. Verify master is 62553ef... or newer.
3. Have user pull current master and run Wave-1 targeted tests if not already done.
4. Expected RED is item normalization / empty sentinel.
5. Implement Wave 1 without touching RahvinGS or sample jobs.
6. User runs targeted tests, then luajit tests/run.lua all.
7. Only after user-confirmed GREEN continue Wave 2.
8. Continue wave-by-wave through Wave 8.
9. Resume live Phase 4 only after Waves 1–6 are GREEN and Waves 7–8 hardened.

Suggested immediate commands:

cd ~/Gearswap
git pull --ff-only
git log -1 --oneline
luajit tests/run.lua gearswap_slots
luajit tests/run.lua equip_backend

Expected at current Wave-1 RED HEAD:
RED.

---

# 20. WAVE-1 ENGINEERING CONSTRAINTS

Do not solve item metadata by changing Rahvin gear definitions.

Do not change:
- RahvinGS/GearSets-Include.lua
- any sample job

Preferred:
- tiny shared item-spec compatibility helper;
- pure table transformation;
- no mutation;
- strings remain strings;
- lowercase aliases normalized;
- uppercase LAC fields preserved;
- unknown metadata preserved unless conflicting;
- empty sentinel handled by identity at GearSwap boundary and translated to remove.

Be careful:
- augments → Augment
- augment → Augment
- define deterministic precedence if Augment and aliases coexist
- bag spelling passed to LAC
- priority remains numeric
- AugPath/AugRank/AugTrial survive unchanged

---

# 21. USER WORKFLOW PREFERENCES

User wants:
- direct action;
- exact commands/paths;
- no generic alternatives;
- no unnecessary clarification;
- no repeated questions;
- no context loss;
- no premature live testing while automated parity work remains;
- audit before implementation;
- RED first;
- user-observed GREEN before declaring pass;
- after GREEN, continue immediately to next meaningful gate when possible.

---

# 22. FINAL HANDOFF STATE

Repository:
TGffxi/Gearswap

Branch:
master

Base before this handoff commit:
62553ef65d87ad93e9cde24fc295b6d182f2b908

Last user-confirmed full GREEN:
d47b144ea1559790c5c4aa958d7b01150d8303ad
47 passed, 0 failed

Current gate:
DEEP PARITY AUDIT RED / WAVE 1 RED CONTRACTS PRESENT

Do not live test.
Do not enter Phase 5.
Do not patch RahvinGS.
Do not redo findings 1–20.

Resume:
Wave 1 — GearSwap item metadata + empty sentinel compatibility.
