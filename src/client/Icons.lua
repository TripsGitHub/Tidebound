-- Renders an item's 3D model inside a ViewportFrame so the UI shows real item pictures.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemModels = require(ReplicatedStorage:WaitForChild("Shared").ItemModels)

local Icons = {}

function Icons.make(itemId: string, parent: GuiObject, size: UDim2?, position: UDim2?): ViewportFrame
	local vf = Instance.new("ViewportFrame")
	vf.Name = "Icon"
	vf.BackgroundTransparency = 1
	vf.Size = size or UDim2.fromScale(1, 1)
	vf.Position = position or UDim2.new()
	vf.Ambient = Color3.fromRGB(170, 170, 170)
	vf.LightColor = Color3.fromRGB(255, 250, 235)
	vf.LightDirection = Vector3.new(-1, -2, -1)

	local model = ItemModels.build(itemId)
	local cf, extents = model:GetBoundingBox()
	-- Tilt it a little so it reads as 3D.
	local tilt = CFrame.Angles(math.rad(-20), math.rad(35), 0)
	model:PivotTo(tilt * (cf:Inverse() * model:GetPivot()))
	model.Parent = vf

	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	local radius = extents.Magnitude / 2
	local distance = radius / math.tan(math.rad(camera.FieldOfView / 2)) * 1.05
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, distance), Vector3.zero)
	camera.Parent = vf
	vf.CurrentCamera = camera
	vf.Parent = parent
	return vf
end

return Icons
