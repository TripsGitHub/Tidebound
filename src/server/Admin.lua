-- Admin commands for testing. Type them in chat, starting with / (or ; on old chat).
-- Who can use them: everyone in a Studio playtest, the game's owner (or a group owner)
-- in a live server, and anyone whose UserId is in ADMINS below.
--
--   /cmds                      list the commands
--   /tp <island>               go to an island (first letters are enough: /tp ember)
--   /tp cave | deep | ember    the spawn island's cave mouth, its deep cavern, the tunnel under Ember
--   /tp route <n>              stop n along the cave route (/tp route to see how many there are)
--   /tp <player>               go to another player
--   /bring <player>            bring a player to you
--   /where                     print where you're standing
--   /speed [n]  /jump [n]      walk speed (16 normal) and jump power (50 normal)
--   /give <item> [n]           add items to your bag, ignoring bag space (/give list to see ids)
--   /level <n>  /shells <n>    set your level or Shells
--   /heal                      full health and hunger
--   /day  /night  /time <h>    change the time of day (0-24)
--   /erupt  /meteor            start the Ember eruption or a meteor shower now
--   /god                       can't be hurt (toggle)
--   /invis                     invisible to everyone else (toggle)
--   /kill <player>  /kick <player>  /respawn [player]
--   /mob <kind> [n]            spawn a herd of animals next to you (/mob list)
--   /cleardrops                remove every loose drop on the ground
-- Admins also get the admin menu (the Admin button, or F4): every island, every
-- command, free cam, spectating and a live list of players (client/AdminMenu.lua).
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Remotes = require(Shared.Remotes)
local Systems = script.Parent
local Events = require(Systems.Events)
local Inventory = require(Systems.Inventory)
local Survival = require(Systems.Survival)
local WorldBuilder = require(Systems.WorldBuilder)
local AnimalDefs = require(Shared.Animals)

