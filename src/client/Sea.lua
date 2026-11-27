-- Sea life that moves: the fish schools the server lays on the sea floor
-- (SeaFloor.school) circle and bob here, only near the camera.
local RunService = game:GetService("RunService")

local Sea = {}

function Sea.start()
	local schools: { Model } = {}
	local function scan()
		local bed = workspace:FindFirstChild("Seabed")
		if not bed then
			return
		end
		table.clear(schools)
		for _, m in bed:GetChildren() do
			if m.Name == "FishSchool" then
				table.insert(schools, m)
			end
		end
	end
	task.spawn(function()
		while true do
			scan()
			task.wait(10)
		end
	end)
	RunService.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		local eye = cam.CFrame.Position
		local now = os.clock()
		for _, m in schools do
			local centre = m:GetAttribute("Centre") :: Vector3?
			if centre and (centre - eye).Magnitude < 180 then
				local r = m:GetAttribute("Radius") or 8
				local speed = m:GetAttribute("Speed") or 0.4
				for _, f in m:GetChildren() do
					if f:IsA("Model") then
						local off = f:GetAttribute("Offset") or Vector3.zero
						local a = now * speed + (f:GetAttribute("Phase") or 0) * 0.2
						local p = centre + Vector3.new(math.cos(a) * r, math.sin(a * 2.3) * 1.2, math.sin(a) * r) + off
						-- Facing along the circle (the model faces -Z), with a little tail wag.
						local tangent = Vector3.new(-math.sin(a), 0, math.cos(a))
						f:PivotTo(CFrame.lookAt(p, p + tangent) * CFrame.Angles(0, math.sin(now * 9 + off.X) * 0.18, 0))
					end
				end
			end
		end
	end)
end

return Sea
