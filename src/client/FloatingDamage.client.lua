-- Only confirmed server hits create numbers. The invisible anchor stays at the
-- impact position even when a target moves, dies, or is replaced after practice.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local NetworkNames = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("NetworkNames") :: ModuleScript)
local damageRemote = ReplicatedStorage:WaitForChild(NetworkNames.Folder):WaitForChild(NetworkNames.DamageMeter) :: RemoteEvent
local random = Random.new()
local active: {BasePart} = {}

local function finite(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

damageRemote.OnClientEvent:Connect(function(hit)
	if type(hit) ~= "table" or not finite(hit.Amount) or hit.Amount <= 0
		or typeof(hit.Position) ~= "Vector3" or not finite(hit.DPS) then return end
	local position = hit.Position
	if not finite(position.X) or not finite(position.Y) or not finite(position.Z) then return end

	for index = #active, 1, -1 do
		if not active[index].Parent then table.remove(active, index) end
	end
	if #active >= 32 then table.remove(active, 1):Destroy() end

	local anchor = Instance.new("Part")
	anchor.Name = "CrownlessHitNumber"
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.Position = position + Vector3.new(random:NextNumber(-0.35, 0.35), 0.6, 0)
	anchor.Parent = workspace
	table.insert(active, anchor)
	Debris:AddItem(anchor, 1.35)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ImpactDamage"
	billboard.Adornee = anchor
	billboard.Size = UDim2.fromOffset(150, 64)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 160
	billboard.LightInfluence = 0
	billboard.Parent = player:WaitForChild("PlayerGui")
	Debris:AddItem(billboard, 1.35)

	local amount = Instance.new("TextLabel")
	amount.Name = "Damage"
	amount.Size = UDim2.new(1, 0, 0, 40)
	amount.BackgroundTransparency = 1
	amount.Font = Enum.Font.GothamBlack
	amount.TextSize = 30
	amount.Text = tostring(math.floor(hit.Amount + 0.5))
	amount.TextColor3 = Color3.fromRGB(255, 229, 175)
	amount.TextStrokeColor3 = Color3.fromRGB(31, 22, 17)
	amount.TextStrokeTransparency = 0.12
	amount.Parent = billboard

	local dps = Instance.new("TextLabel")
	dps.Name = "RollingDPS"
	dps.Position = UDim2.fromOffset(0, 38)
	dps.Size = UDim2.new(1, 0, 0, 18)
	dps.BackgroundTransparency = 1
	dps.Font = Enum.Font.GothamBold
	dps.TextSize = 11
	dps.Text = string.format("%.1f DPS", math.max(0, hit.DPS))
	dps.TextColor3 = Color3.fromRGB(240, 233, 212)
	dps.TextStrokeColor3 = Color3.fromRGB(22, 25, 23)
	dps.TextStrokeTransparency = 0.15
	dps.Parent = billboard

	TweenService:Create(anchor, TweenInfo.new(1.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = anchor.Position + Vector3.new(random:NextNumber(-0.6, 0.6), 2.2, 0),
	}):Play()
	local fade = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.75)
	TweenService:Create(amount, fade, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	TweenService:Create(dps, fade, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
end)
