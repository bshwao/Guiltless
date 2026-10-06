-- Crownless's shared hub HUD and four-role group finder.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local SoundService = game:GetService("SoundService")
local TextChatService = game:GetService("TextChatService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig") :: ModuleScript)
local NetworkNames = require(Shared:WaitForChild("NetworkNames") :: ModuleScript)
local AbilityDefinitions = require(Shared:WaitForChild("AbilityDefinitions") :: ModuleScript)
local EquipmentDefinitions = require(Shared:WaitForChild("EquipmentDefinitions") :: ModuleScript)
local assets = ReplicatedStorage:WaitForChild("Assets")
local NPCDefinitions = require(Shared:WaitForChild("NPCDefinitions") :: ModuleScript)
local remotes = ReplicatedStorage:WaitForChild(NetworkNames.Folder)
local queueRemote = remotes:WaitForChild(NetworkNames.QueueForRole) :: RemoteEvent
local leaveRemote = remotes:WaitForChild(NetworkNames.LeaveQueue) :: RemoteEvent
local partyStateRemote = remotes:WaitForChild(NetworkNames.PartyState) :: RemoteEvent
local getPartyState = remotes:WaitForChild(NetworkNames.GetPartyState) :: RemoteFunction
local useAbilityRemote = remotes:WaitForChild(NetworkNames.UseAbility) :: RemoteEvent
local abilityFeedbackRemote = remotes:WaitForChild(NetworkNames.AbilityFeedback) :: RemoteEvent
local setPreferredRoleRemote = remotes:WaitForChild(NetworkNames.SetPreferredRole) :: RemoteEvent
local equipItemRemote = remotes:WaitForChild(NetworkNames.EquipItem) :: RemoteEvent
local equipmentFeedbackRemote = remotes:WaitForChild(NetworkNames.EquipmentFeedback) :: RemoteEvent
local actionCooldownEnds: {[string]: number} = {}
local mouse = player:GetMouse()

local function requestAbility(abilityId: string)
	if UserInputService:GetFocusedTextBox() or player:GetAttribute("CrownlessMenuOpen") then return end
	if (actionCooldownEnds[abilityId] or 0) > os.clock() then return end
	local camera = workspace.CurrentCamera
	if camera then
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		if not head or not head:IsA("BasePart") then return end
		local ray = mouse.UnitRay
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }
		params.IgnoreWater = true
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
		local point = if hit then hit.Position else ray.Origin + ray.Direction * 1000
		local aim = point - head.Position
		if aim.Magnitude > 0.01 then useAbilityRemote:FireServer(abilityId, aim.Unit) end
	end
end

local toolConnections: {[Tool]: RBXScriptConnection} = {}
local function bindWeapon(tool: Instance)
	if not tool:IsA("Tool") or toolConnections[tool] then return end
	toolConnections[tool] = tool.Activated:Connect(function()
		if tool.Parent ~= player.Character or tool:GetAttribute("CrownlessEquipmentTool") ~= true then return end
		local role = player:GetAttribute("CrownlessRole") or player:GetAttribute("CrownlessPreferredRole") or AbilityDefinitions.DefaultRole
		local kit = AbilityDefinitions.Roles[role] or AbilityDefinitions.Roles[AbilityDefinitions.DefaultRole]
		requestAbility(kit.Abilities[4].Id)
	end)
	tool.Destroying:Once(function()
		local connection = toolConnections[tool]
		if connection then connection:Disconnect() end
		toolConnections[tool] = nil
	end)
end
local function bindCharacterTools(character: Model)
	character.ChildAdded:Connect(bindWeapon)
	for _, child in ipairs(character:GetChildren()) do bindWeapon(child) end
end
player.CharacterAdded:Connect(bindCharacterTools)
if player.Character then bindCharacterTools(player.Character) end

local function activateBasicAttack()
	if player:GetAttribute("CrownlessMenuOpen") or UserInputService:GetFocusedTextBox() then return end
	local character = player.Character
	if character then
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Tool") and child:GetAttribute("CrownlessEquipmentTool") == true then
				bindWeapon(child)
				child:Activate()
				return
			end
		end
	end
	-- Let the existing server feedback explain how to equip a missing weapon.
	local role = player:GetAttribute("CrownlessRole") or player:GetAttribute("CrownlessPreferredRole") or AbilityDefinitions.DefaultRole
	local kit = AbilityDefinitions.Roles[role] or AbilityDefinitions.Roles[AbilityDefinitions.DefaultRole]
	requestAbility(kit.Abilities[4].Id)
end

-- Hide the Roblox top bar that collides with this game's HUD. The custom HUD
-- supplies its own chat, party finder, map, gear, and settings entry points.
task.spawn(function()
	for _ = 1, 12 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
			StarterGui:SetCore("TopbarEnabled", false)
		end)
		if ok then
			return
		end
		task.wait(0.5)
	end
end)

local music = Instance.new("Sound")
music.Name = "GreyfenMarchTheme"
music.SoundId = "rbxassetid://1847223666"
music.Looped = true
music.Volume = 0.16
music.Parent = SoundService
music:Play()

local palette = {
	ink = Color3.fromRGB(20, 22, 21),
	inkSoft = Color3.fromRGB(30, 32, 29),
	parchment = Color3.fromRGB(228, 216, 185),
	muted = Color3.fromRGB(166, 161, 145),
	gold = Color3.fromRGB(184, 139, 65),		ember = Color3.fromRGB(151, 73, 49),
	green = Color3.fromRGB(104, 125, 84),
	line = Color3.fromRGB(91, 80, 59),
	white = Color3.fromRGB(245, 241, 230),
}

local function create(className: string, properties: {[string]: any}, parent: Instance): Instance
	local instance = Instance.new(className)
	for property, value in pairs(properties) do
		(instance :: any)[property] = value
	end
	instance.Parent = parent
	return instance
end

