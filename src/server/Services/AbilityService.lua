local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AbilityDefinitions = require(Shared:WaitForChild("AbilityDefinitions") :: ModuleScript)
local CombatService = require(script.Parent:WaitForChild("CombatService") :: ModuleScript)
local EquipmentService = require(script.Parent:WaitForChild("EquipmentService") :: ModuleScript)
local AbilityService = {}

type Hit = { Target: Model, Position: Vector3, Distance: number, Alignment: number }
type DamageSample = { At: number, Amount: number }

local cooldowns: { [Player]: { [string]: number } } = {}
local requestTimes: { [Player]: number } = {}
local damageSamples: { [Player]: { DamageSample } } = {}
local feedbackRemote: RemoteEvent
local actionAnimationRemote: RemoteEvent
local damageMeterRemote: RemoteEvent

local function roleOf(player: Player): string
	local role = player:GetAttribute("CrownlessRole") or player:GetAttribute("CrownlessPreferredRole") or AbilityDefinitions.DefaultRole
	return AbilityDefinitions.Roles[role] and role or AbilityDefinitions.DefaultRole
end

local function rootOf(character: Model?): BasePart?
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function isLivingEnemy(instance: Instance): boolean
	if not instance:IsA("Model") or not instance:IsDescendantOf(workspace) then
		return false
	end
	local humanoid = instance:FindFirstChildOfClass("Humanoid")
	return CollectionService:HasTag(instance, "CrownlessEnemy")
		and instance:GetAttribute("CrownlessEnemy") == true
		and humanoid ~= nil and humanoid.Health > 0 and rootOf(instance) ~= nil
end

local function rayParams(character: Model): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.IgnoreWater = true
	return params
end

local function validAim(value: any): Vector3?
	if typeof(value) ~= "Vector3" then return nil end
	-- Check each component before normalizing: NaN/inf must never reach a raycast.
	for _, component in ipairs({ value.X, value.Y, value.Z }) do
		if component ~= component or math.abs(component) > 1.001 then return nil end
	end
	if value.Magnitude < 0.99 or value.Magnitude > 1.01 then return nil end
	return value.Unit
end

local function enemyAt(instance: Instance): Model?
	local current: Instance? = instance
	while current and current ~= workspace do
		if current:IsA("Model") and isLivingEnemy(current) then return current end
		current = current.Parent
	end
	return nil
end

local function aimedHits(character: Model, origin: Vector3, direction: Vector3, range: number, isBolt: boolean, isArea: boolean): ({ Hit }, Vector3)
	local params = rayParams(character)
	local ray = workspace:Raycast(origin, direction * range, params)
	local endpoint = if ray then ray.Position else origin + direction * range
	local hits: { Hit } = {}
	if isBolt then
		-- Spells hit the first surface under the crosshair, including intervening walls.
		local target = ray and enemyAt(ray.Instance)
		if target then
			table.insert(hits, { Target = target, Position = endpoint, Distance = (endpoint - origin).Magnitude, Alignment = 1 })
		end
		return hits, endpoint
	end

	local minimumDot = math.cos(math.rad(if isArea then 70 else 50))
	for _, instance in ipairs(CollectionService:GetTagged("CrownlessEnemy")) do
		if instance:IsA("Model") and isLivingEnemy(instance) then
			local root = rootOf(instance)
			if root then
				local offset = root.Position - origin
				local distance = offset.Magnitude
				local alignment = if distance > 0.01 then direction:Dot(offset.Unit) else 1
				if distance <= range and alignment >= minimumDot then
					local sight = if distance > 0.01 then workspace:Raycast(origin, offset, params) else nil
					if not sight or sight.Instance:IsDescendantOf(instance) then
						table.insert(hits, { Target = instance, Position = if sight then sight.Position else root.Position, Distance = distance, Alignment = alignment })
					end
				end
			end
		end
	end
	table.sort(hits, function(left, right)
		return left.Alignment - left.Distance / (range * 4) > right.Alignment - right.Distance / (range * 4)
	end)
	return hits, endpoint
end

local function isPartyAlly(source: Player, candidate: Player): boolean
	if source == candidate then return true end
	local partyId = source:GetAttribute("CrownlessPartyId")
	return partyId ~= nil and candidate:GetAttribute("CrownlessPartyId") == partyId
end

local function injuredAllies(player: Player, origin: Vector3, range: number): { Player }
	local allies: { Player } = {}
	for _, candidate in ipairs(Players:GetPlayers()) do
		local character = candidate.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = rootOf(character)
		if isPartyAlly(player, candidate) and humanoid and root and humanoid.Health > 0 and humanoid.Health < humanoid.MaxHealth and (root.Position - origin).Magnitude <= range then
			table.insert(allies, candidate)
		end
	end
	table.sort(allies, function(left, right)
		local leftHumanoid = left.Character and left.Character:FindFirstChildOfClass("Humanoid")
		local rightHumanoid = right.Character and right.Character:FindFirstChildOfClass("Humanoid")
		if not leftHumanoid or not rightHumanoid then return false end
		return leftHumanoid.Health / leftHumanoid.MaxHealth < rightHumanoid.Health / rightHumanoid.MaxHealth
	end)
	return allies
