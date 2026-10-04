# Rahvin GearSwap 2.1.0 → Ashita v4 + LuAshitacast
## Deep Function / Boundary Parity Audit — 2026-10-04

### Scope and authority

This audit compares the unchanged Rahvin GearSwap 2.1.0 baseline at:

- Rahvin baseline: `f1cda1e41f567b16ec592e6598cda71bb04392d0`
- LuAshitacast baseline: `7ed398edd3ebbdc8af86a79e5d3427da42e3a34a`
- Ashita v4 baseline: `4171c74c8ddb2ca2a31654f199e6c1cee40d7256`

against the current `TGffxi/Gearswap` `master`.

The last user-witnessed automated checkpoint before this audit is:

- `d47b144ea1559790c5c4aa958d7b01150d8303ad`
- `luajit tests/run.lua all` → **47 passed, 0 failed**

That GREEN checkpoint is real, but this audit deliberately does not treat test coverage as proof of full parity. It derives the contract again from the original Rahvin source and from the pinned Ashita/LuAshitacast implementations.

---

## 1. Upstream cleanliness

### PASS

Blob-level comparison confirms:

- all 16 entries under `RahvinGS/` are unchanged from the Rahvin 2.1.0 baseline;
- all 22 files under `Sample Job Files/` are unchanged from the Rahvin 2.1.0 baseline.

The port remains isolated to `compat/`, `ashita/`, tests and documentation.

This preserves the primary upstreamability requirement: Rahvin engine/job changes can continue to be consumed without maintaining a forked engine.

---

## 2. Shipped sample-job exposure

All **22/22** shipped sample jobs:

- call `jobsetup(...)` at file scope;
- define `pet_midcast_custom(...)`;
- define `pet_aftercast_custom(...)`;
- define `sub_job_change_custom(...)`;
- define `self_command_custom(...)`.

Therefore the missing command, pet and subjob boundaries below affect the shipped job contract broadly; they are not edge cases.

Several jobs also contain direct Windower command chains and/or lowercase GearSwap item tables.

---

## 3. GearSwap callback parity

| Rahvin / GearSwap entry | Current port mapping | Audit |
|---|---|---|
| `get_sets()` | `OnLoad → engine.load → get_sets` | PASS |
| `pretarget(spell, action)` | run before `precast` inside LAC `HandlePrecast` | PARTIAL |
| `precast(spell)` | `HandlePrecast` | PASS subject to snapshot/event fixes |
| `midcast(spell)` | `HandleMidcast` | PASS subject to snapshot/event fixes |
| `aftercast(spell)` | action-runtime completion / synthetic aftercast | PASS automated |
| `buff_change(name,gain)` | state snapshot diff | PARTIAL |
| `status_change(new,old)` | state snapshot diff | PASS subject to snapshot timing |
| `pet_change(pet,gain)` | state snapshot diff | PASS subject to snapshot timing |
| `pet_midcast(spell)` | none | **FAIL** |
| `pet_aftercast(spell)` | none | **FAIL** |
| `sub_job_change(new,old)` | none | **FAIL** |
| `file_unload(file_name)` | `OnUnload` | PASS |
| `self_command(cmd)` | `/rahvings` + `/lac fwd` | PASS for direct user forwarding; internal `gs c` FAIL |

### 3.1 Pretarget second argument

Rahvin exposes `pretarget_custom(spell, action)`.

The current composition invokes Rahvin `pretarget` with only the normalized action/spell object, so the second `action` argument is nil.

The shipped sample jobs do not currently dereference that second object, therefore this is not a shipped-job blocker, but it is still an API-parity difference.

Severity: **MEDIUM**.

### 3.2 GearSwap cancel event state

Rahvin reads exactly one GearSwap `_global` field:

`_global.cancel_spell`

GearSwap sets this event-scoped flag when `cancel_spell()` is called. Rahvin uses it after `pretargetcheck` and `pretarget_custom` to settle outgoing IPC debt and Hoxne critical-window behavior.

The current adapter calls LAC `gFunc.CancelAction()` but does not set/reset `_global.cancel_spell`.

Severity: **HIGH**.

---

## 4. Windower event parity

Rahvin root performs 12 registrations across 11 distinct Windower event names.

