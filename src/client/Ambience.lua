--!strict
-- The look of the world through the day, on this client only.
--
-- The server only turns the clock (Lighting.ClockTime). Here the light, sky, haze,
-- clouds and colour grading follow it through dawn, a contrasty golden day, a warm
-- low sun, a mauve dusk and a moonlit night: deep purple sky, a big crisp moon, dark
-- clouds, near-black water, and ground still readable in cool blue moonlight.
--
-- It also adds the small life in the air round the player (pollen and leaves by day,
-- fireflies at night, snow on frozen ground, embers near lava) and the underwater
-- feel when the camera goes under: a blue-green grade, thick fog, a little blur,
-- bubbles drifting up and shafts of light from the surface.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Ambience = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- One look per time of day. Keys are hours; values blend between neighbours.
type Look = {
	brightness: number,
	exposure: number,
	ambient: Color3,
	outdoor: Color3,
	atmoColor: Color3,
	atmoDecay: Color3,
	density: number,
	haze: number,
	glare: number,
	tint: Color3,
	contrast: number,
	saturation: number,
	bloom: number,
	rays: number,
	clouds: Color3,
	cover: number,
	water: Color3,
}

local KEYS: { { h: number, look: Look } } = {
	{ h = 0, look = { -- midnight
		brightness = 1.6, exposure = 0.25,
		ambient = rgb(38, 40, 66), outdoor = rgb(78, 90, 136),
		atmoColor = rgb(74, 58, 104), atmoDecay = rgb(34, 26, 58), density = 0.34, haze = 1.6, glare = 0,
		tint = rgb(196, 204, 255), contrast = 0.16, saturation = -0.12, bloom = 0.9, rays = 0.02,
		clouds = rgb(48, 42, 70), cover = 0.62, water = rgb(14, 26, 44),
	} },
	{ h = 4.8, look = { -- deep night before dawn
		brightness = 1.6, exposure = 0.25,
		ambient = rgb(40, 42, 70), outdoor = rgb(80, 92, 140),
		atmoColor = rgb(80, 62, 110), atmoDecay = rgb(36, 28, 60), density = 0.34, haze = 1.6, glare = 0,
		tint = rgb(198, 206, 255), contrast = 0.16, saturation = -0.12, bloom = 0.9, rays = 0.02,
		clouds = rgb(52, 46, 74), cover = 0.6, water = rgb(16, 28, 48),
	} },
	{ h = 6.2, look = { -- dawn: pink haze, long shadows
		brightness = 2.2, exposure = 0.15,
		ambient = rgb(70, 56, 64), outdoor = rgb(150, 118, 122),
		atmoColor = rgb(255, 176, 156), atmoDecay = rgb(176, 104, 126), density = 0.32, haze = 2.0, glare = 1.6,
		tint = rgb(255, 222, 214), contrast = 0.14, saturation = 0.08, bloom = 0.8, rays = 0.22,
		clouds = rgb(255, 196, 186), cover = 0.5, water = rgb(70, 110, 140),
	} },
	{ h = 8.5, look = { -- morning
		brightness = 3.1, exposure = 0.05,
		ambient = rgb(52, 50, 54), outdoor = rgb(132, 126, 112),
		atmoColor = rgb(236, 226, 200), atmoDecay = rgb(180, 168, 140), density = 0.26, haze = 1.3, glare = 1.0,
		tint = rgb(255, 248, 232), contrast = 0.16, saturation = 0.16, bloom = 0.55, rays = 0.14,
		clouds = rgb(250, 248, 244), cover = 0.42, water = rgb(58, 148, 162),
	} },
	{ h = 12.5, look = { -- midday: bright sun, darker ambient so shadows have depth
		brightness = 3.5, exposure = 0,
		ambient = rgb(46, 46, 52), outdoor = rgb(118, 118, 110),
		atmoColor = rgb(228, 226, 210), atmoDecay = rgb(160, 170, 160), density = 0.22, haze = 1.0, glare = 0.8,
		tint = rgb(255, 250, 238), contrast = 0.18, saturation = 0.18, bloom = 0.5, rays = 0.12,
		clouds = rgb(255, 255, 255), cover = 0.4, water = rgb(52, 152, 166),
	} },
	{ h = 16.3, look = { -- golden afternoon
		brightness = 3.2, exposure = 0.05,
		ambient = rgb(60, 52, 46), outdoor = rgb(150, 128, 100),
		atmoColor = rgb(255, 214, 156), atmoDecay = rgb(204, 146, 92), density = 0.27, haze = 1.5, glare = 1.6,
		tint = rgb(255, 236, 204), contrast = 0.18, saturation = 0.18, bloom = 0.65, rays = 0.2,
		clouds = rgb(255, 232, 200), cover = 0.42, water = rgb(64, 140, 150),
	} },
	{ h = 18.2, look = { -- sunset: deep orange to rose
		brightness = 2.4, exposure = 0.12,
		ambient = rgb(68, 48, 56), outdoor = rgb(156, 106, 100),
		atmoColor = rgb(255, 150, 110), atmoDecay = rgb(150, 74, 100), density = 0.32, haze = 2.2, glare = 2.2,
		tint = rgb(255, 214, 196), contrast = 0.16, saturation = 0.12, bloom = 0.85, rays = 0.26,
		clouds = rgb(240, 150, 140), cover = 0.48, water = rgb(70, 90, 120),
	} },
	{ h = 19.6, look = { -- dusk: mauve sky, first stars
		brightness = 1.8, exposure = 0.22,
		ambient = rgb(46, 40, 66), outdoor = rgb(98, 90, 134),
		atmoColor = rgb(132, 92, 140), atmoDecay = rgb(58, 38, 80), density = 0.33, haze = 1.8, glare = 0.4,
		tint = rgb(220, 210, 255), contrast = 0.16, saturation = -0.04, bloom = 0.85, rays = 0.06,
		clouds = rgb(96, 70, 108), cover = 0.55, water = rgb(26, 36, 62),
	} },
	{ h = 24, look = nil :: any }, -- filled in below: same as midnight
}
KEYS[#KEYS].look = KEYS[1].look

local function lerpLook(a: Look, b: Look, t: number): Look
	local out = {} :: any
	for k, va in a :: any do
		local vb = (b :: any)[k]
		if typeof(va) == "Color3" then
			out[k] = (va :: Color3):Lerp(vb, t)
		else
			out[k] = va + (vb - va) * t
		end
	end
	return out
end

local function lookAt(hour: number): Look
	for i = 1, #KEYS - 1 do
		local a, b = KEYS[i], KEYS[i + 1]
		if hour >= a.h and hour <= b.h then
			local t = (hour - a.h) / (b.h - a.h)
			t = t * t * (3 - 2 * t) -- ease, so each look holds for a while
			return lerpLook(a.look, b.look, t)
		end
	end
	return KEYS[1].look
end

local function getOrMake(parent: Instance, className: string, name: string?): any
	local found = if name then parent:FindFirstChild(name) else parent:FindFirstChildOfClass(className)
	if found then
		return found
	end
	local inst = Instance.new(className)
	if name then
		inst.Name = name
	end
	inst.Parent = parent
	return inst
end

-- Particles -------------------------------------------------------------------------
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Enabled = false
	e.LightInfluence = 1
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

local function fade(a: number, b: number, c: number): NumberSequence
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, a), NumberSequenceKeypoint.new(0.8, b), NumberSequenceKeypoint.new(1, c) })
end

