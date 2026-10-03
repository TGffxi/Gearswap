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

## Baseline verification

Before implementation, the pinned repositories were checked out independently and their revisions verified with `git rev-parse HEAD`:

- LuAshitacast: `7ed398edd3ebbdc8af86a79e5d3427da42e3a34a`.
- Ashita v4: `4171c74c8ddb2ca2a31654f199e6c1cee40d7256`.
- Rahvin product paths have no diff between feature commit `f1cda1e41f567b16ec592e6598cda71bb04392d0` and fork snapshot `8bca6c48d437f93932ccf38313ae3d0a472b626e`.

The LAC callback/profile interface and Ashita event registration surface were inspected at those exact revisions before adapter work. Phase 1 uses only dependency injection and does not claim live-client verification.

## Exit gate

`luajit tests/run.lua all` passes all Phase 1 suites. `RahvinGS/` and `Sample Job Files/` remain unchanged from the pinned Rahvin feature baseline, so the upstream patch ledger remains empty.
