-- Works out where the player is pointing (mouse on PC, last tap on mobile).
local UserInputService = game:GetService("UserInputService")

local Pointer = {}
local lastTouch: Vector3? = nil

function Pointer.setTouch(position: Vector3?)
	lastTouch = position
end

function Pointer.ray(): Ray
	local camera = workspace.CurrentCamera
	if lastTouch then
		return camera:ScreenPointToRay(lastTouch.X, lastTouch.Y)
	end
	local mouse = UserInputService:GetMouseLocation()
	return camera:ViewportPointToRay(mouse.X, mouse.Y)
end

function Pointer.cast(exclude: { Instance }, distance: number?): RaycastResult?
	local ray = Pointer.ray()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	return workspace:Raycast(ray.Origin, ray.Direction * (distance or 250), params)
end

return Pointer