| Original event | Port source | Audit |
|---|---|---|
| `target change` | outgoing-packet target-index diff | PARTIAL |
| `incoming chunk` | Ashita `packet_in` | PARTIAL |
| `outgoing chunk` | Ashita `packet_out` | PARTIAL |
| `zone change` | decoded incoming `0x00A` | PASS |
| `ipc message` | local UDP multicast → Rahvin wire message | PARTIAL |
| `prerender` / Hoxne | lifecycle `d3d_present` → platform event | PASS structural |
| `prerender` / SpellReceived failsafe | same frame surface, separate Rahvin registrations | PASS structural |
| `gain buff` | none | **FAIL** |
| `lose buff` | none | **FAIL** |
| `logout` | incoming `0x00B`, byte +0x04 == 1 → lifecycle | PASS |
| `addon command` | not reproduced | ACCEPTABLE DIFFERENCE |
| `action` | decoded incoming `0x028` | PASS |

### 4.1 Missing gain/lose buff events

Current `state_runtime` reproduces GearSwap `buff_change(name,gain)`, but does not emit Rahvin's separately registered Windower:

- `gain buff` → `E.sr_gain_buff(id)`
- `lose buff` → `E.sr_lose_buff(id)`

Those handlers require the numeric buff ID and own behavior not present in `buff_change`:

- Accession prediction clearing;
- Divine Seal prediction clearing;
- Remedy auto-use;
- Holy Water auto-use;
- Sleep gear hold;
- Doom / Cursna gear hold;
- release of Sleep/Doom holds;
- Corsair roll cleanup.

Severity: **HIGH**.

### 4.2 Raw vs wrapped event semantics are collapsed

Windower `register_event` and `raw_register_event` are not semantically identical in GearSwap.

Rahvin intentionally relies on this distinction and documents it repeatedly:

- wrapped events see refreshed GearSwap globals and may commit equipment;
- raw events intentionally do not commit equipment, so Rahvin defers rebuilds through `gs c ...`.

Current `compat.windower` maps both to the same `platform.register_event`.

Current `platform.emit`:

- does not refresh the snapshot before wrapped handlers;
- does not flush GearSwap-compatible equipment after wrapped handlers;
- does not discard equipment buffered by raw handlers.

Consequences include:

- target-change can build from stale globals and leave its equip pending;
- `ipc message` can equip SpellReceived gear but leave it buffered until some later LAC callback;
- raw zone/action/prerender handlers can accidentally leave gear in the backend buffer for a later callback to send.

Severity: **HIGH / structural**.

---

## 5. State freshness

### FAIL — action callbacks can see stale GearSwap globals

`capture_snapshot()` refreshes:

- `player`
- `world`
- `buffactive`
- `pet`
- `equipment`
- inventory / wardrobes
- target

at initial composition and during `HandleDefault`.

It is not refreshed immediately before:

- `HandleAbility`
- `HandleItem`
- `HandlePrecast`
- `HandleMidcast`
- `HandlePreshot`
- `HandleMidshot`
- `HandleWeaponskill`

Pinned LuAshitacast packet flow can call these handlers directly after setting `PlayerAction`; it does not guarantee a preceding `HandleDefault`.

Therefore Rahvin action hooks can observe state from the previous default cycle.

Severity: **HIGH**.

---

## 6. Pet action parity

### FAIL — pet action runtime missing

Pinned LuAshitacast explicitly states that pet actions are not automatically handled by `HandleDefault`; profiles must call `gData.GetPetAction()`.

Current bootstrap never reads `gData.GetPetAction()`.

Consequently:

- `pet_midcast(spell)` never runs;
- `pet_aftercast(spell)` never runs;
- all 22 shipped `pet_midcast_custom` / `pet_aftercast_custom` hooks are unreachable.

Pinned LAC `GetPetAction()` exposes sufficient source data for a compatibility adapter:

- `ActionType`
- spell: CastTime, Element, Id, MpCost, Name, Recast, Skill, Type
- ability: Name, Id, Type
- mob skill: Id, Name

Severity: **HIGH**.

### 6.1 Missing `pet_midaction()`

Rahvin also calls the GearSwap global helper `pet_midaction()` in:

- action refusal;
- precast building;
- midcast building;
- aftercast selection;
- enchanted-item timing;
- Hoxne timing.

The current compatibility environment does not define it.

This helper must share state with the future pet-action runtime.

Severity: **HIGH**.

---

## 7. Subjob parity

### FAIL — `sub_job_change(new,old)` missing

Rahvin's callback:

1. invalidates display layout;
2. invalidates set-name index;
3. resets warning state;
4. schedules Dual Wield refresh;
5. schedules two-hand refresh;
6. schedules gear rebuild;
7. invokes the job's `sub_job_change_custom(new,old)`.

