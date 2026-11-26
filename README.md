# Tidebound

An original Roblox tribal survival game in the spirit of the old island survival games:
gather, level up, craft, build, and (later) fight rival clans across a chain of islands.

The full design brief lives in Claude Docs. This repo holds the game code.

## What's in Milestone 1 (test baseplate)

- **Gathering:** hit palms, boulders, bushes and slime pools to collect Wood, Stone, Fiber, Sticky Slime, Berries and Coconuts. Hold the mouse button to keep swinging.
- **Levels:** every hit gives XP, and new recipes unlock as you level up (levels 1 to 10).
- **Crafting:** press **C**. Wood Axe and Wood Pick, then walls, floors, campfires, Stone tools, doors and Stone Walls.
- **Hunger:** it drains over time, berries and coconuts refill it, and starving hurts.
- **Building:** hold a wall, floor, door or campfire to see a green preview, press **R** to rotate, and click to place. Anyone can break structures by hitting them. Only the builder can open their own door.
- **Death:** everything you carry (except your Rock) drops in a loot sack that anyone can pick up.
- **Quest Board and Trader:** finish quests for **Shells**, then spend them at the Trader.
- **Our own animations:** chop swings, hit shakes, flying chips, floating "+2 Wood" text, and bobbing slime. No uploaded animation assets.

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
Press **Play** (F5). You spawn on a sandy pad with a Rock in your hand. Walk to a tree and click it.

**Controls:** click to use your held item · **1-9** to pick a hotbar item · **C** to craft · **R** to rotate a build · walk up to the Quest Board, Trader, doors and sacks and press **E**.

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
