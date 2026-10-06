-- Classic R6 locomotion and combat rendered for every player on each client.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Motion = require(script.Parent:WaitForChild("CharacterMotion") :: ModuleScript)

type Rig = {Humanoid: Humanoid, RootPart: BasePart, Motors: {[string]: Motor6D}, Phase: number, Speed: number}
local rigs: {[Model]: Rig} = setmetatable({}, {__mode = "k"})
local joints = {
	Root = {"HumanoidRootPart", "RootJoint"}, Neck = {"Torso", "Neck"},
	Right = {"Torso", "Right Shoulder"}, Left = {"Torso", "Left Shoulder"},
	RightHip = {"Torso", "Right Hip"}, LeftHip = {"Torso", "Left Hip"},
}

local function getRig(character: Model): Rig?
	local cached = rigs[character]
	if cached and cached.Humanoid.Parent == character and cached.RootPart.Parent == character then
		local valid = true
		for _, motor in pairs(cached.Motors) do
			if not motor:IsDescendantOf(character) or not motor.Part0 or not motor.Part1 then valid = false; break end
		end
		if valid then return cached end
	end
	-- Applying avatar cosmetics can rebuild body joints after the first frame.
	rigs[character] = nil
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R6 or not root or not root:IsA("BasePart") then return nil end
	local motors: {[string]: Motor6D} = {}
	for key, path in pairs(joints) do
		local part = character:FindFirstChild(path[1])
		local motor = part and part:FindFirstChild(path[2])
		if not motor or not motor:IsA("Motor6D") then return nil end
		motors[key] = motor
	end
	local rig: Rig = {Humanoid = humanoid, RootPart = root, Motors = motors, Phase = 0, Speed = 0}
	rigs[character] = rig
	return rig
end

local function bindPlayer(player: Player)
	player.CharacterRemoving:Connect(function(character)
		rigs[character] = nil
		Motion.Clear(player.UserId)
	end)
end
Players.PlayerAdded:Connect(bindPlayer)
for _, player in ipairs(Players:GetPlayers()) do bindPlayer(player) end

RunService.PreSimulation:Connect(function(dt: number)
	local now = os.clock()
	local blend = 1 - math.exp(-dt * 20)
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local rig = if character then getRig(character) else nil
		if not rig or rig.Humanoid.Health <= 0 then continue end
		local state = rig.Humanoid:GetState()
		local velocity = rig.RootPart.AssemblyLinearVelocity
		local speed = if state == Enum.HumanoidStateType.Climbing then math.abs(velocity.Y)
			else Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		rig.Speed += (speed - rig.Speed) * blend
		rig.Phase += dt * (if rig.Speed > 0.25 then 3.2 + rig.Speed * 0.42 else 0)
		local action, progress = Motion.Action(player.UserId)
		local pose = Motion.Combat(Motion.Locomotion(rig.Phase, rig.Speed, state, now), action, progress)
		for key, motor in pairs(rig.Motors) do
			-- Absolute poses in the joint's basis: never multiply yesterday's pose.
			local basis = motor.C0.Rotation
			local target = basis:Inverse() * pose[key] * basis
			motor.Transform = motor.Transform:Lerp(target, blend)
		end
	end
end)