local function corner(parent: Instance, radius: number)
	create("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function stroke(parent: Instance, color: Color3, transparency: number?)
	create("UIStroke", { Color = color, Thickness = 1, Transparency = transparency or 0 }, parent)
end

local function label(parent: Instance, name: string, text: string, position: UDim2, size: UDim2, options: {[string]: any}?): TextLabel
	local settings = options or {}
	return create("TextLabel", {
		Name = name,
		Position = position,
		Size = size,
		BackgroundTransparency = 1,
		Font = settings.Font or Enum.Font.Gotham,
		Text = text,
		TextColor3 = settings.Color or palette.parchment,
		TextSize = settings.TextSize or 14,
		TextXAlignment = settings.XAlignment or Enum.TextXAlignment.Left,
		TextYAlignment = settings.YAlignment or Enum.TextYAlignment.Center,
		TextWrapped = settings.Wrapped or false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		RichText = settings.RichText or false,
	}, parent) :: TextLabel
end

local function button(parent: Instance, name: string, text: string, position: UDim2, size: UDim2, color: Color3): TextButton
	local result = create("TextButton", {
		Name = name,
		Position = position,
		Size = size,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		AutoButtonColor = true,
		Font = Enum.Font.GothamSemibold,
		Text = text,
		TextColor3 = palette.white,
		TextSize = 13,
	}, parent) :: TextButton
	corner(result, 7)
	return result
end

local gui = create("ScreenGui", {
	Name = "CrownlessHUD",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 20,
}, player:WaitForChild("PlayerGui")) :: ScreenGui
local uiScale = create("UIScale", { Scale = 1 }, gui) :: UIScale

-- Top bar: the current player's portrait, name, experience, and quick links.
local topbar = create("Frame", {
Name = "Topbar",
Position = UDim2.new(0, 18, 0, 44),
	Size = UDim2.new(1, -36, 0, 62),
	BackgroundColor3 = palette.ink,
	BackgroundTransparency = 0.08,
	BorderSizePixel = 0,
}, gui)
corner(topbar, 10)
stroke(topbar, palette.line, 0.15)

local crest = create("ImageLabel", {
	Name = "AvatarPortrait",
	Position = UDim2.fromOffset(10, 9),
	Size = UDim2.fromOffset(44, 44),
	BackgroundColor3 = palette.inkSoft,
	BorderSizePixel = 0,
	Image = "",
	ScaleType = Enum.ScaleType.Crop,
}, topbar) :: ImageLabel
corner(crest, 8)
stroke(crest, palette.gold, 0.1)
task.spawn(function()
	for _ = 1, 8 do
		local ok, thumbnail, isReady = pcall(function()
			return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if ok and crest.Parent then
			crest.Image = thumbnail
			if isReady then return end
		end
		task.wait(0.5)
	end
end)
local characterName = label(topbar, "CharacterName", player.DisplayName, UDim2.fromOffset(64, 8), UDim2.fromOffset(210, 25), {
	Font = Enum.Font.GothamBlack,
	TextSize = 17,
})
local characterExperience = label(topbar, "CharacterExperience", "LEVEL 01  ·  0 XP", UDim2.fromOffset(65, 32), UDim2.fromOffset(210, 18), {
	Font = Enum.Font.GothamMedium,
	TextSize = 10,
	Color = palette.muted,
})

local right = create("Frame", {
	Name = "CharacterSummary",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -12, 0.5, 0),
	Size = UDim2.fromOffset(310, 44),
	BackgroundTransparency = 1,
}, topbar)
local levelBadge = create("Frame", { Position = UDim2.fromOffset(0, 2), Size = UDim2.fromOffset(82, 40), BackgroundColor3 = palette.inkSoft, BorderSizePixel = 0 }, right)
corner(levelBadge, 7)
local levelText = label(levelBadge, "Level", "LEVEL 01", UDim2.new(), UDim2.fromScale(1, 1), { Font = Enum.Font.GothamBold, TextSize = 12, XAlignment = Enum.TextXAlignment.Center })
local goldBadge = create("Frame", { Position = UDim2.fromOffset(89, 2), Size = UDim2.fromOffset(90, 40), BackgroundColor3 = palette.inkSoft, BorderSizePixel = 0 }, right)
corner(goldBadge, 7)
local goldText = label(goldBadge, "Gold", "0  GOLD", UDim2.new(), UDim2.fromScale(1, 1), { Font = Enum.Font.GothamBold, TextSize = 12, Color = palette.parchment, XAlignment = Enum.TextXAlignment.Center })
local groupToggle = button(right, "GroupToggle", "PARTY  [G]", UDim2.fromOffset(186, 2), UDim2.fromOffset(114, 40), palette.ember)
local gearToggle = button(topbar, "GearToggle", "GEAR  [I]", UDim2.new(1, -542, 0.5, -20), UDim2.fromOffset(100, 40), palette.inkSoft)
local settingsToggle = button(topbar, "SettingsToggle", "SETTINGS [O]", UDim2.new(1, -650, 0.5, -20), UDim2.fromOffset(100, 40), palette.inkSoft)
local chatToggle = button(topbar, "ChatToggle", "CHAT  [/]", UDim2.new(1, -758, 0.5, -20), UDim2.fromOffset(100, 40), palette.inkSoft)

-- Party finder card. Each clickable row reserves one of the four required jobs.
local panel = create("Frame", {
	Name = "PartyFinder",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 18, 0.52, 0),
	Size = UDim2.fromOffset(354, 482),
	BackgroundColor3 = palette.ink,
	BackgroundTransparency = 0.04,
	BorderSizePixel = 0,
	Visible = false,
}, gui) :: Frame
corner(panel, 10)
stroke(panel, palette.line, 0.08)
create("UISizeConstraint", { MinSize = Vector2.new(300, 420), MaxSize = Vector2.new(390, 510) }, panel)

label(panel, "Eyebrow", "THE WAYFARERS' BOARD", UDim2.fromOffset(18, 14), UDim2.new(1, -65, 0, 18), {
	Font = Enum.Font.GothamBold,
	TextSize = 10,
	Color = palette.gold,
})
label(panel, "PanelTitle", "Find a dungeon party", UDim2.fromOffset(18, 34), UDim2.new(1, -70, 0, 31), {
	Font = Enum.Font.GothamBold,
	TextSize = 20,
})
local closeButton = button(panel, "Close", "×", UDim2.new(1, -48, 0, 13), UDim2.fromOffset(32, 32), palette.inkSoft)
closeButton.TextSize = 20
local intro = label(panel, "Intro", "Four adventurers. One role each. Choose your duty to join the muster.", UDim2.fromOffset(18, 70), UDim2.new(1, -36, 0, 38), {
	TextSize = 12,
	Color = palette.muted,
	Wrapped = true,
	YAlignment = Enum.TextYAlignment.Top,
})

