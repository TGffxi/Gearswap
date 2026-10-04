# Rahvin GearSwap 2.1.0 → Ashita v4 + LuAshitacast Detailed Parity Audit

Date: 2026-10-04

## Scope and pinned baselines

This audit compares the original Rahvin GearSwap 2.1.0 behavior against the current `TGffxi/Gearswap` Ashita v4 + LuAshitacast port.

Pinned sources:
- Rahvin GearSwap 2.1.0: `f1cda1e41f567b16ec592e6598cda71bb04392d0`
- LuAshitacast: `7ed398edd3ebbdc8af86a79e5d3427da42e3a34a`
- Ashita v4 beta source baseline: `4171c74c8ddb2ca2a31654f199e6c1cee40d7256`
- Current audited port checkpoint: `d47b144ea1559790c5c4aa958d7b01150d8303ad`

Automated checkpoint at the start of this audit:
- `luajit tests/run.lua all`: **47 passed, 0 failed**

The green test suite is valuable regression evidence, but this audit deliberately checks semantic parity beyond what those tests currently prove.

## Upstream integrity

### PASS — Rahvin engine remains upstream-clean

The current repository was compared directly against the Rahvin baseline.

- `RahvinGS/`: 16/16 entries SHA-identical to the Rahvin 2.1.0 baseline.
- `Sample Job Files/`: 22/22 entries SHA-identical to the Rahvin 2.1.0 baseline.
- No Rahvin engine or sample-job source patch is currently required by the port.
- Port behavior is supplied through `compat/`, `ashita/`, tests and documentation.

This satisfies the design goal of maximizing future upstream portability.

---

# Executive verdict

**The port is not ready for the first real FFXI live test yet.**

The audit found several production-parity blockers that the existing 47-test suite does not cover. The most serious are not cosmetic: they affect ordinary sample-job loading, actual gear equipping, commands, status-item use, pet actions, subjob changes and packet handlers.

The most important result is that the overall architecture is sound, but multiple compatibility boundaries are still too shallow. These can be fixed without modifying RahvinGS.

---

# Detailed parity matrix

## 1. GearSwap item-table semantics

### BLOCKER P0 — GearSwap item fields are not normalized to LuAshitacast item fields

Original Rahvin gear tables use GearSwap spelling:

```lua
{
    name = 'Item Name',
    priority = 100,
    augments = {...},
    bag = 'wardrobe2',
}
```

The central builders in `RahvinGS/GearSets-Include.lua` produce lowercase `name` and `priority`. The same file contains, at the audited baseline:

- approximately **935** `augments = ...` entries
- approximately **77** `bag = ...` entries

LuAshitacast `equip.lua / MakeItemTable()` accepts:

```lua
Name
Priority
Augment
Bag
AugPath
AugRank
AugTrial
```

Current port behavior:
- `compat.gearswap` translates slot names only.
- `ashita.equip_backend` copies the item value without converting GearSwap item-field spelling.
- Existing tests use already-LAC-shaped `Name/Augment/Bag` fixtures and therefore miss this incompatibility.

Impact:
- a GearSwap item table whose only name key is lowercase `name` reaches LAC without `Name`;
- LAC then refuses it as an invalid item table;
- item priority, augment selection and explicit bag selection are also not preserved unless normalized.

This affects the core gear library and therefore ordinary real jobs.

Required fix:
- normalize GearSwap item specs at exactly one adapter boundary;
- preserve strings unchanged;
- map `name→Name`, `priority→Priority`, `augments→Augment`, `bag→Bag`;
- preserve already-valid LAC fields and all supported augment metadata;
- add regression coverage using real Rahvin-style lowercase gear objects.

### PASS — LAC itself supports Rahvin's equip-priority requirement

Pinned LuAshitacast `equip.lua` supports per-item `Priority` and sorts outgoing equip operations:
1. descending priority;
2. slot order as tie-breaker.

Therefore Rahvin's HP/MP/weapon swap ordering can be preserved once the field normalization above is fixed.

