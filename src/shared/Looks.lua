-- Tidebound's own castaway avatars. Every player is drawn from these parts instead of
-- their Roblox avatar, so the island has one look: blocky castaways in sun-bleached
-- sailcloth, rope and dyed cloth. A look is a table of indices into each list.
local Looks = {}

export type Look = { skin: number, hair: number, hairColor: number, outfit: number, dye: number, paint: number }

Looks.OPTIONS = {
	skin = {
		{ name = "Tone 1", color = Color3.fromRGB(255, 224, 189) },
		{ name = "Tone 2", color = Color3.fromRGB(241, 194, 150) },
		{ name = "Tone 3", color = Color3.fromRGB(214, 160, 118) },
		{ name = "Tone 4", color = Color3.fromRGB(176, 120, 82) },
		{ name = "Tone 5", color = Color3.fromRGB(130, 86, 58) },
		{ name = "Tone 6", color = Color3.fromRGB(92, 60, 42) },
	},
	hair = {
		{ name = "Shaggy" },
		{ name = "Topknot" },
		{ name = "Braids" },
		{ name = "Buzz" },
		{ name = "Bald" },
	},
	hairColor = {
		{ name = "Black", color = Color3.fromRGB(34, 28, 26) },
		{ name = "Brown", color = Color3.fromRGB(92, 60, 36) },
		{ name = "Sun-bleached", color = Color3.fromRGB(214, 180, 110) },
		{ name = "Rust", color = Color3.fromRGB(150, 64, 34) },
		{ name = "Grey", color = Color3.fromRGB(170, 166, 160) },
	},
	outfit = {
		{ name = "Castaway" }, -- dyed sailcloth shirt, canvas shorts, rope belt
		{ name = "Islander" }, -- bare chest, cloth sash, wrap skirt, shell necklace
		{ name = "Voyager" }, -- canvas shirt, dyed vest, dark trousers, belt
	},
	dye = {
		{ name = "Sea", color = Color3.fromRGB(52, 120, 150) },
		{ name = "Kelp", color = Color3.fromRGB(84, 120, 60) },
		{ name = "Coral", color = Color3.fromRGB(210, 96, 80) },
		{ name = "Sand", color = Color3.fromRGB(210, 180, 120) },
		{ name = "Dusk", color = Color3.fromRGB(110, 80, 140) },
		{ name = "Ember", color = Color3.fromRGB(200, 120, 40) },
	},
	paint = {
		{ name = "None" },
		{ name = "Cheek stripes" },
		{ name = "Eye band" },
		{ name = "Chin dots" },
	},
}

-- The order the customise screen lists them in, with the label it shows.
Looks.ROWS = {
	{ key = "skin", label = "Skin" },
	{ key = "hair", label = "Hair" },
	{ key = "hairColor", label = "Hair colour" },
	{ key = "outfit", label = "Outfit" },
	{ key = "dye", label = "Dye" },
	{ key = "paint", label = "Face paint" },
}

-- Fixed colours shared by every outfit.
Looks.CANVAS = Color3.fromRGB(222, 208, 170) -- sun-bleached sailcloth
Looks.ROPE = Color3.fromRGB(150, 112, 70)
Looks.LEATHER = Color3.fromRGB(96, 64, 40)
Looks.TROUSERS = Color3.fromRGB(78, 62, 48)
Looks.SHELL = Color3.fromRGB(246, 238, 220)
Looks.EYES = Color3.fromRGB(30, 26, 24)
Looks.MOUTH = Color3.fromRGB(110, 56, 44)
Looks.OCHRE = Color3.fromRGB(176, 62, 40) -- face paint on lighter skin
Looks.CLAY = Color3.fromRGB(240, 236, 226) -- face paint on darker skin

function Looks.random(rng: Random?): Look
	local r = rng or Random.new()
	local look = {}
	for key, list in Looks.OPTIONS do
		look[key] = r:NextInteger(1, #list)
	end
	-- Most castaways start without paint; it reads as a choice, not noise.
	if r:NextNumber() < 0.6 then
		look.paint = 1
	end
	return look :: any
end

-- Clamps anything a client sends to valid indices.
function Looks.sanitize(raw: any): Look?
	if type(raw) ~= "table" then
		return nil
	end
	local look = {}
	for key, list in Looks.OPTIONS do
		local v = raw[key]
		if type(v) ~= "number" or v ~= v then
			return nil
		end
		look[key] = math.clamp(math.floor(v), 1, #list)
	end
	return look :: any
end

return Looks