Pinned LAC auto-profile loading does not replace this for a plain subjob change.

All 22 sample jobs define `sub_job_change_custom`.

Severity: **HIGH**.

---

## 8. Action object field parity

Rahvin core reads these spell/action fields:

- `action_type`
- `element`
- `element_id`
- `english`
- `id`
- `name`
- `prefix`
- `recast_id`
- `skill`
- `skill_id`
- `target`
- `type`

The current LAC normalizer supplies most of these.

### 8.1 Missing `skill_id`

Rahvin compares:

`spell.skill_id == 36`

to decide whether Zodiac Ring is eligible for Elemental Magic.

Pinned LAC's underlying spell resource exposes the numeric Skill value, but the current `lac_data` adapter does not copy it.

Severity: **MEDIUM/HIGH functional**.

### 8.2 Missing `prefix`

Rahvin checks:

`spell.action_type == 'Item' or spell.prefix == '/item'`

The current normalizer already identifies Item action type, so the missing prefix is redundant for the current core behavior.

Severity: **LOW**, but should be filled for full API parity.

---

## 9. Raw packet string compatibility

### FAIL — `string:unpack` missing

Rahvin raw packet handlers use Windower's string helper:

- `data:unpack('I', 0x09)`
- `data:unpack('H', 0x19)`
- `data:unpack('fff', 5)`

for:

- Treasure Hunter death-message packet `0x029`;
- movement parsing from outgoing `0x015`.

Pinned Ashita uses `struct.unpack(format, data, offset)` and its string sugar provides `split`, `slice`, etc., but not `string:unpack`.

Current compatibility environment does not install it.

Severity: **HIGH / live crash**.

The `0x028` action decoder itself is separately verified and passes.

---

## 10. GearSwap item-table parity

### CRITICAL — GearSwap lowercase item fields are not translated to LAC fields

Rahvin/GearSwap item tables use fields such as:

- `name`
- `priority`
- `augments`
- `augment`
- `bag`

Pinned LuAshitacast `MakeItemTable()` recognizes:

- `Name`
- `Priority`
- `Augment`
- `Bag`
- `AugPath`
- `AugRank`
- `AugTrial`

Current `ashita/equip_backend.lua` copies inner item tables unchanged.

Impact is broad:

- `GearSets-Include.lua` generates all core gear entries with lowercase `name` and `priority`;
- it contains approximately **935** lowercase `augments=` entries;
- it contains **77** lowercase `bag=` constraints;
- multiple sample jobs add their own lowercase `{name=..., augments=...}` items.

Strings equip normally, but table-form gear can fail resolution or lose priority/augment/bag identity.

### Positive finding

Pinned LAC does support per-item `Priority` correctly.

Its equip engine:

1. reads `Priority` into the item record;
2. builds equip packet entries with that value;
3. sorts by descending priority, then by slot.

Therefore Rahvin's HP/MP/weapon swap ordering can be preserved by translating the GearSwap field names correctly.

---

## 11. GearSwap `empty` sentinel

### FAIL

Rahvin uses global `empty` for deliberate slot clearing in:

- strip/naked modes;
- range yielding;
- held-slot restoration;
- weapon-lock logic;
- other release/rebuild paths.

Current compatibility environment does not define `empty`.

Pinned LAC does not provide a global `empty`. Its explicit unequip item sentinel is `Name='remove'`.

The adapter must expose a GearSwap-facing stable sentinel and translate it to LAC unequip semantics at the equip boundary.

Severity: **HIGH**.

---

## 12. Command compatibility

### Current behavior

`native.send_command` special-cases only:

- `bind ... gs c ...`
- `unbind ...`

Everything else is sent unchanged through Ashita `QueueCommand`.

That is insufficient because Rahvin emits Windower command-language strings internally.

### 12.1 Normal job-load command

Every shipped sample job calls `jobsetup(...)`.

Rahvin `jobsetup()` emits one chain containing:

- `wait`
- `input /macro book`
- `input /macro set`
- `gs validate`
- `input /lockstyleset`
- `input /echo`
- `gs c update auto`

Ashita's script syntax is not Windower's semicolon/input syntax.

Severity: **BLOCKER for real sample-job load**.

### 12.2 Internal self commands

Rahvin internally emits:

- `gs c update auto`
- `gs c enchrepair`
- `gs c hoxnerelock`
- `gs c hoxnerelease`