### PASS — slot-name normalization

GearSwap slots such as:
- `left_ear/right_ear`
- `left_ring/right_ring`
- aliases such as `lear/rear/lring/rring`

are normalized to LAC slots through `compat.slots`. Existing alias/roundtrip tests cover this.

### PASS — equip/enable/disable/cancel boundary shape

- `equip()` routes to the LAC equip buffer.
- `enable()/disable()` route to `gFunc.Enable/Disable`.
- `cancel_spell()` routes to `gFunc.CancelAction()`.

The pending-buffer/flush design also preserves multiple GearSwap `equip()` merges within one LAC callback.

---

## 2. Action callback parity

### PASS — player action families

Current LAC adapter covers:
- spell precast
- spell midcast
- job ability
- weapon skill
- ranged preshot
- ranged midshot
- item use
- synthetic aftercast/timeout
- resend handling
- SELF target classification
- core spell/ability type and recast normalization

These have direct automated coverage.

### BLOCKER P1 — Rahvin globals can be stale at action callback entry

GearSwap wrapped callbacks refresh globals before entering user/engine handlers.

Current bootstrap refreshes the full snapshot inside `HandleDefault`, but:
- `HandlePrecast`
- `HandleAbility`
- `HandleWeaponskill`
- `HandleItem`
- `HandlePreshot`
- `HandleMidcast`
- `HandleMidshot`

do not refresh Rahvin's `player/world/buffactive/pet/equipment/inventory` globals first.

Pinned LAC action handling can invoke those callbacks directly from a new action packet without first calling `HandleDefault`.

Impact:
- action-set decisions can use state from the previous default cycle;
- this is especially relevant to immediate buff, TP, movement, equipment, weather, pet or inventory-dependent decisions.

Required fix:
- capture/seed a fresh snapshot at the GearSwap-equivalent callback boundary before invoking Rahvin action handlers;
- ensure state-diff callbacks are not duplicated by that refresh.

---

## 3. GearSwap lifecycle callback parity

### PASS — `get_sets()`

Port `OnLoad` explicitly invokes Rahvin's `get_sets()`, then flushes the equip buffer.

### PASS — `file_unload()`

Port `OnUnload` invokes Rahvin's unchanged `file_unload()`, then lifecycle teardown.

### PASS — `pretarget/precast/midcast/aftercast`

The player-action runtime provides these GearSwap-facing hooks.

### PASS — `status_change`

Generated from snapshot state diff.

### PASS — `buff_change`

Generated from snapshot state diff, including busy-time deferral behavior.

### PASS — `pet_change`

Generated when pet identity appears/disappears/changes.

### BLOCKER P1 — `sub_job_change(new, old)` is missing

Rahvin's lifecycle explicitly relies on GearSwap's `sub_job_change` hook to:
- invalidate display layout;
- invalidate set-name indexes;
- clear set warnings;
- schedule Dual Wield refresh;
- schedule two-hand refresh;
- schedule a gear rebuild;
- call the job's `sub_job_change_custom(new, old)`.

The 22 sample jobs define/use this custom lifecycle surface extensively.

Pinned LAC does not automatically reload the profile for a simple subjob change, so this cannot be delegated to LAC.

Required fix:
- include `sub_job` in the state snapshot diff;
- invoke Rahvin `sub_job_change(new, old)` exactly once per actual change;
- preserve Rahvin's own deferred scheduler behavior.

### BLOCKER P1 — `pet_midcast` and `pet_aftercast` are missing

Pinned LuAshitacast explicitly documents that pet spells/skills are **not** automatically handled by `HandleDefault`; profiles must query `gData.GetPetAction()`.

Current port never reads `GetPetAction()`.

Rahvin supplies full `pet_midcast(spell)` / `pet_aftercast(spell)` behavior, and essentially all sample jobs define the corresponding custom hooks.

