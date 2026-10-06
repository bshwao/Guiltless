-- Procedural R6 movement and combat, rendered for all players on each client.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local names = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("NetworkNames") :: ModuleScript)
local remote = ReplicatedStorage:WaitForChild(names.Folder):WaitForChild(names.ActionAnimation) :: RemoteEvent

export type Action = {Started: number, Duration: number, Kind: string, Tint: Color3, Variant: number}
export type Pose = {[string]: CFrame}
local Motion = {}
local actions: {[number]: Action} = {}
local variants: {[number]: number} = {}
local durations: {[string]: number} = {attack = 0.6, spell = 0.9, guard = 0.8, shout = 0.75}

local function smooth(value: number): number
	local t = math.clamp(value, 0, 1)
	return t * t * (3 - 2 * t)
end

function Motion.Neutral(): Pose
	return {Root = CFrame.identity, Neck = CFrame.identity, Right = CFrame.identity,
		Left = CFrame.identity, RightHip = CFrame.identity, LeftHip = CFrame.identity}
end

function Motion.Action(userId: number): (Action?, number)
	local action = actions[userId]
	if not action then return nil, 0 end
	local progress = (os.clock() - action.Started) / action.Duration
	if progress >= 1 then
		actions[userId] = nil
		return nil, 0
	end
	return action, math.clamp(progress, 0, 1)
end

function Motion.Clear(userId: number)
	actions[userId] = nil
end

function Motion.Locomotion(phase: number, speed: number, state: Enum.HumanoidStateType, now: number): Pose
	local pose = Motion.Neutral()
	local breath = math.sin(now * 1.8)
	local weight = math.clamp(speed / 16, 0, 1.45)
	local stride = math.sin(phase) * math.min(weight * 0.68, 0.95)
	local sway = math.cos(phase) * weight
	pose.Root = CFrame.new(0, math.abs(math.sin(phase)) * 0.065 * weight, 0) * CFrame.Angles(-0.055 * weight, 0, sway * 0.025)
	pose.Neck = CFrame.Angles(0.02 * breath + 0.035 * weight, -sway * 0.025, 0)
	pose.Right = CFrame.Angles(stride + 0.08 + breath * 0.018, 0, -0.045)
	pose.Left = CFrame.Angles(-stride + 0.03 + breath * 0.018, 0, 0.045)
	pose.RightHip = CFrame.Angles(-stride, 0, 0)
	pose.LeftHip = CFrame.Angles(stride, 0, 0)
	if state == Enum.HumanoidStateType.Jumping then
		pose.Right = CFrame.Angles(-0.35, 0, -0.38)
		pose.Left = CFrame.Angles(-0.35, 0, 0.38)
		pose.RightHip = CFrame.Angles(0.5, 0, 0)
		pose.LeftHip = CFrame.Angles(-0.25, 0, 0)
		pose.Root = CFrame.Angles(-0.1, 0, 0)
	elseif state == Enum.HumanoidStateType.Freefall then
		pose.Right = CFrame.Angles(0.18, 0, -0.55)
		pose.Left = CFrame.Angles(0.18, 0, 0.55)
		pose.RightHip = CFrame.Angles(-0.18, 0, -0.06)
		pose.LeftHip = CFrame.Angles(0.22, 0, 0.06)
	elseif state == Enum.HumanoidStateType.Climbing then
		pose.Right = CFrame.Angles(2.1 + math.sin(phase) * 0.5, 0, -0.1)
		pose.Left = CFrame.Angles(2.1 - math.sin(phase) * 0.5, 0, 0.1)
		pose.RightHip = CFrame.Angles(-stride * 0.8, 0, 0)
		pose.LeftHip = CFrame.Angles(stride * 0.8, 0, 0)
	elseif state == Enum.HumanoidStateType.Swimming then
		pose.Root = CFrame.Angles(-0.25, 0, 0)
		pose.Right = CFrame.Angles(1.5 + math.sin(phase) * 0.8, 0, -0.2)
		pose.Left = CFrame.Angles(1.5 - math.sin(phase) * 0.8, 0, 0.2)
		pose.RightHip = CFrame.Angles(stride * 0.4, 0, 0)
		pose.LeftHip = CFrame.Angles(-stride * 0.4, 0, 0)
	elseif state == Enum.HumanoidStateType.Seated then
		pose = Motion.Neutral()
		pose.RightHip = CFrame.Angles(math.pi / 2, 0, 0)
		pose.LeftHip = CFrame.Angles(math.pi / 2, 0, 0)
		pose.Right = CFrame.Angles(0.2, 0, -0.08)
		pose.Left = CFrame.Angles(0.2, 0, 0.08)
	end
	return pose
end

