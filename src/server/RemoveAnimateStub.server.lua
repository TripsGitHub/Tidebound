-- Older versions of the project put an empty "Animate" script in
-- StarterCharacterScripts to switch off Roblox's default walk/idle/jump animations.
-- The game uses the default animations again now, but a place saved back then can
-- still hold that stub, which stops Roblox adding its real Animate script (no walk
-- animation). Remove it if it's there. The real one has StringValue children
-- ("walk", "idle", ...); the stub has none.
local StarterPlayer = game:GetService("StarterPlayer")

local scripts = StarterPlayer:FindFirstChild("StarterCharacterScripts")
local stub = scripts and scripts:FindFirstChild("Animate")
if stub and not stub:FindFirstChild("walk") and not stub:FindFirstChild("idle") then
	stub:Destroy()
	print("[Tidebound] Removed the old empty Animate script so walking animates again")
end
