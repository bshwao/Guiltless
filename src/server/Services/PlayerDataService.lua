local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local GameConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("GameConfig"))
local useStudioMockData = RunService:IsStudio() and GameConfig.UseStudioMockData
local Store = not useStudioMockData and DataStoreService:GetDataStore(GameConfig.DataStoreName) or nil

local PlayerDataService = {}
local Profiles = {}
local Loading = {}

local DEFAULT_DATA = {
	level = 1,
	experience = 0,
	gold = 0,
	inventory = {},
	gearDurability = {},
}

local function copyTable(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, child in pairs(value) do
		result[key] = copyTable(child)
	end
	return result
end

local function dataKey(player)
	return "Player_" .. player.UserId
end

local function loadPlayer(player)
	if Loading[player.UserId] or Profiles[player.UserId] then
		return
	end
	Loading[player.UserId] = true
	if useStudioMockData then
		Profiles[player.UserId] = { token = "studio-mock", data = copyTable(DEFAULT_DATA) }
		Loading[player.UserId] = nil
		player:SetAttribute("CrownlessLevel", 1)
		player:SetAttribute("CrownlessExperience", 0)
		player:SetAttribute("CrownlessGold", 0)
		return
	end

	local token = game.JobId .. ":" .. HttpService:GenerateGUID(false)
	local success, profile

	for attempt = 1, 5 do
		local now = os.time()
		local ok, result = pcall(function()
			return Store:UpdateAsync(dataKey(player), function(old)
				old = type(old) == "table" and old or {}
				local lock = old.SessionLock
				if type(lock) == "table" and lock.owner ~= token and (tonumber(lock.expiresAt) or 0) > now then
					return nil
				end
				old.Data = type(old.Data) == "table" and old.Data or copyTable(DEFAULT_DATA)
				old.SessionLock = { owner = token, expiresAt = now + GameConfig.SessionLockSeconds }
				return old
			end)
		end)
		if ok and type(result) == "table" and type(result.SessionLock) == "table" and result.SessionLock.owner == token then
			profile = {
				token = token,
				data = copyTable(result.Data or DEFAULT_DATA),
			}
			success = true
			break
		end
		if not ok then
			warn("Crownless data load failed for user " .. player.UserId .. ": " .. tostring(result))
		end
		task.wait(math.min(attempt * 2, 8))
	end

	Loading[player.UserId] = nil
	if not player.Parent then
		if success then
			Profiles[player.UserId] = profile
			PlayerDataService.Release(player)
		end
		return
	end
	if not success then
		player:Kick("Your data could not be safely loaded. Please rejoin.")
		return
	end

	Profiles[player.UserId] = profile
	player:SetAttribute("CrownlessLevel", tonumber(profile.data.level) or 1)
	player:SetAttribute("CrownlessExperience", tonumber(profile.data.experience) or 0)
	player:SetAttribute("CrownlessGold", tonumber(profile.data.gold) or 0)
end

function PlayerDataService.GetData(player)
	local profile = Profiles[player.UserId]
	return profile and profile.data or nil
end

function PlayerDataService.Save(player, releaseLock)
	local profile = Profiles[player.UserId]
	if not profile then
		return false
	end
	if useStudioMockData then
		if releaseLock then
			Profiles[player.UserId] = nil
		end
		return true
	end

	local ok, result = pcall(function()
		return Store:UpdateAsync(dataKey(player), function(old)
			if type(old) ~= "table" or type(old.SessionLock) ~= "table" or old.SessionLock.owner ~= profile.token then
				return nil
			end
			old.Data = copyTable(profile.data)
			if releaseLock then
				old.SessionLock = nil
			else
				old.SessionLock.expiresAt = os.time() + GameConfig.SessionLockSeconds
			end
			return old
		end)
	end)

	if not ok or type(result) ~= "table" then
		warn("Crownless data save failed for user " .. player.UserId .. ": " .. tostring(result))
		return false
	end
	if releaseLock then
		Profiles[player.UserId] = nil
	end
	return true
end

function PlayerDataService.Release(player)
	return PlayerDataService.Save(player, true)
end

function PlayerDataService.Start()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(loadPlayer, player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(loadPlayer, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		Loading[player.UserId] = nil
		PlayerDataService.Release(player)
	end)

	task.spawn(function()
		while true do
			task.wait(GameConfig.AutosaveSeconds)
			for _, player in ipairs(Players:GetPlayers()) do
				if Profiles[player.UserId] then
					task.spawn(PlayerDataService.Save, player, false)
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for _, player in ipairs(Players:GetPlayers()) do
			if Profiles[player.UserId] then
				pending += 1
				task.spawn(function()
					PlayerDataService.Release(player)
					pending -= 1
				end)
			end
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return PlayerDataService
