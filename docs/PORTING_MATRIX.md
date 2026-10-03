# Porting matrix

Statuses: **UNAUDITED**, **A — UPSTREAM CLEAN**, **B — COMPAT**, or **C — ASHITA PATCH**.

Phase 1 audit evidence is provided by `tests/compat/test_phase1_primitives.lua`,
`tests/compat/test_slots.lua`, `tests/contract/test_gearswap_slots.lua`, and
`tests/contract/test_windower_surface.lua`. These tests cover the compatibility
surfaces statically observed across both upstream product paths; the construction
gate remains `tests/contract/test_upstream_load.lua`.

Phase 2 core-gear evidence is split at the platform boundary. LAC translation,
action lifecycle, bootstrap ordering, equipment buffering, and state transitions
are covered under `tests/ashita/`. `tests/parity/test_core_sets.lua` now executes
the unchanged Rahvin engine/builders in a controlled harness and captures the
actual pre-LAC GearSwap-shaped logical result. `tests/parity/test_merge_precedence.lua`
keeps the simpler set-combine precedence cases separate. Live packet timing and
actual client item selection remain release gates rather than simulated APIs.

The Phase 2 audit additionally locks Geomancy/Trust resource taxonomy, Windower-style
spell recast identity, the full Rahvin ability-family taxonomy used by the builders,
SELF target recovery from the pinned LAC player/target surfaces, LAC `Resend`
semantics, identical sequential action generations, and Rahvin-compatible status,
buff, and pet busy behavior.

| Rahvin module | Status | Adapter / evidence |
|---|---|---|
| `RahvinGS/GearSets-Include.lua` | A — UPSTREAM CLEAN | Loaded unchanged through `tests/contract/test_upstream_load.lua`; dependencies supplied by class-B compatibility adapters |
| `RahvinGS/Rahvin-Engine.lua` | A — UPSTREAM CLEAN | Loaded unchanged through `tests/contract/test_upstream_load.lua`; dependencies supplied by class-B compatibility adapters |
| `RahvinGS/builders.lua` | A — UPSTREAM CLEAN | Executed unchanged by `tests/parity/test_core_sets.lua` and loaded by `tests/contract/test_upstream_load.lua` |
| `RahvinGS/commands.lua` | A — UPSTREAM CLEAN | Loaded unchanged through `tests/contract/test_upstream_load.lua`; dependencies supplied by class-B compatibility adapters |
| `RahvinGS/core.lua` | A — UPSTREAM CLEAN | Loaded unchanged through `tests/contract/test_upstream_load.lua`; dependencies supplied by class-B compatibility adapters |
| `RahvinGS/display.lua` | A — UPSTREAM CLEAN | Loaded unchanged through `tests/contract/test_upstream_load.lua`; dependencies supplied by class-B compatibility adapters |
| `RahvinGS/enchant.lua` | A — UPSTREAM CLEAN | Loaded unchanged through `tests/contract/test_upstream_load.lua`; dependencies supplied by class-B compatibility adapters |
| `RahvinGS/equip.lua` | A — UPSTREAM CLEAN | Loaded unchanged through `tests/contract/test_upstream_load.lua`; dependencies supplied by class-B compatibility adapters |
| `RahvinGS/hooks.lua` | A — UPSTREAM CLEAN | Loaded unchanged through `tests/contract/test_upstream_load.lua`; dependencies supplied by class-B compatibility adapters |
| `RahvinGS/hoxne.lua` | A — UPSTREAM CLEAN | Loaded unchanged through `tests/contract/test_upstream_load.lua`; dependencies supplied by class-B compatibility adapters |
| `RahvinGS/interface.lua` | A — UPSTREAM CLEAN | Loaded unchanged through `tests/contract/test_upstream_load.lua`; dependencies supplied by class-B compatibility adapters |
| `RahvinGS/lifecycle.lua` | A — UPSTREAM CLEAN | Loaded unchanged through `tests/contract/test_upstream_load.lua`; dependencies supplied by class-B compatibility adapters |
| `RahvinGS/monitor.lua` | A — UPSTREAM CLEAN | Loaded unchanged through `tests/contract/test_upstream_load.lua`; dependencies supplied by class-B compatibility adapters |
| `RahvinGS/spellreceived.lua` | A — UPSTREAM CLEAN | Loaded unchanged through `tests/contract/test_upstream_load.lua`; dependencies supplied by class-B compatibility adapters |
| `RahvinGS/state.lua` | A — UPSTREAM CLEAN | Loaded unchanged through `tests/contract/test_upstream_load.lua`; dependencies supplied by class-B compatibility adapters |
| `RahvinGS/th.lua` | A — UPSTREAM CLEAN | Loaded unchanged through `tests/contract/test_upstream_load.lua`; dependencies supplied by class-B compatibility adapters |
