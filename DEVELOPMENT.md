# Development

## Source layout

Rojo maps `src/shared` → `ReplicatedStorage.LastShift`, `src/server` → `ServerScriptService.LastShift`, `src/client` → `StarterPlayer.StarterPlayerScripts.LastShift`, and `src/range/Workspace.project.json` → `Workspace`.

```
src/
  shared/                      ReplicatedStorage.LastShift (server + client)
    Net.luau                   Remote names, creation, payload types
    Data/                      Pure data — all tuning lives here
      Calibers.luau            Caliber → ordered ammo list (sets 1/2/3 keys)
      Ammo.luau                Damage, penetration, range, falloff per round
      Weapons.luau             Magazine, cadence, reload, spread, recoil, FOV, sound
      Armor.luau               Helmets / body armor and their protection
      Zones.luau               Hit-zone damage scales, armor slots, lethal zones
      Movement.luau            Speeds per movement mode, crouch offset
      Loadout.luau             Spawn weapon
    Combat/
      Damage.luau              Pure damage rules (no Roblox APIs; unit-tested)
      Spread.luau              Server spread cone
  server/                      ServerScriptService.LastShift
    Main.server.luau           Bootstrap
    Services/
      PlayerSessions.luau      Per-life session state + request gate (rate limit)
      MovementService.luau     Validates movement mode, owns WalkSpeed
      WeaponService.luau       Ammo, reload, fire validation, raycast
      TargetService.luau       Range dummies: hit lookup, armor, damage, reset
  client/                      StarterPlayerScripts.LastShift
    Main.client.luau           Bootstrap, input routing, render loop
    Keybinds.luau
    Controllers/
      CharacterController.luau Aim/sprint/crouch → movement mode, crouch camera
      WeaponController.luau    Fire/reload/select requests, server state
    View/
      Viewmodel.luau           Rifle model, ADS, recoil, flash, tracer, sound
      DebugHud.luau            Developer HUD + crosshair
  range/Workspace.project.json Range geometry, spawn, lighting, target dummies
tests/run.luau                 Engine-free data + damage tests (Luau CLI)
tools/check_luau.py            Structural checker for machines without Luau tools
build.bat                      Syntax check → tests → rojo build
```

The 2026-11-19 restructure replaced six older files. They are now empty placeholders and **can be deleted**: `src/shared/Config.luau`, `src/server/Combat.server.luau`, `src/server/Damage.luau`, `src/server/Range.luau`, `src/client/Controller.client.luau`, `src/client/RangeView.luau`. `tools-local/check-combat.luau` tests the old code and is stale too. The originals are kept in `_backup/2026-11-19-before-restructure/`.

## Architecture decisions

1. **The server owns combat.** The client sends only a unit aim vector. The server checks the session (live character), rate budget, reload state, sprint, ammo and cadence. It chooses the origin (Head, lowered when crouched), adds spread with its own RNG, raycasts, and resolves damage. Ammo counts and hit results reach the client only through `WeaponState` and `ShotResult`.
2. **All tuning is data.** Weapons point at a caliber, calibers list their rounds, and targets wear armor by id. Adding content means editing `Data/` only (see below).
3. **The damage rules are pure.** `Combat/Damage.luau` has no requires and no Roblox APIs, so `tests/run.luau` runs it in the plain Luau CLI. It takes the zone rules as a parameter.
4. **Sessions are per life.** `PlayerSessions` creates a fresh session on every spawn. Delayed work (reloads) checks `isCurrent`, so callbacks from a previous life can't touch the new one. Future per-life systems (health, bleeding, inventory-in-raid) attach to the session the same way `weapon` does.
5. **One remote per message, one gate.** `Net.luau` defines every remote and its payload. Every client→server handler goes through `PlayerSessions.gate`: a live character plus a token bucket of 24 burst and 16/s.
6. **Client prediction is cosmetic only.** Recoil, flash and sound play on click. Counts, hits and damage wait for the server.
7. **Recoil can't drift aim.** The camera pitch from recoil is undone before Roblox's camera update each frame and re-applied after it. Follow-up shots climb while recoil is up, then the view returns, with no random shake.

## Combat rules (prototype values)