local roleRows: {[string]: {Frame: GuiObject, Member: TextLabel, Action: TextLabel}} = {}
local roleMeta: {[string]: { Glyph: string, Short: string, Tint: Color3 }} = {
	Tank = { Glyph = "▰", Short = "Hold the line", Tint = Color3.fromRGB(104, 119, 129) },
	Healer = { Glyph = "+", Short = "Keep the party standing", Tint = Color3.fromRGB(113, 137, 102) },
	Damage = { Glyph = "✦", Short = "Break enemy ranks", Tint = Color3.fromRGB(166, 91, 64) },
	Controller = { Glyph = "⌁", Short = "Interrupt and restrain", Tint = Color3.fromRGB(128, 109, 151) },
}

for index, role in ipairs(GameConfig.PartyRoles) do
	local y = 120 + (index - 1) * 66
	local row = button(panel, role .. "Role", "", UDim2.fromOffset(16, y), UDim2.new(1, -32, 0, 56), palette.inkSoft)
	row.Text = ""
	stroke(row, palette.line, 0.32)
	local meta = roleMeta[role]
	local icon = create("Frame", { Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(40, 40), BackgroundColor3 = meta.Tint, BorderSizePixel = 0 }, row)
	corner(icon, 8)
	label(icon, "RoleGlyph", meta.Glyph, UDim2.new(), UDim2.fromScale(1, 1), { Font = Enum.Font.GothamBold, TextSize = 19, XAlignment = Enum.TextXAlignment.Center })
	label(row, "RoleName", string.upper(role), UDim2.fromOffset(58, 8), UDim2.new(0.5, -52, 0, 19), { Font = Enum.Font.GothamBold, TextSize = 12 })
	label(row, "RoleDescription", meta.Short, UDim2.fromOffset(58, 29), UDim2.new(0.56, -52, 0, 16), { TextSize = 10, Color = palette.muted })
	local member = label(row, "Member", "OPEN", UDim2.new(1, -112, 0, 9), UDim2.fromOffset(99, 17), { Font = Enum.Font.GothamBold, TextSize = 10, Color = palette.gold, XAlignment = Enum.TextXAlignment.Right })
	local action = label(row, "Action", "JOIN ROLE  ›", UDim2.new(1, -112, 0, 29), UDim2.fromOffset(99, 16), { Font = Enum.Font.GothamMedium, TextSize = 9, Color = palette.parchment, XAlignment = Enum.TextXAlignment.Right })
	row.Activated:Connect(function()
		queueRemote:FireServer(role)
	end)
	roleRows[role] = { Frame = row, Member = member, Action = action }
end

local statusLine = label(panel, "PartyStatus", "Waiting for adventurers…", UDim2.fromOffset(18, 391), UDim2.new(1, -36, 0, 37), {
	Font = Enum.Font.GothamMedium,
	TextSize = 11,
	Color = palette.muted,
	Wrapped = true,
})
local leaveButton = button(panel, "LeaveQueue", "LEAVE THE MUSTER", UDim2.fromOffset(16, 437), UDim2.new(1, -32, 0, 32), Color3.fromRGB(79, 49, 41))
leaveButton.Activated:Connect(function()
	leaveRemote:FireServer()
end)

-- Compact local map card for orientation around Greyfen and the mine road.
local mapToggle = button(topbar, "MapToggle", "MAP  [M]", UDim2.new(1, -432, 0.5, -20), UDim2.fromOffset(100, 40), palette.inkSoft)
local mapCard = create("Frame", {
	Name = "RegionMap",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -18, 0, 116),
	Size = UDim2.fromOffset(250, 238),
	BackgroundColor3 = palette.ink,
	BackgroundTransparency = 0.06,
	BorderSizePixel = 0,
	Visible = false,
}, gui) :: Frame
corner(mapCard, 10)
stroke(mapCard, palette.line, 0.08)
label(mapCard, "MapEyebrow", "LOWLAND MARCH  /  GREYFEN", UDim2.fromOffset(14, 12), UDim2.new(1, -28, 0, 16), { Font = Enum.Font.GothamBold, TextSize = 9, Color = palette.gold })
label(mapCard, "MapTitle", "Roads & landmarks", UDim2.fromOffset(14, 31), UDim2.new(1, -28, 0, 24), { Font = Enum.Font.GothamBold, TextSize = 16 })
local mapField = create("Frame", { Position = UDim2.fromOffset(14, 64), Size = UDim2.new(1, -28, 0, 158), BackgroundColor3 = Color3.fromRGB(37, 45, 37), BorderSizePixel = 0 }, mapCard)
corner(mapField, 7)
create("UIStroke", { Color = palette.line, Thickness = 1 }, mapField)
label(mapField, "MapHub", "●  GREYFEN", UDim2.fromOffset(14, 16), UDim2.new(0.7, 0, 0, 20), { Font = Enum.Font.GothamBold, TextSize = 11, Color = palette.parchment })
label(mapField, "MapRoad", "│", UDim2.fromOffset(24, 39), UDim2.fromOffset(20, 55), { Font = Enum.Font.Gotham, TextSize = 29, Color = palette.gold })
label(mapField, "MapMine", "◆  PLAGUE MINE", UDim2.fromOffset(14, 96), UDim2.new(0.9, 0, 0, 20), { Font = Enum.Font.GothamBold, TextSize = 10, Color = Color3.fromRGB(200, 133, 93) })
label(mapField, "MapHint", "The east road leaves from the market gate.", UDim2.fromOffset(14, 128), UDim2.new(1, -28, 0, 18), { TextSize = 9, Color = palette.muted })

-- Character vitals stay subtle and never cover the center of the screen.
local vitals = create("Frame", {
	Name = "Vitals",
	Position = UDim2.new(0, 18, 1, -72),
	Size = UDim2.fromOffset(270, 50),
	BackgroundColor3 = palette.ink,
	BackgroundTransparency = 0.12,
	BorderSizePixel = 0,
}, gui)
corner(vitals, 8)
stroke(vitals, palette.line, 0.22)
label(vitals, "HealthCaption", "VITALITY", UDim2.fromOffset(12, 7), UDim2.fromOffset(76, 14), { Font = Enum.Font.GothamBold, TextSize = 9, Color = palette.muted })
local healthTrack = create("Frame", { Position = UDim2.fromOffset(12, 25), Size = UDim2.new(1, -24, 0, 12), BackgroundColor3 = Color3.fromRGB(55, 48, 43), BorderSizePixel = 0 }, vitals)
corner(healthTrack, 6)
local healthFill = create("Frame", { Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(139, 74, 59), BorderSizePixel = 0 }, healthTrack) :: Frame
corner(healthFill, 6)

local toast = label(gui, "Toast", "", UDim2.new(0.5, -210, 1, -126), UDim2.fromOffset(420, 32), {
	Font = Enum.Font.GothamSemibold,
	TextSize = 12,
	Color = palette.parchment,
	XAlignment = Enum.TextXAlignment.Center,
})
local showToast: (string) -> ()

