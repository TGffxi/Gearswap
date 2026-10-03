# Rahvin GearSwap 2.1.0 → Ashita v4 / LuAshitacast Port

**Design date:** 2026-10-03  
**Status:** Design approved in conversation; implementation not started; repository fork created at `TGffxi/Gearswap`  
**Primary goal:** Full functional parity with Rahvin GearSwap 2.1.0 on Ashita v4, while preserving an upgrade path that makes future Rahvin releases controlled upstream merges rather than new ports.

## 1. Baselines and provenance

The first Ashita port is pinned to the following upstream snapshots:

- **Rahvin GearSwap feature baseline:** tag `2.1.0`, commit `f1cda1e41f567b16ec592e6598cda71bb04392d0`
- **Fork starting snapshot / current Rahvin master:** commit `8bca6c48d437f93932ccf38313ae3d0a472b626e`. The three commits after tag `2.1.0` change only README punctuation, `index.html` comparison-report content, and add `LICENSE.md`; they do not change `RahvinGS/` product code.
- **Rahvin release asset:** `Rahvin.GS.2.1.zip`, SHA-256 `0111cb34cdfb800f58ab495480b383d922f9e5846f41f40d7b39400432f2ab01`
- **LuAshitacast baseline for design work:** commit `7ed398edd3ebbdc8af86a79e5d3427da42e3a34a`
- **Ashita v4 beta baseline for design work:** commit `4171c74c8ddb2ca2a31654f199e6c1cee40d7256`

The implementation must record the exact tested Ashita and LuAshitacast revisions in every release manifest. A newer LAC/Ashita revision may be adopted during implementation only through an explicit baseline update and regression run.

### Licensing

Rahvin GearSwap is MIT-licensed and preserves Mirdain and Rahvin copyright notices. The Ashita fork must preserve those notices and ship the MIT license text. The `2.1.0` tag itself does not expose `LICENSE.md` at repository root, while the current upstream branch does; the fork must therefore deliberately include the upstream MIT license text and provenance rather than silently omitting it.

## 2. Non-negotiable product requirements

1. **Feature target is Rahvin GearSwap 2.1.0 parity, not merely similar gear swapping.**
2. **LuAshitacast is the equipment/action backend.** We do not reimplement LAC's normal equipment pipeline unless a specific parity gap proves it necessary.
3. **Rahvin's decision logic stays as close to upstream as technically possible.**
4. **Ashita-specific behavior is isolated behind compatibility/platform adapters.**
5. **Every unavoidable source modification inside an upstream Rahvin file is tracked.**
6. **Future Rahvin versions must be importable through a documented upstream-sync procedure and regression suite.**
7. **No Rahvin 2.1 feature is dropped merely because the Windower implementation does not map directly.** Such features move to an Ashita-native adapter or are marked temporarily blocked until an equivalent is implemented and verified.
8. **User job/profile compatibility is a first-class requirement.** Existing Rahvin set naming, state concepts and sample-job semantics should be preserved where feasible; incompatible syntax must be handled by a documented compatibility shim or migration rule.

## 3. Chosen architecture

Three approaches were considered:

### A. Rewrite every Rahvin job as a native LAC profile

This is the simplest short-term path but loses Rahvin's engine semantics and makes future upstream versions expensive to port. Rejected.

### B. Preserve Rahvin engine semantics behind a GearSwap/Windower compatibility layer

This is the selected approach. Rahvin's modules remain in their original paths wherever possible. A bootstrap profile and compatibility layer expose the subset of GearSwap/Windower APIs that Rahvin actually uses and route them to LAC/Ashita.

Advantages:

- smallest long-term diff against upstream;
- future Rahvin releases remain mergeable;
- one compatibility implementation serves all jobs;
- Rahvin's set-building behavior remains the source of truth;
- parity tests can compare outputs at the engine boundary.

### C. Build a standalone Ashita gear engine and stop using LAC

This offers maximum control but duplicates action timing, equip buffering, augment matching, slot locking and other functionality already provided by LAC. Rejected unless a future hard blocker proves LAC incapable of a required parity behavior.

## 4. Repository strategy for future upstream updates

The project is the GitHub fork `TGffxi/Gearswap` of `RahvinCode/Gearswap`. Development uses **only the `master` branch**. No feature, sync, release-candidate, or temporary integration branches are to be created.

