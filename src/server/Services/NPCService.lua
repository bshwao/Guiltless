local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NPCDefinitions = require(Shared:WaitForChild("NPCDefinitions") :: ModuleScript)
local CombatService = require(script.Parent:WaitForChild("CombatService") :: ModuleScript)
local NPCService = {}

local function createAvatarNPC(definition, spawnCFrame: CFrame): Model?
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = Color3.fromRGB(202, 174, 143)
	description.TorsoColor = definition.Coat
	description.LeftArmColor = definition.Coat
	description.RightArmColor = definition.Coat
	description.LeftLegColor = Color3.fromRGB(58, 54, 47)
	description.RightLegColor = Color3.fromRGB(58, 54, 47)
	description.Shirt = 0
	description.Pants = 0
	description.GraphicTShirt = 0
	description.HatAccessory = ""
	description.HairAccessory = definition.HairAccessory or ""

	local ok, result = pcall(function()
		return Players:CreateHumanoidModelFromDescriptionAsync(
			description,
			Enum.HumanoidRigType.R6,
			Enum.AssetTypeVerification.Default
		)
	end)
	if not ok and description.HairAccessory ~= "" then
		-- A catalog hair asset failing to load must not keep the town NPC from spawning.
		description.HairAccessory = ""
		ok, result = pcall(function()
			return Players:CreateHumanoidModelFromDescriptionAsync(
				description,
				Enum.HumanoidRigType.R6,
				Enum.AssetTypeVerification.Default
			)
		end)
	end
	description:Destroy()
	if not ok or not result or not result:IsA("Model") then
		warn("Could not create the R6 avatar for " .. definition.Name .. ": " .. tostring(result))
		return nil
	end

	local character = result :: Model
	character.Name = definition.Name
	character:SetAttribute("CrownlessNPC", true)
	character:SetAttribute("CrownlessDialogueId", definition.Id)
	local humanoid = character:FindFirstChildOfClass("Humanoid")	
	local root = character:FindFirstChild("HumanoidRootPart")	
	if not humanoid or not root or not root:IsA("BasePart") then
		character:Destroy()
		warn("Generated avatar is missing its R6 Humanoid or root part: " .. definition.Name)
		return nil
	end

	humanoid.DisplayName = definition.Name
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.AutoRotate = false
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
		end
	end
	character.PrimaryPart = root
	character:PivotTo(spawnCFrame)
	return character
end

local function createTrainingPost(spawnCFrame: CFrame): Model
	local template = StarterPlayer:WaitForChild("StarterCharacter")
	assert(template:IsA("Model"), "Training targets need the source R6 StarterCharacter")
	local model = template:Clone()
	model.Name = "Training Dummy"
	model:SetAttribute("CrownlessNPC", false)
	model:SetAttribute("CrownlessEnemy", true)
	model:SetAttribute("CrownlessTrainingDummy", true)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	assert(root and humanoid, "R6 training rig is missing its root or Humanoid")
	-- Keep the complete neck/limb skeleton, anchoring only the root. A root-only
	-- model cannot behave as a valid Humanoid target.
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = descendant == root
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = descendant ~= root
			descendant.Material = Enum.Material.Wood
			descendant.Color = if descendant.Name == "Torso" then Color3.fromRGB(143, 89, 55) else Color3.fromRGB(170, 132, 88)
		elseif descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant:Destroy()
		end
	end
	model.PrimaryPart = root
	model:PivotTo(spawnCFrame * CFrame.new(0, 3, 0))
	humanoid.AutoRotate = false
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.MaxHealth = 300
	humanoid.Health = 300
	return model
end

