# Phase 4 Live Smoke — RahvinGS on Ashita v4 + LuAshitacast

This is the first real-client gate after the automated production-composition suite.

Verified automated checkpoint before this live test:
- master: 6aca7140a9c912ebadc2d5e4761ab15acd22cf9a
- LuaJIT suite: 47 passed, 0 failed

This smoke test deliberately uses the repository's minimal production job fixture first. It exercises the real Rahvin engine, production adapters, display/settings/event/scheduler/IPC wiring and lifecycle without changing the user's normal job macro book or lockstyle.

## 1. Prepare an isolated profile copy

Let:

- `<ASHITA>` be the Ashita v4 install directory.
- `<PROFILE>` be the active LuAshitacast character directory:
  `<ASHITA>\config\addons\luashitacast\<Character>_<ServerId>`

Create:

```text
<PROFILE>\RAHVIN-SMOKE.lua
<PROFILE>\rahvings-port\
```

Copy the current repository master contents into:

```text
<PROFILE>\rahvings-port\
```

The copied tree must therefore contain at least:

```text
rahvings-port\ashita\profile.lua
rahvings-port\compat\include.lua
rahvings-port\RahvinGS\Rahvin-Engine.lua
rahvings-port\tests\fixtures\production_job.lua
```

## 2. Create RAHVIN-SMOKE.lua

Use exactly:

```lua
local source = debug.getinfo(1, 'S').source:sub(2)
local profile_dir = source:match('^(.*)[/\\][^/\\]+$') or '.'
local port_root = profile_dir .. '\\rahvings-port'

package.path =
    port_root .. '\\?.lua;' ..
    port_root .. '\\?\\init.lua;' ..
    package.path

return require('ashita.profile').production('tests/fixtures/production_job.lua')
```

Do not copy or alter Rahvin engine code in the stub.

## 3. Load gate

In FFXI:

```text
/lac load RAHVIN-SMOKE
```

PASS requires:

- LuAshitacast reports the profile loaded.
- No `RahvinCompatError` or Lua stack trace appears.
- Exactly one Rahvin status display generation is visible.
- No duplicate display objects appear after several seconds.
- The client remains responsive and normal game input works.

Then execute:

```text
/rahvings version
/lac fwd version
```

Both must reach the same Rahvin command dispatcher and report Rahvin version 2.1.

## 4. Reload gate

Run three times:

```text
/lac reload
```

After every reload:

- profile reload succeeds;
- only one status display generation remains;
- no duplicate command handler is observed;
- no stale overlay remains;
- no error mentions duplicate event aliases, scheduler, keybinds, IPC or destroyed font objects.

Then run again:

```text
/rahvings version
```

It must still work once.

## 5. Display/settings gate

Exercise all four Rahvin display styles through the same command bridge:

```text
/rahvings displaystyle classic
/rahvings displaystyle harness
/rahvings displaystyle lattice
/rahvings displaystyle halo
```

Also test:

```text
/rahvings display off
/rahvings display on
/rahvings displaypos
```

PASS requires:

- every supported style renders without a Lua error;
- hide/show does not create another display instance;
- reported position is stable;
- dragging the display and reloading restores the saved position;
- repeat one position-changing save/reload cycle at least twice to exercise Windows replacement behavior.

## 6. Zone gate

With the smoke profile still loaded, zone once.

PASS requires:

- no Lua error during zoning;
- display/runtime resumes after zoning;
- `/rahvings version` still works;
- no duplicate display or command response appears.

## 7. Logout/login gate

Return to character select normally, then log back into the same character.

The pinned Ashita v4 logout path is incoming packet `0x00B` with byte `+0x04 == 1`. LuAshitacast subsequently sees the new `0x00A` identity packet and auto-loads the character profile again.

PASS requires at character select:

- Rahvin display is gone;
- no stale overlay remains;
- no obviously active Rahvin keybind remains;
- no error is printed during teardown.

PASS after logging back in:

- LuAshitacast loads the selected profile again;
- exactly one Rahvin display generation appears;
- `/rahvings version` works once;
- no duplicate command/event behavior appears.

## 8. Unload gate

Finally run:

```text
/lac unload
```

PASS requires:

- display disappears;
- no stale overlay remains;
- no Lua error occurs;
- another `/lac load RAHVIN-SMOKE` succeeds cleanly.

## Evidence to return

Paste the Ashita/LuAshitacast console/chat output covering:

1. initial `/lac load RAHVIN-SMOKE`;
2. `/rahvings version`;
3. one `/lac reload`;
4. all four display-style commands;
5. the zone transition;
6. logout and subsequent login/profile load;
7. final `/lac unload`.

Also record the exact Ashita v4 build/revision and LuAshitacast revision actually installed. Do not infer them from this repository's pinned design baselines.