Recommended remotes:

```text
origin   = https://github.com/TGffxi/Gearswap.git
upstream = https://github.com/RahvinCode/Gearswap.git
```

The port should retain Rahvin source files at their original paths instead of moving them into a vendor subtree. This maximizes Git's ability to merge future upstream changes. All implementation commits land directly on `master` in small, test-gated increments.

New Ashita-specific code is added under dedicated directories, for example:

```text
RahvinGS/                 # upstream paths preserved
Sample Job Files/         # upstream paths preserved
ashita/
  bootstrap.lua
  platform.lua
  events.lua
  packets.lua
  ipc.lua
  display.lua
  scheduler.lua
  settings.lua
compat/
  gearswap.lua
  windower.lua
  modes.lua
  resources.lua
  extdata.lua
  config.lua
  include.lua
tests/
  contract/
  fixtures/
  parity/
docs/
  PORTING_MATRIX.md
  UPSTREAM_PATCH_LEDGER.md
  UPSTREAM_UPDATE.md
  RELEASE_BASELINES.md
```

If a Rahvin source file must be edited, that edit must be recorded in `docs/UPSTREAM_PATCH_LEDGER.md` with:

- file and function;
- reason an adapter alone could not solve it;
- expected upstream-conflict risk;
- test that protects the behavior;
- whether the patch can later be removed.

### Change classes

Every port difference is classified as:

- **A — UPSTREAM CLEAN:** byte-identical or semantically unchanged Rahvin source.
- **B — COMPAT:** Rahvin code is unchanged and behavior is supplied by the compatibility/platform layer.
- **C — ASHITA PATCH:** direct modification of Rahvin source is unavoidable.

The architectural target is to maximize A and B and keep C minimal.


## 4.1 Development access and Termux

Repository work should use the connected GitHub integration directly whenever it can perform the required read/write operation. **Termux is optional**, not a runtime or build dependency. It is retained only as a fallback path for operations that require access to a local checkout, local Ashita files, or a live client/test machine that the GitHub integration cannot access. No shipped code may depend on Termux.

## 5. Runtime architecture

### 5.1 LAC profile bootstrap

A thin LuAshitacast profile/bootstrap becomes the entry point. It:

1. initializes the compatibility environment;
2. creates GearSwap-compatible globals required by the Rahvin interface;
3. loads the selected Rahvin job file and engine;
4. exposes LAC handlers such as `HandlePrecast`, `HandleMidcast`, `HandlePreshot`, `HandleMidshot`, `HandleWeaponskill`, `HandleAbility`, `HandleItem`, `HandleDefault`, `HandleCommand`, `OnLoad` and `OnUnload`;
5. translates each LAC callback into the corresponding Rahvin engine lifecycle call;
6. commits the resulting equipment set through LAC.

LAC already accepts Lua set tables directly and provides equip buffering, action cancellation, set combination, slot disable/enable and augment-aware item selection. The port should use these public interfaces instead of reproducing them.

### 5.2 GearSwap compatibility surface

The compatibility layer must implement only the GearSwap surface actually consumed by Rahvin and supported job files. Expected compatibility globals include, subject to exact implementation audit:

- `sets`
- `set_combine`
- `equip`
- `enable`
- `disable`
- `cancel_spell`
- `include`
- `M{}` / Modes-compatible state objects
- `player`
- `buffactive`
- current action/spell structures
- world/day/weather information
- inventory/equipment views
- command dispatch helpers

The shim must preserve Rahvin-facing semantics even when the underlying Ashita/LAC naming differs. Example: GearSwap `lear`/`rear` and `lring`/`rring` must map deterministically to LAC `Ear1`/`Ear2` and `Ring1`/`Ring2` without leaking LAC names back into upstream logic.

### 5.3 Windower compatibility surface

Rahvin 2.1.0 directly uses Windower in multiple engine modules. The compatibility object should emulate the used subset rather than globally pretending to implement all of Windower.

Expected areas include:

- chat output/input;
- command queueing;
- character/player/inventory/recast access;
- mob/entity lookup;
- event registration;
- raw packet/action hooks;
- zone/target/buff/logout lifecycle events;
- frame/timer scheduling;
- IPC/multibox transport;
- primitive/text rendering used by the status display.

