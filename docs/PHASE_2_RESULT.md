# Phase 2 result — Core Gear Parity

Phase 2 completed on 2026-10-03 directly on `master`, starting from
`8070cc78234c37863253bbe78d7744ed92f37095`.

## Tasks and commits

| Task | Commit | Result |
|---|---|---|
| LAC action and entity translation | `bb42b07` | Translates the documented pinned-LAC action, target, player, pet, day and weather fields into Rahvin-shaped data. |
| LAC equipment backend | `e069dd8` | Buffers precedence-preserving logical equips and flushes only through `EquipSet`; enable, disable and cancellation use public `gFunc` calls. |
| Exactly-once action lifecycle | `cd70cc2` | Owns start generations and emits one aftercast for completion, interruption, cancellation, replacement or reset. |
| LuAshitacast bootstrap/profile | `02ef60d` | Routes every callback supported by the pinned LAC profile interface and uses `HandleDefault` for completion and default rebuilds. |
| State transition bridge | `82060b1` | Diffs status, counted buffs and pet identity and defers transitions across busy windows without losing them. |
| Core logical-set parity contracts | `618b2c6` | Locks pre-LAC GearSwap-shaped merge results for the required default, mode, action and exception cases. |
| GearSwap action taxonomy correction | `419511d` | Converts LAC action/type names to the exact strings consumed by Rahvin. |
| Element and target semantics correction | `b5d4e35` | Supplies actual resource element IDs, weather intensity and GearSwap entity categories. |
| Deployable profile callback surface | `49b8f73` | Exposes the exact pinned-LAC callback table and fails explicitly until dependencies are configured. |
| Repeated-start lifecycle hardening | `3fc0363` | Makes repeat callbacks for the same active identity idempotent. |

## Tested contracts

- Spell, weaponskill, job ability, ranged attack, item and nil-action translation.
- Player, pet, target, day, weather, element, skill, action type and available recast identity.
- Public `gFunc.EquipSet`, `Enable`, `Disable` and `CancelAction` routing; no normal-flow `ForceEquip`.
- Buffered precedence and preservation of item descriptor fields and distinct augmented instances.
- Exactly-once aftercast for success, disappearance, interruption, cancellation, replacement and zone/reset paths.
- All pinned-LAC profile callbacks and `HandleDefault` completion/default routing.
- Idle, Engaged and Resting changes; counted duplicate buffs; pet appearance/disappearance; unchanged snapshots; busy deferral.
- Logical idle/engaged and offense-mode sets, named and ranged weaponskills, Aftermath, weapon locks, wield state, movement, buff and elemental overlays, Cure/Light bonus, Bard instrument and GEO handbell exceptions.

## Known limits and live verification gates

The automated suite deliberately does not simulate behavior that only the live client and
LuAshitacast equipment engine can establish. The following remain live Ashita/FFXI gates:

- exact callback and `HandleDefault` timing for success, packet interruption and server rejection;
- real buffered equip timing across fast-cast, midcast, ranged and default transitions;
- LAC selection of duplicate augmented items from real wardrobes and bags;
- actual `Enable`/`Disable` persistence and action cancellation in the client;
- resource-provided recast IDs on every action family;
- self-target classification, because pinned LAC `GetPlayer()` exposes no player ID or index;
- live buff enumeration and pet/status timing supplied by the Ashita snapshot provider;
- job-file loading/configuration and normal combat execution inside a running client.

These are integration gates, not silent compatibility claims. Missing adapter services raise
`RahvinCompatError` rather than manufacturing data.

## Upstream patches

No Class-C patches were required. `RahvinGS/` and `Sample Job Files/` remain byte-unchanged
from the port baseline, and `docs/UPSTREAM_PATCH_LEDGER.md` remains empty.
