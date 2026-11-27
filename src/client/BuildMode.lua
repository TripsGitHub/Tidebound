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
local tiles = 1 -- floors: lay n x n in one go ([ and ] to change)
local snappedTo: Vector3? = nil -- where the ghost snapped to a neighbour, if it did

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
		local g = Instance.new("Part")
		g.Name = "BuildGhost"
		g.Anchored = true
		g.CanCollide = false
		g.CanQuery = false
		g.CanTouch = false
		g.Material = Enum.Material.SmoothPlastic
		g.Transparency = 0.65
		g.Size = Structures.sizeFor(item.structure, tiles)
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

function BuildMode.resize(step: number)
	local item = currentItem and Items[currentItem]
	if not item or not Structures.isFloor(item.structure) or not ghost then
		return
	end
	tiles = math.clamp(tiles + step, 1, Structures.MAX_TILES)
	ghost.Size = Structures.sizeFor(item.structure, tiles)
end

function BuildMode.tiles(): number
	return tiles
end

function BuildMode.tryPlace()
	if ghost and currentItem and valid then
		local bottom = ghost.Position - Vector3.new(0, ghost.Size.Y / 2, 0)
		local _, ry = ghost.CFrame:ToOrientation()
		Remotes.Place:FireServer(currentItem, bottom, math.deg(ry), tiles)
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
	local cf = CFrame.new(snapped.X, hit.Position.Y + size.Y / 2, snapped.Z) * CFrame.Angles(0, math.rad(rotation), 0)
	local item = Items[currentItem :: string]
	local floor = Structures.isFloor(item.structure)
	local wall = item.structure == "WoodWall" or item.structure == "StoneWall" or item.structure == "WoodGate"
	-- Walls snap to your base: they line up along its nearest edge.
	local structures = workspace:FindFirstChild("Structures")
	if structures and wall then
		local best, bestDist = nil, math.huge
		for _, m in structures:GetChildren() do
			local st = m:GetAttribute("StructureType")
			if st and Structures.isFloor(st) and m:IsA("Model") and m.PrimaryPart then
				local d = (m.PrimaryPart.Position - hit.Position) * Vector3.new(1, 0, 1)
				local reach = m.PrimaryPart.Size.X / 2 + (if floor then size.X / 2 + 4 else 3)
				if math.abs(d.X) < reach + 4 and math.abs(d.Z) < reach + 4 and d.Magnitude < bestDist then
					best, bestDist = m, d.Magnitude
				end
			end
		end
		if best then
			local core = best.PrimaryPart :: BasePart
			local half = core.Size.X / 2
			local top = core.Position.Y + core.Size.Y / 2
			local baseCf = CFrame.new(core.Position) * (core.CFrame - core.CFrame.Position)
			local rel = baseCf:PointToObjectSpace(hit.Position)
			local _, ry = baseCf:ToOrientation()
			if floor then
				-- Which side are we off? Put the new floor flush against it.
				local off = size.X / 2 + half
				local local_ = if math.abs(rel.X) > math.abs(rel.Z) then Vector3.new(math.sign(rel.X) * off, 0, 0) else Vector3.new(0, 0, math.sign(rel.Z) * off)
				if math.abs(rel.X) > half or math.abs(rel.Z) > half then
					local p = baseCf:PointToWorldSpace(local_)
					cf = CFrame.new(p.X, core.Position.Y + 0.15, p.Z) * CFrame.Angles(0, ry, 0)
				end
			elseif math.abs(rel.X) <= half + 3 and math.abs(rel.Z) <= half + 3 then
				-- Nearest edge, and the wall slides along it in wall-width steps.
				local w = size.X
				local along, edge
				if half - math.abs(rel.X) < half - math.abs(rel.Z) then
					edge = Vector3.new(math.sign(rel.X) * half, 0, 0)
					along = math.clamp(math.round((rel.Z + half - w / 2) / w) * w - half + w / 2, -half + w / 2, half - w / 2)
					local p = baseCf:PointToWorldSpace(edge + Vector3.new(0, 0, along))
					cf = CFrame.new(p.X, top + size.Y / 2, p.Z) * CFrame.Angles(0, ry + math.pi / 2, 0)
				else
					edge = Vector3.new(0, 0, math.sign(rel.Z) * half)
					along = math.clamp(math.round((rel.X + half - w / 2) / w) * w - half + w / 2, -half + w / 2, half - w / 2)
					local p = baseCf:PointToWorldSpace(edge + Vector3.new(along, 0, 0))
					cf = CFrame.new(p.X, top + size.Y / 2, p.Z) * CFrame.Angles(0, ry, 0)
				end
			end
		end
	end
	ghost.CFrame = cf
	valid = (ghost.Position - root.Position).Magnitude <= Config.BuildRange + size.X / 2 and hit.Material ~= Enum.Material.Water
	local color = if valid then Color3.fromRGB(90, 220, 90) else Color3.fromRGB(230, 70, 60)
	ghost.Transparency = 0.65
	ghost.Color = color
	outline.Visible = true
	outline.Color3 = color
	outline.SurfaceColor3 = color
end)

return BuildMode
