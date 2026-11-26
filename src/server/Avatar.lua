-- Dresses every character as a Tidebound castaway (see Shared/Looks). The Roblox
-- avatar is not loaded (StarterPlayer.LoadCharacterAppearance = false in the
-- project file), so characters spawn as plain blocky R15 bodies; this colours the
-- body parts and welds on a block head with a face, hair and outfit pieces.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Looks = require(Shared.Looks)
local Remotes = require(Shared.Remotes)

local Avatar = {}

local O = Looks.OPTIONS
local HEAD = Vector3.new(1.2, 1.2, 1.2) -- the block head every castaway gets
local looks: { [Player]: Looks.Look } = {}
local lastChange: { [Player]: number } = {}

local function piece(folder: Instance, to: BasePart, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = "LookPiece"
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CFrame = to.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = to
	weld.Part1 = p
	weld.Parent = p
	p.Parent = folder
	return p
end

local function part(character: Model, name: string): BasePart?
	local p = character:FindFirstChild(name)
	return if p and p:IsA("BasePart") then p else nil
end

local SIDES = { "Left", "Right" }

-- Which colour each body part gets for an outfit: "skin", "dye", "canvas", "trousers".
local BODY = {
	Castaway = { UpperTorso = "dye", UpperArm = "dye", LowerTorso = "canvas", UpperLeg = "canvas" },
	Islander = { LowerTorso = "dye", UpperLeg = "dye" },
	Voyager = { UpperTorso = "canvas", UpperArm = "canvas", LowerTorso = "trousers", UpperLeg = "trousers", LowerLeg = "trousers" },
}

local function colourBody(character: Model, look: Looks.Look)
	local outfit = O.outfit[look.outfit].name
	local colors = {
		skin = O.skin[look.skin].color,
		dye = O.dye[look.dye].color,
		canvas = Looks.CANVAS,
		trousers = Looks.TROUSERS,
	}
	local map = BODY[outfit]
	local function set(name: string, key: string)
		local p = part(character, name)
		if p then
			p.Color = colors[map[key] or "skin"]
			p.Material = Enum.Material.SmoothPlastic
		end
	end
	set("UpperTorso", "UpperTorso")
	set("LowerTorso", "LowerTorso")
	for _, side in SIDES do
		for _, limb in { "UpperArm", "LowerArm", "Hand", "UpperLeg", "LowerLeg", "Foot" } do
			set(side .. limb, limb)
		end
	end
end

local function face(folder: Folder, head: BasePart, look: Looks.Look)
	local hairColor = O.hairColor[look.hairColor].color
	local front = -HEAD.Z / 2
	for _, x in { -0.24, 0.24 } do
		piece(folder, head, Vector3.new(0.16, 0.26, 0.05), CFrame.new(x, 0.08, front - 0.02), Looks.EYES)
		piece(folder, head, Vector3.new(0.3, 0.07, 0.05), CFrame.new(x, 0.3, front - 0.02) * CFrame.Angles(0, 0, math.rad(x > 0 and 2 or -2)), hairColor)
	end
	piece(folder, head, Vector3.new(0.3, 0.06, 0.04), CFrame.new(0, -0.28, front - 0.015), Looks.MOUTH)

	local paint = O.paint[look.paint].name
	local paintColor = if look.skin <= 3 then Looks.OCHRE else Looks.CLAY
	if paint == "Cheek stripes" then
		for _, x in { -0.3, 0.3 } do
			for k = 0, 1 do
				piece(folder, head, Vector3.new(0.26, 0.05, 0.03), CFrame.new(x, -0.12 - k * 0.1, front - 0.01), paintColor)
			end
		end
	elseif paint == "Eye band" then
		piece(folder, head, Vector3.new(HEAD.X + 0.02, 0.36, 0.03), CFrame.new(0, 0.08, front - 0.008), paintColor)
	elseif paint == "Chin dots" then
		for _, x in { -0.14, 0, 0.14 } do
			piece(folder, head, Vector3.new(0.07, 0.07, 0.03), CFrame.new(x, -0.44, front - 0.01), paintColor)
		end
	end
end

local function hair(folder: Folder, head: BasePart, look: Looks.Look)
	local style = O.hair[look.hair].name
	local c = O.hairColor[look.hairColor].color
	local top = HEAD.Y / 2
	local back = HEAD.Z / 2
	if style == "Bald" then
		return
	elseif style == "Buzz" then
		piece(folder, head, Vector3.new(HEAD.X + 0.04, 0.12, HEAD.Z + 0.04), CFrame.new(0, top + 0.02, 0), c)
		piece(folder, head, Vector3.new(HEAD.X + 0.04, HEAD.Y * 0.45, 0.06), CFrame.new(0, top - HEAD.Y * 0.22, back + 0.02), c)
		return
	end
	-- Shaggy, Topknot and Braids share a thicker cap with sides and a back.
	local thick = if style == "Topknot" then 0.16 else 0.3
	piece(folder, head, Vector3.new(HEAD.X + 0.12, thick, HEAD.Z + 0.12), CFrame.new(0, top + thick / 2 - 0.08, 0), c)
	local sideLen = if style == "Topknot" then HEAD.Y * 0.4 else HEAD.Y * 0.6
	for _, sx in { -1, 1 } do
		piece(folder, head, Vector3.new(0.1, sideLen, HEAD.Z * 0.7), CFrame.new(sx * (HEAD.X / 2 + 0.04), top - sideLen / 2, HEAD.Z * 0.15), c)
	end
	local backLen = if style == "Shaggy" then HEAD.Y * 0.85 else HEAD.Y * 0.6
	piece(folder, head, Vector3.new(HEAD.X + 0.12, backLen, 0.12), CFrame.new(0, top - backLen / 2, back + 0.05), c)
	if style == "Shaggy" then
		for i, x in { -0.36, 0, 0.36 } do
			local tilt = math.rad(({ 10, -4, -12 })[i])
			piece(folder, head, Vector3.new(0.38, 0.24, 0.1), CFrame.new(x, top - 0.12, -back - 0.04) * CFrame.Angles(0, 0, tilt), c)
		end
		-- a few ragged ends below the back
		for _, x in { -0.4, 0, 0.4 } do
			piece(folder, head, Vector3.new(0.3, 0.2, 0.1), CFrame.new(x, top - backLen - 0.05, back + 0.05), c)
		end
	elseif style == "Topknot" then
		-- a small bun tied at the back of the crown
		piece(folder, head, Vector3.new(0.34, 0.34, 0.34), CFrame.new(0, top + 0.12, 0.32) * CFrame.Angles(math.rad(45), math.rad(45), 0), c)
		piece(folder, head, Vector3.new(0.3, 0.08, 0.3), CFrame.new(0, top + 0.02, 0.32) * CFrame.Angles(math.rad(-20), math.rad(45), 0), O.dye[look.dye].color)
	elseif style == "Braids" then
		for _, sx in { -1, 1 } do
			local x = sx * (HEAD.X / 2 + 0.05)
			for k = 0, 2 do
				piece(folder, head, Vector3.new(0.24, 0.3, 0.24), CFrame.new(x, -HEAD.Y * 0.1 - k * 0.28, 0.05) * CFrame.Angles(0, math.rad(45), 0), c)
			end
			piece(folder, head, Vector3.new(0.16, 0.14, 0.16), CFrame.new(x, -HEAD.Y * 0.1 - 0.86, 0.05), O.dye[look.dye].color)
		end
	end
end

local function outfit(folder: Folder, character: Model, look: Looks.Look)
	local name = O.outfit[look.outfit].name
	local dye = O.dye[look.dye].color
	local upper = part(character, "UpperTorso")
	local lower = part(character, "LowerTorso")
	if not upper or not lower then
		return
	end
	local us, ls = upper.Size, lower.Size
	if name == "Castaway" then
		-- rope belt, a canvas patch on the shirt, ragged sleeve and shorts hems
		piece(folder, lower, Vector3.new(ls.X + 0.08, 0.22, ls.Z + 0.08), CFrame.new(0, 0.05, 0), Looks.ROPE, Enum.Material.Fabric)
		piece(folder, lower, Vector3.new(0.22, 0.32, 0.06), CFrame.new(-0.55, -0.12, -ls.Z / 2 - 0.05), Looks.ROPE, Enum.Material.Fabric)
		piece(folder, upper, Vector3.new(0.42, 0.38, 0.04), CFrame.new(0.5, -0.25, -us.Z / 2 - 0.02) * CFrame.Angles(0, 0, math.rad(8)), Looks.CANVAS)
		for _, side in SIDES do
			local arm = part(character, side .. "UpperArm")
			if arm then
				for _, x in { -0.25, 0.22 } do
					piece(folder, arm, Vector3.new(0.5, 0.16, arm.Size.Z + 0.06), CFrame.new(x, -arm.Size.Y / 2 + 0.04, 0) * CFrame.Angles(0, 0, math.rad(x * 30)), dye)
				end
			end
			local leg = part(character, side .. "UpperLeg")
			if leg then
				piece(folder, leg, Vector3.new(leg.Size.X + 0.06, 0.18, leg.Size.Z + 0.06), CFrame.new(0, -leg.Size.Y / 2 + 0.05, 0) * CFrame.Angles(0, 0, math.rad(side == "Left" and 5 or -5)), Looks.CANVAS)
			end
		end
	elseif name == "Islander" then
		-- cloth sash over one shoulder, wrap skirt flaps, shell necklace
		piece(folder, upper, Vector3.new(0.34, us.Y * 1.25, us.Z + 0.06), CFrame.Angles(0, 0, math.rad(38)), dye, Enum.Material.Fabric)
		for i = -2, 2 do
			piece(folder, upper, Vector3.new(0.14, 0.14, 0.1), CFrame.new(i * 0.22, us.Y / 2 - 0.18 - (2 - math.abs(i)) * 0.06, -us.Z / 2 - 0.05), Looks.SHELL)
		end
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2
			local r = Vector3.new(ls.X / 2 + 0.06, 0, ls.Z / 2 + 0.06)
			local pos = Vector3.new(math.sin(a) * r.X, -0.45, math.cos(a) * r.Z)
			piece(folder, lower, Vector3.new(0.6, 0.9, 0.08), CFrame.new(pos) * CFrame.Angles(0, a, 0) * CFrame.Angles(math.rad(-6), 0, 0), dye:Lerp(Color3.new(0, 0, 0), (i % 2) * 0.15), Enum.Material.Fabric)
		end
		piece(folder, lower, Vector3.new(ls.X + 0.14, 0.16, ls.Z + 0.14), CFrame.new(0, 0.1, 0), Looks.ROPE, Enum.Material.Fabric)
	elseif name == "Voyager" then
		-- dyed vest panels front and back, a leather belt with a buckle, rolled sleeves
		for _, sx in { -1, 1 } do
			piece(folder, upper, Vector3.new(us.X * 0.32, us.Y + 0.02, 0.06), CFrame.new(sx * us.X * 0.33, 0, -us.Z / 2 - 0.03), dye, Enum.Material.Fabric)
		end
		piece(folder, upper, Vector3.new(us.X + 0.04, us.Y + 0.02, 0.06), CFrame.new(0, 0, us.Z / 2 + 0.03), dye, Enum.Material.Fabric)
		piece(folder, lower, Vector3.new(ls.X + 0.06, 0.2, ls.Z + 0.06), CFrame.new(0, 0.08, 0), Looks.LEATHER)
		piece(folder, lower, Vector3.new(0.24, 0.2, 0.06), CFrame.new(0, 0.08, -ls.Z / 2 - 0.05), Color3.fromRGB(214, 178, 90), Enum.Material.Metal)
		for _, side in SIDES do
			local arm = part(character, side .. "UpperArm")
			if arm then
				piece(folder, arm, Vector3.new(arm.Size.X + 0.08, 0.2, arm.Size.Z + 0.08), CFrame.new(0, -arm.Size.Y / 2 + 0.1, 0), Looks.CANVAS)
			end
		end
	end
end

function Avatar.apply(character: Model, look: Looks.Look)
	local old = character:FindFirstChild("Look")
	if old then
		old:Destroy()
	end
	-- Anything Roblox put on the body
	for _, child in character:GetChildren() do
		if child:IsA("Accessory") or child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") or child:IsA("BodyColors") or child:IsA("CharacterMesh") then
			child:Destroy()
		end
	end
	local head = part(character, "Head")
	if not head then
		return
	end
	-- Hide the stock head and weld on a plain block head, so every face and
	-- hairstyle fits the same 1.2 stud cube.
	head.Transparency = 1
	for _, d in head:GetChildren() do
		if d:IsA("Decal") then
			d:Destroy()
		end
	end
	colourBody(character, look)

	local folder = Instance.new("Folder")
	folder.Name = "Look"
	local block = piece(folder, head, HEAD, CFrame.new(0, 0.05, 0), O.skin[look.skin].color)
	block.Name = "HeadBlock"
	face(folder, block, look)
	hair(folder, block, look)
	outfit(folder, character, look)
	folder.Parent = character
end

function Avatar.get(player: Player): Looks.Look
	return looks[player]
end

local function set(player: Player, look: Looks.Look)
	looks[player] = look
	player:SetAttribute("Look", HttpService:JSONEncode(look))
	if player.Character then
		Avatar.apply(player.Character, look)
	end
end

function Avatar.init(player: Player)
	-- Everyone starts as a random castaway and can change it from the Look menu.
	-- TODO: save the look with the rest of the player's data once saving lands.
	set(player, Looks.random())
	player:SetAttribute("LookChosen", false)
end

function Avatar.onCharacter(player: Player, character: Model)
	local look = looks[player]
	if not look then
		return
	end
	character:WaitForChild("UpperTorso", 5)
	character:WaitForChild("Head", 5)
	Avatar.apply(character, look)
end

Remotes.SetLook.OnServerEvent:Connect(function(player: Player, raw: any, done: any)
	local now = os.clock()
	if now - (lastChange[player] or 0) < 0.1 then
		return
	end
	lastChange[player] = now
	local look = Looks.sanitize(raw)
	if look then
		set(player, look)
	end
	if done == true then
		player:SetAttribute("LookChosen", true)
	end
end)

game:GetService("Players").PlayerRemoving:Connect(function(player)
	looks[player] = nil
	lastChange[player] = nil
end)

return Avatar