These must reach the same Rahvin dispatcher as `/rahvings` and `/lac fwd`, not be handed to Ashita as unknown `gs` commands.

Severity: **HIGH**.

### 12.3 Buff-cancel commands

Rahvin emits:

- `cancel 71`
- `cancel 37`
- delayed `cancel 66`

These are Windower command forms and must be mapped to the existing packet-based cancel semantics or an exact Ashita equivalent.

Severity: **HIGH**.

### 12.4 `windower.chat.input`

Current adapter maps it to Ashita `SetInputText()`.

That only fills the chat/input line; Windower `chat.input('/item ...')` executes the command.

Rahvin uses this for:

- Remedy;
- Holy Water;
- food;
- arbitrary enchanted items;
- Hoxne abilities;
- Hoxne Ampulla.

Severity: **HIGH**.

### 12.5 `gs validate`

LAC exposes `/lac validate`, but it validates its `profile.Packer` list through the Packer plugin. It is not equivalent to GearSwap validation of Rahvin sets.

Do not blindly map `gs validate` to `/lac validate`.

Status: **requires compatibility implementation or explicit parity decision**.

### 12.6 User command `profile`

Rahvin emits Windower `exec <path>`.

Pinned Ashita exposes ChatManager `ExecuteScript` / `ExecuteScriptString`, so an explicit mapping is possible.

Status: **unimplemented**.

### 12.7 User command `shutdown`

Rahvin emits `terminate`.

No equivalent command has yet been proven in the pinned Ashita Lua command surface.

Status: **unproven / must not be passed through blindly**.

### 12.8 Sample-job command extensions

The unchanged sample jobs add additional Windower command usage, including:

- BLU command chains with `input` and waits;
- PLD/RUN delayed `aset` commands;
- SMN macro-book/macro-set command chains;
- COR `lua u autocor`.

These need explicit compatibility classification before sample-job parity can be declared.

---

## 13. Settings parity and safety

### PASS — new store basics

The new Ashita-side store has:

- per-character identity;
- deterministic serialization;
- temp-file write;
- rename replacement;
- Windows-style replace fallback with backup/restore.

### ACCEPTED DIFFERENCE — old Windower XML migration

The approved port design explicitly makes legacy Windower `settings.xml` migration non-mandatory for release 1.

Therefore the current inert `files.new/xml.parse` legacy-migration surface is not by itself a blocker.

### FAIL — corrupted new settings can be overwritten

If the new Ashita `rahvings/settings.lua` exists but cannot be decoded, `ashita.settings.load()` silently returns defaults.

Rahvin receives no `settings_refused` marker.

Those defaults contain stale/missing per-character version stamps, so Rahvin's scheduled settings-reset path can save them, overwriting the corrupt user file.

This violates Rahvin's explicit refusal-on-unreadable-settings safety model.

Severity: **HIGH / data safety**.

---

## 14. Equipment backend and priority

### PASS — slot aliases

GearSwap aliases are normalized to LAC slot names and the translation is intentionally idempotent.

### PASS — LAC equip priority capability

As noted above, pinned LAC supports per-item `Priority` ordering correctly.

### FAIL — item metadata normalization

See section 10.

### PASS — cancel backend primitive

`cancel_spell()` reaches LAC `CancelAction()`.

The missing part is GearSwap's event-scoped `_global.cancel_spell` state, not the LAC cancel primitive itself.

---

## 15. Resources, inventory, extdata and recasts

### PASS — core resource families

The port supplies the Rahvin-used resource collections and normalized core fields for:

- items;
- spells;
- job abilities;
- weapon skills;
- buffs;
- elements;
- zones;
- bags.

### PASS — `res.items:with(...)`

`compat.resources` restores the collection `:with(field,value)` helper Rahvin uses for two-handed weapon lookup.

### PASS — inventory index basis

Ashita/LAC itself scans container item indices `1..max`; the adapter follows the same convention.

### PASS — extdata core behavior

Augments and enchanted-item timing are normalized and automated tests cover the current Hoxne/enchant use.

### PASS — recast surfaces

Spell and ability recast tables exist and are wired.

### Remaining action-field gap

`spell.skill_id` is still missing; see section 8.

---

## 16. Packet parity

### PASS — incoming action `0x028`

The decoder follows the pinned Ashita action parser's bit-packed layout and exposes Rahvin's required:

- actor id;
- category;
- param;
- target list;
- action list;
- action message;
- add-effect message;
- spike-effect fields.