Unsupported calls must fail loudly with a precise compatibility error during development. Silent no-ops are forbidden unless the original behavior is intentionally a no-op and covered by a test.

### 5.4 Compatibility modules for Windower libraries

Rahvin's core currently depends on Windower-provided modules including `config`, `resources`, `socket` and `extdata`. The Ashita port must provide or map the exact subset Rahvin consumes.

- `config`: map to Ashita/LAC-side persisted character settings while retaining Rahvin settings semantics.
- `resources`: map spell, ability, item, buff, job and related lookups to Ashita resources.
- `extdata`: provide the augment/item metadata Rahvin needs, preferably backed by LAC/Ashita item parsing rather than a duplicate parser.
- `socket`: determine whether the exact Rahvin use needs LuaSocket on Ashita; if not available or not required, replace only the consumed function behind a compatibility wrapper.

## 6. Feature mapping

### 6.1 Direct or near-direct through LAC

These areas should primarily use LAC's public profile API:

- precast/midcast spell handling;
- ranged preshot/midshot;
- weapon skills;
- job abilities;
- item usage;
- default idle/engaged/resting processing;
- table-based set equipping;
- slot enable/disable;
- action cancellation;
- set combination;
- augment/path/rank/trial/bag item matching.

### 6.2 Rahvin logic preserved above LAC

The following remain Rahvin engine concerns:

- offense modes and weapon modes;
- layered set construction;
- named weaponskill overlays;
- Aftermath layers;
- buff-set overlays;
- day/weather/distance decisions;
- weapon-lock semantics;
- movement/idle/engaged state selection;
- cure/enhancing/blue-magic/song/action classification;
- ammunition policy and warnings;
- job-specific hooks and custom modes;
- settings behavior and commands;
- gear reporting and diagnostic warnings.

### 6.3 Ashita-native adapters required

The following are known to rely on Windower events/APIs and need dedicated Ashita implementations:

- Treasure Hunter target/action/packet tracking;
- SpellReceived and multibox communication;
- incoming/outgoing packet-driven polling;
- zone and target change tracking;
- gain/loss buff handling where not already surfaced by LAC;
- Hoxne and enchanted-item inventory/recast handling;
- frame/prerender failsafes;
- logout teardown;
- command/keybind integration;
- Rahvin status/display rendering;
- scheduled/deferred startup tasks;
- chained command execution and timed waits.

## 7. Action and event model

The port must not assume that LAC callback timing is identical to GearSwap timing. Each lifecycle path must be verified empirically and with packet traces where necessary.

For every action family, document:

1. event/callback source;
2. Rahvin handler entered;
3. action data available at that point;
4. whether equipment goes into LAC's buffered equip path or requires a forced/direct path;
5. cancellation behavior;
6. post-action/default restoration behavior;
7. failure/interrupt behavior.

No direct equipment packet should be used where buffered LAC equipment provides equivalent behavior. `ForceEquip`/direct packet paths are exceptions that require an explicit reason and test.

## 8. State compatibility

The port should expose Rahvin-compatible state objects rather than rewrite mode logic to LAC idioms.

The `M{}` replacement must support the operations actually used by Rahvin/sample jobs, including at minimum:

- option declaration;
- current `.value` access;
- cycling/setting;
- boolean/toggle states where used;
- deterministic string representation if commands/display rely on it.

Player, world, buff and action state must be refreshed from Ashita/LAC at stable boundaries so a single Rahvin handler does not observe mixed snapshots.

## 9. Settings and per-character behavior

Rahvin 2.1 introduced per-character settings files. The Ashita port must preserve the user-visible semantics even though the physical path changes.

Recommended path:

```text
ashita/config/addons/luashitacast/<CharacterName>_<CharacterId>/rahvings/settings.lua
```

or an equivalent character-scoped path approved during implementation.

The stored settings must cover the same Rahvin preferences, including display settings, chat/debug/warn/info/gear-reporting toggles, key bindings and other persisted engine choices.

A migration layer may import Rahvin `settings.xml` from an existing Windower installation when explicitly requested, but automatic discovery outside Ashita's tree is not required for first release.

## 10. Display

Rahvin's display is a parity requirement but should not depend on Windower primitives in the final Ashita build.

Implement a renderer abstraction exposing the operations Rahvin display logic needs. The Ashita renderer may use Ashita font/primitive APIs or ImGui if appropriate, but must preserve:

