-- Player-vs-player rules, the Island Tribes way.
--  * Hitting a player, or being hit by one, tags you "in combat" for
--    Config.CombatTagSeconds (the InCombat attribute; everyone sees crossed swords
--    over your head and you get a warning over the hotbar).
--  * Leaving while tagged drops your held tool and armour where you stood (Main
--    calls Death.dropGear when Combat.inCombat says so).
--  * Tribe mates can't hurt each other.
--  * Passive Mode (the Passive attribute): no PvP either way, and passive players
--    only see other passive players (client side, see client/Combat.lua). It can't
--    be switched while in combat, and only once every Config.PassiveCooldown s.
--  * Every death goes in the kill feed: "Killer(lvl) [weapon] Victim(lvl)". A
--    player killed by another player drops their Soul.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Combat = {}

local tagUntil: { [Player]: number } = {}
local passiveAt: { [Player]: number } = {}
-- Who last hurt a player, and with what: { by = Player | string (mob name), item, at }.
local lastHit: { [Player]: { by: any, item: string?, at: number } } = {}

local function setTag(player: Player)
	local untilT = os.clock() + Config.CombatTagSeconds
	tagUntil[player] = untilT
	player:SetAttribute("InCombat", true)
	player:SetAttribute("CombatUntil", workspace:GetServerTimeNow() + Config.CombatTagSeconds)
	task.delay(Config.CombatTagSeconds + 0.05, function()
		if tagUntil[player] == untilT and player.Parent then
			tagUntil[player] = nil
			player:SetAttribute("InCombat", nil)
			player:SetAttribute("CombatUntil", nil)
		end
	end)
end

function Combat.inCombat(player: Player): boolean
	return (tagUntil[player] or 0) > os.clock()
end

-- Can attacker hurt victim at all? Returns false and a reason to show the attacker.
function Combat.canHurt(attacker: Player, victim: Player): (boolean, string?)
	if attacker == victim then
		return false
	end
	if attacker:GetAttribute("Passive") then
		return false, "You're in Passive Mode: you can't fight players"
	end
	if victim:GetAttribute("Passive") then
		return false, "That player is in Passive Mode"
	end
	local tribe = attacker:GetAttribute("Tribe")
	if tribe ~= nil and tribe == victim:GetAttribute("Tribe") then
		return false, "You can't hurt your own tribe"
	end
	return true
end

-- A player hit another player: tag both and remember who did it.
function Combat.playerHit(attacker: Player, victim: Player, itemId: string?)
	setTag(attacker)
	setTag(victim)
	lastHit[victim] = { by = attacker, item = itemId, at = os.clock() }
end

-- A creature or boss hit a player (for the kill feed only; no combat tag).
function Combat.mobHit(victim: Player, mobName: string)
	local last = lastHit[victim]
	-- A player's recent hit still counts as the kill if a mob finishes you off.
	if last and typeof(last.by) == "Instance" and os.clock() - last.at < Config.CombatTagSeconds then
		return
	end
	lastHit[victim] = { by = mobName, at = os.clock() }
end

-- Called when a player dies. Posts the kill feed line, drops a Soul for a PvP kill,
-- and returns the player who killed them (if one did).
function Combat.onDied(victim: Player, at: Vector3?, spawnDrop: ((string, number, Vector3, Player) -> ())?): Player?
	local last = lastHit[victim]
	lastHit[victim] = nil
	tagUntil[victim] = nil
	victim:SetAttribute("InCombat", nil)
	victim:SetAttribute("CombatUntil", nil)
	local vLevel = victim:GetAttribute("Level") or 1
	if last and os.clock() - last.at < 20 then
		if typeof(last.by) == "Instance" and (last.by :: Player).Parent then
			local killer = last.by :: Player
			Remotes.KillFeed:FireAllClients(killer.DisplayName, killer:GetAttribute("Level") or 1, last.item, victim.DisplayName, vLevel)
			if at and spawnDrop then
				spawnDrop("soul", 1, at, killer)
			end
			return killer
		elseif type(last.by) == "string" then
			Remotes.KillFeed:FireAllClients(last.by, nil, nil, victim.DisplayName, vLevel)
			return nil
		end
	end
	Remotes.KillFeed:FireAllClients(nil, nil, nil, victim.DisplayName, vLevel)
	return nil
end

function Combat.setPassive(player: Player, on: unknown)
	if type(on) ~= "boolean" then
		return
	end
	if (player:GetAttribute("Passive") == true) == on then
		return
	end
	if Combat.inCombat(player) then
		Remotes.Notify:FireClient(player, "You can't change Passive Mode while in combat", "warn")
		return
	end
	local wait = (passiveAt[player] or -math.huge) + Config.PassiveCooldown - os.clock()
	if wait > 0 then
		Remotes.Notify:FireClient(player, "You can change Passive Mode again in " .. math.ceil(wait) .. "s", "warn")
		return
	end
	passiveAt[player] = os.clock()
	player:SetAttribute("Passive", if on then true else nil)
	Remotes.Notify:FireClient(player, if on then "Passive Mode on: no PvP, and you only see other passive players" else "Passive Mode off: you can fight other players", "good")
end

function Combat.removePlayer(player: Player)
	tagUntil[player] = nil
	passiveAt[player] = nil
	lastHit[player] = nil
end

function Combat.start()
	Remotes.SetPassive.OnServerEvent:Connect(Combat.setPassive)
end

return Combat
