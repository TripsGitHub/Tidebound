-- Everyone spawns as the same kind of island tribesperson instead of their own Roblox
-- avatar: a plain blocky R15 body at normal scale (so armour always fits, and nobody
-- can be tiny or invisible to get an edge), a skin tone and hair colour picked from
-- their user id, a hide tunic and kilt with jagged hems, a belt, a Roblox hair and face, and a
-- necklace of three white fangs. The same player always gets the same look.
local Players = game:GetService("Players")

local Avatar = {}

local rgb = Color3.fromRGB
local SKIN = { rgb(255, 220, 186), rgb(234, 190, 150), rgb(204, 150, 106), rgb(160, 106, 70), rgb(120, 76, 48), rgb(92, 58, 38) }
local HAIR = { rgb(40, 30, 24), rgb(62, 44, 30), rgb(24, 20, 18), rgb(96, 64, 38), rgb(140, 98, 54) }
-- Free Roblox catalog hair and faces (checked in Studio): Pal Hair, Brown Charmer
-- Hair, Shaggy, Brown Hair, Lavender Updo; Smile, Check It, Man Face. No hats.
local HAIRS = { 63690008, 376548738, 20573078, 62234425, 451220849 }
local FACES = { 144075659, 7074786, 86487700 }
local HIDE = { rgb(150, 86, 44), rgb(136, 78, 42), rgb(160, 100, 56), rgb(122, 74, 44) }

