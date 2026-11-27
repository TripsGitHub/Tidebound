-- Saving: each player's bag, worn armour, held item, level, XP, Shells and quests are
-- kept in a DataStore between visits.
--
--   * Loads when the player joins, before they can do anything.
--   * Saves every few minutes, when they leave, and when the server shuts down.
--   * Retries with a growing wait when Roblox's save service is busy or down.
--   * A session lock stops two servers writing the same player at once (for example
--     when someone rejoins straight into a new server before the old one has saved).
--   * If the data can't be loaded, that session is NOT saved, so a hiccup can never
--     wipe someone's progress. The player is told saving is off for this visit.
--
-- In Studio, saving only works when "Enable Studio Access to API Services" is turned on
-- (Game Settings > Security). Without it you play normally and nothing is saved.
-- Quest progress and claimed rewards are saved too, so rewards can't be claimed twice.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Inventory = require(script.Parent.Inventory)
local Progression = require(script.Parent.Progression)
local Quests = require(script.Parent.Quests)

local Save = {}

local STORE_NAME = "TideboundPlayers_v1"
local VERSION = 1
local AUTOSAVE_SECONDS = 120
local LOCK_STALE_SECONDS = 300 -- a lock older than this belongs to a server that died
local RETRIES = 4

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[Save] DataStore unavailable, progress won't be saved: " .. tostring(result))
	end
end

-- Players whose data loaded correctly this session. Only they are ever saved.
local loaded: { [Player]: boolean } = {}
local saving: { [Player]: boolean } = {}

local function key(userId: number): string
	return "player_" .. userId
end

-- Runs fn, retrying with 1s, 2s, 4s... waits. Returns ok, result.
local function retry(label: string, fn: () -> any): (boolean, any)
	local wait = 1
	local lastErr
	for attempt = 1, RETRIES do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		local msg = tostring(result)
		if string.find(msg, "StudioAccessToApisNotAllowed") or string.find(msg, "publish") then
			-- Studio without API access (or an unpublished place): retrying won't help.
			warn("[Save] Saving is off: turn on Game Settings > Security > Enable Studio Access to API Services")
			store = nil
			return false, result
		end
		warn(string.format("[Save] %s failed (try %d/%d): %s", label, attempt, RETRIES, msg))
		if attempt < RETRIES then
			task.wait(wait)
			wait *= 2
		end
	end
	return false, lastErr
end

local function snapshot(player: Player): { [string]: any }?
	local inv = Inventory.export(player)
	if not inv then
		return nil
	end
	local prog = Progression.export(player)
	return {
		v = VERSION,
		items = inv.items,
		armour = inv.armour,
		equipped = inv.equipped,
		level = prog.level,
		xp = prog.xp,
		shells = prog.shells,
		quests = Quests.export(player),
	}
end

-- Loads the player's save into Inventory and Progression (call after their init).
-- Yields. Returns true if the player is now saving normally.
function Save.load(player: Player): boolean
	if not store then
		Remotes.Notify:FireClient(player, "Saving is off on this server", "warn")
		return false
	end
	local jobId = if game.JobId ~= "" then game.JobId else "studio"
	local data
	-- Take the lock. If another live server holds it, give it a few seconds to finish
	-- its save, then take over anyway: the newest server always wins.
	for wait = 1, 4 do
		if not store then
			Remotes.Notify:FireClient(player, "Saving is off on this server", "warn")
			return false
		end
		local blocked = false
		local ok, result = retry("load " .. player.UserId, function()
			return (store :: DataStore):UpdateAsync(key(player.UserId), function(old)
				old = if type(old) == "table" then old else {}
				local lock = old.lock
				if
					wait < 4
					and type(lock) == "table"
					and lock.job ~= jobId
					and type(lock.time) == "number"
					and os.time() - lock.time < LOCK_STALE_SECONDS
				then
					blocked = true
					return nil -- leave it alone; try again shortly
				end
				old.lock = { job = jobId, time = os.time() }
				return old
			end)
		end)
		if not ok then
			Remotes.Notify:FireClient(player, "Couldn't load your progress - saving is off this visit", "warn")
			return false
		end
		if not blocked then
			data = result
			break
		end
		task.wait(2 * wait)
	end
	if not player.Parent then
		return false
	end
	if type(data) == "table" and data.v then
		Inventory.load(player, data)
		Progression.load(player, data)
		Quests.load(player, data.quests)
	end
	loaded[player] = true
	return true
end

-- Writes the player's current state. `release` also gives up the session lock (when
-- they leave). Yields; safe to call while another save for them is running.
function Save.save(player: Player, release: boolean?, state: { [string]: any }?): boolean
	if not store or not loaded[player] then
		return false
	end
	local data = state or snapshot(player)
	if not data then
		return false
	end
	while saving[player] do
		task.wait(0.2)
	end
	saving[player] = true
	local jobId = if game.JobId ~= "" then game.JobId else "studio"
	local lostLock = false
	local ok = retry("save " .. player.UserId, function()
		return (store :: DataStore):UpdateAsync(key(player.UserId), function(old)
			local lock = type(old) == "table" and old.lock
			if type(lock) == "table" and lock.job ~= jobId then
				lostLock = true -- a newer server has this player now; don't overwrite it
				return nil
			end
			data.lock = if release then nil else { job = jobId, time = os.time() }
			return data
		end)
	end)
	saving[player] = nil
	if lostLock then
		loaded[player] = nil
		warn("[Save] " .. player.Name .. " is active on another server; stopped saving here")
	end
	return ok and not lostLock
end

-- Call from PlayerRemoving BEFORE the player's inventory is cleared. Takes a snapshot
-- right away, then saves it in the background.
function Save.leave(player: Player)
	if not loaded[player] then
		return
	end
	local state = snapshot(player)
	task.spawn(function()
		Save.save(player, true, state)
		loaded[player] = nil
	end)
end

function Save.start()
	-- Autosave, spread out so every player isn't saved in the same second.
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			local list = Players:GetPlayers()
			for _, player in list do
				if loaded[player] and player.Parent then
					task.spawn(Save.save, player)
					task.wait(math.min(2, AUTOSAVE_SECONDS / math.max(#list, 1) / 2))
				end
			end
		end
	end)

	-- Server shutting down: save everyone still here (Roblox allows about 30 seconds).
	game:BindToClose(function()
		local pending = 0
		for _, player in Players:GetPlayers() do
			if loaded[player] then
				pending += 1
				task.spawn(function()
					Save.save(player, true)
					pending -= 1
				end)
			end
		end
		local started = os.clock()
		while (pending > 0 or next(saving) ~= nil) and os.clock() - started < 25 do
			task.wait(0.2)
		end
		if RunService:IsStudio() then
			task.wait(0.5)
		end
	end)
end

return Save
