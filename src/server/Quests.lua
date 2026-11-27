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

-- kind is "gather", "craft", "build" or "hunt".
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
					Remotes.Notify:FireClient(player, "Quest done: " .. quest.title .. ". Claim it at the Quest Board", "good")
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
			Remotes.Notify:FireClient(player, "+" .. quest.reward .. " Shells", "good")
			Quests.sync(player)
			return
		end
	end
end

-- For saving: progress and which quests were claimed (so rewards can't be claimed twice).
function Quests.export(player: Player): QuestData?
	local d = data[player]
	return if d then { progress = table.clone(d.progress), claimed = table.clone(d.claimed) } else nil
end

function Quests.load(player: Player, saved: any)
	local d = data[player]
	if not d or type(saved) ~= "table" then
		return
	end
	local known = {}
	for _, quest in QuestList do
		known[quest.id] = quest
	end
	if type(saved.progress) == "table" then
		for id, n in saved.progress do
			if known[id] and type(n) == "number" then
				d.progress[id] = math.clamp(n, 0, known[id].amount)
			end
		end
	end
	if type(saved.claimed) == "table" then
		for id, v in saved.claimed do
			if known[id] and v == true then
				d.claimed[id] = true
			end
		end
	end
end

return Quests
