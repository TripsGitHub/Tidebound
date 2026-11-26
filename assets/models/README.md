# Models

Low-poly models for Tidebound, generated with Blender's Python API (`blender/`).
Sizes are in studs, scaled against a 5.5-stud Roblox player. Each model is split
into one object per colour (e.g. `Trunk`, `Leaves1`) so the game can colour and tint them.

## Importing into Studio
1. Avatar tab > Import 3D, pick the `.obj`.
2. Keep the scale at 1 (the files are already in studs).
3. Note the asset id of each imported mesh; the game code will reference them by id.

## Rebuilding
`pip install bpy`, then `python3 blender/set1.py` (trees, rocks, club) or
`python3 blender/set2.py world|items` (boar, building pieces, campfire, slime pool, dropped items).