Adapter does not wrongly actor-filter; Rahvin retains its intentional cross-actor skillchain/roll behavior.

### PASS — zone `0x00A`

Mapped and old/new zone history maintained.

### PASS — logout `0x00B`

Uses the pinned Ashita criterion: byte at `+0x04 == 1`.

### FAIL — raw string `:unpack`

See section 9.

---

## 17. Mob / party / IPC parity

### PASS — Windower mob distance surface

Ashita squared entity distance is exposed as a Windower-compatible object with:

- `.squared`
- `:sqrt()`

Rahvin's monitor path works without patching Rahvin.

### PASS — party shape

Port exposes Rahvin-consumed keys:

- `p0..p5`
- `a10..a15`
- `a20..a25`

with member name/id/index/mob data.

### PASS — IPC time base

Rahvin uses `socket.gettime()*1000`.

Port IPC uses wall-clock milliseconds and the same timestamps survive translation.

### PASS structural — local transport

UDP multicast is host-local and profile generations create/close their own transport instance.

### PARTIAL — IPC event equipment semantics

The transport/message translation itself is sound, but `ipc message` currently lacks wrapped-event refresh/flush semantics; see section 4.2.

---

## 18. Display parity

### PASS — text method surface

All text-object methods currently used by Rahvin are implemented:

- alpha
- bg_alpha
- bg_color
- bg_visible
- bold
- bottom_justified
- color
- draggable
- extents
- font
- hide
- italic
- pad
- pos
- pos_x
- pos_y
- register_event
- right_justified
- show
- size
- stroke_alpha
- stroke_color
- stroke_width
- text
- unregister_event
- destroy

### PASS — primitives

Rahvin LATTICE uses exactly:

- create
- delete
- set_position
- set_size
- set_color
- set_visibility

All are supplied by the native Ashita adapter.

### PASS — inline colors

Windower `\cs(r,g,b)...\cr` is translated at the renderer boundary to Ashita `|cAARRGGBB|...|r`.

Rahvin-facing text getters retain the original Windower-form source string.

---

## 19. Modes / T / S / string helpers

### PASS

Current compatibility supplies the Rahvin-used mode operations and table/set primitives.

Pinned Ashita sugar supplies `string:split` and `string:slice`.

Compat supplies missing Windower helpers such as trim/lpad/startswith/endswith.

### FAIL

`string:unpack` remains absent; see section 9.

---

## 20. GearSwap internal optimization

Rahvin `build_is_worn()` can inspect GearSwap internals such as:

- current item model;
- disable/encumbrance tables;
- in-flight equipment registry;
- proposed equip list.

The port does not emulate those internal tables.

However Rahvin intentionally treats missing internals as "cannot prove already worn" and returns false, falling back to a normal equip.

Impact: possible extra equip work/traffic, not correctness loss.

Severity: **LOW / optimization parity only**.

---

## 21. LAC profile / lifecycle / reload

### PASS structural — profile return contract

Pinned LAC performs `loadfile(profilePath)` and assigns the chunk return value to `gProfile`.

The port's `return require('ashita.profile').production(...)` model is correct.

### PASS structural — reload cleanup

Current ownership inspection shows:

- scheduler queue cleared on stop;
- Ashita event registry unregistered and reset;
- IPC detached/closed;
- command event unregistered;
- bridged keybind registry cleared;
- native primitive map belongs to the profile instance;
- Rahvin includes use `loadfile`, not cached `require`.

No confirmed module-cache state leak was found.

A same-process reload regression test is still warranted before live.

---

## 22. Severity summary

### CRITICAL

1. GearSwap lowercase item metadata is not translated to LAC item fields.

### HIGH / release-blocking before live parity claim

2. Missing Windower `gain buff` / `lose buff`.
3. Missing `pet_midcast` / `pet_aftercast`.
4. Missing `pet_midaction()`.
5. Missing `sub_job_change`.
6. Stale GearSwap globals before LAC action callbacks.
7. Wrapped/raw event semantics collapsed; no event-level equip commit/discard.
8. Internal `gs c` and jobsetup Windower command language not translated.
9. `windower.chat.input` fills input text instead of executing it.
10. Raw packet `string:unpack` missing.
11. GearSwap `empty` sentinel missing.
12. GearSwap `_global.cancel_spell` event flag missing.
13. Corrupted new Ashita settings can be overwritten with defaults.

### MEDIUM / functional or API parity