- the four Rahvin display styles;
- visibility behavior;
- positions and persisted layout settings;
- mode/status information;
- teardown on unload/logout;
- no stale overlay at character selection.

Rendering code belongs in `ashita/display.lua`; display-state computation should remain upstream-clean where possible.

## 11. SpellReceived / multibox

Windower IPC cannot simply be called on Ashita. Define an internal transport interface:

```text
send(message)
subscribe(handler)
unsubscribe(handler)
```

The first Ashita implementation should use the most reliable same-machine mechanism available within Ashita without requiring an external service. Message payloads must be versioned and include enough sender/action/target identity to prevent cross-character ambiguity.

SpellReceived parity tests must cover:

- supported incoming spell detection;
- correct target filtering;
- received set equip;
- lock/borrow behavior;
- completion release;
- failure/timeout release;
- multiple local clients;
- stale or malformed messages.

## 12. Treasure Hunter

TH parity must be built from Ashita action/packet/entity events rather than timing guesses.

Tests must cover at least:

- target change;
- attack/action application;
- TH set application only when intended;
- zone reset;
- non-player actions ignored where Rahvin ignores them;
- skillchain/action paths retained if Rahvin uses them for other engine features.

## 13. Hoxne and enchanted items

These features depend on live inventory and recast/cooldown information. The adapter must provide stable inventory iteration over the bags Rahvin supports and equivalent cooldown semantics.

Do not simplify away item-instance identity or augment data. Where duplicate items exist, the adapter must retain enough identity to choose the intended instance or reproduce Rahvin's selection semantics.

## 14. Commands and keybinds

Rahvin command semantics remain the public contract. The Ashita-facing command syntax may expose both:

```text
/lac fwd ...
```

and a convenience command namespace such as:

```text
/rahvings ...
```

but the underlying Rahvin commands and arguments must behave consistently with `gs c ...` where applicable.

Keybind persistence and cleanup must be deterministic across profile load/unload/reload.

## 15. Testing strategy

### 15.1 Pure compatibility unit tests

Test without a live FFXI client wherever possible:

- `set_combine` precedence;
- slot-name translations;
- `M{}` behavior;
- command parsing;
- settings round-trip;
- event registration bookkeeping;
- item/augment mapping;
- resource translations.

### 15.2 Rahvin decision-contract tests

Build fixtures representing player/world/action/buff state and assert the final logical gear set selected by Rahvin.

Representative fixtures include:

- idle vs engaged;
- TP vs ACC/DT/PDL/SB/CRIT/MEVA modes where applicable;
- Savage Blade and other named WS overlays;
- ranged WS;
- Aftermath tiers;
- weapon lock on/off;
- dual wield/two-hand behavior;
- buff-set overlays;
- day/weather bonus;
- cure/light bonus;
- Bard instrument exceptions;
- GEO handbell behavior;
- movement;
- low-ammo warning paths;
- blue magic categories;
- received-spell gear;
- TH state transitions.

The key contract is the **logical result set**, not the implementation mechanism.

### 15.3 Live LAC integration tests

Run inside Ashita with explicit test scripts/checklists for:

- callback ordering;
- buffered equip timing;
- interrupts/cancels;
- fast cast → midcast → return;
- ranged preshot → midshot → return;
- WS weapon preservation;
- slot locking/unlocking;
- duplicate augmented item selection;
- job changes/profile reloads;
- zoning/logout;
- multibox SpellReceived;
- TH;
- Hoxne/enchant cooldown behavior;
- display cleanup.

### 15.4 Regression gate for future Rahvin versions

A new upstream version cannot be called ported until:

1. upstream diff classified;
2. patch ledger reconciled;
3. compatibility unit suite passes;
4. Rahvin decision-contract suite passes;
5. impacted live-integration tests pass;
6. release manifest records new Rahvin tag/commit and tested LAC/Ashita revisions.

## 16. Upstream update workflow

For each future Rahvin release `X.Y.Z`:

```bash
git checkout master
git fetch upstream --tags
git diff <previous-upstream-commit>..X.Y.Z -- RahvinGS 'Sample Job Files' README.md 'PATCH NOTES.md'
git merge --no-commit --no-ff X.Y.Z
```

Because this project is `master`-only, the merge is staged directly on `master`. If review or tests identify a problem before commit, run `git merge --abort`; no temporary sync branch is created.

