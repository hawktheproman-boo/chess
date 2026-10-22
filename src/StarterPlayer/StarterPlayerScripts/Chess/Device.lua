-- Which input the player used last: "mouse" (keyboard + mouse), "touch" or "pad". The HUD swaps its
-- control hints on Changed. (Descent Depths' ReplicatedFirst/Input.lua does the same for keyboard /
-- controller; this one adds touch.)

local UserInputService = game:GetService("UserInputService")

local Device = {}

local changed = Instance.new("BindableEvent")
Device.Changed = changed.Event

local function classify(kind)
	if kind == Enum.UserInputType.Touch then
		return "touch"
	elseif string.find(kind.Name, "Gamepad") then
		return "pad"
	elseif kind == Enum.UserInputType.Keyboard or string.find(kind.Name, "Mouse") then
		return "mouse"
	end
	return nil
end

Device.current = classify(UserInputService:GetLastInputType())
	or (if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then "touch" else "mouse")

UserInputService.LastInputTypeChanged:Connect(function(kind)
	local d = classify(kind)
	if d and d ~= Device.current then
		Device.current = d
		changed:Fire(d)
	end
end)

return Device