function Ambience.start()
	local terrain = workspace.Terrain
	local camera = workspace.CurrentCamera
	local atmosphere = getOrMake(Lighting, "Atmosphere") :: Atmosphere
	local bloom = getOrMake(Lighting, "BloomEffect") :: BloomEffect
	local rays = getOrMake(Lighting, "SunRaysEffect") :: SunRaysEffect
	local grade = getOrMake(Lighting, "ColorCorrectionEffect", "ColorCorrectionEffect") :: ColorCorrectionEffect
	local sky = getOrMake(Lighting, "Sky") :: Sky
	local clouds = getOrMake(terrain, "Clouds") :: Clouds
	local underGrade = getOrMake(Lighting, "ColorCorrectionEffect", "Underwater") :: ColorCorrectionEffect
	local underBlur = getOrMake(Lighting, "BlurEffect", "UnderwaterBlur") :: BlurEffect
	underGrade.Enabled, underBlur.Enabled = false, false
	underBlur.Size = 5
	underGrade.TintColor = rgb(150, 220, 230)
	underGrade.Saturation = -0.1
	underGrade.Contrast = 0.1
	underGrade.Brightness = -0.04

	sky.MoonAngularSize = 22 -- big and crisp, like the reference
	sky.SunAngularSize = 16
	sky.StarCount = 3000
	sky.CelestialBodiesShown = true
	clouds.Density = 0.55

	-- A box of air round the player that the life in the air spawns in.
	local air = Instance.new("Part")
	air.Name = "AmbientAir"
	air.Anchored, air.CanCollide, air.CanQuery, air.CanTouch = true, false, false, false
	air.Transparency = 1
	air.Size = Vector3.new(90, 18, 90)
	air.Parent = camera
	local fx = {
		pollen = emitter(air, {
			Texture = SPARK, Color = ColorSequence.new(rgb(255, 244, 196)), LightEmission = 0.6,
			Size = NumberSequence.new(0.12, 0.08), Transparency = fade(0.3, 0.4, 1),
			Lifetime = NumberRange.new(6, 10), Rate = 22, Speed = NumberRange.new(0.3, 1),
			SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0.6, 0.05, 0.3),
			RotSpeed = NumberRange.new(-40, 40),
		}),
		leaves = emitter(air, {
			Texture = SMOKE, Color = ColorSequence.new(rgb(170, 190, 80), rgb(210, 150, 60)), LightEmission = 0,
			Size = NumberSequence.new(0.35, 0.3), Transparency = fade(0.1, 0.2, 1), Squash = NumberSequence.new(0.6),
			Lifetime = NumberRange.new(5, 8), Rate = 3, Speed = NumberRange.new(1, 3),
			SpreadAngle = Vector2.new(60, 60), Acceleration = Vector3.new(2, -1.2, 1),
			Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-180, 180),
		}),
		fireflies = emitter(air, {
			Texture = SPARK, Color = ColorSequence.new(rgb(210, 255, 120)), LightEmission = 1, LightInfluence = 0,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 0.1) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0), NumberSequenceKeypoint.new(0.5, 0.7), NumberSequenceKeypoint.new(0.75, 0), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(4, 7), Rate = 14, Speed = NumberRange.new(0.4, 1.4),
			SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, 0.15, 0),
		}),
		snow = emitter(air, {
			Texture = SPARK, Color = ColorSequence.new(rgb(255, 255, 255)), LightEmission = 0.3,
			Size = NumberSequence.new(0.22, 0.16), Transparency = fade(0.1, 0.2, 1),
			Lifetime = NumberRange.new(5, 8), Rate = 70, Speed = NumberRange.new(2, 4),
			EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(25, 25), Acceleration = Vector3.new(1.2, -0.6, 0.4),
		}),
		embers = emitter(air, {
			Texture = FIRE, Color = ColorSequence.new(rgb(255, 180, 70), rgb(255, 70, 20)), LightEmission = 1, LightInfluence = 0,
			Size = NumberSequence.new(0.18, 0.05), Transparency = fade(0, 0.3, 1),
			Lifetime = NumberRange.new(3, 5), Rate = 26, Speed = NumberRange.new(1.5, 4),
			EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(40, 40), Acceleration = Vector3.new(0.8, 1.2, 0),
		}),
		bubbles = emitter(air, {
			Texture = SPARK, Color = ColorSequence.new(rgb(220, 250, 255)), LightEmission = 0.5,
			Size = NumberSequence.new(0.14, 0.3), Transparency = fade(0.2, 0.4, 1),
			Lifetime = NumberRange.new(3, 6), Rate = 40, Speed = NumberRange.new(2, 5),
			EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(15, 15), Acceleration = Vector3.new(0, 1.5, 0),
		}),
		motes = emitter(air, { -- the specks of drifting stuff that make water look like water
			Texture = SMOKE, Color = ColorSequence.new(rgb(170, 230, 210)), LightEmission = 0.2,
			Size = NumberSequence.new(0.1, 0.18), Transparency = fade(0.5, 0.6, 1),
			Lifetime = NumberRange.new(6, 10), Rate = 60, Speed = NumberRange.new(0.1, 0.5),
			SpreadAngle = Vector2.new(180, 180),
		}),
	}

	-- Shafts of sunlight coming down through the water near the camera.
	local shafts = Instance.new("Folder")
	shafts.Name = "LightShafts"
	shafts.Parent = camera
	local beams: { Beam } = {}
	local anchor = Instance.new("Part")
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = CFrame.new()
	anchor.Parent = shafts
	for k = 1, 9 do
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Parent, a1.Parent = anchor, anchor
		local b = Instance.new("Beam")
		b.Attachment0, b.Attachment1 = a0, a1
		b.FaceCamera = true
		b.LightEmission = 1
		b.LightInfluence = 0
		b.Color = ColorSequence.new(rgb(200, 250, 255))
		b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.78), NumberSequenceKeypoint.new(0.6, 0.9), NumberSequenceKeypoint.new(1, 1) })
		b.Width0 = 3 + (k % 3) * 2
		b.Width1 = b.Width0 * 2.2
		b.Segments = 1
		b.Enabled = false
		b.Parent = anchor
		table.insert(beams, b)
	end
	local shaftCentre: Vector3? = nil
	local function placeShafts(at: Vector3)
		shaftCentre = at
		for k, b in beams do
			local a = k * 2.4
			local d = 8 + (k * 7) % 34
			local top = Vector3.new(at.X + math.cos(a) * d, -0.5, at.Z + math.sin(a) * d)
			local slant = Vector3.new(-14, -46, -6)
			;(b.Attachment0 :: Attachment).WorldPosition = top
			;(b.Attachment1 :: Attachment).WorldPosition = top + slant
		end
	end

	local voxelSize = Vector3.new(4, 4, 4)
	local function inWater(p: Vector3): boolean
		if p.Y > 1 then
			return false
		end
		local min = Vector3.new(math.floor(p.X / 4) * 4, math.floor(p.Y / 4) * 4, math.floor(p.Z / 4) * 4)
		local ok, mats = pcall(function()
			return (terrain:ReadVoxels(Region3.new(min, min + voxelSize), 4))
		end)
		return ok and mats[1] and mats[1][1] and mats[1][1][1] == Enum.Material.Water
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { terrain }
	params.IgnoreWater = true

	local underwater = false
	local ground: Enum.Material? = nil
	local nearLava = false
	local lastProbe = 0
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local hour = Lighting.ClockTime
		local look = lookAt(hour)
		local night = hour < 5.6 or hour > 19.4

		-- Every so often: is the camera under water, and what's the ground underfoot?
		if now - lastProbe > 0.15 then
			lastProbe = now
			underwater = inWater(camera.CFrame.Position)
			local root = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local hit = workspace:Raycast(root.Position + Vector3.new(0, 2, 0), Vector3.new(0, -14, 0), params)
				ground = hit and hit.Material
				nearLava = ground == Enum.Material.CrackedLava or ground == Enum.Material.Basalt
			end
		end

		-- The world grade for the time of day.
		Lighting.Brightness = look.brightness
		Lighting.ExposureCompensation = look.exposure
		Lighting.Ambient = look.ambient
		Lighting.OutdoorAmbient = look.outdoor
		Lighting.ShadowSoftness = 0.15
		Lighting.EnvironmentDiffuseScale = 1
		Lighting.EnvironmentSpecularScale = 1
		bloom.Intensity, bloom.Size, bloom.Threshold = look.bloom, 30, 1.25
		rays.Intensity, rays.Spread = look.rays, 0.75
		grade.TintColor, grade.Contrast, grade.Saturation, grade.Brightness = look.tint, look.contrast, look.saturation, 0.02
		clouds.Color, clouds.Cover = look.clouds, look.cover
		terrain.WaterColor = look.water

		if underwater then
			atmosphere.Color, atmosphere.Decay = rgb(40, 120, 140), rgb(14, 60, 90)
			atmosphere.Density, atmosphere.Offset, atmosphere.Haze, atmosphere.Glare = 0.62, 0, 2.5, 0
			underGrade.Enabled, underBlur.Enabled = true, true
			underGrade.TintColor = if night then rgb(110, 150, 200) else rgb(150, 220, 230)
			rays.Intensity = 0
		else
			atmosphere.Color, atmosphere.Decay = look.atmoColor, look.atmoDecay
			atmosphere.Density, atmosphere.Offset, atmosphere.Haze, atmosphere.Glare = look.density, 0.1, look.haze, look.glare
			underGrade.Enabled, underBlur.Enabled = false, false
		end

		-- Life in the air round the player.
		local focus = camera.Focus.Position
		air.CFrame = CFrame.new(focus + Vector3.new(0, if underwater then -6 else 4, 0))
		local grassy = ground == Enum.Material.Grass or ground == Enum.Material.LeafyGrass or ground == Enum.Material.Ground
		local snowy = ground == Enum.Material.Snow or ground == Enum.Material.Glacier or ground == Enum.Material.Ice
		local outside = focus.Y > -4
		fx.pollen.Enabled = outside and not underwater and not night and grassy
		fx.leaves.Enabled = outside and not underwater and not night and grassy
		fx.fireflies.Enabled = outside and not underwater and night and (grassy or ground == Enum.Material.Mud)
		fx.snow.Enabled = outside and not underwater and snowy
		fx.embers.Enabled = not underwater and nearLava
		fx.bubbles.Enabled = underwater
		fx.motes.Enabled = underwater

		local shaftsOn = underwater and not night
		if shaftsOn and (shaftCentre == nil or (Vector3.new(focus.X, 0, focus.Z) - Vector3.new((shaftCentre :: Vector3).X, 0, (shaftCentre :: Vector3).Z)).Magnitude > 30) then
			placeShafts(focus)
		end
		for _, b in beams do
			b.Enabled = shaftsOn
		end
	end)
end

return Ambience
