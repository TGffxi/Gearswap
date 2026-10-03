# Porting matrix

Statuses: **UNAUDITED**, **A — UPSTREAM CLEAN**, **B — COMPAT**, or **C — ASHITA PATCH**.

Phase 1 audit evidence is provided by `tests/compat/test_phase1_primitives.lua`,
`tests/compat/test_slots.lua`, `tests/contract/test_gearswap_slots.lua`, and
`tests/contract/test_windower_surface.lua`. These tests cover the compatibility
surfaces statically observed across both upstream product paths; the construction
gate remains `tests/contract/test_upstream_load.lua`.

Phase 2 core-gear evidence is split at the platform boundary: LAC data and public
`gFunc` contracts are covered by `tests/ashita/`, while
`tests/parity/test_core_sets.lua` locks Rahvin's pre-translation logical merge
results for default, offense-mode, weaponskill, weapon-lock, movement, buff,
elemental, Bard-instrument, and Geomancy-handbell decisions. Live callback timing
and actual item selection remain live-client release gates rather than simulated
APIs.

| Rahvin module | Status | Adapter / evidence |
|---|---|---|
| `RahvinGS/GearSets-Include.lua` | A — UPSTREAM CLEAN | Loaded unchanged through `tests/contract/test_upstream_load.lua`; dependencies supplied by class-B compatibility adapters |
| `RahvinGS/Rahvin-Engine.lua` | A — UPSTREAM CLEAN | Loaded unchanged through `tests/contract/test_upstream_load.lua`; dependencies supplied by class-B compatibility adapters |
| `RahvinGS/builders.lua` | A — UPSTREAM CLEAN | Loaded unchanged through `tests/contract/test_upstream_load.lua`; dependencies supplied by class-B compatibility adapters |
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