-- Role tabs and actual equipment slots. Items stay in the assets folder;
-- only the server grants a Tool or attaches armor to the player.
local gearPanel = create("Frame", {
	Name = "FieldKit",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 18, 0.52, 0),
	Size = UDim2.fromOffset(596, 510),
	BackgroundColor3 = palette.ink,
	BackgroundTransparency = 0.04,
	BorderSizePixel = 0,
	Visible = false,
}, gui) :: Frame
corner(gearPanel, 10)
stroke(gearPanel, palette.line, 0.08)
label(gearPanel, "GearEyebrow", "THE GREYFEN ARMORY", UDim2.fromOffset(18, 14), UDim2.new(1, -64, 0, 18), { Font = Enum.Font.GothamBold, TextSize = 10, Color = palette.gold })
label(gearPanel, "GearTitle", "Equipment & role", UDim2.fromOffset(18, 35), UDim2.new(1, -65, 0, 30), { Font = Enum.Font.GothamBold, TextSize = 21 })
local gearClose = button(gearPanel, "Close", "×", UDim2.new(1, -48, 0, 13), UDim2.fromOffset(32, 32), palette.inkSoft)
gearClose.TextSize = 20
label(gearPanel, "GearIntro", "Choose your duty, then equip the items available to that role.", UDim2.fromOffset(18, 73), UDim2.new(1, -36, 0, 24), { TextSize = 12, Color = palette.muted, Wrapped = true })
local gearRows: {[string]: TextButton} = {}
label(gearPanel, "RoleCaption", "FIELD ROLE", UDim2.fromOffset(18, 105), UDim2.fromOffset(190, 18), { Font = Enum.Font.GothamBold, TextSize = 10, Color = palette.gold })
local gearSummary = label(gearPanel, "GearSummary", "STARTER EQUIPMENT", UDim2.fromOffset(230, 105), UDim2.fromOffset(346, 18), { Font = Enum.Font.GothamBold, TextSize = 10, Color = palette.gold })
local gearHint = label(gearPanel, "GearHint", "", UDim2.fromOffset(18, 462), UDim2.new(1, -36, 0, 32), { TextSize = 11, Color = palette.muted, Wrapped = true })
create("Frame", {Position = UDim2.fromOffset(213, 128), Size = UDim2.fromOffset(1, 312), BackgroundColor3 = palette.line, BorderSizePixel = 0}, gearPanel)

for index, role in ipairs(GameConfig.PartyRoles) do
	local kit = AbilityDefinitions.Roles[role]
	local row = button(gearPanel, role .. "Kit", "", UDim2.fromOffset(16, 130 + (index - 1) * 70), UDim2.fromOffset(181, 60), palette.inkSoft)
	row.Text = ""
	stroke(row, palette.line, 0.3)
	label(row, "RoleName", string.upper(role), UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 19), { Font = Enum.Font.GothamBold, TextSize = 12 })
	label(row, "RoleKit", kit.Weapon, UDim2.fromOffset(12, 31), UDim2.new(1, -24, 0, 17), { TextSize = 11, Color = palette.muted })
	row:SetAttribute("Role", role)
	row.Activated:Connect(function()
		setPreferredRoleRemote:FireServer(role)
	end)
	gearRows[role] = row
end

type EquipmentCard = { Preview: ViewportFrame, Name: TextLabel, Detail: TextLabel, State: TextLabel, Action: TextButton, ItemId: string? }
local equipmentCards: {[string]: EquipmentCard} = {}
for index, slot in ipairs(EquipmentDefinitions.Slots) do
	local card = create("Frame", {Name = slot .. "Slot", Position = UDim2.fromOffset(230, 130 + (index - 1) * 157), Size = UDim2.fromOffset(348, 147), BackgroundColor3 = palette.inkSoft, BorderSizePixel = 0}, gearPanel) :: Frame
	corner(card, 8)
	stroke(card, palette.line, 0.3)
	local preview = create("ViewportFrame", {
		Name = "ItemPreview", Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(98, 112),
		BackgroundColor3 = Color3.fromRGB(24, 27, 25), BorderSizePixel = 0,
		Ambient = Color3.fromRGB(160, 157, 145), LightColor = Color3.fromRGB(255, 243, 217), LightDirection = Vector3.new(-1, -1, -1),
	}, card) :: ViewportFrame
	corner(preview, 6)
	local name = label(card, "ItemName", "", UDim2.fromOffset(120, 10), UDim2.fromOffset(216, 37), {Font = Enum.Font.GothamBold, TextSize = 15, Wrapped = true})
	label(card, "Slot", string.upper(slot), UDim2.fromOffset(120, 51), UDim2.fromOffset(210, 12), {Font = Enum.Font.GothamBold, TextSize = 9, Color = palette.gold})
	local detail = label(card, "Detail", "", UDim2.fromOffset(120, 67), UDim2.fromOffset(214, 27), {TextSize = 10, Wrapped = true, Color = palette.muted})
	local state = label(card, "EquippedState", "", UDim2.fromOffset(8, 124), UDim2.fromOffset(102, 15), {Font = Enum.Font.GothamBold, TextSize = 9, XAlignment = Enum.TextXAlignment.Center})
	local action = button(card, "Equip", "EQUIP", UDim2.fromOffset(120, 102), UDim2.fromOffset(216, 33), palette.ember)
	local data: EquipmentCard = {Preview = preview, Name = name, Detail = detail, State = state, Action = action, ItemId = nil}
	equipmentCards[slot] = data
	action.Activated:Connect(function()
		if not data.ItemId or player:GetAttribute("CrownlessEquipmentReady") ~= true then return end
		local equipped = player:GetAttribute("CrownlessEquipped" .. slot) == data.ItemId
		equipItemRemote:FireServer(data.ItemId, not equipped)
	end)
end

