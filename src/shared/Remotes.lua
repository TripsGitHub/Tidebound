-- The messages the client and server send each other.
-- The server creates them; the client waits for them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	-- server -> client
	"Inventory", -- (items, equippedId)
	"Notify", -- (text)
	"HitFeedback", -- (model, text)
	"QuestState", -- (progress, claimed)
	"OpenPanel", -- (panelName) "quests" or "shop"
	"Swing", -- (character) play a swing on every client
	-- client -> server
	"Hit", -- (targetModel)
	"Equip", -- (itemId or nil)
	"Craft", -- (recipeId)
	"Eat", -- (itemId)
	"Place", -- (itemId, position, rotation)
	"ClaimQuest", -- (questId)
	"Buy", -- (shopEntryId)
}

local folder: Folder
if RunService:IsServer() then
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