Required fix:
- add a pet-action translator for LAC's `GetPetAction()` table;
- detect pet-action start/change/end in the default tick;
- invoke Rahvin pet midcast once when an action begins;
- invoke Rahvin pet aftercast once when it completes/disappears;
- coexist safely with simultaneous player action state.

---

## 4. Windower event parity

Original Rahvin registers 11 handlers over 10 unique event names:

1. `target change`
2. `incoming chunk`
3. `outgoing chunk`
4. `zone change`
5. `ipc message`
6. `prerender` — Hoxne
7. `prerender` — SpellReceived failsafe
8. `gain buff`
9. `lose buff`
10. `logout`
11. `addon command`

### PASS — target change

Port detects target-index changes on outgoing traffic and emits Rahvin's expected `new, old` shape.

### PASS — incoming chunk required by TH

Raw 0x029 is forwarded with:
`id, data, data_modified, injected, blocked`.

### PASS — outgoing chunk cadence

Rahvin's `main_engine` is driven by **every outgoing packet**, not only player-action packets.

The port preserves this.

### PASS — zone change

0x00A decoding reaches Rahvin's zone-change hook.

### PASS — ipc message

Localhost IPC payloads are translated back to Rahvin's original textual IPC protocol before dispatch.

### PASS — prerender isolation and order

A single Ashita frame emits the Windower-shaped `prerender` event. Multiple Rahvin handlers are kept separately and invoked in registration order. One failing handler does not suppress later handlers.

### BLOCKER P1 — `gain buff` / `lose buff` Windower events are missing

This is separate from GearSwap `buff_change(name,gain)`.

Rahvin registers additional event handlers:
- `E.sr_gain_buff`
- `E.sr_lose_buff`

These currently never fire.

Impact includes:
- status-removal automation;
- Sleep/Doom and other received-gear holds;
- Accession/Divine Seal prediction cleanup;
- Corsair roll tracker cleanup;
- other SpellReceived state transitions.

Required fix:
- derive exact gained/lost buff ids from the same snapshot diff;
- emit Windower-compatible `gain buff` / `lose buff` arguments in addition to GearSwap `buff_change`;
- preserve ordering relative to state refresh and Rahvin's normal hook.

### PASS — logout ownership after recent fix

Pinned Ashita v4 uses incoming 0x00B with byte +0x04 == 1 for logout.

The port now:
- decodes this exact condition;
- routes it to the single lifecycle owner;
- emits Rahvin's logical logout before teardown;
- unregisters events, IPC and scheduled state.

### DESIGN DIFFERENCE — addon command

Rahvin's original `addon command` registration only prints a warning when a user directly uses native GearSwap enable/disable commands.

Ashita has no native GearSwap addon command surface to protect here. This event does not need artificial emulation as long as port commands remain tracked.

Documented difference, not a release blocker.

---

## 5. Raw packet/string helper parity

### BLOCKER P0 — Windower-style `string:unpack()` is not provided

Rahvin's unchanged raw packet handlers call `data:unpack(...)` directly.

Examples include:
- TH/action-message parsing;
- movement/target-related raw packet parsing.

Pinned Ashita's sugar string library provides helpers such as `split` and `slice`, but not Windower's string-method `unpack`. Ashita code normally uses `struct.unpack(format, data, offset)`.

Current compat environment does not install `string.unpack`.

Impact:
- first matching live raw packet can raise `attempt to call method 'unpack'`.

Required fix:
- provide a Windower-compatible `string.unpack` method backed by Ashita `struct.unpack`;
- verify offset semantics against every Rahvin call site;
- test using realistic 0x015/0x029 raw buffers, not hand-decoded data.

### PASS — string helpers used elsewhere

Required helpers such as:
- `trim`
- `lpad`
- `contains`
- `startswith`
- `endswith`

are supplied by compat/Ashita as appropriate.

Ashita sugar also provides the `split`/`slice` methods used by Rahvin.

---

## 6. Command and chat-input parity

### BLOCKER P0 — `windower.chat.input()` currently does not execute commands