local function renderItemPreview(viewport: ViewportFrame, item)
	if viewport:GetAttribute("Asset") == item.Asset then return end
	viewport:ClearAllChildren()
	corner(viewport, 6)
	viewport:SetAttribute("Asset", nil)
	local folder = assets:FindFirstChild(if item.Slot == "Weapon" then "Weapons" else "Armor")
	local template = folder and folder:FindFirstChild(item.Asset)
	if not template then return end
	local scene = Instance.new("WorldModel")
	scene.Parent = viewport
	local model = Instance.new("Model")
	model.Name = "EquipmentPreview"
	local copy = template:Clone()
	copy.Parent = model
	model.Parent = scene
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then descendant.Anchored = true
		elseif descendant:IsA("Script") or descendant:IsA("LocalScript") then descendant:Destroy() end
	end
	local bounds, size = model:GetBoundingBox()
	local extent = math.max(size.Y, size.X, size.Z, 1)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 35
	camera.CFrame = CFrame.lookAt(bounds.Position + Vector3.new(extent * 0.55, extent * 0.1, extent * 1.85), bounds.Position)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	viewport:SetAttribute("Asset", item.Asset)
end

-- A compact four-slot action bar; each request is independently checked server-side.
local abilityBar = create("Frame", {
	Name = "AbilityBar",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -16),
	Size = UDim2.fromOffset(568, 76),
	BackgroundColor3 = palette.ink,
	BackgroundTransparency = 0.12,
	BorderSizePixel = 0,
}, gui) :: Frame
corner(abilityBar, 9)
stroke(abilityBar, palette.line, 0.2)
local abilityButtons: {[string]: { Button: TextButton, Cooldown: TextLabel }} = {}
for index, abilityIndex in ipairs({ 1, 2, 3, 4 }) do
	local x = 10 + (index - 1) * 138
	local slot = button(abilityBar, "Ability" .. tostring(abilityIndex), "", UDim2.fromOffset(x, 8), UDim2.fromOffset(132, 60), palette.inkSoft)
	slot.Text = ""
	stroke(slot, palette.line, 0.28)
	local caption = label(slot, "AbilityName", "", UDim2.fromOffset(8, 5), UDim2.new(1, -16, 1, -10), { Font = Enum.Font.GothamBold, TextSize = 11, XAlignment = Enum.TextXAlignment.Center, Wrapped = true })
	local remaining = label(slot, "Cooldown", "", UDim2.new(1, -47, 1, -20), UDim2.fromOffset(42, 15), { Font = Enum.Font.GothamBold, TextSize = 9, Color = palette.gold, XAlignment = Enum.TextXAlignment.Right })
	slot.Activated:Connect(function()
		local currentRole = player:GetAttribute("CrownlessRole") or player:GetAttribute("CrownlessPreferredRole") or AbilityDefinitions.DefaultRole
		local roleData = AbilityDefinitions.Roles[currentRole] or AbilityDefinitions.Roles[AbilityDefinitions.DefaultRole]
		local ability = roleData.Abilities[abilityIndex]
		if ability then
			if abilityIndex == 4 then activateBasicAttack() else requestAbility(ability.Id) end
		end
	end)
	abilityButtons[tostring(abilityIndex)] = { Button = slot, Cooldown = remaining }
end

-- Settings replace the small part of the Roblox top bar used for game entry points.
local settingsPanel = create("Frame", {
	Name = "SettingsPanel",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -18, 0, 116),
	Size = UDim2.fromOffset(302, 290),
	BackgroundColor3 = palette.ink,
	BackgroundTransparency = 0.04,
	BorderSizePixel = 0,
	Visible = false,
}, gui) :: Frame
corner(settingsPanel, 10)
stroke(settingsPanel, palette.line, 0.08)
label(settingsPanel, "SettingsEyebrow", "CROWNLESS", UDim2.fromOffset(18, 14), UDim2.new(1, -60, 0, 18), { Font = Enum.Font.GothamBold, TextSize = 10, Color = palette.gold })
label(settingsPanel, "SettingsTitle", "Settings", UDim2.fromOffset(18, 34), UDim2.new(1, -60, 0, 28), { Font = Enum.Font.GothamBold, TextSize = 20 })
local settingsClose = button(settingsPanel, "Close", "×", UDim2.new(1, -48, 0, 12), UDim2.fromOffset(32, 32), palette.inkSoft)
settingsClose.TextSize = 20
local musicLabel = label(settingsPanel, "MusicSetting", "MARCH THEME   ·   16%", UDim2.fromOffset(18, 79), UDim2.new(1, -36, 0, 22), { Font = Enum.Font.GothamBold, TextSize = 11 })
local volumeDown = button(settingsPanel, "MusicDown", "−", UDim2.fromOffset(18, 108), UDim2.fromOffset(54, 38), palette.inkSoft)
volumeDown.TextSize = 20
local volumeUp = button(settingsPanel, "MusicUp", "+", UDim2.fromOffset(80, 108), UDim2.fromOffset(54, 38), palette.inkSoft)
volumeUp.TextSize = 20
local muteMusic = button(settingsPanel, "MusicToggle", "MUTE MUSIC", UDim2.fromOffset(145, 108), UDim2.new(1, -163, 0, 38), palette.green)
local scaleButton = button(settingsPanel, "ScaleToggle", "UI SCALE  ·  100%", UDim2.fromOffset(18, 160), UDim2.new(1, -36, 0, 38), palette.inkSoft)
local topbarButton = button(settingsPanel, "TopbarToggle", "ROBLOX TOP BAR  ·  HIDDEN", UDim2.fromOffset(18, 208), UDim2.new(1, -36, 0, 38), palette.inkSoft)
label(settingsPanel, "SettingsHint", "WASD: Move   ·   Right drag: Camera   ·   Wheel: Zoom\nClick / 4: Attack   ·   1–3: Abilities   ·   E: Interact", UDim2.fromOffset(18, 252), UDim2.new(1, -36, 0, 30), { TextSize = 9, Color = palette.muted, Wrapped = true })

