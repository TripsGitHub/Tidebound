-- The wandering merchant: the only place to make Tidecaller gear and the boss gear
-- (Fang Blade, Golem Harvester, Warden Pack). You still bring every material; the
-- merchant does the work. They move through the day: dawn, day, dusk and night each
-- find them on a different island, with a different few things on offer.
--   workspace attributes (for the client): MerchantPlace (island), MerchantStock
--   ("id,id,id,id"), MerchantUntil (the phase that ends their stay, e.g. "dusk").
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Recipes = require(Shared.Recipes)
local Remotes = require(Shared.Remotes)

local Traders = {}

export type Spot = { cf: CFrame, place: string }

local PHASES = {
	{ name = "dawn", from = 5 },
	{ name = "day", from = 11 },
	{ name = "dusk", from = 17 },
	{ name = "night", from = 22 },
}
local STOCK_SIZE = 4
local REACH = 18

local list: { string } = {}
for _, r in Recipes do
	if r.trader then
		table.insert(list, r.id)
	end
end

local merchant: Model? = nil
local spots: { Spot } = {}
local stock: { [string]: boolean } = {}
local cycle = 0

local function phaseAt(clock: number): number
	for i = #PHASES, 1, -1 do
		if clock >= PHASES[i].from then
			return i
		end
	end
	return #PHASES -- before dawn: still night
end

local function moveTo(phase: number)
	if not merchant or #spots == 0 then
		return
	end
	cycle += 1
	local spot = spots[(cycle - 1) % #spots + 1]
	merchant:PivotTo(spot.cf)
	-- Four things this stop, rotating through everything so each comes round often.
	table.clear(stock)
	local ids = {}
	for j = 0, STOCK_SIZE - 1 do
		local id = list[((cycle - 1) * STOCK_SIZE + j) % #list + 1]
		if not stock[id] then
			stock[id] = true
			table.insert(ids, id)
		end
	end
	local nextPhase = PHASES[phase % #PHASES + 1].name
	workspace:SetAttribute("MerchantPlace", spot.place)
	workspace:SetAttribute("MerchantStock", table.concat(ids, ","))
	workspace:SetAttribute("MerchantUntil", nextPhase)
	workspace:SetAttribute("MerchantAt", spot.cf.Position)
	Remotes.Notify:FireAllClients("The wandering merchant has set up on " .. spot.place .. " until " .. nextPhase, "good")
end

-- spots: where the merchant can stand. model: the merchant and their stall, built
-- by WorldBuilder (pivot at the ground in front of the stall).
function Traders.start(model: Model, where: { Spot })
	merchant = model
	spots = where
	if #spots == 0 or #list == 0 then
		return
	end
	-- Shuffle the route once per server so it isn't the same every game.
	local rng = Random.new()
	for i = #spots, 2, -1 do
		local j = rng:NextInteger(1, i)
		spots[i], spots[j] = spots[j], spots[i]
	end
	local current = phaseAt(Lighting.ClockTime)
	moveTo(current)
	task.spawn(function()
		while true do
			task.wait(2)
			local p = phaseAt(Lighting.ClockTime)
			if p ~= current then
				current = p
				moveTo(p)
			end
		end
	end)
end

-- May this player make this recipe here, right now?
function Traders.canCraft(player: Player, recipeId: string): (boolean, string?)
	if not stock[recipeId] then
		return false, "The merchant isn't offering that right now. Check back at " .. (workspace:GetAttribute("MerchantUntil") or "the next stop")
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not merchant or not root or (merchant:GetPivot().Position - root.Position).Magnitude > REACH then
		return false, "Bring the materials to the wandering merchant on " .. (workspace:GetAttribute("MerchantPlace") or "one of the islands")
	end
	return true, nil
end

Traders.players = Players
return Traders
