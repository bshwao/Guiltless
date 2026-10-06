local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Definitions = require(Shared:WaitForChild("EquipmentDefinitions") :: ModuleScript)
local Assets = ReplicatedStorage:WaitForChild("Assets")
local Weapons = Assets:WaitForChild("Weapons")
local Armor = Assets:WaitForChild("Armor")
local Offhands = Assets:WaitForChild("Offhands")

type State = { Role: string, Character: Model?, Tool: Tool?, WantWeapon: boolean, WantArmor: boolean }
local states: {[Player]: State} = {}
local requestTimes: {[Player]: number} = {}
local EquipmentService = {}

local function roleOf(player: Player): string
	local role = player:GetAttribute("CrownlessRole") or player:GetAttribute("CrownlessPreferredRole") or "Damage"
	return if type(role) == "string" and Definitions.RoleItems[role] then role else "Damage"
end

local function removeModel(character: Model, name: string)
	local old = character:FindFirstChild(name)
	if old then old:Destroy() end
end

local function attachModel(character: Model, template: Model, target: BasePart, name: string, itemId: string?): Model
	local model = template:Clone()
	model.Name = name
	model:SetAttribute("CrownlessItemId", itemId)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			-- Armor source positions are offsets from the R6 torso; shield
			-- source positions are offsets from the left arm.
			part.CFrame = target.CFrame * part.CFrame
			part.Anchored = false
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = target
			weld.Part1 = part
			weld.Parent = part
		end
	end
	model.Parent = character
	return model
end

function EquipmentService.GetEquippedWeapon(player: Player): Tool?
	local state = states[player]
	local character = player.Character
	if not state or not character or state.Character ~= character or state.Role ~= roleOf(player)
		or character:GetAttribute("CrownlessAppearanceReady") ~= true then return nil end
	local tool = state.Tool
	return if tool and tool.Parent == character then tool else nil
end

local function refresh(player: Player, state: State)
	if states[player] ~= state then return end
	local character = player.Character
	local weapon = EquipmentService.GetEquippedWeapon(player)
	local ids = Definitions.RoleItems[state.Role]
	local armor = character and character:FindFirstChild("CrownlessEquipment")
	local hasArmor = state.Character == character and state.Role == roleOf(player)
		and armor ~= nil and armor:GetAttribute("CrownlessItemId") == ids.Armor
	player:SetAttribute("CrownlessEquippedWeapon", if weapon then ids.Weapon else "")
	player:SetAttribute("CrownlessEquippedArmor", if hasArmor then ids.Armor else "")
	player:SetAttribute("CrownlessArmorRating", if hasArmor then Definitions.Items[ids.Armor].ArmorRating else 0)
	if character then
		removeModel(character, "CrownlessOffhand")
		local offhandName = if weapon then Definitions.Items[ids.Weapon].Offhand else nil
		local arm = character:FindFirstChild("Left Arm")
		local template = offhandName and Offhands:FindFirstChild(offhandName)
		if arm and arm:IsA("BasePart") and template and template:IsA("Model") then
			attachModel(character, template, arm, "CrownlessOffhand", nil)
		end
	end
end

local function clearTool(state: State)
	local old = state.Tool
	state.Tool = nil
	if old then old:Destroy() end
end

function EquipmentService.ClearCharacter(player: Player, character: Model)
	local state = states[player]
	if state and state.Character == character then
		clearTool(state)
		state.Character = nil
	end
	player:SetAttribute("CrownlessEquippedWeapon", "")
	player:SetAttribute("CrownlessEquippedArmor", "")
	player:SetAttribute("CrownlessArmorRating", 0)
	player:SetAttribute("CrownlessEquipmentReady", false)
end

