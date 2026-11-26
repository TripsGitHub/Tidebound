-- Shows a see-through preview of the structure you're holding, snapped to the grid.
-- Green = you can build here, red = too far. Press R to rotate, click to place.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Structures = require(Shared.Structures)
local Remotes = require(Shared.Remotes)
local Pointer = require(script.Parent.Pointer)

local player = Players.LocalPlayer
local BuildMode = {}

local ghost: Part? = nil
local currentItem: string? = nil
local rotation = 0
local valid = false

function BuildMode.setItem(itemId: string?)
	local item = itemId and Items[itemId]
	if item and item.kind == "placeable" then
		if currentItem == itemId and ghost then
			return
		end
		if ghost then
			ghost:Destroy()
		end
		currentItem = itemId
		local def = Structures[item.structure]
		local g = Instance.new("Part")
		g.Name = "BuildGhost"
		g.Anchored = true
		g.CanCollide = false
		g.CanQuery = false
		g.CanTouch = false
		g.Material = Enum.Material.ForceField
		g.Transparency = 0.3
		g.Size = def.size
		g.Parent = workspace.CurrentCamera
		ghost = g
	else
		currentItem = nil
		if ghost then
			ghost:Destroy()
			ghost = nil
		end
	end
end

function BuildMode.rotate()
	rotation = (rotation + 90) % 360
end

function BuildMode.isActive(): boolean
	return ghost ~= nil
end

function BuildMode.tryPlace()
	if ghost and currentItem and valid then
		Remotes.Place:FireServer(currentItem, ghost.Position, rotation)
	end
end

RunService.RenderStepped:Connect(function()
	if not ghost or not currentItem then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local exclude: { Instance } = { ghost }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	local nodes = workspace:FindFirstChild("Nodes")
	if nodes then
		table.insert(exclude, nodes)
	end
	local hit = Pointer.cast(exclude, 120)
	if not hit then
		ghost.Transparency = 1
		valid = false
		return
	end
	local size = ghost.Size
	local snapped = Structures.snap(hit.Position)
	ghost.CFrame = CFrame.new(snapped.X, hit.Position.Y + size.Y / 2, snapped.Z) * CFrame.Angles(0, math.rad(rotation), 0)
	valid = (ghost.Position - root.Position).Magnitude <= Config.BuildRange
	ghost.Transparency = 0.3
	ghost.Color = if valid then Color3.fromRGB(110, 230, 120) else Color3.fromRGB(240, 90, 80)
end)

return BuildMode