local function addNameplate(model: Model, title: string, isDummy: boolean?)
	local head = model:FindFirstChild("Head") or model.PrimaryPart
	if not head or not head:IsA("BasePart") then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "CrownlessNameplate"
	gui.Size = UDim2.fromOffset(190, 38)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 1.5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 85
	gui.Adornee = head
	gui.Parent = head
	local text = Instance.new("TextLabel")
	text.Name = "Title"
	text.BackgroundColor3 = Color3.fromRGB(26, 25, 22)
	text.BackgroundTransparency = 0.16
	text.BorderSizePixel = 0
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamSemibold
	text.Text = title
	text.TextColor3 = if isDummy then Color3.fromRGB(198, 169, 116) else Color3.fromRGB(228, 216, 185)
	text.TextSize = 13
	text.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = text
	if isDummy then
		local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
		local fill = Instance.new("Frame")
		fill.Name = "HealthFill"
		fill.AnchorPoint = Vector2.new(0, 1)
		fill.Position = UDim2.new(0, 0, 1, 0)
		fill.Size = UDim2.new(1, 0, 0, 3)
		fill.BorderSizePixel = 0
		fill.BackgroundColor3 = Color3.fromRGB(174, 101, 65)
		fill.Parent = text
		local function updateHealth(health: number)
			text.Text = if health > 0 then string.format("PRACTICE · %d / %d", math.ceil(health), humanoid.MaxHealth) else "RESETTING…"
			fill.Size = UDim2.new(math.clamp(health / humanoid.MaxHealth, 0, 1), 0, 0, 3)
		end
		humanoid.HealthChanged:Connect(updateHealth)
		updateHealth(humanoid.Health)
	end
end

local function spawnTownsfolk()
	local worldModel = Workspace:WaitForChild("CrownlessWorld", 30)
	if not worldModel then
		warn("Crownless world model was not found; NPCs were not created.")
		return
	end
	local town = worldModel:WaitForChild("GreyfenTown", 15)
	local markerFolder = town and town:WaitForChild("NPCSpawnPoints", 10)
	if not markerFolder then
		warn("NPC spawn markers were not found; run tools/generate_world.py and sync the map.")
		return
	end
	local people = Workspace:FindFirstChild("GreyfenPeople") or Instance.new("Folder")
	people.Name = "GreyfenPeople"
	people.Parent = Workspace
	for id, definition in pairs(NPCDefinitions) do
		local marker = markerFolder:FindFirstChild(id)
		if marker and marker:IsA("BasePart") then
			local spawnAt = CFrame.new(marker.Position + Vector3.new(0, 3, 0)) * CFrame.Angles(0, math.rad(definition.Yaw or 180), 0)
			local avatarDefinition = table.clone(definition)
			avatarDefinition.Id = id
			local npc = createAvatarNPC(avatarDefinition, spawnAt)
			if npc then
				addNameplate(npc, definition.Title)
				local root = npc:FindFirstChild("HumanoidRootPart") :: BasePart
				local prompt = Instance.new("ProximityPrompt")
				prompt.Name = "NPCDialoguePrompt"
				prompt.ActionText = "Speak"
				prompt.ObjectText = definition.Name
				prompt.KeyboardKeyCode = Enum.KeyCode.E
				prompt.HoldDuration = 0
				prompt.MaxActivationDistance = 11
				prompt.RequiresLineOfSight = false
				prompt:SetAttribute("DialogueId", id)
				prompt.Parent = root
				npc.Parent = people
			end
		end
	end
end

local function spawnTrainingDummies()
	local worldModel = Workspace:WaitForChild("CrownlessWorld", 30)
	local town = worldModel and worldModel:WaitForChild("GreyfenTown", 15)
	local markers = town and town:WaitForChild("TrainingTargets", 10)
	if not markers then
		return
	end
	local targets = Workspace:FindFirstChild("GreyfenTrainingYard") or Instance.new("Folder")
	targets.Name = "GreyfenTrainingYard"
	targets.Parent = Workspace
	local function spawnTarget(marker: BasePart)
		if not marker.Parent or not targets.Parent then return end
		local target = createTrainingPost(CFrame.new(marker.Position))
		addNameplate(target, "PRACTICE TARGET", true)
		target.Parent = targets
		CollectionService:AddTag(target, "CrownlessEnemy")
		target.Destroying:Once(function() CombatService.ClearEnemy(target) end)
		local humanoid = target:FindFirstChildOfClass("Humanoid") :: Humanoid
		humanoid.Died:Once(function()
			CollectionService:RemoveTag(target, "CrownlessEnemy")
			task.delay(2, function()
				target:Destroy()
				-- Dead Humanoids do not revive by assigning Health. Replace the rig.
				spawnTarget(marker)
			end)
		end)
	end
	for _, marker in ipairs(markers:GetChildren()) do
		if marker:IsA("BasePart") then
			spawnTarget(marker)
		end
	end
end

function NPCService.Start()
	task.spawn(spawnTownsfolk)
	task.spawn(spawnTrainingDummies)
end

return NPCService
