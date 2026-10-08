# Halcyon Research Station - Site 9 (Roblox facility builder)

A from-scratch, procedurally built research facility for Roblox. `tools/FacilityBuilder.luau` is a single
Luau script that builds the whole map (architecture, props, lights, signs, particles, gameplay markers) into
`Workspace.Facility`. Rebuilding is safe: it deletes the previous `Facility` first.

## Install (pick one)

**A. ModuleScript (recommended, short command)**
1. Open an empty place in Studio (Edit mode).
2. In ServerStorage insert a `ModuleScript`, name it `FacilityBuilder`, replace its contents with `tools/FacilityBuilder.luau`.
3. View > Command Bar, run: `require(game.ServerStorage.FacilityBuilder)`

**B. Paste into the Command Bar**: paste the whole file, press Enter.

It prints `[Facility] built: ... parts, ... lights, ... chests`. Press Play: you spawn in Reception.
To drop it into an existing place, build it in an empty place, select `Workspace.Facility`, right-click > *Save to File*
(.rbxm), then *Insert from File* in your game. Use `CFG.ORIGIN` to shift it before saving.

> The builder deletes `Workspace.Baseplate` (its top face would z-fight with the floor). Set `CFG.REMOVE_BASEPLATE = false` to keep it.
> Not scriptable at runtime, so set it by hand: **Workspace.StreamingEnabled = true** is recommended for the size.

## Layout (north is -Z; Reception is the start)

```
Reception (hero atrium) -> Security checkpoint -> Main Corridor A (spine)
   |- west: Research Lab (hero, glass containment cell) -- door to Storage B
   |- east: Medical / Recovery Ward                    -- door to Maintenance
   |- west: Storage B (tall warehouse, overhead crane)
   |- east: Maintenance / Power (reactor landmark, catwalk) -> Service Hallway (optional route) -> Containment
   '- north: Decontamination airlock -> Restricted Containment Area (hero, breached chamber) -> Evacuation Lift (extraction)
```

Hierarchy of spaces: 50-stud atrium, 10-stud main corridor, 6-stud service hallway, tight decon airlock, tall
warehouse/containment halls. Windows connect corridor <-> lab/ward. Different floors, ceilings, wall finishes and light colour per area.

## Gameplay markers (all under `Workspace.Facility.GameplayMarkers`)

Tag (CollectionService) | What
--- | ---
`PlayerSpawn` | 4 `SpawnLocation`s in Reception
`ChestSpawn` | 10 chest models. Attributes: `Tier` (Common/Uncommon/Rare/Legendary), `ChestId`. Placeholder visuals - swap for your own and keep the tag/attributes
`Extraction` | Part in front of the evac lift (`Name` attribute)
`EnemySpawn` | `Type`, `Zone` attributes
`NPCSpawn` | `Zone` attribute
`PatrolPoint` | `Route`, `Index` attributes (6 routes)
`KeycardReader` | on the blast doors, `DoorId` attribute (doors are open geometry: lock them with your own logic)
`Camera` | CCTV cameras
`AmbientZone` | set the `SoundId` attribute to your audio asset and a client script loops it

## Atmosphere

`FacilityAmbience` (LocalScript, installed in StarterPlayerScripts) drives light flicker (`FlickerLight`), pulsing
emergency beacons (`PulseLight`), spinning fans (`Fan`), spark bursts (`SparkSource`) and ambient audio zones.
Global lighting (Future technology, Atmosphere, ColorCorrection, Bloom) is set at the end of the builder.
Colour language: yellow = hazard, red = emergency/restricted, green = safe/authorized, cyan/blue = research.

## Tuning (`CFG` at the top of the file)

`LIGHT_SCALE`, `LIGHT_DENSITY` (0.6 for mobile-heavy games), `DETAIL` (clutter density), `ORIGIN`, `FLICKER`, `SEED`.
Stats at defaults: ~3.4k anchored parts, ~90 lights (no shadows except what Future lighting adds), 0 unions, 0 meshes.

## Modular source + tests

Source is in `src/*.luau` (core -> fx -> props -> arch -> rooms -> gameplay -> finish). `build.sh` concatenates it into
`../FacilityBuilder.luau`. Props and wall/room builders are reusable (`P.crate`, `P.shelf`, `P.labTable`, `wallRun`, `newRoom`, ...).

`test/` runs the builder headlessly against a mock of the Roblox API ([Luau CLI](https://github.com/luau-lang/luau/releases)):

```
LUAU=/path/to/luau test/run.sh analyze.luau      # sizes + flood-fill walkability (doors, spawns, chests, extraction, patrols)
LUAU=... test/run.sh dump.luau > scene.txt       # then: python3 test/render.py scene.txt out.png "x,y,z" "tx,ty,tz"
```

`preview/` holds a walkability floor plan and rough software renders. They are **not Roblox renders** (no shadows, PBR, text or
real lighting); they only check composition. The script has not been run inside Roblox Studio.
