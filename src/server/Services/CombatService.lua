-- Server-only threat bookkeeping. Call these functions with actual, server
-- calculated damage/healing after the corresponding effect has resolved.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig") :: ModuleScript)
local CombatService = {}
local threatByEnemy = setmetatable({}, { __mode = "k" })

local function getThreat(enemy)
	local threat = threatByEnemy[enemy]
	if not threat then
		threat = { values = {}, tauntPlayer = nil, tauntExpires = 0 }
		threatByEnemy[enemy] = threat
	end
	return threat
end

function CombatService.RecordDamageThreat(enemy, player, actualDamage)
	if not enemy or not enemy:IsDescendantOf(workspace) or not player or player.Parent ~= Players then
		return
	end
	local amount = math.max(0, tonumber(actualDamage) or 0)
	local role = player:GetAttribute("CrownlessRole")
	local definition = GameConfig.RoleDefinitions[role]
	local multiplier = definition and definition.ThreatMultiplier or 1
	local threat = getThreat(enemy)
	threat.values[player] = (threat.values[player] or 0) + amount * multiplier
end

function CombatService.RecordHealingThreat(healer, effectiveHealing, engagedEnemies)
	if not healer or healer.Parent ~= Players or type(engagedEnemies) ~= "table" then
		return
	end
	local enemies = {}
	for _, enemy in ipairs(engagedEnemies) do
		if enemy and enemy:IsDescendantOf(workspace) then
			table.insert(enemies, enemy)
		end
	end
	if #enemies == 0 then
		return
	end
	local perEnemy = math.max(0, tonumber(effectiveHealing) or 0) * 0.5 / #enemies
	for _, enemy in ipairs(enemies) do
		local threat = getThreat(enemy)
		threat.values[healer] = (threat.values[healer] or 0) + perEnemy
	end
end

function CombatService.Taunt(enemy, player, duration)
	if not enemy or not enemy:IsDescendantOf(workspace) or not player or player.Parent ~= Players then
		return false
	end
	local threat = getThreat(enemy)
	local highest = 0
	for _, value in pairs(threat.values) do
		highest = math.max(highest, value)
	end
	local role = player:GetAttribute("CrownlessRole")
	local definition = GameConfig.RoleDefinitions[role]
	local multiplier = definition and definition.ThreatMultiplier or 1
	threat.values[player] = math.max(threat.values[player] or 0, highest + 1) * multiplier
	threat.tauntPlayer = player
	threat.tauntExpires = os.clock() + math.max(0.1, tonumber(duration) or 3)
	return true
end

function CombatService.GetTopThreatPlayer(enemy)
	local threat = threatByEnemy[enemy]
	if not threat then
		return nil
	end
	if threat.tauntPlayer and threat.tauntExpires > os.clock() and threat.tauntPlayer.Parent == Players then
		return threat.tauntPlayer
	end
	local topPlayer, topValue = nil, -1
	for player, value in pairs(threat.values) do
		if player.Parent == Players and value > topValue then
			topPlayer, topValue = player, value
		end
	end
	return topPlayer
end

function CombatService.ClearEnemy(enemy)
	threatByEnemy[enemy] = nil
end

-- Shared damage formula for enemy attack scripts. Tank gear and Brace both
-- reduce incoming physical damage; the caller still owns applying the result.
function CombatService.ResolveIncomingDamage(player, rawDamage)
	if not player or player.Parent ~= Players then
		return 0
	end
	local amount = math.max(0, tonumber(rawDamage) or 0)
	local armor = math.clamp(tonumber(player:GetAttribute("CrownlessArmorRating")) or 0, 0, 500)
	local damageAfterArmor = amount * (120 / (120 + armor))
	local guardUntil = tonumber(player:GetAttribute("CrownlessGuardUntil")) or 0
	if guardUntil > os.clock() then
		damageAfterArmor *= 0.45
	end
	return math.floor(damageAfterArmor + 0.5)
end

return CombatService
