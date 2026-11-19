# LAST SHIFT

An original Roblox PvPvE tactical extraction horror shooter. **Milestone 001** is a desktop shooting range: first person with a 5.56mm prototype rifle, four target lanes, and a debug HUD for comparing ammunition, hit zones and armor.

## Play it on Windows

1. **Build** the place: double-click `build.bat` in this folder. It checks syntax, runs the data/damage tests, and writes `LastShift.rbxl`. It needs `tools-local\rojo\rojo.exe` (and optionally `tools-local\luau\`); see *Rebuild from source* below.
2. **Open** Roblox Studio, choose **File → Open from File**, and open `LastShift.rbxl`. The range is visible in the editor.
3. Press **F5** (Play). Wait for the HUD at the bottom-left to show `FMJ 30 / 30`. Press **Shift+F5** to stop.

> `LastShift.rbxl` is a build output. After pulling or editing source, run `build.bat` again before opening it, or Studio will show the old version.

| Input | Action |
| --- | --- |
| WASD + mouse | Move and look |
| Left mouse | Fire one round per click (semi-auto) |
| Hold right mouse | Aim down sights |
| Hold left Shift | Sprint (can't fire) |
| C | Toggle crouch |
| 1 / 2 / 3 | Select FMJ / AP / HP for the next magazine |
| R | Reload, loading the selected ammo type |

**Lanes:** `01 UNARMORED`, `02 LIGHT ARMOR` (light helmet + soft vest), `03 HEAVY ARMOR` (heavy helmet + plate carrier), `04 DISTANCE` (unarmored, far). Targets reset 2.5 s after going down.

**Try this:** shoot the heavy helmet with FMJ (*STOPPED*), press **2** then **R**, and shoot it again with AP (*PENETRATED · LETHAL*). The HUD shows the zone, damage, armor protection vs ammo penetration, target HP, distance and falloff for every shot.

## Rebuild from source

The project uses [Rojo](https://rojo.space) to turn the `src` folder into a Roblox place.

1. Download `rojo-7.7.0-windows-x86_64.zip` from the [Rojo 7.7.0 release](https://github.com/rojo-rbx/rojo/releases/tag/v7.7.0) and extract `rojo.exe` into `tools-local\rojo\`.
2. Optional, for syntax checks and tests: download `luau-windows.zip` from the [Luau releases](https://github.com/luau-lang/luau/releases) and extract it into `tools-local\luau\`.
3. Run `build.bat`.

**Live sync (optional):** run `.\tools-local\rojo\rojo.exe plugin install` once, restart Studio, then run `.\tools-local\rojo\rojo.exe serve` in this folder and click **Connect** in Studio's Rojo plugin. Saved source changes then appear in Studio immediately.

See [DEVELOPMENT.md](DEVELOPMENT.md) for architecture, how to add ammo/weapons/armor, and verification status. See [VISION.md](VISION.md) for the long-term design.
