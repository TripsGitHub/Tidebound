-- While you hold a buildable: a see-through preview with a green (ok) or red (too far)
-- outline that snaps to the grid. R rotates, click places.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Structures = require(Shared.Structures)
local Remotes = require(Shared.Remotes)
local Pointer = require(script.Parent.Pointer)
local Anim = require(script.Parent.Anim)

local player = Players.LocalPlayer
local BuildMode = {}

local ghost: Part? = nil
local outline: SelectionBox? = nil
local currentItem: string? = nil
local rotation = 0
local valid = false

function BuildMode.current(): string?
	return currentItem
end

function BuildMode.setItem(itemId: string?)
	local item = itemId and Items[itemId]
	if item and item.kind == "placeable" then
		if currentItem == itemId and ghost then
			return
		end
		BuildMode.setItem(nil)
		currentItem = itemId
		local def = Structures[item.structure]
		local g = Instance.new("Part")
		g.Name = "BuildGhost"
		g.Anchored = true
		g.CanCollide = false
		g.CanQuery = false
		g.CanTouch = false
		g.Material = Enum.Material.SmoothPlastic
		g.Transparency = 0.65
		g.Size = def.size
		g.Parent = workspace.CurrentCamera
		local box = Instance.new("SelectionBox")
		box.Adornee = g
		box.LineThickness = 0.08
		box.Parent = g
		ghost, outline = g, box
	else
		currentItem = nil
		if ghost then
			ghost:Destroy()
		end
		ghost, outline = nil, nil
	end
end

function BuildMode.rotate()
	rotation = (rotation + 90) % 360
end

function BuildMode.tryPlace()
	if ghost and currentItem and valid then
		Remotes.Place:FireServer(currentItem, ghost.Position, rotation)
		Anim.play(Players.LocalPlayer.Character, "place")
	end
end

RunService.RenderStepped:Connect(function()
	if not ghost or not outline then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local exclude: { Instance } = { workspace.CurrentCamera }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	for _, name in { "Nodes", "Drops", "Animals" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(exclude, f)
		end
	end
	local hit = Pointer.cast(exclude, 120)
	if not hit then
		ghost.Transparency = 1
		outline.Visible = false
		valid = false
		return
	end
	local size = ghost.Size
	local snapped = Structures.snap(hit.Position)
	ghost.CFrame = CFrame.new(snapped.X, hit.Position.Y + size.Y / 2, snapped.Z) * CFrame.Angles(0, math.rad(rotation), 0)
	valid = (ghost.Position - root.Position).Magnitude <= Config.BuildRange and hit.Material ~= Enum.Material.Water
	local color = if valid then Color3.fromRGB(90, 220, 90) else Color3.fromRGB(230, 70, 60)
	ghost.Transparency = 0.65
	ghost.Color = color
	outline.Visible = true
	outline.Color3 = color
	outline.SurfaceColor3 = color
end)

return BuildMode