local function look(userId: number)
	local rng = Random.new(math.abs(userId) + 17)
	return {
		skin = SKIN[rng:NextInteger(1, #SKIN)],
		hair = HAIR[rng:NextInteger(1, #HAIR)],
		hide = HIDE[rng:NextInteger(1, #HIDE)],
		hairId = HAIRS[rng:NextInteger(1, #HAIRS)],
		faceId = FACES[rng:NextInteger(1, #FACES)],
	}
end

function Avatar.description(player: Player): HumanoidDescription
	local l = look(player.UserId)
	local d = Instance.new("HumanoidDescription")
	d.HeadColor, d.LeftArmColor, d.RightArmColor = l.skin, l.skin, l.skin
	d.TorsoColor = l.hide
	d.LeftLegColor, d.RightLegColor = l.hide:Lerp(Color3.new(0, 0, 0), 0.12), l.hide:Lerp(Color3.new(0, 0, 0), 0.12)
	-- Blocky default body parts, standard scale, a Roblox hair and face, no hats.
	d.HeightScale, d.WidthScale, d.DepthScale, d.HeadScale = 1, 1, 1, 1
	d.BodyTypeScale, d.ProportionScale = 0, 0
	d.HairAccessory = tostring(l.hairId)
	d.Face = l.faceId
	return d
end

-- Spawns the player as their tribesperson.
function Avatar.load(player: Player)
	local ok = pcall(function()
		player:LoadCharacterWithHumanoidDescription(Avatar.description(player))
	end)
	if not ok and player.Parent then
		player:LoadCharacter()
	end
end

local function weld(p: BasePart, to: BasePart)
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, false, true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = to, p
	w.Parent = p
end

local function piece(folder: Instance, to: BasePart, size: Vector3, offset: CFrame, colour: Color3, mat: Enum.Material?, class: string?): BasePart
	local p = Instance.new(class or "Part") :: BasePart
	p.Size = size
	p.Color = colour
	p.Material = mat or Enum.Material.Fabric
	p.CFrame = to.CFrame * offset
	weld(p, to)
	p.Parent = folder
	return p
end

-- A jagged hem: little downward points all the way round the bottom of a part.
local function hem(folder: Instance, to: BasePart, y: number, colour: Color3, grow: number)
	local s = to.Size
	local w, dp = s.X + grow, s.Z + grow
	local function teeth(count: number, len: number, along: Vector3, out: Vector3)
		for i = 0, count - 1 do
			local t = (i + 0.5) / count - 0.5
			local h = if i % 2 == 0 then 0.32 else 0.22
			local pos = along * (t * len) + out + Vector3.new(0, y - h / 2, 0)
			local cf = CFrame.lookAt(pos, pos + out) * CFrame.Angles(0, 0, math.pi)
			piece(folder, to, Vector3.new(len / count + 0.02, h, 0.06), cf, colour, Enum.Material.Fabric, "WedgePart")
		end
	end
	teeth(4, w, Vector3.xAxis, Vector3.new(0, 0, -dp / 2))
	teeth(4, w, Vector3.xAxis, Vector3.new(0, 0, dp / 2))
	teeth(2, dp, Vector3.zAxis, Vector3.new(-w / 2, 0, 0))
	teeth(2, dp, Vector3.zAxis, Vector3.new(w / 2, 0, 0))
end

-- Dresses a freshly spawned character: tunic hem, belt, kilt, necklace.
function Avatar.dress(player: Player, character: Model)
	local l = look(player.UserId)
	local old = character:FindFirstChild("TribeOutfit")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "TribeOutfit"
	local head = character:WaitForChild("Head", 5) :: BasePart?
	local upper = character:WaitForChild("UpperTorso", 5) :: BasePart?
	local lower = character:WaitForChild("LowerTorso", 5) :: BasePart?
	if not head or not upper or not lower then
		return
	end
	-- The tunic's ragged bottom edge and a dark belt.
	local us = upper.Size
	hem(folder, upper, -us.Y / 2 + 0.05, l.hide, 0.08)
	local ls = lower.Size
	piece(folder, lower, Vector3.new(ls.X + 0.1, 0.22, ls.Z + 0.1), CFrame.new(0, ls.Y / 2 - 0.08, 0), l.hide:Lerp(Color3.new(0, 0, 0), 0.45), Enum.Material.Leather)
	-- The kilt: a hide skirt over the hips with a jagged hem halfway down the thighs.
	for _, name in { "LeftUpperLeg", "RightUpperLeg" } do
		local leg = character:FindFirstChild(name) :: BasePart?
		if leg then
			local s = leg.Size
			piece(folder, leg, Vector3.new(s.X + 0.12, s.Y * 0.6, s.Z + 0.12), CFrame.new(0, s.Y * 0.2, 0), l.hide, Enum.Material.Fabric)
			hem(folder, leg, -s.Y * 0.1, l.hide, 0.14)
		end
	end
	-- Fang necklace: a dark cord round the neck with three white fangs on the chest.
	local cord = l.hide:Lerp(Color3.new(0, 0, 0), 0.6)
	piece(folder, upper, Vector3.new(us.X * 0.62, 0.12, 0.1), CFrame.new(0, us.Y * 0.36, -us.Z / 2 - 0.05), cord, Enum.Material.Leather)
	for _, x in { -1, 1 } do
		piece(folder, upper, Vector3.new(0.12, 0.42, 0.1), CFrame.new(x * us.X * 0.31, us.Y * 0.2, -us.Z / 2 - 0.05) * CFrame.Angles(0, 0, x * 0.5), cord, Enum.Material.Leather)
	end
	for i = -1, 1 do
		local len = if i == 0 then 0.62 else 0.5
		local cf = CFrame.new(i * 0.32, us.Y * 0.32 - len / 2, -us.Z / 2 - 0.09) * CFrame.Angles(0, 0, i * 0.25) * CFrame.Angles(0, math.pi, math.pi)
		piece(folder, upper, Vector3.new(0.05, len, 0.2), cf * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(240, 236, 224), Enum.Material.SmoothPlastic, "WedgePart")
	end
	folder.Parent = character
	-- Armour may already be on (it goes on as the character spawns).
	local worn = {}
	local armour = character:FindFirstChild("Armour")
	for _, m in if armour then armour:GetChildren() else {} do
		local slot = m:GetAttribute("Slot")
		if slot then
			worn[slot] = m:GetAttribute("ItemId") or true
		end
	end
	Avatar.hideUnder(character, worn)
end

-- Armour on a slot covers that part of the outfit (Appearance calls this).
function Avatar.hideUnder(character: Model, slots: { [string]: string })
	local folder = character:FindFirstChild("TribeOutfit")
	if not folder then
		return
	end
	local head, body, legs = slots.head ~= nil, slots.body ~= nil, slots.legs ~= nil
	for _, p in folder:GetChildren() do
		if p:IsA("BasePart") then
			local to = (p:FindFirstChildOfClass("WeldConstraint") :: WeldConstraint?)
			local parent = to and to.Part0
			local name = parent and parent.Name or ""
			local hidden = (head and name == "Head") or (body and (name == "UpperTorso" or name == "LowerTorso")) or (legs and string.find(name, "UpperLeg") ~= nil)
			p.Transparency = if hidden then 1 else 0
		end
	end
	-- The Roblox hair goes under a helmet.
	for _, acc in character:GetChildren() do
		if acc:IsA("Accessory") and acc.AccessoryType == Enum.AccessoryType.Hair then
			local handle = acc:FindFirstChild("Handle") :: BasePart?
			if handle then
				handle.Transparency = if head then 1 else 0
			end
		end
	end
end

Avatar.players = Players
return Avatar
