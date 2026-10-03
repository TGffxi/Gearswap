# Phase 1 result — Foundation and Compatibility

Phase 1 completed on 2026-10-03 on `master`.

## Implemented points and commits

| Plan task | Commit | Result |
|---|---|---|
| Baseline guard and deterministic LuaJIT runner | `3d6ae2d` | Pinned Rahvin, fork, LuAshitacast and Ashita revisions; added release, porting and patch-ledger documentation. |
| GearSwap sets and slot aliases | `83ca5e8` | Deep-copying `set_combine` semantics and deterministic translation of all 16 GearSwap slots. |
| Modes state objects | `e6fcf8f` | Ordered options, cycle/set/reset/toggle behavior, boolean modes and deterministic display values. |
| Controlled includes and environment | `bcc58e4` | Repository-rooted, non-shadowable includes and explicit compatibility failures. |
| Coherent snapshots | `99fb211` | One-generation player/world/buff/pet/equipment/inventory captures with duplicate inventory preservation. |
| Compatibility shells and upstream construction gate | `45902c1` | GearSwap, Windower, resources, config and extdata contracts; unchanged Rahvin engine construction through mocked services. |

## External audit corrections

The Phase 1 compatibility audit was closed on 2026-10-03 without changing
`RahvinGS/` or `Sample Job Files/`:

- Slot translation now accepts every spelling in `RahvinGS/core.lua`'s
  `CANON_SLOT` table. Reverse translation emits Rahvin's canonical `range`,
  `left_ear`, `right_ear`, `left_ring`, and `right_ring` forms.
- A contract test passes a canonical Rahvin gear set through `equip()` and
  verifies the LuAshitacast `Ear1`, `Ear2`, `Ring1`, and `Ring2` keys.
- Every Windower symbol observed by a static sweep has a callable compatibility
  surface. `get_spell_recasts` and `get_party` are now explicit platform
  adapters, and unavailable services fail with `RahvinCompatError` rather than
  remaining `nil`.
- The primitive sweep added the observed `T{}` methods (`insert`, `concat`, and
  `clear`), `S{}` membership indexing, and the Modes list tracking metadata
  consumed by Rahvin. Unsupported file and wildcard services now fail
  explicitly instead of returning fabricated results.
- The observed `config`, `resources`, `extdata`, `socket`, `files`, and `xml`
  module surfaces are covered by contract tests.

## Baseline verification

Before implementation, the pinned repositories were checked out independently and their revisions verified with `git rev-parse HEAD`:

- LuAshitacast: `7ed398edd3ebbdc8af86a79e5d3427da42e3a34a`.
- Ashita v4: `4171c74c8ddb2ca2a31654f199e6c1cee40d7256`.
- Rahvin product paths have no diff between feature commit `f1cda1e41f567b16ec592e6598cda71bb04392d0` and fork snapshot `8bca6c48d437f93932ccf38313ae3d0a472b626e`.

The LAC callback/profile interface and Ashita event registration surface were inspected at those exact revisions before adapter work. Phase 1 uses only dependency injection and does not claim live-client verification.

## Exit gate

`luajit tests/run.lua all` passes all Phase 1 suites, including the audit-specific
primitive, slot/equip, and Windower contracts. `RahvinGS/` and
`Sample Job Files/` remain unchanged from the pinned Rahvin feature baseline, so
the upstream patch ledger remains empty.
