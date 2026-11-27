-- Renders an item's 3D model inside a ViewportFrame so the UI shows real item pictures.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemModels = require(ReplicatedStorage:WaitForChild("Shared").ItemModels)

local Icons = {}

-- Building an item model is slow (meshes are put together from many parts), so each
-- item is built once, posed for its picture, and cloned for every icon after that.
local templates: { [string]: { model: Model, distance: number } } = {}
local FOV = 30

local function template(itemId: string)
	local t = templates[itemId]
	if t then
		return t
	end
	local model = ItemModels.build(itemId)
	local cf, extents = model:GetBoundingBox()
	-- Tilt it a little so it reads as 3D.
	local tilt = CFrame.Angles(math.rad(-20), math.rad(35), 0)
	model:PivotTo(tilt * (cf:Inverse() * model:GetPivot()))
	local radius = extents.Magnitude / 2
	t = { model = model, distance = radius / math.tan(math.rad(FOV / 2)) * 1.05 }
	templates[itemId] = t
	return t
end

function Icons.make(itemId: string, parent: GuiObject, size: UDim2?, position: UDim2?): ViewportFrame
	local vf = Instance.new("ViewportFrame")
	vf.Name = "Icon"
	vf.BackgroundTransparency = 1
	vf.Size = size or UDim2.fromScale(1, 1)
	vf.Position = position or UDim2.new()
	vf.Ambient = Color3.fromRGB(170, 170, 170)
	vf.LightColor = Color3.fromRGB(255, 250, 235)
	vf.LightDirection = Vector3.new(-1, -2, -1)

	local t = template(itemId)
	t.model:Clone().Parent = vf

	local camera = Instance.new("Camera")
	camera.FieldOfView = FOV
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, t.distance), Vector3.zero)
	camera.Parent = vf
	vf.CurrentCamera = camera
	vf.Parent = parent
	return vf
end

-- Slowly turns an icon's item round, with a gentle bob and a little tilt that rocks as
-- it turns (the selected hotbar item). Stops by itself when the icon goes away.
function Icons.spin(vf: ViewportFrame, speed: number?)
	local camera = vf.CurrentCamera
	if not camera then
		return
	end
	local dist = camera.CFrame.Position.Magnitude
	local t0 = os.clock()
	local conn
	conn = game:GetService("RunService").RenderStepped:Connect(function()
		if not vf.Parent then
			conn:Disconnect()
			return
		end
		local t = os.clock() - t0
		local a = t * (speed or 1.1)
		local pitch = math.rad(8 + math.sin(t * 1.7) * 6)
		local eye = Vector3.new(math.sin(a) * math.cos(pitch), math.sin(pitch), math.cos(a) * math.cos(pitch)) * dist
		local bob = Vector3.new(0, math.sin(t * 2.4) * dist * 0.03, 0)
		camera.CFrame = CFrame.lookAt(eye + bob, bob)
	end)
end

return Icons
