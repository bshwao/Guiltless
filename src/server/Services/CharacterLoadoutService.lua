local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AbilityDefinitions = require(Shared:WaitForChild("AbilityDefinitions") :: ModuleScript)
local EquipmentService = require(script.Parent:WaitForChild("EquipmentService") :: ModuleScript)
local CharacterLoadoutService = {}
local boundPlayers: { [Player]: boolean } = {}
local roleRequestTimes: {[Player]: number} = {}

local function classicAppearance(source: HumanoidDescription): HumanoidDescription
	-- Only copy cosmetics that work on our source-managed R6 skeleton. Body
	-- packages, layered clothing, dynamic heads and avatar animation packs are
	-- deliberately omitted so they cannot replace the game's rig or movement.
	local description = Instance.new("HumanoidDescription")
	description.UseAvatarSettings = false
	description.HeadColor = source.HeadColor
	description.TorsoColor = source.TorsoColor
	description.LeftArmColor = source.LeftArmColor
	description.RightArmColor = source.RightArmColor
	description.LeftLegColor = source.LeftLegColor
	description.RightLegColor = source.RightLegColor
	description.Face = source.Face
	description.Shirt = source.Shirt
	description.Pants = source.Pants
	description.GraphicTShirt = source.GraphicTShirt
	description.HatAccessory = source.HatAccessory
	description.HairAccessory = source.HairAccessory
	description.FaceAccessory = source.FaceAccessory
	description.NeckAccessory = source.NeckAccessory
	description.ShouldersAccessory = source.ShouldersAccessory
	description.FrontAccessory = source.FrontAccessory
	description.BackAccessory = source.BackAccessory
	description.WaistAccessory = source.WaistAccessory
	return description
end

local function applyCharacter(player: Player, character: Model)
	EquipmentService.ApplyCharacter(player, character)
end

local function bindPlayer(player: Player)
	if boundPlayers[player] then
		return
	end
	boundPlayers[player] = true
	if not player:GetAttribute("CrownlessPreferredRole") then
		player:SetAttribute("CrownlessPreferredRole", AbilityDefinitions.DefaultRole)
	end
	local generation = 0
	local preparingCharacter: Model? = nil
	local readyCharacter: Model? = nil
	local queued = false
	local function queueApply()
		if queued then
			return
		end
		queued = true
		task.defer(function()
			queued = false
			local character = readyCharacter
			if character and character == player.Character then
				applyCharacter(player, character)
			end
		end)
	end
	local function prepareCharacter(character: Model)
		if preparingCharacter == character then
			return
		end
		generation += 1
		local thisGeneration = generation
		preparingCharacter = character
		readyCharacter = nil
		character:SetAttribute("CrownlessAppearanceReady", false)
		player:SetAttribute("CrownlessEquipmentReady", false)
		local function isCurrent(): boolean
			return generation == thisGeneration and player.Parent == Players and player.Character == character
		end
		task.spawn(function()
			local humanoid = character:WaitForChild("Humanoid", 10)
			if not isCurrent() or not humanoid or not humanoid:IsA("Humanoid") then
				return
			end
			-- CharacterAdded may fire before the model enters Workspace. Applying
			-- a description needs the fully parented character, not a fixed delay.
			local deadline = os.clock() + 10
			while isCurrent() and not character:IsDescendantOf(workspace) and os.clock() < deadline do
				task.wait(0.05)
			end
			if not isCurrent() or not character:IsDescendantOf(workspace) then
				return
			end
			if humanoid.RigType ~= Enum.HumanoidRigType.R6 then
				warn("Crownless requires the R6 StarterCharacter from default.project.json; sync the complete project.")
				return
			end
			humanoid.DisplayName = player.DisplayName
			local ok, source = pcall(function()
				return Players:GetHumanoidDescriptionFromUserIdAsync(player.UserId)
			end)
			if not isCurrent() then
				if ok and typeof(source) == "Instance" then
					source:Destroy()
				end
				return
			end
			if ok and typeof(source) == "Instance" and source:IsA("HumanoidDescription") then
				local description = classicAppearance(source)
				source:Destroy()
				local applied, reason = pcall(function()
					humanoid:ApplyDescriptionResetAsync(description)
				end)
				description:Destroy()
				if not applied and isCurrent() then
					warn("Crownless kept the R6 fallback appearance for " .. player.Name .. ": " .. tostring(reason))
				end
			elseif isCurrent() then
				warn("Crownless could not load avatar cosmetics for " .. player.Name .. "; using the R6 starter appearance.")
			end
			if not isCurrent() or not character:IsDescendantOf(workspace) or humanoid.Health <= 0 then
				return
			end
			-- Role changes during the yield are picked up by applyCharacter here.
			-- Equipment must follow ApplyDescription so Roblox cannot remove it.
			character:SetAttribute("CrownlessAppearanceReady", true)
			readyCharacter = character
			applyCharacter(player, character)
		end)
	end
	player.CharacterAdded:Connect(prepareCharacter)
	player.CharacterRemoving:Connect(function(character)
		EquipmentService.ClearCharacter(player, character)
		if preparingCharacter == character then
			generation += 1
			preparingCharacter = nil
			readyCharacter = nil
		end
	end)
	player:GetAttributeChangedSignal("CrownlessRole"):Connect(queueApply)
	player:GetAttributeChangedSignal("CrownlessPreferredRole"):Connect(queueApply)
	if player.Character then
		prepareCharacter(player.Character)
	end
end


function CharacterLoadoutService.Start(setRoleRemote: RemoteEvent, equipRemote: RemoteEvent, equipmentFeedback: RemoteEvent)
	EquipmentService.Init(equipRemote, equipmentFeedback)
	setRoleRemote.OnServerEvent:Connect(function(player, role)
		if player.Parent ~= Players or type(role) ~= "string" or not AbilityDefinitions.Roles[role] then
			return
		end
		local now = os.clock()
		if now - (roleRequestTimes[player] or 0) < 0.5 then return end
		roleRequestTimes[player] = now
		player:SetAttribute("CrownlessPreferredRole", role)
		if not player:GetAttribute("CrownlessPartyId") then
			player:SetAttribute("CrownlessRole", role)
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		bindPlayer(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		boundPlayers[player] = nil
		roleRequestTimes[player] = nil
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		bindPlayer(player)
	end
end

return CharacterLoadoutService
