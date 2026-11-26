# Tidebound

An original Roblox tribal survival game in the spirit of the old island survival games:
gather, level up, craft, build, and (later) fight rival clans across a chain of islands.

The full design brief lives in Claude Docs. This repo holds the game code.

## What's in Milestone 1 (survival-feel rework)

- **A real island:** Smooth Terrain beaches, grass hills, rock cliffs, a snowy peak, a small islet to swim to, and a day/night cycle (12 minutes).
- **Gathering you can see:** hits knock Small Logs, Sticks, Leaves and Small Rocks onto the ground. Trees tip over and break into logs. Walk up and press **F** (hold it to grab everything nearby).
- **Bag space:** you can carry 30 items until you craft a Leather Bag (80). When it's full you'll see "Bag too full!".
- **Hover info:** point at anything to see its name, its health and what you can do with it.
- **Hunting and cooking:** boars wander the island. Hit one and it runs, then turns and fights back. They drop Raw Meat and Leather. Cook meat at a Campfire (press **E** at the fire).
- **Gear:** Wooden Club, Wooden Harvester, then Stone versions. Wood armour (helmet, body, legs, boots) shows on your character and cuts damage.
- **Building:** Wood Base and Stone Base floors with log and boulder borders, palisade Wood Walls, Stone Walls, doors and campfires. Placement shows a green or red outline. Anyone can break structures.
- **Levels:** recipes unlock as you level up (to level 20).
- **Death:** you drop a loot sack with everything but your Rock and the bag you're wearing.
- **Quest Board and Trader:** quests pay Shells, and you spend them at the Trader.

## Setting up (first time, about 15 minutes)

You only do this once. After that, it's just steps 6 and 7.

### 1. Get the code onto your computer
1. Install **GitHub Desktop** from https://desktop.github.com and sign in with your GitHub account.
2. Click **File > Clone repository**, pick **TripsGitHub/Tidebound**, and click **Clone**.
   Remember the folder it saves to (usually `Documents/GitHub/Tidebound`).

### 2. Install VS Code and the Rojo extension
1. Install **Visual Studio Code** from https://code.visualstudio.com.
2. Open it, click **File > Open Folder...**, and pick the `Tidebound` folder from step 1.
3. Click the **Extensions** icon on the left (four little squares), search for **Rojo**, and install the one by **evaera**.
4. If VS Code asks whether you trust the folder's authors, click **Yes**.

### 3. Install Rojo and the Studio plugin
1. In VS Code press **Ctrl+Shift+P** (Mac: **Cmd+Shift+P**), type **Rojo: Open menu**, and press Enter.
2. If it offers to install **Rojo** or **Rokit**, accept. It reads `rokit.toml` and installs the right version.
3. In the same menu, click **Install Roblox Studio plugin**.
4. Restart Roblox Studio if it was open.

### 4. Start Rojo
1. Open the Rojo menu again (**Ctrl+Shift+P > Rojo: Open menu**) and click **default.project.json**.
2. It says it's serving on port 34872. Leave VS Code open.

### 5. Connect Roblox Studio
1. In Roblox Studio, create a new **Baseplate** place.
2. Go to the **Plugins** tab, click **Rojo**, then click **Connect**.
3. The game's scripts appear under ServerScriptService, ReplicatedStorage and StarterPlayer.
4. Save the place (**File > Save to File**) somewhere outside the Tidebound folder.

### 6. Play
Press **Play** (F5). You wash up on the south beach with a Rock. Hit a tree, press F to pick up what falls, then press C to craft a Wooden Harvester.

**Controls:**
- **Click** (hold to keep swinging): harvest, attack, or place a build
- **1-8:** hold a hotbar item
- **C:** inventory and crafting
- **F** (hold for more): pick up items
- **E:** eat food on the ground, or use the Campfire, doors, Quest Board, Trader and sacks
- **R:** rotate a build
- **Esc:** close menus

To test with more than one player, go to the **Test** tab, set **Clients** to 2, and click **Start**.

### 7. Getting updates
When new code is pushed, open GitHub Desktop and click **Fetch origin**, then **Pull origin**.
If Rojo is connected, Studio updates by itself.

> Don't edit the scripts inside Studio. Rojo overwrites them from the files.
> Tell Claude what you want changed instead, or edit the files in VS Code.

## Where things live

| Folder | What it is |
|---|---|
| `src/shared` | Data both sides read: items, recipes, nodes, quests, shop, tuning numbers (`Config.lua`) |
| `src/server` | Game rules that run on the server (so exploiters can't fake them) |
| `src/client` | UI, input, build preview and animations |

Want to tweak balance? Most numbers are in `src/shared/Config.lua`, `Items.lua`, `Recipes.lua` and `Nodes.lua`.

## Optional: animations and sounds

The game ships with a built-in swing made in code. For a real keyframed swing:
1. In Studio, open **Avatar > Animation Editor**, select a rig, and animate an overhead chop.
2. Click **...** > **Publish to Roblox** and copy the id.
3. Paste it into `Config.Animations.Swing` in `src/shared/Config.lua`, as `"rbxassetid://123..."`.

Sounds work the same way: put Creator Store sound ids in `Config.Sounds`.
