-- A single heartbeat connection updates every registered enemy, keeping a
-- dungeon server from creating one loop per NPC.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig") :: ModuleScript)

type EnemyTick = (model: Model, deltaTime: number) -> ()

local EnemyAIManager = {}
local enemies: {[Model]: EnemyTick} = {}
local started = false

local function clearEnemy(model: Model)
	local services = script.Parent
	if not services then
		return
	end
	local combatService = services:WaitForChild("CombatService") :: ModuleScript
	require(combatService).ClearEnemy(model)
end

function EnemyAIManager.Register(model: Model, onTick: EnemyTick)
	assert(typeof(model) == "Instance" and model:IsA("Model"), "Register expects an enemy Model")
	enemies[model] = onTick
	model.Destroying:Once(function()
		enemies[model] = nil
		clearEnemy(model)
	end)
end

function EnemyAIManager.Unregister(model: Model)
	enemies[model] = nil
	clearEnemy(model)
end

function EnemyAIManager.Start()
	if started then
		return
	end
	started = true
	local elapsed = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		elapsed += deltaTime
		if elapsed < GameConfig.EnemyAITickSeconds then
			return
		end
		local tickDelta = elapsed
		elapsed = 0
		for model, onTick in pairs(enemies) do
			if model.Parent then
				local ok, message = pcall(function()
					onTick(model, tickDelta)
				end)
				if not ok then
					warn("Crownless enemy AI error: " .. tostring(message))
				end
			else
				enemies[model] = nil
			end
		end
	end)
end

return EnemyAIManager