Original Rahvin uses `windower.chat.input()` to actually execute:
- `/item "Remedy" <me>`
- `/item "Holy Water" <me>`
- enchanted item uses
- Hoxne job abilities/items
- `food`

Current `ashita.native.input()` calls Ashita `SetInputText()`.

That edits the visible input buffer; it does not represent Windower's execute-input semantics.

Required fix:
- execute the passed game command through the appropriate Ashita chat/command path;
- do not merely prefill the chat input line;
- test both item and job-ability cases.

### BLOCKER P0 — Windower `send_command` syntax is not translated

Current adapter special-cases bind/unbind only, then forwards the original text to `QueueCommand(-1,...)`.

Rahvin itself uses Windower command grammar, including:
- `gs c ...`
- `gs validate`
- `wait ...; ...`
- `input ...`
- `cancel <buffid>`
- `exec ...`
- `terminate`
- optional/broadcast commands

The normal job-load path is especially important. Every sample job calls `jobsetup(...)` at file scope, and Rahvin's `jobsetup` sends a chain equivalent to:

```text
wait 1;
input /macro book ...;
wait 1;
input /macro set ...;
gs validate;
wait 3;
input /lockstyleset ...;
input /echo Change Complete;
gs c update auto;
```

Therefore a real sample job would hit this compatibility boundary immediately.

Required fix:
- parse Windower semicolon command chains;
- preserve ordered delay semantics using the shared scheduler;
- map `input ...` to Ashita/game command execution;
- map `gs c ...` to the same Rahvin command dispatcher as `/lac fwd` / `/rahvings`;
- provide a port implementation of the behavior Rahvin expects from `gs validate`;
- map `cancel` without requiring an unrelated optional Ashita addon;
- explicitly define behavior for `exec`, `terminate`, addon load/unload commands and broadcasts;
- fail loudly for unsupported commands rather than silently queueing Windower syntax.

### PASS — keybind command interception

Rahvin keybinds of the form:
`bind <key> gs c <command>`
are intercepted and translated to Ashita binds calling:
`/lac fwd <command>`.

Windower Shift prefix `~` is translated to Ashita `+`.

Owned binds are tracked and cleared on teardown.

### PASS — direct port command entry

Both the native profile command surface and `/rahvings` route to Rahvin's `self_command` dispatcher.

---

## 7. Sample-job compatibility

### PASS — source integrity

All 22 sample job files are unchanged from Rahvin 2.1.0.

### BLOCKER — common callback expectations are currently unmet

Across the sample set, the normal job-file API includes:
- `sub_job_change_custom`
- `pet_midcast_custom`
- `pet_aftercast_custom`
- `buff_change_custom`
- `status_change_custom`
- `self_command_custom`
- `user_file_unload`

The missing subjob and pet bridges therefore affect the supplied job family, not isolated custom files.

### BLOCKER — sample job command chains

Examples found:
- BLU: `input //aset ...; input /macro ...; wait ...`
- PLD/RUN: `wait 2; aset set tanking`
- SMN: repeated macro-book/set chains
- COR: `lua u autocor`

The core command bridge must preserve generic command execution while translating Windower-specific pieces.

External addon commands such as `aset` or `autocor` are user-environment dependencies; the port should pass through valid Ashita equivalents or document required addon substitutions, not silently claim internal support.

---

## 8. State/snapshot parity

### PASS — snapshot data breadth

Production snapshot provides Rahvin-facing:
- player identity/jobs/levels/status/HP/MP/TP/movement
- equipment
- inventory/wardrobe views
- world/day/weather/moon data
- buffs
- pet
- target
- job points

### PASS — inventory container index basis

Pinned LAC itself iterates equip containers from index 1 through max. The port follows the same container-index convention.

### PASS — mob distance after recent fix

Ashita entity distance is squared. Port now exposes a Windower-compatible distance object with `:sqrt()`.

### BLOCKER — action-time freshness

See section 2. Full snapshot refresh must occur before action hooks, not only in the default tick.

---

## 9. Resource and extdata parity

### PASS — resource collections

