-- Tracks quest progress and pays out Shells.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local QuestList = require(Shared.Quests)
local Remotes = require(Shared.Remotes)
local Progression = require(script.Parent.Progression)

type QuestData = { progress: { [string]: number }, claimed: { [string]: boolean } }

local Quests = {}
local data: { [Player]: QuestData } = {}

function Quests.init(player: Player)
	data[player] = { progress = {}, claimed = {} }
end

function Quests.removePlayer(player: Player)
	data[player] = nil
end

function Quests.sync(player: Player)
	local d = data[player]
	if d then
		Remotes.QuestState:FireClient(player, d.progress, d.claimed)
	end
end

-- Call when something quest-worthy happens.
-- kind is "gather", "craft" or "build"; itemId can be nil for "build".
function Quests.record(player: Player, kind: string, itemId: string?, amount: number)
	local d = data[player]
	if not d then
		return
	end
	local changed = false
	for _, quest in QuestList do
		if quest.type == kind and (quest.item == nil or quest.item == itemId) and not d.claimed[quest.id] then
			local current = d.progress[quest.id] or 0
			if current < quest.amount then
				d.progress[quest.id] = math.min(quest.amount, current + amount)
				changed = true
				if d.progress[quest.id] >= quest.amount then
					Remotes.Notify:FireClient(player, "Quest complete: " .. quest.title .. ". Claim it at the Quest Board!")
				end
			end
		end
	end
	if changed then
		Quests.sync(player)
	end
end

function Quests.claim(player: Player, questId: unknown)
	local d = data[player]
	if not d or type(questId) ~= "string" then
		return
	end
	for _, quest in QuestList do
		if quest.id == questId then
			if d.claimed[questId] or (d.progress[questId] or 0) < quest.amount then
				return
			end
			d.claimed[questId] = true
			Progression.addShells(player, quest.reward)
			Remotes.Notify:FireClient(player, "+" .. quest.reward .. " Shells")
			Quests.sync(player)
			return
		end
	end
end

return Quests
