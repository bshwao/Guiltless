local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local NetworkNames = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("NetworkNames") :: ModuleScript)
local remotesFolder = ReplicatedStorage:FindFirstChild(NetworkNames.Folder)
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = NetworkNames.Folder
	remotesFolder.Parent = ReplicatedStorage
end

local function getRemote(className, name)
	local remote = remotesFolder:FindFirstChild(name)
	if not remote then
		remote = Instance.new(className)
		remote.Name = name
		remote.Parent = remotesFolder
	end
	return remote
end

local remotes = {
	QueueForRole = getRemote("RemoteEvent", NetworkNames.QueueForRole),
	LeaveQueue = getRemote("RemoteEvent", NetworkNames.LeaveQueue),
	PartyState = getRemote("RemoteEvent", NetworkNames.PartyState),
	GetPartyState = getRemote("RemoteFunction", NetworkNames.GetPartyState),
	UseAbility = getRemote("RemoteEvent", NetworkNames.UseAbility),
	AbilityFeedback = getRemote("RemoteEvent", NetworkNames.AbilityFeedback),
	ActionAnimation = getRemote("RemoteEvent", NetworkNames.ActionAnimation),
	DamageMeter = getRemote("RemoteEvent", NetworkNames.DamageMeter),
	SetPreferredRole = getRemote("RemoteEvent", NetworkNames.SetPreferredRole),
	EquipItem = getRemote("RemoteEvent", NetworkNames.EquipItem),
	EquipmentFeedback = getRemote("RemoteEvent", NetworkNames.EquipmentFeedback),
}

local Services = assert(script.Parent, "Bootstrap must be parented to a server container"):WaitForChild("Services")
local PartyService = require(Services:WaitForChild("PartyService"))
local DungeonService = require(Services:WaitForChild("DungeonService"))
local GroupFinderService = require(Services:WaitForChild("GroupFinderService"))
local PlayerDataService = require(Services:WaitForChild("PlayerDataService"))
local EnemyAIManager = require(Services:WaitForChild("EnemyAIManager"))
local NPCService = require(Services:WaitForChild("NPCService"))
local CharacterLoadoutService = require(Services:WaitForChild("CharacterLoadoutService"))
local AbilityService = require(Services:WaitForChild("AbilityService"))

PartyService.Init(remotes)
DungeonService.Init({ PartyService = PartyService })
GroupFinderService.Init(PartyService, DungeonService)
EnemyAIManager.Start()
PlayerDataService.Start()
NPCService.Start()
CharacterLoadoutService.Start(remotes.SetPreferredRole, remotes.EquipItem, remotes.EquipmentFeedback)
AbilityService.Init(remotes.UseAbility, remotes.AbilityFeedback, remotes.ActionAnimation, remotes.DamageMeter)

Players.PlayerRemoving:Connect(function(player)
	PartyService.HandlePlayerRemoving(player)
end)

print("Crownless server systems started.")
