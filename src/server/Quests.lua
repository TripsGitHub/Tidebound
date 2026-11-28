-- Tracks quest progress and pays out Shells.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local QuestList = require(Shared.Quests)
local Remotes = require(Shared.Remotes)
local Progression = require(script.Parent.Progression)

type QuestData = { progress: { [string]: number }, claimed: { [string]: boolean }, path: number, pathProgress: number }

local Quests = {}
local data: { [Player]: QuestData } = {}

function Quests.init(player: Player)
	data[player] = { progress = {}, claimed = {}, path = 1, pathProgress = 0 }
end

function Quests.removePlayer(player: Player)
	data[player] = nil
end

function Quests.sync(player: Player)
	local d = data[player]
	if d then
		Remotes.QuestState:FireClient(player, d.progress, d.claimed, { index = d.path, progress = d.pathProgress })
	end
end

-- Pays out a Tribe Path step: XP, Shells and any items, straight away.
local function payPath(player: Player, step)
	local Inventory = require(script.Parent.Inventory)
	local Items = require(Shared.Items)
	local got = {}
	for id, n in step.items or {} do
		if Items[id] then
			Inventory.add(player, id, n, true)
			Remotes.PickedUp:FireClient(player, id, n)
			table.insert(got, n .. " " .. Items[id].name)
		end
	end
	Progression.addShells(player, step.reward or 0)
	local text = "Path done: " .. step.title .. "!  +" .. (step.xp or 0) .. " XP, +" .. (step.reward or 0) .. " Shells"
	if #got > 0 then
		text ..= ", " .. table.concat(got, ", ")
	end
	Remotes.Notify:FireClient(player, text, "good")
	Progression.addXp(player, step.xp or 0)
end

-- kind is "gather", "craft", "build", "hunt" or "smelt".
function Quests.record(player: Player, kind: string, itemId: string?, amount: number)
	local d = data[player]
	if not d then
		return
	end
	local changed = false
	-- The Tribe Path: only the current step counts.
	local step = QuestList.PATH[d.path]
	if step and step.type == kind and (step.item == nil or step.item == itemId) then
		d.pathProgress = math.min(step.amount, d.pathProgress + amount)
		changed = true
		if d.pathProgress >= step.amount then
			d.path += 1
			d.pathProgress = 0
			payPath(player, step)
		end
	end
	for _, quest in ipairs(QuestList) do
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
	for _, quest in ipairs(QuestList) do
		if quest.id == questId then
			if d.claimed[questId] or (d.progress[questId] or 0) < quest.amount then
				return
			end
			d.claimed[questId] = true
			Progression.addShells(player, quest.reward)
			Remotes.Notify:FireClient(player, "+" .. quest.reward .. " Shells, +" .. (quest.xp or 0) .. " XP", "good")
			Progression.addXp(player, quest.xp or 0)
			Quests.sync(player)
			return
		end
	end
end

-- For saving: progress and which quests were claimed (so rewards can't be claimed twice).
function Quests.export(player: Player): QuestData?
	local d = data[player]
	return if d then { progress = table.clone(d.progress), claimed = table.clone(d.claimed), path = d.path, pathProgress = d.pathProgress } else nil
end

function Quests.load(player: Player, saved: any)
	local d = data[player]
	if not d or type(saved) ~= "table" then
		return
	end
	local known = {}
	for _, quest in ipairs(QuestList) do
		known[quest.id] = quest
	end
	if type(saved.progress) == "table" then
		for id, n in saved.progress do
			if known[id] and type(n) == "number" then
				d.progress[id] = math.clamp(n, 0, known[id].amount)
			end
		end
	end
	if type(saved.path) == "number" then
		d.path = math.clamp(math.floor(saved.path), 1, #QuestList.PATH + 1)
		local step = QuestList.PATH[d.path]
		d.pathProgress = if step and type(saved.pathProgress) == "number" then math.clamp(saved.pathProgress, 0, step.amount) else 0
	elseif (player:GetAttribute("Level") or 1) > 12 then
		-- Players from before the Tribe Path: skip the early steps they're past.
		d.path = 8
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
