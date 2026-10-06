local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local DungeonService = {}
local partyService

function DungeonService.Init(dependencies)
	partyService = dependencies.PartyService
end

function DungeonService.LaunchParty(partyId)
	if GameConfig.DungeonPlaceId <= 0 then
		partyService.SetStatus(partyId, "ready", "Set DungeonPlaceId in GameConfig to enable dungeon teleporting.")
		return false
	end

	local members = partyService.GetMembers(partyId)
	if not members or #members ~= GameConfig.PartySize then
		partyService.SetStatus(partyId, "forming", "The party changed before launch; waiting for a replacement.")
		return false
	end

	partyService.SetStatus(partyId, "launching", "Reserving a dungeon server...")
	local options = Instance.new("TeleportOptions")
	options.ShouldReserveServer = true
	options:SetTeleportData({
		partyId = partyId,
		difficulty = GameConfig.DungeonDifficulty,
	})

	local ok, result = pcall(function()
		return TeleportService:TeleportAsync(GameConfig.DungeonPlaceId, members, options)
	end)
	if not ok then
		warn("Crownless party teleport failed: " .. tostring(result))
		partyService.SetStatus(partyId, "ready", "Dungeon launch failed. Your party is still assembled; try again later.")
		return false
	end
	return true
end

return DungeonService
