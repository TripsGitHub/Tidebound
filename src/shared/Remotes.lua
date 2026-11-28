-- The messages the client and server send each other.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	-- server -> client
	"Inventory", -- (items, equippedTool, armour, bagSize)
	"Notify", -- (text, style?) style: "warn" | "good" | nil
	"WorldEvent", -- (text) posted in everyone's chat as a server message
	"PickedUp", -- (itemId, amount) shows in the pickup feed
	"QuestState", -- (progress, claimed)
	"OpenPanel", -- (panelName) "quests" | "shop"
	"Swing", -- (character)
	"HitFeedback", -- (target)
	"Marker", -- (position, amount, kind, itemId?) kind: "hit" | "harvest" damage you dealt
	"WorldFx", -- (kind, ...) big event effects: "quake", "sky", "bomb", "meteor", "impact"
	"ChestState", -- (chestModel, contents | nil) open/refresh the chest panel; nil closes it
	"Arrow", -- (character, from, to, hit) an arrow flying from a bow
	"RaftState", -- (raftModel | nil) you're sitting on a raft (for the steer hint)
	"AdminState", -- (state) admin menu: islands, players, mobs (admins only)
	"CrateOpened", -- (crateId, { {itemId, amount} }) plays the crate-opening screen
	-- client -> server
	"Hit", -- (target)
	"Equip", -- (itemId or nil) hold a tool/food/placeable
	"Wear", -- (itemId) put on / take off armour
	"Craft", -- (recipeId)
	"Eat", -- (itemId)
	"Drop", -- (itemId)
	"PickUp", -- (dropModel)
	"EatDrop", -- (dropModel)
	"Place", -- (itemId, position, rotation)
	"CancelBuild", -- () put the buildable away; refunds it if it was just crafted
	"ClaimQuest", -- (questId)
	"Buy", -- (shopEntryId)
	"ChestMove", -- (chestModel, itemId, "put" | "take") move a whole stack
	"Launch", -- (itemId) put a raft in the water in front of you
	"AdminRun", -- (commandText) a command from the admin menu, e.g. "tp Tide Isle"
	"ToggleLock", -- (structureModel) the owner locks / unlocks their build
	"HotbarLayout", -- (text) your pinned hotbar slots, "id,id,,id", saved with your data
}

local folder: Folder
if RunService:IsServer() or not RunService:IsRunning() then -- (edit mode: the map bake)
	local existing = ReplicatedStorage:FindFirstChild("Remotes")
	if existing then
		folder = existing :: Folder
	else
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in NAMES do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

local Remotes = {}
for _, name in NAMES do
	Remotes[name] = folder:WaitForChild(name) :: RemoteEvent
end

return Remotes