Current adapters normalize the Rahvin-read fields for:
- items
- buffs
- jobs
- bags
- elements
- zones
- spells
- job abilities
- weapon skills

`res.items:with('en', ...)` is provided by the compat collection wrapper.

### PASS — recasts

Ability and spell recasts are mapped to Windower-shaped tables.

### PASS — extdata use cases already targeted

Current implementation covers fields used by Rahvin for:
- augmented instance identification;
- Path/Rank/Trial;
- enchant charge/recast calculations.

### LIVE EVIDENCE STILL REQUIRED

Hoxne/enchant use should still be validated against real item instances and real extdata after blockers are fixed.

---

## 10. Display parity

### PASS — text object method surface

Every text-object method actually called by Rahvin's display code is present, including:
- position getters/setters
- extents
- show/hide
- draggable
- text
- font/size/color/alpha
- stroke/background
- padding/alignment
- drag event register/unregister
- destroy

### PASS — primitive surface

Rahvin LATTICE uses exactly:
- create
- delete
- set_position
- set_size
- set_color
- set_visibility

All are implemented by the Ashita primitive adapter.

### PASS — Windower inline colors after `d47b144`

Rahvin continues to generate:
`\cs(r,g,b)...\cr`

The renderer now translates only at the Ashita boundary to:
`|cAARRGGBB|...|r`

Rahvin's getter still sees the original source string.

### LIVE EVIDENCE STILL REQUIRED

After blocker fixes:
- classic
- harness
- lattice
- halo
- drag/save/reload
- cleanup on unload/logout

must be tested in the real client.

---

## 11. Settings parity and safety

### DESIGN DIFFERENCE — old Windower XML migration

Automatic migration of legacy Windower `settings.xml` was explicitly excluded from the initial Ashita release design.

The virtual `files.new()`/unimplemented XML parser is therefore not, by itself, a parity blocker for Release 1.

### BLOCKER P1 — corrupted new Ashita settings can be overwritten

The new Ashita settings store falls back to defaults on parse failure.

Rahvin's unchanged safety model expects `settings_refused` to be set when a settings file exists but cannot be safely parsed. While refused:
- user runs on defaults;
- **nothing is saved** until the file is fixed/deleted.

Current virtual `files.new()` always reports no file, so Rahvin never gets a refusal record for a broken Ashita settings file.

A default-loaded settings table has stale/missing version stamps. Rahvin's scheduled `settings_reset_announce()` can then save reset/default data.

Impact:
- a corrupted new settings file can be silently replaced instead of protected.

Required fix:
- propagate load validity/refusal from the Ashita settings store into the Rahvin compatibility contract;
- retain Rahvin's “run on defaults but do not save” behavior;
- test truncated/syntax-invalid settings files and repeated reload.

---

## 12. Scheduler / lifecycle / reload ownership

### PASS — one scheduler

Rahvin `coroutine.schedule` uses the same scheduler lifecycle ticks.

The 11 startup schedules are captured exactly once during engine inclusion and replayed through the lifecycle owner.

### PASS — event ownership

One Ashita event registry owns packet/frame callbacks and is fully unregistered on teardown.

### PASS — IPC generation ownership

Logout/unload detaches and closes the current IPC generation before a new one is created.

### PASS — keybind cleanup

Only bridge-owned keybinds are removed.

### NO CONFIRMED BUG — same-process reload state

Module caching by `require()` is not currently shown to retain stale per-profile runtime state:
- scheduler queue is cleared;
- event registry resets;
- IPC closes;
- keybind registry clears;
- primitives/fonts are destroyed by Rahvin/compat ownership.

### TEST GAP

Add a single-process:
`production → OnLoad → OnUnload → production → OnLoad → OnUnload`
regression covering:
- no duplicate events;
- empty old scheduler queue;
- no old IPC subscriber;
- no held bridge key;
- no old primitive/font ownership.

---

## 13. IPC / SpellReceived parity

### PASS — protocol preservation

