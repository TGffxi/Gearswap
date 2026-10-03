# Porting matrix

Statuses: **UNAUDITED**, **A — UPSTREAM CLEAN**, **B — COMPAT**, or **C — ASHITA PATCH**.

Phase 1 audit evidence is provided by `tests/compat/test_phase1_primitives.lua`,
`tests/compat/test_slots.lua`, `tests/contract/test_gearswap_slots.lua`, and
`tests/contract/test_windower_surface.lua`. These tests cover the compatibility
surfaces statically observed across both upstream product paths; the construction
gate remains `tests/contract/test_upstream_load.lua`.

Phase 2 core-gear evidence is split at the platform boundary. LAC translation,
action lifecycle, bootstrap ordering, equipment buffering, and state transitions
are covered under `tests/ashita/`. `tests/parity/test_core_sets.lua` executes the
unchanged Rahvin engine/builders in a controlled harness and captures the actual
pre-LAC GearSwap-shaped logical result. `tests/parity/test_merge_precedence.lua`
keeps the simpler set-combine precedence cases separate. The Phase 2 audit also
locks Geomancy/Trust taxonomy, Windower-style spell recast identity, Rahvin's
ability-family taxonomy, SELF target recovery, LAC `Resend`, identical sequential
action generations, and Rahvin-compatible status/buff/pet busy behavior.

Phase 3 adds class-B Ashita services without editing upstream product files:
`ashita/events.lua`, `scheduler.lua`, `packets.lua`, `ipc.lua`, `inventory.lua`,
`recasts.lua`, plus the extdata/string compatibility needed by unchanged Rahvin
code. Evidence is `tests/ashita/test_events.lua`, `test_scheduler.lua`,
`test_packets.lua`, `test_ipc.lua`, `test_inventory.lua`, and the real-engine
parity suites `tests/parity/test_th.lua`, `test_spellreceived.lua`, and
`test_enchant_hoxne.lua`. The observed automated gate at master
`8307ab47c7e4716b41398b5d4b4619ed0b450073` was `26 passed, 0 failed`.

The Phase 3 diff from the independently approved Phase 2 endpoint
`5fc56b35470e58717f82c1f0208a82ec2ec45ab1` through `8307ab47c7e4716b41398b5d4b4619ed0b450073`
contains only `ashita/`, `compat/` and `tests/` files. There are no changes under
`RahvinGS/` or `Sample Job Files/`.

**Live status:** Phase 3 automated parity is green, but its live exit gate remains
pending until the approved Phase 4 lifecycle work assembles and tears down the
special-system services in the production runtime. `docs/LIVE_TEST_SPECIAL_SYSTEMS.md`
contains the exact live checks. No live-client claim is made before those checks
are executed and recorded.

| Rahvin module | Status | Adapter / evidence |
|---|---|---|
| `RahvinGS/GearSets-Include.lua` | A — UPSTREAM CLEAN | Loaded unchanged through `tests/contract/test_upstream_load.lua`; dependencies supplied by class-B compatibility adapters |
| `RahvinGS/Rahvin-Engine.lua` | A — UPSTREAM CLEAN | Loaded unchanged through `tests/contract/test_upstream_load.lua`; dependencies supplied by class-B compatibility adapters |
| `RahvinGS/builders.lua` | A — UPSTREAM CLEAN | Executed unchanged by `tests/parity/test_core_sets.lua` and loaded by `tests/contract/test_upstream_load.lua` |
| `RahvinGS/commands.lua` | A — UPSTREAM CLEAN | Loaded unchanged; Ashita command bridge is Phase 4 |
| `RahvinGS/core.lua` | A — UPSTREAM CLEAN | Loaded unchanged; class-B resources/extdata/platform primitives supply the observed dependencies |
| `RahvinGS/display.lua` | A — UPSTREAM CLEAN | Loaded unchanged; concrete Ashita renderer is Phase 4 |
| `RahvinGS/enchant.lua` | A — UPSTREAM CLEAN | Real unchanged enchant entry path exercised by `tests/parity/test_enchant_hoxne.lua`; `ashita/inventory.lua`, `ashita/recasts.lua`, `compat/extdata.lua` supply data |
| `RahvinGS/equip.lua` | A — UPSTREAM CLEAN | Loaded unchanged; LAC equipment translation/buffering covered by Phase 2 tests |
| `RahvinGS/hooks.lua` | A — UPSTREAM CLEAN | Loaded unchanged; action lifecycle and Hoxne critical classifications are exercised through parity tests |
| `RahvinGS/hoxne.lua` | A — UPSTREAM CLEAN | Real unchanged critical-action decisions exercised by `tests/parity/test_enchant_hoxne.lua`; inventory/recast adapters preserve bag-instance and timer semantics |
| `RahvinGS/interface.lua` | A — UPSTREAM CLEAN | Loaded unchanged through `tests/contract/test_upstream_load.lua` |
| `RahvinGS/lifecycle.lua` | A — UPSTREAM CLEAN | Loaded unchanged; Ashita lifecycle assembly/cleanup remains Phase 4 Task 5 and is the prerequisite for live Phase 3 acceptance |
| `RahvinGS/monitor.lua` | A — UPSTREAM CLEAN | Loaded unchanged; scheduler/event compatibility supplied by class-B adapters |
| `RahvinGS/spellreceived.lua` | A — UPSTREAM CLEAN | Unchanged registered IPC/prerender handlers exercised by `tests/parity/test_spellreceived.lua`; versioned localhost IPC is translated losslessly at the adapter edge |
| `RahvinGS/state.lua` | A — UPSTREAM CLEAN | Loaded unchanged; Phase 2 state runtime plus Phase 3 reset/event services supply platform state |
| `RahvinGS/th.lua` | A — UPSTREAM CLEAN | Packet/action routing preserves Rahvin actor semantics in `tests/parity/test_th.lua`; `0x00A`, `0x028`, `0x029` bridge behavior is covered in `tests/ashita/test_packets.lua` |