- **Penetration ≥ protection:** penetrated. Full damage; on the head this is lethal.
- **Head (helmet) with penetration < protection:** stopped (0 damage). Helmets never "reduce".
- **Body armor with penetration < 60% of protection:** stopped.
- **Body armor otherwise:** reduced, to 40% damage.
- **No armor:** head is lethal. Torso ×1, arms ×0.65, legs ×0.55.
- **Falloff:** full damage up to `effectiveRange`, then `falloffPerStud` per stud down to `minDamageScale`.

| Ammo | Damage | Penetration | Eff. range |
| --- | --- | --- | --- |
| 5.56 FMJ | 36 | 45 | 90 |
| 5.56 AP | 31 | 75 | 120 |
| 5.56 HP | 52 | 20 | 65 |

| Armor | Slot | Protection |
| --- | --- | --- |
| Light helmet | Head | 35 |
| Heavy helmet | Head | 65 |
| Soft vest | Torso | 55 |
| Plate carrier | Torso | 70 |

These are fictional balance values, not real ballistics.

## Adding content

- **New round:** add it to `Data/Ammo.luau` and append its id to its caliber in `Data/Calibers.luau`.
- **New caliber/weapon:** add the caliber, its rounds, and a `Data/Weapons.luau` entry. The weapon logic is shared. (Swapping between several weapons, and a per-weapon viewmodel, are future work; the client currently builds one viewmodel for `Loadout.startingWeapon`.)
- **New armor:** add it to `Data/Armor.luau`. Give a target `Helmet` / `BodyArmor` attributes with the armor id (empty string = none).
- **New target:** put a Model in `Workspace.LastShiftRange.Targets` with `Health` / `MaxHealth` and armor attributes, plus BasePart children with a `Zone` attribute (`Head`, `Torso`, `Arms`, `Legs`).

Run `build.bat` afterwards. The data-integrity tests catch broken references (an ammo id missing from its caliber, a weapon pointing at an unknown caliber, and so on).

## Verification status

**Run during the 2026-11-19 restructure (Linux sandbox, no Luau or Rojo binaries available):**
- `python tools/check_luau.py`: block/bracket/string balance for all Luau files, and every `require` / `WaitForChild` path resolved against the Rojo tree. 0 problems. The checker was itself tested by planting five bugs (missing `end`, bad paths, unbalanced paren, unterminated string); it reported all five.
- The expected values of all 19 damage cases in `tests/run.luau` were cross-checked against an independent Python implementation of the rules. All matched.

**Not yet run on the restructured code:** `luau-compile`, the Luau test run, `rojo build`, and any Studio play test. `build.bat` runs the first three on Windows. Earlier Studio results in the git history / backup docs apply to the pre-restructure code only.

**Studio checklist (Milestone 001 success condition):**
1. F5: spawn in the lit range, first person, HUD shows `FMJ 30 / 30 (reserve 120)`. Check mouse look, WASD, Shift, C, right mouse; the rifle should line up with the dot in ADS.
2. Fire: the magazine drops by one per click; recoil, flash, tracer and sound play; holding the button fires once. Sprinting blocks fire.
3. Unarmored head with FMJ: `HEAD · 100 damage · LETHAL`, `No armor on Head`; the target fades and resets after ~2.5 s.
4. Light torso with FMJ: `REDUCED`, 14 damage. Heavy helmet with FMJ: `STOPPED`. Press 2, R, wait for reload: heavy helmet with AP → `PENETRATED · LETHAL`.
5. HP on the unarmored torso (52) vs the soft vest (`STOPPED`). Arms ≈23, legs ≈20 with FMJ. Lane 04 at range shows falloff below 100%.
6. Reserve: switching back to FMJ returns the unfired AP rounds to the AP reserve.
7. **Server & Clients** with 2 players: independent ammo, shared dummy health. Reset during a reload; the new character's ammo must not change when the old timer finishes.

## Known issues / limitations

- The gunshot uses Creator Store asset 213603013. If it's silent, the asset isn't permitted in your place; set `sound.id` in `Data/Weapons.luau` to a sound you own.
- Crouch lowers only the camera and shot origin. There's no crouch animation or smaller hitbox yet.
- Movement mode is client-requested (speed is server-set from it). Real movement-integrity checks belong to the multiplayer milestone.
- Players can't damage each other yet. `TargetService` handles range dummies only.
- One weapon. Weapon switching and per-weapon viewmodels come with the inventory work.