-- Extra admins for live servers, by UserId (find yours in your profile's URL).
local ADMINS: { number } = {}

local Admin = {}

local function isAdmin(player: Player): boolean
	if RunService:IsStudio() or table.find(ADMINS, player.UserId) then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	local ok, rank = pcall(player.GetRankInGroup, player, game.CreatorId)
	return ok and rank >= 255
end

local function tell(player: Player, text: string, kind: string?)
	Remotes.Notify:FireClient(player, text, kind or "good")
	print("[Admin] " .. player.Name .. ": " .. text)
end

local function root(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function humanoid(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function moveTo(player: Player, position: Vector3)
	local character = player.Character
	if character then
		character:PivotTo(CFrame.new(position + Vector3.new(0, 4, 0)))
	end
end

-- Dry land near an island's middle (not sea, not lava), searching outwards.
local GROUND_PARAMS = RaycastParams.new()
GROUND_PARAMS.FilterType = Enum.RaycastFilterType.Include
GROUND_PARAMS.FilterDescendantsInstances = { workspace.Terrain }
GROUND_PARAMS.IgnoreWater = false
local BAD_GROUND = { [Enum.Material.Water] = true, [Enum.Material.CrackedLava] = true }

local function landOn(isl: { x: number, z: number, r: number }): Vector3?
	for ring = 0, 8 do
		local radius = isl.r * ring / 10
		local steps = if ring == 0 then 1 else 12
		for i = 1, steps do
			local a = (i / steps) * math.pi * 2
			local x, z = isl.x + math.cos(a) * radius, isl.z + math.sin(a) * radius
			local hit = workspace:Raycast(Vector3.new(x, 1000, z), Vector3.new(0, -1200, 0), GROUND_PARAMS)
			if hit and not BAD_GROUND[hit.Material] and hit.Position.Y > 2 then
				return hit.Position
			end
		end
	end
	return nil
end

local function caveRoute(): { Vector3 }
	local route = {}
	local text = workspace:GetAttribute("CaveRoute")
	if type(text) == "string" then
		for x, y, z in text:gmatch("(-?[%d.]+),(-?[%d.]+),(-?[%d.]+)") do
			table.insert(route, Vector3.new(tonumber(x), tonumber(y), tonumber(z)))
		end
	end
	return route
end

local function findPlayer(name: string): Player?
	name = name:lower()
	for _, p in Players:GetPlayers() do
		if p.Name:lower():sub(1, #name) == name or p.DisplayName:lower():sub(1, #name) == name then
			return p
		end
	end
	return nil
end

local function findIsland(name: string)
	name = name:lower()
	for _, isl in WorldBuilder.Islands do
		if isl.name:lower() == name then
			return isl
		end
	end
	for _, isl in WorldBuilder.Islands do
		local full = isl.name:lower()
		if full:sub(1, #name) == name or full:gsub("%s+", ""):sub(1, #name) == name then
			return isl
		end
	end
	return nil
end

local function findItem(name: string): string?
	local key = name:lower():gsub("%s+", "_")
	if type(Items[key]) == "table" then
		return key
	end
	for id, item in Items do
		if type(item) == "table" and type(item.name) == "string" and item.name:lower():gsub("%s+", "_") == key then
			return id
		end
	end
	return nil
end

local function islandNames(): string
	local names = {}
	for _, isl in WorldBuilder.Islands do
		table.insert(names, isl.name)
	end
	return table.concat(names, ", ")
end

local commands: { [string]: (Player, { string }) -> () } = {}

commands.cmds = function(player)
	tell(player, "/tp /bring /where /speed /jump /give /level /shells /heal /day /night /time /erupt /meteor")
end

commands.tp = function(player, args)
	local what = table.concat(args, " "):lower()
	if what == "" then
		tell(player, "Where to? " .. islandNames() .. ", cave, deep, ember, route <n>, or a player", "warn")
		return
	end
	local route = caveRoute()
	if what == "cave" or what == "deep" or what == "ember" or args[1] == "route" then
		if #route == 0 then
			tell(player, "No cave route yet (it's made by the Studio cave check once the world is built)", "warn")
			return
		end
		local index = 1
		if what == "deep" then
			for i, p in route do
				if p.Y < route[index].Y then
					index = i
				end
			end
		elseif what == "ember" then
			index = #route
		elseif args[1] == "route" then
			local n = tonumber(args[2])
			if not n then
				tell(player, "The cave route has " .. #route .. " stops: /tp route 1 to " .. #route)
				return
			end
			index = math.clamp(math.floor(n), 1, #route)
		end
		moveTo(player, route[index])
		tell(player, ("Cave route stop %d of %d"):format(index, #route))
		return
	end
	local isl = findIsland(what)
	if isl then
		local spot = landOn(isl)
		if spot then
			moveTo(player, spot)
			tell(player, "Welcome to " .. isl.name)
		else
			tell(player, "Couldn't find dry land on " .. isl.name, "warn")
		end
		return
	end
	local other = findPlayer(what)
	local there = other and root(other)
	if there then
		moveTo(player, there.Position)
		tell(player, "Went to " .. other.DisplayName)
		return
	end
	tell(player, "No island or player called '" .. what .. "'. Islands: " .. islandNames(), "warn")
end

commands.bring = function(player, args)
	local other = findPlayer(args[1] or "")
	local here = root(player)
	if other and here then
		moveTo(other, here.Position + here.CFrame.LookVector * 5)
		tell(player, "Brought " .. other.DisplayName)
	else
		tell(player, "No player called '" .. tostring(args[1]) .. "'", "warn")
	end
end

commands.where = function(player)
	local here = root(player)
	if here then
		local p = here.Position
		tell(player, ("You're at %d, %d, %d"):format(math.round(p.X), math.round(p.Y), math.round(p.Z)))
	end
end

commands.speed = function(player, args)
	local h = humanoid(player)
	if h then
		h.WalkSpeed = math.clamp(tonumber(args[1]) or 16, 0, 500)
		tell(player, "Walk speed " .. h.WalkSpeed)
	end
end

commands.jump = function(player, args)
	local h = humanoid(player)
	if h then
		h.UseJumpPower = true
		h.JumpPower = math.clamp(tonumber(args[1]) or 50, 0, 1000)
		tell(player, "Jump power " .. h.JumpPower)
	end
end

commands.give = function(player, args)
	if args[1] == "list" or args[1] == nil then
		local ids = {}
		for id, item in Items do
			if type(item) == "table" and item.name then
				table.insert(ids, id)
			end
		end
		table.sort(ids)
		print("[Admin] Item ids: " .. table.concat(ids, ", "))
		tell(player, "Item ids are printed in the Output window (F9 in a live game)")
		return
	end
	local amount = 1
	local last = tonumber(args[#args])
	if last and #args > 1 then
		amount = math.clamp(math.floor(last), 1, 999)
		table.remove(args)
	end
	local itemId = findItem(table.concat(args, " "))
	if not itemId then
		tell(player, "No item called '" .. table.concat(args, " ") .. "'. Try /give list", "warn")
		return
	end
	Inventory.add(player, itemId, amount, true)
	tell(player, ("+%d %s"):format(amount, Items[itemId].name))
end

commands.level = function(player, args)
	local n = tonumber(args[1])
	if not n then
		tell(player, "Usage: /level <1-" .. Config.MaxLevel .. ">", "warn")
		return
	end
	local level = math.clamp(math.floor(n), 1, Config.MaxLevel)
	player:SetAttribute("Level", level)
	player:SetAttribute("XP", 0)
	tell(player, "Level " .. level)
end

commands.shells = function(player, args)
	local n = tonumber(args[1])
	if not n then
		tell(player, "Usage: /shells <amount>", "warn")
		return
	end
	player:SetAttribute("Shells", math.max(0, math.floor(n)))
	tell(player, "Shells " .. player:GetAttribute("Shells"))
end

commands.heal = function(player)
	local h = humanoid(player)
	if h then
		h.Health = h.MaxHealth
	end
	Survival.reset(player)
	tell(player, "Healed")
end

local function setTime(player: Player, hours: number)
	Lighting.ClockTime = hours % 24
	tell(player, ("Time is now %.1f"):format(Lighting.ClockTime))
end

commands.day = function(player)
	setTime(player, 12)
end

commands.night = function(player)
	setTime(player, 0)
end

commands.time = function(player, args)
	local n = tonumber(args[1])
	if n then
		setTime(player, n)
	else
		tell(player, "Usage: /time <0-24>", "warn")
	end
end

commands.erupt = function(player)
	tell(player, "Starting an eruption")
	task.spawn(Events.erupt)
end

commands.meteor = function(player)
	tell(player, "Starting a meteor shower")
	task.spawn(Events.meteorShower)
end

commands.god = function(player)
	local on = not player:GetAttribute("God")
	player:SetAttribute("God", on)
	local character = player.Character
	local ff = character and character:FindFirstChild("AdminShield")
	if on and character and not ff then
		local f = Instance.new("ForceField")
		f.Name = "AdminShield"
		f.Visible = false
		f.Parent = character
	elseif not on and ff then
		ff:Destroy()
	end
	tell(player, if on then "God mode on" else "God mode off")
end

commands.invis = function(player)
	local on = not player:GetAttribute("Invisible")
	player:SetAttribute("Invisible", on)
	local character = player.Character
	if character then
		for _, d in character:GetDescendants() do
			if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
				d.LocalTransparencyModifier = 0
				d.Transparency = if on then 1 else (d:GetAttribute("BaseTransparency") or 0)
			elseif d:IsA("Decal") then
				d.Transparency = if on then 1 else 0
			end
		end
	end
	tell(player, if on then "You're invisible" else "You're visible again")
end

commands.kill = function(player, args)
	local target = findPlayer(args[1] or "")
	local h = target and humanoid(target)
	if h then
		h.Health = 0
		tell(player, "Killed " .. target.Name)
	else
		tell(player, "Usage: /kill <player>", "warn")
	end
end

commands.kick = function(player, args)
	local target = findPlayer(args[1] or "")
	if target and target ~= player then
		target:Kick("Kicked by an admin")
		tell(player, "Kicked " .. target.Name)
	else
		tell(player, "Usage: /kick <player>", "warn")
	end
end

commands.respawn = function(player, args)
	local target = if args[1] then findPlayer(args[1]) else player
	if target then
		require(Systems.Avatar).load(target)
		tell(player, "Respawned " .. target.Name)
	end
end

commands.mob = function(player, args)
	local kind = args[1]
	local found
	for name in AnimalDefs do
		if kind and name:lower() == kind:lower() then
			found = name
		end
	end
	local r = root(player)
	if not found or not r then
		local names = {}
		for name in AnimalDefs do
			table.insert(names, name)
		end
		table.sort(names)
		tell(player, "Mobs: " .. table.concat(names, ", "), "warn")
		return
	end
	local n = math.clamp(tonumber(args[2]) or 1, 1, 10)
	require(Systems.Animals).spawnHerd(found, r.Position + r.CFrame.LookVector * 14, n)
	tell(player, ("Spawned %d %s"):format(n, found))
end

commands.cleardrops = function(player)
	local folder = workspace:FindFirstChild("Drops")
	local n = 0
	for _, d in if folder then folder:GetChildren() else {} do
		d:Destroy()
		n += 1
	end
	tell(player, ("Cleared %d drops"):format(n))
end

commands.tpxyz = function(player, args)
	local x, y, z = tonumber(args[1]), tonumber(args[2]), tonumber(args[3])
	if x and y and z then
		moveTo(player, Vector3.new(x, y, z))
	else
		tell(player, "Usage: /tpxyz <x> <y> <z>", "warn")
	end
end

-- Places worth jumping to, for the admin menu: boss gates and lairs, the Maw, cave
-- mouths, landmarks, camps, outposts, grottos and secret rooms.
local function places(): { any }
	local list = {}
	local function add(group: string, name: string, pos: Vector3)
		table.insert(list, { group = group, name = name, x = math.floor(pos.X), y = math.floor(pos.Y + 2), z = math.floor(pos.Z) })
	end
	local gates = workspace:FindFirstChild("BossGates")
	for _, g in if gates then gates:GetChildren() else {} do
		if g:IsA("Model") then
			local cf = g:GetPivot()
			add("Boss gates", (g.Name:gsub("^Gate_", "")) .. " gate", cf.Position - cf.LookVector * 10)
		end
	end
	local net = WorldBuilder.network
	for _, room in if net and net.bossRooms then net.bossRooms else {} do
		add("Boss lairs", tostring(room.boss) .. " lair", room.pos + Vector3.new(0, 4, 0))
	end
	if net and net.hub then
		add("Caves", "The Maw (heart)", net.hub.pos + Vector3.new(0, 6, 0))
	end
	for i, b in if net and net.barriers then net.barriers else {} do
		if not string.match(b.kind, "^gate_") then
			add("Caves", tostring(b.kind) .. " seal " .. i, b.pos - (b.dir or Vector3.zero) * 10)
		end
	end
	for i, e in if net and net.entrances then net.entrances else {} do
		add("Cave mouths", "Cave mouth " .. i, e.pos - (e.facing or Vector3.zero) * 6)
	end
	for i, room in if net and net.secretRooms then net.secretRooms else {} do
		add("Secret rooms", "Secret room " .. i, room.pos)
	end
	for _, folderName in { "Landmarks", "Camps", "Grottos" } do
		local f = workspace:FindFirstChild(folderName)
		for _, m in if f then f:GetChildren() else {} do
			if m:IsA("Model") then
				add(folderName, m.Name, m:GetPivot().Position + Vector3.new(0, 4, 0))
			end
		end
	end
	return list
end

-- What the admin menu shows: the islands, the mobs, and everyone online.
local function adminState(): any
	local islands = {}
	for _, isl in WorldBuilder.Islands do
		table.insert(islands, { name = isl.name, nameless = isl.nameless == true, x = isl.x, z = isl.z })
	end
	local mobs = {}
	for name in AnimalDefs do
		table.insert(mobs, name)
	end
	table.sort(mobs)
	local players = {}
	for _, p in Players:GetPlayers() do
		local h = humanoid(p)
		local r = root(p)
		local near, best = nil, math.huge
		if r then
			for _, isl in WorldBuilder.Islands do
				local d = (Vector3.new(isl.x, 0, isl.z) - Vector3.new(r.Position.X, 0, r.Position.Z)).Magnitude - isl.r
				if d < best then
					near, best = isl.name, d
				end
			end
		end
		table.insert(players, {
			name = p.Name,
			display = p.DisplayName,
			userId = p.UserId,
			level = p:GetAttribute("Level") or 1,
			hp = if h then math.floor(h.Health) else 0,
			maxHp = if h then math.floor(h.MaxHealth) else 100,
			held = Inventory.getEquipped(p),
			where = if r then (if best <= 40 then near else "at sea near " .. tostring(near)) else "not spawned",
			pos = if r then r.Position else nil,
			god = p:GetAttribute("God") == true,
		})
	end
	local okP, placeList = pcall(places)
	return { places = if okP then placeList else {}, islands = islands, mobs = mobs, players = players, items = (function()
		local ids = {}
		for id, item in Items do
			if type(item) == "table" and type(item.name) == "string" then
				table.insert(ids, id)
			end
		end
		table.sort(ids)
		return ids
	end)() }
end

local function run(player: Player, text: string)
	local words = text:split(" ")
	local filtered = {}
	for _, w in words do
		if w ~= "" then
			table.insert(filtered, w)
		end
	end
	local name = table.remove(filtered, 1)
	if not name then
		return
	end
	name = name:lower():gsub("^[/;]", "")
	local command = commands[name]
	if not command or not isAdmin(player) then
		return
	end
	local ok, err = pcall(command, player, filtered)
	if not ok then
		tell(player, "/" .. name .. " failed: " .. tostring(err), "warn")
	end
end

function Admin.start()
	-- The admin menu: commands typed into it, and the state it shows.
	Remotes.AdminRun.OnServerEvent:Connect(function(player, text)
		if type(text) ~= "string" or #text > 200 or not isAdmin(player) then
			return
		end
		if text == "__state" then
			Remotes.AdminState:FireClient(player, adminState())
			return
		end
		run(player, "/" .. text)
	end)
	-- Keep god mode up (some damage sets health directly).
	game:GetService("RunService").Heartbeat:Connect(function()
		for _, p in Players:GetPlayers() do
			if p:GetAttribute("God") then
				local h = humanoid(p)
				if h and h.Health > 0 and h.Health < h.MaxHealth then
					h.Health = h.MaxHealth
				end
			end
		end
	end)
	-- New chat: each command is a TextChatCommand, so the message isn't posted to chat.
	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		local folder = Instance.new("Folder")
		folder.Name = "AdminCommands"
		folder.Parent = TextChatService
		for name in commands do
			local command = Instance.new("TextChatCommand")
			command.Name = "Admin_" .. name
			command.PrimaryAlias = "/" .. name
			command.Parent = folder
			command.Triggered:Connect(function(source: TextSource, text: string)
				local player = Players:GetPlayerByUserId(source.UserId)
				if player then
					run(player, text)
				end
			end)
		end
	end
	-- Old chat, or typing ;tp instead of /tp.
	local function hook(player: Player)
		player:SetAttribute("Admin", isAdmin(player))
		player.Chatted:Connect(function(text)
			if text:sub(1, 1) == ";" or TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then
				if text:sub(1, 1) == ";" or text:sub(1, 1) == "/" then
					run(player, text)
				end
			end
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
end

return Admin
