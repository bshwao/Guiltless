-- Roblox's normal third-person orbit camera, with zoom kept outside the body.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer

local function useThirdPerson()
	player.CameraMode = Enum.CameraMode.Classic
	player.CameraMinZoomDistance = 6
	player.CameraMaxZoomDistance = 24
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
	player:SetAttribute("CrownlessCursorFree", false)
end

player.CharacterAdded:Connect(useThirdPerson)
useThirdPerson()