function Motion.Combat(base: Pose, action: Action?, progress: number): Pose
	if not action then return base end
	local fade = smooth(progress / 0.14) * (1 - smooth((progress - 0.72) / 0.28))
	local pose = Motion.Neutral()
	if action.Kind == "spell" then
		local release = smooth((progress - 0.34) / 0.2)
		pose.Right = CFrame.Angles(0.85 + release * 0.85, 0.1, -0.28)
		pose.Left = CFrame.Angles(1.05 + release * 0.55, -0.1, 0.28)
		pose.Root = CFrame.Angles(-0.08 + release * 0.12, -0.13, 0)
		pose.Neck = CFrame.Angles(0, 0.13, 0)
	elseif action.Kind == "guard" then
		pose.Right = CFrame.Angles(1.15, -0.25, -0.25)
		pose.Left = CFrame.Angles(1.45, 0.45, 0.32)
		pose.Root = CFrame.Angles(-0.12, 0.18, 0)
		pose.Neck = CFrame.Angles(0.12, -0.18, 0)
	elseif action.Kind == "shout" then
		pose.Right = CFrame.Angles(2.35, 0, -0.28)
		pose.Left = CFrame.Angles(0.35, 0, 0.35)
		pose.Root = CFrame.Angles(0.12, 0, 0)
		pose.Neck = CFrame.Angles(-0.12, 0, 0)
	else
		-- Wind-up, fast contact, longer recovery; alternate diagonal cuts.
		local strike = smooth((progress - 0.27) / 0.2)
		local side = if action.Variant % 2 == 0 then -1 else 1
		pose.Right = CFrame.Angles(2.55 - strike * 1.6, side * (0.28 - strike * 0.65), -0.48 + strike * 0.7)
		pose.Left = CFrame.Angles(0.3 + strike * 0.35, 0, 0.16)
		pose.Root = CFrame.Angles(-0.04 + strike * 0.12, side * (-0.35 + strike * 0.65), 0)
		pose.Neck = CFrame.Angles(0, side * (0.2 - strike * 0.35), 0)
	end
	return {
		Root = base.Root:Lerp(base.Root * pose.Root, fade), Neck = base.Neck:Lerp(pose.Neck, fade),
		Right = base.Right:Lerp(pose.Right, fade), Left = base.Left:Lerp(pose.Left, fade),
		RightHip = base.RightHip, LeftHip = base.LeftHip,
	}
end

-- Camera-space hand offsets use the same server-confirmed action clock.
function Motion.Hands(action: Action?, progress: number): (CFrame, CFrame, number)
	local right, left, glow = CFrame.identity, CFrame.identity, 0
	if not action then return right, left, glow end
	local fade = smooth(progress / 0.12) * (1 - smooth((progress - 0.65) / 0.35))
	if action.Kind == "spell" then
		local release = smooth((progress - 0.35) / 0.18)
		right = CFrame.new(-0.12, 0.2, -release * 0.55) * CFrame.Angles(0.15, -0.12, 0.12)
		left = CFrame.new(0.22, 0.3, -release * 0.65) * CFrame.Angles(0.2, 0.18, -0.12)
		glow = math.sin(progress * math.pi) * fade
	elseif action.Kind == "guard" then
		right = CFrame.new(-0.28, 0.2, 0.12) * CFrame.Angles(0.22, -0.45, -0.16)
		left = CFrame.new(0.35, 0.4, -0.2) * CFrame.Angles(0.3, 0.35, 0.28)
	elseif action.Kind == "shout" then
		right = CFrame.new(0.04, 0.6, -0.2) * CFrame.Angles(-0.25, 0, 0.25)
		left = CFrame.new(-0.08, 0.15, 0)
	else
		local strike = smooth((progress - 0.27) / 0.2)
		local side = if action.Variant % 2 == 0 then -1 else 1
		right = CFrame.new(side * (0.22 - strike * 0.8), 0.5 - strike * 0.75, 0.2 - strike * 0.75)
			* CFrame.Angles(-0.75 + strike * 1.2, side * (0.35 - strike * 0.85), side * (-0.45 + strike * 0.9))
		left = CFrame.new(0.05, 0.08, -0.1 * strike)
	end
	return CFrame.identity:Lerp(right, fade), CFrame.identity:Lerp(left, fade), glow
end

remote.OnClientEvent:Connect(function(userId: number, kind: string, tint: Color3?, animationDuration: number?)
	if type(userId) ~= "number" or type(kind) ~= "string" or not durations[kind] then return end
	variants[userId] = (variants[userId] or 0) + 1
	actions[userId] = {
		Started = os.clock(), Duration = if type(animationDuration) == "number" and animationDuration == animationDuration then math.clamp(animationDuration, 0.15, 1.5) else durations[kind], Kind = kind,
		Tint = if typeof(tint) == "Color3" then tint else Color3.fromRGB(170, 209, 193),
		Variant = variants[userId],
	}
end)
Players.PlayerRemoving:Connect(function(player)
	actions[player.UserId], variants[player.UserId] = nil, nil
end)
return Motion