-- Roblox filtered text chat remains available from a custom, low-profile panel.
local chatPanel = create("Frame", {
	Name = "GreyfenChat",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -18, 1, -98),
	Size = UDim2.fromOffset(310, 264),
	BackgroundColor3 = palette.ink,
	BackgroundTransparency = 0.07,
	BorderSizePixel = 0,
	Visible = false,
}, gui) :: Frame
corner(chatPanel, 10)
stroke(chatPanel, palette.line, 0.12)
label(chatPanel, "ChatTitle", "GREYFEN  ·  LOCAL CHAT", UDim2.fromOffset(14, 10), UDim2.new(1, -70, 0, 20), { Font = Enum.Font.GothamBold, TextSize = 10, Color = palette.gold })
local chatClose = button(chatPanel, "Close", "×", UDim2.new(1, -42, 0, 6), UDim2.fromOffset(30, 30), palette.inkSoft)
local chatLog = create("ScrollingFrame", {
	Name = "Messages",
	Position = UDim2.fromOffset(12, 38),
	Size = UDim2.new(1, -24, 1, -91),
	BackgroundColor3 = palette.inkSoft,
	BackgroundTransparency = 0.25,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 4,
}, chatPanel) :: ScrollingFrame
corner(chatLog, 6)
create("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, chatLog)
create("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, chatLog)
local chatInput = create("TextBox", {
	Name = "MessageInput",
	Position = UDim2.new(0, 12, 1, -43),
	Size = UDim2.new(1, -24, 0, 32),
	BackgroundColor3 = palette.inkSoft,
	BorderSizePixel = 0,
	ClearTextOnFocus = false,
	Font = Enum.Font.Gotham,
	PlaceholderText = "Type a message…",
	Text = "",
	TextColor3 = palette.parchment,
	PlaceholderColor3 = palette.muted,
	TextSize = 12,
	TextXAlignment = Enum.TextXAlignment.Left,
}, chatPanel) :: TextBox
corner(chatInput, 6)
create("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9) }, chatInput)
local chatChannel: TextChannel? = nil
local function addChatMessage(message: string)
	local item = label(chatLog, "Message", message, UDim2.new(), UDim2.new(1, 0, 0, 0), { TextSize = 10, Color = palette.parchment, Wrapped = true, YAlignment = Enum.TextYAlignment.Top })
	item.AutomaticSize = Enum.AutomaticSize.Y
	item.LayoutOrder = #chatLog:GetChildren()
	while #chatLog:GetChildren() > 52 do
		local first = chatLog:FindFirstChild("Message")
		if not first then break end
		first:Destroy()
	end
	task.defer(function()
		chatLog.CanvasPosition = Vector2.new(0, math.max(0, chatLog.AbsoluteCanvasSize.Y - chatLog.AbsoluteSize.Y))
	end)
end
task.spawn(function()
	local ok, channel = pcall(function()
		local channels = TextChatService:WaitForChild("TextChannels", 20)
		return channels and channels:WaitForChild("RBXGeneral", 12)
	end)
	if ok and channel and channel:IsA("TextChannel") then
		chatChannel = channel
		channel.MessageReceived:Connect(function(message)
			if message.Text ~= "" then
				addChatMessage(message.PrefixText .. "  " .. message.Text)
			end
		end)
		addChatMessage("The march is quiet. Speak freely, but keep your word.")
	else
		addChatMessage("Hub chat is unavailable until TextChatService is enabled for this place.")
	end
end)
chatInput.FocusLost:Connect(function(enterPressed)
	if not enterPressed then return end
	local message = string.sub(chatInput.Text, 1, 180)
	chatInput.Text = ""
	if message:gsub("%s", "") == "" then return end
	if chatChannel then
		local ok, issue = pcall(function()
			chatChannel:SendAsync(message)
		end)
		if not ok then showToast("Chat could not send: " .. tostring(issue)) end
	end
end)

local dialoguePanel = create("Frame", {
	Name = "NPCDialogue",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -106),
	Size = UDim2.fromOffset(500, 138),
	BackgroundColor3 = palette.ink,
	BackgroundTransparency = 0.04,
	BorderSizePixel = 0,
	Visible = false,
}, gui) :: Frame
corner(dialoguePanel, 10)
stroke(dialoguePanel, palette.line, 0.06)
local dialogueName = label(dialoguePanel, "Speaker", "", UDim2.fromOffset(18, 13), UDim2.new(1, -120, 0, 18), { Font = Enum.Font.GothamBold, TextSize = 10, Color = palette.gold })
local dialogueText = label(dialoguePanel, "Line", "", UDim2.fromOffset(18, 39), UDim2.new(1, -36, 0, 55), { TextSize = 13, Wrapped = true, YAlignment = Enum.TextYAlignment.Top })
local dialogueNext = button(dialoguePanel, "Next", "CONTINUE  ›", UDim2.new(1, -142, 1, -38), UDim2.fromOffset(124, 28), palette.ember)
local dialogueClose = button(dialoguePanel, "Close", "CLOSE", UDim2.fromOffset(18, 99), UDim2.fromOffset(76, 28), palette.inkSoft)
local activeDialogueId: string? = nil
local activeDialogueLine = 1

-- Panel visibility blocks combat while using menus, including NPC dialogue.
local function updateMenuState()
	player:SetAttribute("CrownlessMenuOpen", panel.Visible or gearPanel.Visible or settingsPanel.Visible
		or chatPanel.Visible or mapCard.Visible or dialoguePanel.Visible)
end
for _, menu in ipairs({ panel, gearPanel, settingsPanel, chatPanel, mapCard, dialoguePanel }) do
	menu:GetPropertyChangedSignal("Visible"):Connect(updateMenuState)
end
updateMenuState()
local musicVolume = music.Volume
local musicMuted = false
local uiScalePercent = 100
local defaultTopbarHidden = true

local function selectedRole(): string
	local role = player:GetAttribute("CrownlessRole") or player:GetAttribute("CrownlessPreferredRole") or AbilityDefinitions.DefaultRole
	return AbilityDefinitions.Roles[role] and role or AbilityDefinitions.DefaultRole
end

local function renderLoadout()
	local role = selectedRole()
	local kit = AbilityDefinitions.Roles[role]
	gearSummary.Text = string.upper(role) .. "  /  STARTER EQUIPMENT"
	local ready = player:GetAttribute("CrownlessEquipmentReady") == true
	local preferredRole = player:GetAttribute("CrownlessPreferredRole") or role
	gearHint.Text = if preferredRole ~= role then "Your party role is " .. role .. ". " .. tostring(preferredRole) .. " is selected for your next party."
		elseif ready then "Equipped weapons enable your abilities. Unequipping armor removes its protection."
		else "Preparing your character and equipment…"
	for slot, card in pairs(equipmentCards) do
		local item = EquipmentDefinitions.Items[EquipmentDefinitions.RoleItems[role][slot]]
		local equipped = player:GetAttribute("CrownlessEquipped" .. slot) == item.Id
		card.ItemId = item.Id
		card.Name.Text = item.Name
		card.Detail.Text = if slot == "Armor" then tostring(item.ArmorRating) .. " armor rating · " .. item.Description else item.Description
		card.State.Text = if not ready then "PREPARING" elseif equipped then (if slot == "Weapon" then "IN HAND" else "WORN") else "UNEQUIPPED"
		card.State.TextColor3 = if equipped then palette.green else palette.muted
		card.Action.Text = if not ready then "PREPARING…" elseif equipped then "UNEQUIP" else "EQUIP"
		card.Action.Active = ready
		card.Action.AutoButtonColor = ready
		card.Action.BackgroundColor3 = if not ready then palette.inkSoft elseif equipped then Color3.fromRGB(63, 72, 56) else palette.ember
		renderItemPreview(card.Preview, item)
	end
	for roleName, row in pairs(gearRows) do
		local selected = roleName == role
		row.BackgroundColor3 = selected and Color3.fromRGB(57, 68, 53) or palette.inkSoft
		local roleLabel = row:FindFirstChild("RoleName") :: TextLabel
		roleLabel.TextColor3 = selected and palette.gold or palette.parchment
	end
	for index, buttonData in pairs(abilityButtons) do
		local ability = kit.Abilities[tonumber(index)]
		local name = buttonData.Button:FindFirstChild("AbilityName") :: TextLabel
		if ability then
			name.Text = (if index == "4" then "[CLICK / 4]  " else "[" .. ability.Key .. "]  ") .. ability.Name
			buttonData.Button:SetAttribute("AbilityId", ability.Id)
			buttonData.Button:SetAttribute("AbilityDescription", ability.Description)
		end
	end
end

local function renderCooldowns()
	for index, buttonData in pairs(abilityButtons) do
		local endsAt = actionCooldownEnds[buttonData.Button:GetAttribute("AbilityId") or ""] or 0
		local remaining = endsAt - os.clock()
		buttonData.Cooldown.Text = if remaining > 0 then string.format("%.1f", remaining) else ""
		buttonData.Button.BackgroundColor3 = if remaining > 0 then palette.inkSoft:Lerp(palette.ember, 0.26) else palette.inkSoft
	end
end

local function openDialogue(id: string)
	local definition = NPCDefinitions[id]
	if not definition then return end
	activeDialogueId = id
	activeDialogueLine = 1
	dialogueName.Text = string.upper(definition.Name .. "  ·  " .. definition.Title)
	dialogueText.Text = definition.Dialogue[activeDialogueLine]
	dialogueNext.Text = if #definition.Dialogue == 1 then "FINISH  ›" else "CONTINUE  ›"
	dialoguePanel.Visible = true
	abilityBar.Visible = false
	panel.Visible = false
	groupToggle.BackgroundColor3 = palette.inkSoft
	gearPanel.Visible = false
	gearToggle.BackgroundColor3 = palette.inkSoft
	settingsPanel.Visible = false
	settingsToggle.BackgroundColor3 = palette.inkSoft
end

local function setPanelOpen(open: boolean)
	panel.Visible = open
	groupToggle.BackgroundColor3 = open and palette.ember or palette.inkSoft
	if open then
		gearPanel.Visible = false
		gearToggle.BackgroundColor3 = palette.inkSoft
		settingsPanel.Visible = false
		settingsToggle.BackgroundColor3 = palette.inkSoft
	end
end

local function setMapOpen(open: boolean)
	mapCard.Visible = open
	mapToggle.BackgroundColor3 = open and palette.green or palette.inkSoft
end

showToast = function(message: string)
	toast.Text = message
	task.delay(3.5, function()
		if toast.Text == message then
			toast.Text = ""
		end
	end)
end

local function setGearOpen(open: boolean)
	gearPanel.Visible = open
	gearToggle.BackgroundColor3 = open and palette.green or palette.inkSoft
	if open then
		setPanelOpen(false)
		settingsPanel.Visible = false
		settingsToggle.BackgroundColor3 = palette.inkSoft
		renderLoadout()
	end
end

local function setSettingsOpen(open: boolean)
	settingsPanel.Visible = open
	settingsToggle.BackgroundColor3 = open and palette.green or palette.inkSoft
	if open then
		setPanelOpen(false)
		gearPanel.Visible = false
		gearToggle.BackgroundColor3 = palette.inkSoft
	end
end

local function setChatOpen(open: boolean)
	chatPanel.Visible = open
	chatToggle.BackgroundColor3 = open and palette.green or palette.inkSoft
	if open then
		settingsPanel.Visible = false
		settingsToggle.BackgroundColor3 = palette.inkSoft
		gearPanel.Visible = false
		gearToggle.BackgroundColor3 = palette.inkSoft
	end
end

local function updateSummary()
	local level = math.max(1, math.floor(tonumber(player:GetAttribute("CrownlessLevel")) or 1))
	local experience = math.max(0, math.floor(tonumber(player:GetAttribute("CrownlessExperience")) or 0))
	characterName.Text = player.DisplayName
	characterExperience.Text = string.format("LEVEL %02d  ·  %d XP", level, experience)
	levelText.Text = "LEVEL " .. string.format("%02d", level)
	goldText.Text = tostring(player:GetAttribute("CrownlessGold") or 0) .. "  GOLD"
end

local function updateHealth(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local function renderHealth()
		local ratio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
		healthFill.Size = UDim2.fromScale(ratio, 1)
		local caption = healthTrack.Parent:FindFirstChild("HealthCaption") :: TextLabel
		caption.Text = string.format("VITALITY  %d / %d", humanoid.Health, humanoid.MaxHealth)
	end
	humanoid.HealthChanged:Connect(renderHealth)
	humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(renderHealth)
	renderHealth()
end

local function renderParty(data: any)
	if type(data) ~= "table" then
		return
	end
	local party = data.party
	for role, row in pairs(roleRows) do
		local memberName = party and party.roles and party.roles[role]
		if data.role == role then
			row.Member.Text = "YOU"
			row.Member.TextColor3 = palette.green
			row.Action.Text = "SELECTED"
		elseif memberName then
			row.Member.Text = string.upper(memberName)
			row.Member.TextColor3 = palette.parchment
			row.Action.Text = "FILLED"
		else
			row.Member.Text = "OPEN"
			row.Member.TextColor3 = palette.gold
			row.Action.Text = "JOIN ROLE  ›"
		end
	end

	if data.message then
		statusLine.Text = data.message
	elseif party then
		statusLine.Text = "PARTY " .. tostring(party.partyId) .. "  ·  " .. string.upper(tostring(party.status))
	else
		statusLine.Text = "Waiting for adventurers…"
	end
	if data.status == "ready" or data.status == "launching" then
		statusLine.TextColor3 = palette.parchment
	else
		statusLine.TextColor3 = palette.muted
	end
end

groupToggle.Activated:Connect(function()
	setPanelOpen(not panel.Visible)
end)
closeButton.Activated:Connect(function()
	setPanelOpen(false)
end)
mapToggle.Activated:Connect(function()
	setMapOpen(not mapCard.Visible)
end)
gearToggle.Activated:Connect(function()
	setGearOpen(not gearPanel.Visible)
end)
gearClose.Activated:Connect(function()
	setGearOpen(false)
end)
settingsToggle.Activated:Connect(function()
	setSettingsOpen(not settingsPanel.Visible)
end)
settingsClose.Activated:Connect(function()
	setSettingsOpen(false)
end)
chatToggle.Activated:Connect(function()
	setChatOpen(not chatPanel.Visible)
end)
chatClose.Activated:Connect(function()
	setChatOpen(false)
end)
volumeDown.Activated:Connect(function()
	musicVolume = math.max(0, math.floor((musicVolume - 0.04) * 100 + 0.5) / 100)
	if not musicMuted then music.Volume = musicVolume end
	musicLabel.Text = string.format("MARCH THEME   ·   %d%%", math.floor(musicVolume * 100 + 0.5))
end)
volumeUp.Activated:Connect(function()
	musicVolume = math.min(0.6, math.floor((musicVolume + 0.04) * 100 + 0.5) / 100)
	if not musicMuted then music.Volume = musicVolume end
	musicLabel.Text = string.format("MARCH THEME   ·   %d%%", math.floor(musicVolume * 100 + 0.5))
end)
muteMusic.Activated:Connect(function()
	musicMuted = not musicMuted
	music.Volume = if musicMuted then 0 else musicVolume
	muteMusic.Text = if musicMuted then "UNMUTE" else "MUTE MUSIC"
	musicLabel.Text = string.format("MARCH THEME   ·   %d%%", math.floor(musicVolume * 100 + 0.5))
end)
scaleButton.Activated:Connect(function()
	uiScalePercent = if uiScalePercent == 100 then 90 elseif uiScalePercent == 90 then 110 else 100
	uiScale.Scale = uiScalePercent / 100
	scaleButton.Text = "UI SCALE  ·  " .. tostring(uiScalePercent) .. "%"
end)
topbarButton.Activated:Connect(function()
	defaultTopbarHidden = not defaultTopbarHidden
	local ok = pcall(function()
		StarterGui:SetCore("TopbarEnabled", not defaultTopbarHidden)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
	if not ok then
		defaultTopbarHidden = not defaultTopbarHidden
	end
	topbarButton.Text = if defaultTopbarHidden then "ROBLOX TOP BAR  ·  HIDDEN" else "ROBLOX TOP BAR  ·  SHOWN"
end)
dialogueNext.Activated:Connect(function()
	local definition = activeDialogueId and NPCDefinitions[activeDialogueId]
	if not definition then return end
	if activeDialogueLine < #definition.Dialogue then
		activeDialogueLine += 1
		dialogueText.Text = definition.Dialogue[activeDialogueLine]
		dialogueNext.Text = if activeDialogueLine == #definition.Dialogue then "FINISH  ›" else "CONTINUE  ›"
	else
		dialoguePanel.Visible = false
		abilityBar.Visible = true
		activeDialogueId = nil
	end
end)
dialogueClose.Activated:Connect(function()
	dialoguePanel.Visible = false
	abilityBar.Visible = true
	activeDialogueId = nil
end)

equipmentFeedbackRemote.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then return end
	if type(data.Message) == "string" then showToast(data.Message) end
	renderLoadout()
end)

abilityFeedbackRemote.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then return end
	if data.Success and type(data.AbilityId) == "string" and type(data.Cooldown) == "number" then
		actionCooldownEnds[data.AbilityId] = os.clock() + data.Cooldown
	end
	if type(data.Message) == "string" then
		showToast(data.Message)
	end
end)

local abilityKeys = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
}

partyStateRemote.OnClientEvent:Connect(function(data)
	renderParty(data)
	if type(data) == "table" and data.message then
		showToast(data.message)
	end
end)

ProximityPromptService.PromptTriggered:Connect(function(promptObject, whoTriggered)
	if promptObject.Name == "OpenGroupFinder" and (whoTriggered == nil or whoTriggered == player) then
		setPanelOpen(true)
		return
	end
	local dialogueId = promptObject:GetAttribute("DialogueId")
	if type(dialogueId) == "string" and (whoTriggered == nil or whoTriggered == player) then
		openDialogue(dialogueId)
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then
		return
	end
	if input.KeyCode == Enum.KeyCode.G then
		setPanelOpen(not panel.Visible)
	elseif input.KeyCode == Enum.KeyCode.M then
		setMapOpen(not mapCard.Visible)
	elseif input.KeyCode == Enum.KeyCode.I then
		setGearOpen(not gearPanel.Visible)
	elseif input.KeyCode == Enum.KeyCode.O then
		setSettingsOpen(not settingsPanel.Visible)
	elseif input.KeyCode == Enum.KeyCode.Slash then
		setChatOpen(not chatPanel.Visible)
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 and not player:GetAttribute("CrownlessCursorFree") then
		activateBasicAttack()
	elseif abilityKeys[input.KeyCode] then
		local roleData = AbilityDefinitions.Roles[selectedRole()]
		local ability = roleData.Abilities[abilityKeys[input.KeyCode]]
		if ability then
			if abilityKeys[input.KeyCode] == 4 then activateBasicAttack() else requestAbility(ability.Id) end
		end
	end
end)

player:GetAttributeChangedSignal("CrownlessLevel"):Connect(updateSummary)
player:GetAttributeChangedSignal("CrownlessExperience"):Connect(updateSummary)
player:GetPropertyChangedSignal("DisplayName"):Connect(updateSummary)
player:GetAttributeChangedSignal("CrownlessGold"):Connect(updateSummary)
player:GetAttributeChangedSignal("CrownlessRole"):Connect(renderLoadout)
player:GetAttributeChangedSignal("CrownlessPreferredRole"):Connect(renderLoadout)
player:GetAttributeChangedSignal("CrownlessEquippedWeapon"):Connect(renderLoadout)
player:GetAttributeChangedSignal("CrownlessEquippedArmor"):Connect(renderLoadout)
player:GetAttributeChangedSignal("CrownlessEquipmentReady"):Connect(renderLoadout)
player.CharacterAdded:Connect(updateHealth)
if player.Character then
	updateHealth(player.Character)
end
updateSummary()
renderLoadout()
task.spawn(function()
	while gui.Parent do
		renderCooldowns()
		task.wait(0.12)
	end
end)

local ok, initialState = pcall(function()
	return getPartyState:InvokeServer()
end)
if ok then
	renderParty(initialState)
end
