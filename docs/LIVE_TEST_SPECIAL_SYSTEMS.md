# Live test — Phase 3 special systems

This checklist is the live-client acceptance gate for the Phase 3 special-system adapters.
It does **not** replace the automated suites.

## Baselines

- Rahvin GearSwap: `2.1.0` / `f1cda1e41f567b16ec592e6598cda71bb04392d0`
- LuAshitacast: `7ed398edd3ebbdc8af86a79e5d3427da42e3a34a`
- Ashita v4: `4171c74c8ddb2ca2a31654f199e6c1cee40d7256`
- Phase 3 automated verification observed on master `8307ab47c7e4716b41398b5d4b4619ed0b450073`: `26 passed, 0 failed`

## Execution status

**Automated special-system gate: PASS.**

**Live special-system gate: PENDING.** The individual Phase 3 services exist and are unit/parity tested, but the current production `ashita/bootstrap.lua` does not yet assemble the Phase 3 event, packet, IPC, inventory/recast and cleanup services into one live runtime. The approved Phase 4 plan assigns that assembly/teardown responsibility to lifecycle work. Live results must therefore not be claimed before that integration exists.

Once the Phase 4 lifecycle/runtime assembly is present, run this checklist on Windows with the pinned Ashita/LAC revisions (or record the exact newer revisions actually tested).

## Evidence rules

For every case record: character/job, Ashita revision, LuAshitacast revision, exact command/action, observed chat or gear state, PASS/FAIL, and any relevant packet/action note. A live failure becomes an automated regression fixture **before** product code is changed.

## 1. Load, reload and handler cleanup

1. Load the RahvinGS Ashita/LAC profile and confirm one clean startup with no duplicate event aliases or callback errors.
2. Reload the profile three times.
3. Perform one normal action after every reload.
4. Confirm each action produces one lifecycle only: one precast generation, one midcast where applicable and one aftercast completion.
5. Confirm scheduler/packet/IPC callbacks are not multiplied by reloads.

Expected: no duplicate handlers, no duplicate aftercasts, no stale scheduled work from the previous profile instance.

## 2. Treasure Hunter / packet bridge

1. Use a job/configuration with Rahvin Treasure Hunter tracking enabled.
2. Target a fresh monster and perform the action that applies the TH tag.
3. Confirm Rahvin records the tag for that target and subsequently returns to its normal damage behavior where the unchanged Rahvin TH logic says it should.
4. Change to another target and back; confirm target-change polling does not transfer a tag to the wrong monster.
5. Kill the tagged monster and confirm the `0x029` action-message path clears the dead target state.
6. Observe another player perform WS/spell/roll actions while this client is active.

Expected: own TH tagging/completion follows Rahvin behavior; relevant foreign WS/spell/roll actions still reach Rahvin where its original logic consumes them; unrelated packets do nothing.

## 3. Zone reset

1. Establish TH/target state, then zone.
2. After zoning, select a target and perform a normal action.
3. Repeat once while no target is selected before zoning.

Expected: packet `0x00A` resets zone-local target tracking. The first post-zone target sample establishes a fresh baseline instead of reporting a synthetic cross-zone target change. No old TH target survives the zone.

## 4. SpellReceived / same-machine multibox

Requires two Ashita clients on the same Windows machine.

1. Enable Rahvin SpellReceived behavior on the receiving character and configure a visible received-spell set (for example two easily identifiable slots).
2. From client A cast a tracked spell on client B.
3. Confirm B equips the received set before the spell lands and releases it after A completes.
4. Repeat with two casters targeting B at overlapping times.
5. Confirm B keeps the borrowed slots until the **last** active caster completes.
6. Cast at a different target and confirm B does not equip received gear.
7. Interrupt one cast and verify the corresponding completion/release path.
8. Force/observe a missing completion and wait through Rahvin's existing failsafe window.
9. Reload one client and repeat to confirm transport subscribers are not duplicated.

Expected: localhost transport preserves Rahvin's `RAHVIN|...` semantics, stale/malformed/duplicate payloads do not create permanent holds, and the unchanged Rahvin failsafe releases abandoned received gear.

## 5. Hoxne critical windows

1. Test Hoxne OFF, ON-Locked and ON-Allow Critical states using the existing Rahvin controls.
2. Under ON-Locked attempt Tomahawk/Angon and confirm Rahvin gives its normal refusal rather than silently losing the action.
3. Under ON-Allow Critical perform Tomahawk or Angon with the required throwing item carried.
4. Confirm ammo is temporarily made available, the required item is equipped, the ability fires only after the bag copy reports `status == 5`, then Hoxne resumes after Rahvin's normal delay.
5. Perform a Bard song and a Geomancy cast and confirm the range critical window opens and remains open for the documented five-second rotation window.
6. Test a normal job ability and confirm it does not open a Hoxne critical window.

Expected: Rahvin's unchanged critical-action classifier remains authoritative; adapters only supply live bag/recast data.

## 6. Enchanted item — ready path

1. Carry an enchanted item in Inventory or Wardrobe 1–8.
2. Use Rahvin's existing `gs c use <item>` semantic through the Ashita command bridge once available.
3. Confirm the exact physical item copy is found, including duplicate same-name/same-id copies.
4. Confirm the item equips, waits its activation delay, sends `/item`, and releases the slot when the server reports completion.

Expected: no same-name aggregation, worn state follows the live bag-copy status byte, and the slot returns to the next owner after completion.

## 7. Enchanted item — cooldown and repair paths

1. Attempt an enchanted item while its extdata reports a future `next_use_time`.
2. Confirm Rahvin refuses/reports the cooldown with the same timing semantics as upstream.
3. Test an item whose activation delay is still running; confirm it waits rather than falsely reporting a recast.
4. During a waiting use, disturb the equipped item once and confirm Rahvin's repair command re-equips/restarts the delay.
5. Let a deliberately unaccepted item use reach its watchdog deadline.

Expected: extdata timestamps/usable state remain intact, cooldown and activation are distinct, repair is bounded, and watchdog release leaves no held slot.

## 8. Duplicate augmented items

1. Carry at least two copies of one item id with different augment/path data; if practical, wear one copy.
2. Exercise a path that queries/matches those copies.
3. Confirm the LAC-compatible matcher selects by descriptor/augment identity rather than collapsing by name or id.
4. Confirm the worn copy remains independently observable via `status == 5`.

Expected: every `(bag,index)` instance stays distinct throughout matching and extdata decoding.

## 9. Logout/reload cleanup

Run after Phase 4 lifecycle integration exists.

1. Begin or establish TH state, an IPC subscription, a scheduled callback and—where safe—a borrowed/held special-system slot.
2. Reload the LAC profile.
3. Repeat and then logout to character selection.
4. Log back in and load again.

Expected: event registrations, scheduler queue, IPC transport/subscribers, target state, action runtime and temporary holds from the previous instance are gone. No old callback fires after reload/logout.

## Result record

Do not mark Phase 3 live-complete until all applicable cases above have recorded PASS evidence and there is no unresolved parity blocker. The final release acceptance in Phase 5 repeats representative TH, SpellReceived, Hoxne/enchant, zoning/logout and duplicate-augmented-item cases from the release tree.
