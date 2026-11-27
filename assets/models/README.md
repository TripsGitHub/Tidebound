# Models

Low-poly models for Tidebound, generated with Blender's Python API (`blender/`).
Sizes are in studs, scaled against a 5.5-stud Roblox player. Each model is split
into one object per colour (e.g. `Trunk`, `Leaves1`) so the game can colour and tint them.

## Importing into Studio
1. Home tab > Import, pick `tidebound_models.obj`. Each part comes in as its own MeshPart
   named `<model>__<Part>` (the OBJ has one group per part).
2. Scale Unit: Stud. Tick Anchored.
3. Rename the imported model to `Models` and move it to ReplicatedStorage (next to Shared,
   not inside it, since Rojo manages Shared). Save the place.

The game builds every model from those parts (`src/shared/Meshes.lua`) and colours them
from `src/shared/MeshColors.lua`. If the folder is missing it falls back to block models.

After changing a model: re-run `blender/combine.py`, then `python3 assets/models/blender/colors.py`
from the repo root, and re-import.

## Rebuilding
`pip install bpy`, then `python3 blender/set1.py` (trees, rocks, club) or
`python3 blender/set2.py world|items` (boar, building pieces, campfire, slime pool, dropped items),
`python3 blender/set3.py` (armour, swords, harvesters and bags; `PREVIEW=1` also renders the sheets
in `docs/previews/armour/`).

## Armour and tiered tools (set 3)
Armour, swords and harvesters come in four styles: wood, stone, metal and crystal. All ten tiers
(`src/shared/Tiers.lua`) reuse their style's meshes, and the game recolours each part by its name:
`Plate`, `Trim`, `Accent`, `Strap` (and `Handle`, which stays wood).

These models have an invisible `Bounds` part centred on their origin. `Meshes.build` measures
from it and leaves it out:
- Armour pieces are centred on the body part they're worn on, and modelled for the R15 sizes in
  `src/shared/ArmourModels.lua`, so they stretch to fit any R15 avatar.
- Swords and harvesters have the grip at the origin. Bags are centred.