Then:

1. inspect `git diff <previous-upstream-tag>..X.Y.Z`;
2. classify changed files/functions as A/B/C impact;
3. resolve only genuine conflicts;
4. update compatibility adapters where upstream began using new GearSwap/Windower behavior;
5. update patch ledger for any C patches;
6. run the regression gate;
7. tag an Ashita release only after parity is restored.

Enable and retain Git conflict-resolution reuse (`rerere`) for the port repository so recurring mechanical conflicts can be reapplied, but never accept an automatic resolution without tests.

## 17. Versioning

Release metadata must separate Rahvin compatibility from Ashita-port revision.

Recommended manifest fields:

```text
rahvin_upstream_version = 2.1.0
rahvin_upstream_commit  = f1cda1e41f567b16ec592e6598cda71bb04392d0
ashita_port_version     = 1.0.0
luashitacast_tested     = 7ed398edd3ebbdc8af86a79e5d3427da42e3a34a
ashita_v4_tested        = 4171c74c8ddb2ca2a31654f199e6c1cee40d7256
```

Human-facing releases may use a format such as `RahvinGS-Ashita 2.1.0+a1.0.0`, where the Rahvin portion remains visibly tied to upstream while Ashita-only fixes can increment independently.

## 18. Initial implementation milestones

### Milestone 0 — Fork hygiene and baselines

- use existing fork `TGffxi/Gearswap`;
- `master` is the only development branch;
- configure/record `upstream` remote where a local Git checkout is used;
- record baseline commits and release digest;
- add license/provenance;
- add porting matrix and patch ledger;
- no behavior changes.

### Milestone 1 — Compatibility substrate

- bootstrap LAC profile;
- `include`/module loading;
- set table and slot mapping;
- `set_combine`;
- `M{}` state compatibility;
- player/world/buff snapshots;
- chat/command/scheduler wrappers;
- tests.

Success gate: Rahvin interface and pure set builders can load under a test harness without a live GearSwap runtime.

### Milestone 2 — Core action/equip parity

- spells;
- WS;
- JA;
- ranged;
- item use;
- idle/engaged/movement;
- weapon locks;
- augment-aware gear selection.

Success gate: representative jobs can perform normal combat swapping with parity-contract tests passing.

### Milestone 3 — Stateful/special systems

- TH;
- SpellReceived/multibox;
- Hoxne;
- enchanted items;
- buff event paths;
- special monitors and delayed recovery.

### Milestone 4 — Display/settings/commands

- full settings persistence;
- display styles;
- command parity;
- keybinds;
- lifecycle cleanup.

### Milestone 5 — Sample jobs and full regression

- port/verify every shipped sample job;
- full parity matrix;
- live test checklist;
- installation/update documentation;
- release candidate.

## 19. Explicit non-goals for the first implementation

- Rewriting Rahvin's engine into a new style merely because Ashita APIs differ.
- Replacing LAC's equip engine with custom packet injection unless required for parity.
- Redesigning Rahvin's public mode/set semantics.
- Adding unrelated new gameplay automation.
- Optimizing before parity is established and measured.

## 20. Definition of done

The first release is done when:

1. Rahvin GearSwap 2.1.0's documented functional surface has a status in the parity matrix and no required feature is silently omitted.
2. Normal spell/WS/JA/ranged/default gear flow works through LAC.
3. Weapon locks and WS weapon preservation behave correctly.
4. Buff/day/weather/mode layering produces Rahvin-equivalent logical sets.
5. Duplicate/augmented item selection is verified.
6. TH, SpellReceived, Hoxne/enchant, settings, commands, display and lifecycle behavior are implemented or explicitly blocked by an evidenced Ashita limitation; a release named full-parity requires all of them implemented.
7. Sample jobs intended for 2.1 are verified.
8. Automated contract tests pass.
9. Live Ashita regression checklist passes.
10. A dry-run upstream-sync exercise demonstrates that a synthetic or later Rahvin change can be classified and integrated through the documented workflow.

## 21. Design invariant

The core maintenance rule for the lifetime of the project is:

> **Never modify Rahvin upstream code merely because an Ashita API is different. First add or extend a compatibility adapter. Direct upstream-file patches are the last resort, must be documented, and must be protected by a regression test.**

This invariant is what makes future Rahvin releases inexpensive to port.