end

local function engagedEnemies(position: Vector3): { Model }
	local enemies: { Model } = {}
	for _, instance in ipairs(CollectionService:GetTagged("CrownlessEnemy")) do
		if instance:IsA("Model") and isLivingEnemy(instance) then
			local root = rootOf(instance)
			if root and (root.Position - position).Magnitude <= 60 then table.insert(enemies, instance) end
		end
	end
	return enemies
end

local function spellVisual(fromPosition: Vector3, toPosition: Vector3, tint: Color3, pulse: boolean?)
	local effect = Instance.new("Part")
	effect.Name = if pulse then "RenewingWordEffect" else "CrownlessSpellEffect"
	effect.Shape = Enum.PartType.Ball
	effect.Material = Enum.Material.Neon
	effect.Color = tint
	effect.Transparency = 0.12
	effect.Size = if pulse then Vector3.new(2, 2, 2) else Vector3.new(0.85, 0.85, 0.85)
	effect.Anchored = true
	effect.CanCollide = false
	effect.CanTouch = false
	effect.CanQuery = false
	effect.CFrame = CFrame.new(if pulse then toPosition else fromPosition)
	effect.Parent = workspace
	local goal = if pulse then { Size = Vector3.new(7, 7, 7), Transparency = 1 } else { Position = toPosition, Size = Vector3.new(0.18, 0.18, 0.18), Transparency = 0.25 }
	TweenService:Create(effect, TweenInfo.new(if pulse then 0.45 else 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
	Debris:AddItem(effect, 0.5)
end

local function recordHit(player: Player, target: Model, position: Vector3, damage: number, now: number)
	if damage <= 0 then return end
	local samples = damageSamples[player] or {}
	damageSamples[player] = samples
	local total = damage
	local firstAt = now
	for index = #samples, 1, -1 do
		local sample = samples[index]
		if now - sample.At > 10 then
			table.remove(samples, index)
		else
			total += sample.Amount
			firstAt = math.min(firstAt, sample.At)
		end
	end
	table.insert(samples, { At = now, Amount = damage })
	damageMeterRemote:FireClient(player, {
		Amount = damage,
		Position = position,
		Target = target,
		DPS = total / math.clamp(now - firstAt, 1, 10),
		Total = total,
	})
end

local function applyDamage(player: Player, hit: Hit, amount: number, now: number): number
	local humanoid = hit.Target:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return 0 end
	local before = humanoid.Health
	humanoid:TakeDamage(math.max(0, amount))
	-- ForceFields and overkill can make the health delta differ from the requested damage.
	local actualDamage = math.max(0, before - humanoid.Health)
	if actualDamage > 0 then
		CombatService.RecordDamageThreat(hit.Target, player, actualDamage)
		recordHit(player, hit.Target, hit.Position, actualDamage, now)
	end
	return actualDamage
end

local function findAbility(role: string, abilityId: string)
	for _, ability in ipairs(AbilityDefinitions.Roles[role].Abilities) do
		if ability.Id == abilityId then return ability end
	end
	return nil
end

local function sendFeedback(player: Player, abilityId: string, ok: boolean, message: string, cooldown: number?)
	feedbackRemote:FireClient(player, { AbilityId = abilityId, Success = ok, Message = message, Cooldown = cooldown })
end

local function handleAbility(player: Player, abilityId: any, aimDirection: any)
	if type(abilityId) ~= "string" or #abilityId > 40 or player.Parent ~= Players then return end
	local direction = validAim(aimDirection)
	if not direction then return end
	local now = os.clock()
	if now - (requestTimes[player] or 0) < 0.12 then return end
	requestTimes[player] = now
	local role = roleOf(player)
	local ability = findAbility(role, abilityId)
	if not ability then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = rootOf(character)
	if not character or not humanoid or humanoid.Health <= 0 or not root then
		sendFeedback(player, abilityId, false, "You cannot act right now.")
		return
	end
	if not EquipmentService.GetEquippedWeapon(player) then
		sendFeedback(player, abilityId, false, "Equip your role's weapon in Gear [I] first.")
		return
	end
	local playerCooldowns = cooldowns[player] or {}
	cooldowns[player] = playerCooldowns
	if (playerCooldowns[abilityId] or 0) > now then
		sendFeedback(player, abilityId, false, "That ability is still recovering.")
		return
	end

	local head = character:FindFirstChild("Head")
	local origin = if head and head:IsA("BasePart") then head.Position else root.Position + Vector3.new(0, 1.5, 0)
	local kind = ability.Kind
	local actionType = if ability.Visual or kind == "heal" or kind == "group_heal" or kind == "control" then "spell" elseif kind == "guard" then "guard" elseif kind == "taunt" then "shout" else "attack"
	local message = ability.Name .. "."
	local tint = AbilityDefinitions.Roles[role].Tint
	-- A valid action spends its cooldown and animates even when it hits nothing.
	playerCooldowns[abilityId] = now + ability.Cooldown
	actionAnimationRemote:FireAllClients(player.UserId, actionType, tint, ability.AnimationDuration)
	if kind == "damage" or kind == "area_damage" then
		local hits, endpoint = aimedHits(character, origin, direction, ability.Range, ability.Visual == "bolt", kind == "area_damage")
		local count = if kind == "area_damage" then #hits else math.min(#hits, 1)
		for index = 1, count do
			local hit = hits[index]
			applyDamage(player, hit, ability.Damage, now)
			if ability.Stun then hit.Target:SetAttribute("CrownlessStunnedUntil", now + ability.Stun) end
			if ability.Interrupt then hit.Target:SetAttribute("CrownlessInterruptedUntil", now + ability.Interrupt) end
		end
		if ability.Visual == "bolt" then spellVisual(origin, endpoint, tint, false) end
		message = ability.Name .. (if count > 0 then " · " .. tostring(count) .. " hit" else " · missed")
	elseif kind == "taunt" or kind == "control" then
		local hits, endpoint = aimedHits(character, origin, direction, ability.Range, ability.Visual == "bolt", false)
		if #hits > 0 then
			if kind == "taunt" then
				CombatService.Taunt(hits[1].Target, player, ability.Duration)
				message = "You call the enemy's attention."
			else
				hits[1].Target:SetAttribute("CrownlessStunnedUntil", now + ability.Duration)
				message = ability.Name .. " · foe held"
			end
		else
			message = ability.Name .. " · no target struck"
		end
		if ability.Visual == "bolt" then spellVisual(origin, endpoint, tint, false) end
	elseif kind == "guard" then
		player:SetAttribute("CrownlessGuardUntil", now + ability.Duration)
		message = "You brace behind your armor."
	elseif kind == "heal" then
		local allies = injuredAllies(player, root.Position, ability.Range)
		local ally = allies[1] or player
		local allyHumanoid = ally.Character and ally.Character:FindFirstChildOfClass("Humanoid")
		local allyRoot = rootOf(ally.Character)
		local effective = 0
		if allyHumanoid and allyHumanoid.Health > 0 then
			local before = allyHumanoid.Health
			allyHumanoid.Health = math.min(allyHumanoid.MaxHealth, before + ability.Healing)
			effective = allyHumanoid.Health - before
		end
		CombatService.RecordHealingThreat(player, effective, engagedEnemies(root.Position))
		if ability.Visual == "pulse" then spellVisual(origin, if allyRoot then allyRoot.Position else origin, tint, true) end
		message = if effective > 0 then "Mended " .. ally.DisplayName .. " for " .. math.floor(effective) .. "." else ability.Name .. " · already at full health"
	elseif kind == "group_heal" then
		local total = 0
		local count = 0
		for _, ally in ipairs(Players:GetPlayers()) do
			local allyHumanoid = ally.Character and ally.Character:FindFirstChildOfClass("Humanoid")
			local allyRoot = rootOf(ally.Character)
			if isPartyAlly(player, ally) and allyHumanoid and allyHumanoid.Health > 0 and allyRoot and (allyRoot.Position - root.Position).Magnitude <= ability.Range then
				local before = allyHumanoid.Health
				allyHumanoid.Health = math.min(allyHumanoid.MaxHealth, before + ability.Healing)
				total += allyHumanoid.Health - before
				count += 1
				if ability.Visual == "pulse" then spellVisual(origin, allyRoot.Position, tint, true) end
			end
		end
		CombatService.RecordHealingThreat(player, total, engagedEnemies(root.Position))
		message = "Renewing word · " .. tostring(count) .. " in the party"
	end
	sendFeedback(player, abilityId, true, message, ability.Cooldown)
end

function AbilityService.Init(abilityRemote: RemoteEvent, feedback: RemoteEvent, actionAnimation: RemoteEvent, damageMeter: RemoteEvent)
	feedbackRemote = feedback
	actionAnimationRemote = actionAnimation
	damageMeterRemote = damageMeter
	abilityRemote.OnServerEvent:Connect(handleAbility)
	Players.PlayerRemoving:Connect(function(player)
		cooldowns[player] = nil
		requestTimes[player] = nil
		damageSamples[player] = nil
	end)
end

return AbilityService