Rahvin's textual IPC messages are converted to a versioned localhost payload and converted back before the unchanged Rahvin handler receives them.

### PASS — clock units

Rahvin sends milliseconds using `socket.gettime()*1000`. Port IPC timestamps and age checks are also milliseconds.

### PASS — same-machine transport architecture

Transport is local multicast/loopback and needs no external helper process.

### LIVE EVIDENCE STILL REQUIRED

Two real clients must prove:
- start messages;
- completion;
- Roll XI query/state;
- no duplicates after reload/logout/login.

---

## 14. TH packet path

### PASS — packet registration/routing shape

0x029 reaches Rahvin with the Windower raw-event argument shape.

0x028 action packets are decoded and reach the Rahvin action handler.

### BLOCKER — raw `:unpack()`

The raw 0x029 handler cannot be considered live-ready until the Windower string-unpack compatibility method exists and is tested.

### LIVE EVIDENCE STILL REQUIRED

After that fix:
- real TH target change;
- tagging;
- death-message cleanup;
- zone reset.

---

# Confirmed blockers ordered by fix priority

1. **P0 — GearSwap item-table field normalization**
   - ordinary Rahvin gear objects can fail to equip.
2. **P0 — Windower command-chain translation**
   - normal `jobsetup()` path is not Ashita-compatible.
3. **P0 — `windower.chat.input` execution semantics**
   - status items, enchants, Hoxne and food do not execute correctly.
4. **P0 — Windower string `:unpack()` compatibility**
   - raw packet paths can crash.
5. **P1 — refresh snapshot before every player-action handler**
   - prevents stale GearSwap globals.
6. **P1 — emit `gain buff` / `lose buff` events**
   - restores SpellReceived/status-item/hold/roll state.
7. **P1 — implement `sub_job_change` state transition**
   - restores Rahvin and sample-job subjob lifecycle.
8. **P1 — implement pet action lifecycle**
   - restores `pet_midcast` / `pet_aftercast`.
9. **P1 — protect invalid Ashita settings from overwrite**
   - restores Rahvin's refusal/no-save safety.
10. **P2 — explicit translations/documentation for `terminate`, `exec`, addon-specific commands and broadcasts**
11. **P2 — add same-process production reload regression**

All should be completed before the first real FFXI live smoke test.

---

# Areas currently considered correctly mapped

Subject to the blockers above, the audit found no new structural defect in:

- upstream Rahvin file integrity;
- set-combine/mode primitives used by the engine;
- slot aliases and slot normalization;
- LAC per-item priority capability itself;
- player spell/JA/WS/ranged/item action taxonomy;
- cancel-action backend;
- recast mapping;
- resource collections used by Rahvin;
- extdata fields already under parity tests;
- bag/index iteration convention;
- target/mob lookup and squared-distance compatibility;
- Windower-shaped incoming/outgoing/zone/target/prerender event routing;
- per-handler error isolation;
- local IPC encoding/timebase/ownership;
- logout detection via Ashita 0x00B;
- keybind translation and cleanup;
- text-object surface;
- primitive surface;
- inline color rendering;
- single shared scheduler ownership;
- 11 Rahvin startup tasks scheduled once.

---

# Next engineering wave

Do not begin the real-client smoke yet.

Use TDD in this order:

1. Add RED tests using real lowercase Rahvin gear objects; implement item normalization.
2. Add RED tests for `chat.input` execution and full `jobsetup` command chain.
3. Add RED raw-buffer tests for Windower `:unpack()`.
4. Add RED action-callback test proving snapshot refresh happens before Rahvin handler.
5. Add RED buff event ordering/argument tests.
6. Add RED subjob transition test.
7. Add RED pet-action start/end test using pinned LAC `GetPetAction()` shape.
8. Add invalid-settings refusal/no-overwrite test.
9. Add same-process double-production reload test.
10. Run every targeted suite, then full suite.
11. Only then begin CachyOS/Ashita/LAC live gates.

This audit deliberately leaves `RahvinGS/` and the 22 sample jobs untouched.