function EquipmentService.ApplyCharacter(player: Player, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local torso = character:FindFirstChild("Torso")
	local backpack = player:FindFirstChildOfClass("Backpack")
	if player.Parent ~= Players or player.Character ~= character or not backpack
		or not humanoid or humanoid.Health <= 0 or not torso or not torso:IsA("BasePart")
		or character:GetAttribute("CrownlessAppearanceReady") ~= true then return end
	local role = roleOf(player)
	local state = states[player]
	if not state then
		state = {Role = role, Character = nil, Tool = nil, WantWeapon = true, WantArmor = true}
		states[player] = state
	end
	if state.Role ~= role then
		clearTool(state)
		state.Role = role
		state.WantWeapon, state.WantArmor = true, true
	end
	if state.Character ~= character then
		clearTool(state)
		state.Character = character
	end
	local ids = Definitions.RoleItems[role]
	if not state.Tool or not state.Tool.Parent then
		local template = Weapons:FindFirstChild(Definitions.Items[ids.Weapon].Asset)
		if not template or not template:IsA("Tool") or not template:FindFirstChild("Handle") then
			warn("Missing Crownless Tool asset for " .. role)
			return
		end
		-- Only this role's weapon is granted. Other role Tools are removed when
		-- the role changes, rather than accumulating in the player's Backpack.
		for _, container in ipairs({character, backpack}) do
			for _, child in ipairs(container:GetChildren()) do
				if child:IsA("Tool") and child:GetAttribute("CrownlessEquipmentTool") then child:Destroy() end
			end
		end
		local tool = template:Clone()
		tool.Name = Definitions.Items[ids.Weapon].Name
		tool:SetAttribute("CrownlessEquipmentTool", true)
		tool:SetAttribute("CrownlessItemId", ids.Weapon)
		tool:SetAttribute("CrownlessRole", role)
		tool.CanBeDropped = false
		-- Our action bar owns 1–4 and click input, preventing duplicate casts
		-- from Roblox's Tool activation binding.
		tool.ManualActivationOnly = true
		state.Tool = tool
		tool.Equipped:Connect(function()
			if state.Tool ~= tool then return end
			state.WantWeapon = true
			refresh(player, state)
		end)
		tool.Unequipped:Connect(function()
			if state.Tool ~= tool then return end
			if humanoid.Health > 0 then state.WantWeapon = false end
			refresh(player, state)
		end)
		tool.AncestryChanged:Connect(function()
			task.defer(function()
				if state.Tool == tool then refresh(player, state) end
			end)
		end)
		tool.Parent = backpack
	end
	removeModel(character, "CrownlessEquipment")
	if state.WantArmor then
		local template = Armor:FindFirstChild(Definitions.Items[ids.Armor].Asset)
		if template and template:IsA("Model") then
			attachModel(character, template, torso, "CrownlessEquipment", ids.Armor)
		end
	end
	local tool = state.Tool
	if tool then
		if state.WantWeapon and tool.Parent ~= character then humanoid:EquipTool(tool)
		elseif not state.WantWeapon and tool.Parent == character then humanoid:UnequipTools() end
	end
	refresh(player, state)
	player:SetAttribute("CrownlessEquipmentReady", true)
end

function EquipmentService.Init(equipRemote: RemoteEvent, feedbackRemote: RemoteEvent)
	equipRemote.OnServerEvent:Connect(function(player: Player, itemId: any, equip: any)
		if player.Parent ~= Players or type(itemId) ~= "string" or #itemId > 64 or type(equip) ~= "boolean" then return end
		local now = os.clock()
		if now - (requestTimes[player] or 0) < 0.15 then return end
		requestTimes[player] = now
		local item = Definitions.Items[itemId]
		local state = states[player]
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local message: string? = nil
		if not item or item.Role ~= roleOf(player) then message = "That item is not available to your current role."
		elseif not state or state.Role ~= roleOf(player) or state.Character ~= character
			or not character or not humanoid or humanoid.Health <= 0
			or character:GetAttribute("CrownlessAppearanceReady") ~= true then
			message = "Your character is still preparing. Try again shortly."
		end
		if message then
			feedbackRemote:FireClient(player, {Success = false, Message = message})
			return
		end
		if not state or not character or not item then return end
		if item.Slot == "Weapon" then state.WantWeapon = equip else state.WantArmor = equip end
		EquipmentService.ApplyCharacter(player, character)
		local attribute = if item.Slot == "Weapon" then "CrownlessEquippedWeapon" else "CrownlessEquippedArmor"
		local success = (player:GetAttribute(attribute) == item.Id) == equip
		feedbackRemote:FireClient(player, {
			Success = success,
			Message = if success then item.Name .. (if equip then " equipped." else " unequipped.") else "The item could not be equipped. Sync the complete assets folder.",
		})
	end)
	Players.PlayerRemoving:Connect(function(player)
		local state = states[player]
		if state then clearTool(state) end
		states[player], requestTimes[player] = nil, nil
	end)
end

return EquipmentService