14. `spell.skill_id` missing; Zodiac Ring Elemental Magic gate affected.
15. `pretarget_custom(spell, action)` second argument missing.
16. `profile/exec`, `shutdown/terminate`, `gs validate` and sample-job external command families need explicit mappings/parity decisions.

### LOW / accepted differences

17. No old Windower XML settings migration (approved release-1 difference).
18. No GearSwap-internal `build_is_worn` optimization surface.
19. Native GearSwap `addon command` advisory event not reproduced because there is no Ashita GearSwap native `//gs disable/enable` surface to warn about.
20. `spell.prefix` currently missing but redundant for active Rahvin Item routing.

---

## 23. Confirmed-good foundations

The audit does **not** invalidate the work already completed. The following foundations remain sound:

- untouched Rahvin engine and sample jobs;
- deterministic include environment;
- M/T/S and set-combine basics;
- slot alias normalization;
- LAC action category normalization for Spell / JA / WS / Ranged / Item;
- LAC cancel primitive;
- LAC per-item priority support;
- resource collections;
- inventory iteration;
- recast surfaces;
- extdata/Hoxne decoding foundations;
- 0x028 action packet decode;
- 0x00A zone decode;
- 0x00B logout detection;
- target diffing;
- Windower mob `:sqrt()` distance compatibility;
- party shape;
- IPC wire translation and wall-clock units;
- text-object surface;
- primitive surface;
- inline color translation;
- settings atomic write/replace path;
- keybind syntax translation and cleanup;
- production LAC profile return contract;
- lifecycle ownership and unload cleanup architecture.

---

## 24. Required TDD fix waves

Do not begin live parity testing against real job files until Waves 1–6 are GREEN.

### Wave 1 — equipment contract

RED first:

- GearSwap `name/priority/augments/augment/bag` → LAC `Name/Priority/Augment/Bag`;
- preserve already-LAC-form fields;
- preserve AugPath/AugRank/AugTrial;
- GearSwap `empty` → LAC unequip/remove;
- priority survives to LAC backend.

### Wave 2 — GearSwap event primitives

RED first:

- event-scoped `_global.cancel_spell`;
- Windower-compatible packet `string:unpack`;
- `spell.skill_id` and `prefix`;
- snapshot refresh before every action boundary.

### Wave 3 — wrapped/raw event ownership

RED first:

- wrapped event = refresh → handler(s) → one equip flush;
- raw event = handler(s) → discard any buffered equip;
- IPC and target-change wrapped behavior;
- zone/action/outgoing/prerender raw behavior;
- no stale pending set can cross event boundaries.

### Wave 4 — state events

RED first:

- gain/lose buff numeric-ID events plus ordinary `buff_change(name,gain)`;
- exact ordering;
- subjob diff → `sub_job_change(new,old)`;
- deferred schedules remain on the one shared scheduler.

### Wave 5 — pet runtime

RED first:

- `pet_midaction()`;
- LAC `GetPetAction()` normalization;
- one `pet_midcast` on action start;
- one `pet_aftercast` on completion;
- no duplicate callbacks from repeated `HandleDefault`.

### Wave 6 — command compatibility

RED first:

- direct internal `gs c` dispatch;
- Windower command-chain parsing;
- wait scheduling on shared scheduler;
- `input /...` executes, never just populates the input line;
- cancel command mapping;
- normal sample-job `jobsetup`;
- explicit decision/implementation for validate, exec/profile, terminate/shutdown;
- classify/migrate sample-job `aset`, `lua u`, and broadcast commands.

### Wave 7 — settings corruption safety

RED first:

- malformed new settings file must be surfaced as refused;
- defaults may be used in memory;
- no save may overwrite malformed source;
- user receives one precise refusal/recovery message.

### Wave 8 — integration / reload

- same Lua process: production generation A → load → activity → unload → generation B → load;
- no carried scheduler tasks, platform handlers, command aliases, IPC subscriptions, keybind ownership, primitives or action state;
- all 22 sample jobs load through the real compatibility environment.

Only after these waves should the Phase-4 live matrix resume.

---

## 25. Audit gate result

**Current status: AUTOMATED SUITE GREEN, DEEP PARITY AUDIT RED.**

The port is not ready for a full feature-parity claim or real-job live acceptance yet.

The reason is not failure of the existing tested foundations. It is that the deeper original-source-derived audit exposed important GearSwap/Windower semantics that the first test matrix did not cover.

Next action: begin Wave 1 with failing regression tests; do not patch RahvinGS or the sample jobs.
