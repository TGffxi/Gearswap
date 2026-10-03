# Phase 2 result — Core Gear Parity

Phase 2 was completed on 2026-10-03 directly on `master`, starting from
`8070cc78234c37863253bbe78d7744ed92f37095`, then independently re-audited before Phase 3.
The audit baseline was `d973c5100be358215ab24574cfaf3469b839a71c`.

## Implemented contracts

- LAC action/entity translation into Rahvin/GearSwap-shaped data.
- Public LuAshitacast equipment backend through `gFunc.EquipSet`, `Enable`, `Disable`, and `CancelAction`.
- Exactly-once synthetic Rahvin `aftercast` lifecycle over the pinned LuAshitacast callback model.
- LuAshitacast profile/bootstrap callback surface.
- Status, buff, and pet transition bridge.
- Pre-LAC logical gear decisions from the unchanged Rahvin builders.

## Audit corrections

The independent Phase 2 audit found and corrected several cases that the original tests did not cover:

- Geomancy and Trust are recovered from the pinned Ashita spell resource `MagicType` when LAC reports `Unknown`.
- Spell `recast_id` follows Windower/GearSwap spell-id semantics; ability/WS recasts remain resource `RecastTimerId` based.
- Ability families such as Ready/PetCommand, Blood Pacts, Corsair Roll/Shot, Samba, Waltz, Step, Flourish1/2/3, Scholar, Jig, Rune, Ward, and Effusion are classified from the pinned Ashita ability resource type instead of falling through to `JobAbility`.
- A player-like action target whose name matches `GetPlayer().Name` is classified as `SELF`; other PC/party/alliance targets remain `PLAYER`.
- LAC `Resend` is propagated. Only a genuine resend of the same action is idempotent; two identical non-resend actions are separate generations and each receives exactly one aftercast.
- `status_change` and `pet_change` are not blanket-deferred by the adapter busy state. Buff changes retain the deferred behavior needed around Rahvin's busy window.
- Bootstrap tests now model pinned-LAC ordering: spell precast→midcast, ranged preshot→midshot, and `HandleDefault` only after `PlayerAction` has cleared.
- Core parity now executes the unchanged Rahvin engine/builders in a controlled harness and captures the actual logical GearSwap-shaped result before LuAshitacast slot translation. The old layer-precedence fixture remains only as a separate merge-order regression test.

## Automated verification

The full Termux/LuaJIT suite was run after the audit fixes at executable commit
`bdd8e339ef18c709410883ca53ceb49d4abd25b8`:

```text
RESULT 18 passed, 0 failed
```

The suite covers, among other contracts:

- spell, weaponskill, job ability, ranged attack, item, Geomancy, Trust, and nil-action translation;
- player/pet/target/day/weather/element/skill/recast translation and SELF/PLAYER/NPC/MONSTER target semantics;
- the expanded Rahvin action-family taxonomy;
- buffered equipment precedence and augmented item descriptor preservation;
- exactly-once aftercast for completion, interruption, cancellation, replacement, reset, resend, and identical sequential non-resend actions;
- pinned-LAC callback ordering and default/completion routing;
- status, counted buff, and pet transitions with the corrected busy semantics;
- real Rahvin builder decisions for idle/engaged/offense modes, named and ranged weaponskills, Aftermath, wield/weapon-lock behavior, movement, buff overlays, elemental cases, Cure/Light bonus, Bard instrument handling, Geomancy handbell handling, and SELF-vs-other-player builder paths.

## Known live verification gates

The automated suite deliberately does not claim behavior that only a running Ashita/FFXI client can establish. Remaining live gates include:

- actual callback/packet timing for success, interruption, cancellation, timeout, and server rejection;
- real buffered equip timing across fast-cast, midcast, ranged, and return-to-default transitions;
- LuAshitacast selection of duplicate augmented items from live wardrobes/bags;
- actual `Enable`/`Disable` persistence and cancellation behavior in the client;
- live resource/recast data across all real actions;
- live buff enumeration, pet/status timing, and target naming supplied by Ashita/LuAshitacast;
- job-file configuration and normal combat execution in a running client.

These remain integration gates, not silent compatibility claims.

## Upstream cleanliness

The audit diff from `d973c5100be358215ab24574cfaf3469b839a71c` through the verified executable
commit contains changes only under `ashita/` and `tests/`. No file under `RahvinGS/` or
`Sample Job Files/` changed. No Class-C patch is required.
