local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local PartyService = {}

local parties = {}
local memberParty = {}
local nextPartyId = 0
local stateRemote
local readyEvent = Instance.new("BindableEvent")

local function makeSummary(party)
	local slots = {}
	for _, role in ipairs(GameConfig.PartyRoles) do
		local player = party.members[role]
		slots[role] = player and player.DisplayName or nil
	end
	return {
		partyId = party.id,
		status = party.status,
		roles = slots,
	}
end

local function publish(party, message)
	local summary = makeSummary(party)
	for _, player in pairs(party.members) do
		if player and player.Parent == Players then
			stateRemote:FireClient(player, {
				status = party.status,
				role = player:GetAttribute("CrownlessRole"),
				party = summary,
				message = message,
			})
		end
	end
end

local function partyHasRole(party, role)
	return party.members[role] ~= nil
end

local function findOpenParty(role)
	for id = 1, nextPartyId do
		local party = parties[id]
		if party and party.status == "forming" and not partyHasRole(party, role) then
			return party
		end
	end
	return nil
end

local function isFull(party)
	for _, role in ipairs(GameConfig.PartyRoles) do
		if not party.members[role] then
			return false
		end
	end
	return true
end

local function queuePlayer(player, role)
	if type(role) ~= "string" or not GameConfig.RoleDefinitions[role] then
		return
	end
	if memberParty[player.UserId] then
		return
	end

	local party = findOpenParty(role)
	if not party then
		nextPartyId += 1
		party = { id = nextPartyId, members = {}, status = "forming" }
		parties[party.id] = party
	end

	party.members[role] = player
	memberParty[player.UserId] = party.id
	player:SetAttribute("CrownlessRole", role)
	player:SetAttribute("CrownlessPartyId", party.id)

	if isFull(party) then
		party.status = "ready"
	end
	publish(party, party.status == "ready" and "Party assembled. Preparing dungeon..." or "Queued for a four-role party.")
	if party.status == "ready" then
		readyEvent:Fire(party.id)
	end
end

local function leave(player)
	local partyId = memberParty[player.UserId]
	local party = partyId and parties[partyId]
	if not party or party.status == "launching" then
		return
	end
	for role, member in pairs(party.members) do
		if member == player then
			party.members[role] = nil
			break
		end
	end
	memberParty[player.UserId] = nil
	player:SetAttribute("CrownlessRole", nil)
	player:SetAttribute("CrownlessPartyId", nil)
	if next(party.members) == nil then
		parties[party.id] = nil
	else
		party.status = "forming"
		publish(party, "A player left; the party is forming again.")
	end
	if player.Parent == Players then
		stateRemote:FireClient(player, { status = "idle", message = "You left the group finder." })
	end
end

function PartyService.Init(remotes)
	stateRemote = remotes.PartyState
	remotes.QueueForRole.OnServerEvent:Connect(queuePlayer)
	remotes.LeaveQueue.OnServerEvent:Connect(leave)
	remotes.GetPartyState.OnServerInvoke = function(player)
		local partyId = memberParty[player.UserId]
		local party = partyId and parties[partyId]
		if not party then
			return { status = "idle" }
		end
		return {
			status = party.status,
			role = player:GetAttribute("CrownlessRole"),
			party = makeSummary(party),
		}
	end
end

function PartyService.GetReadyEvent()
	return readyEvent.Event
end

function PartyService.GetMembers(partyId)
	local party = parties[partyId]
	if not party then
		return nil
	end
	local members = {}
	for _, role in ipairs(GameConfig.PartyRoles) do
		local player = party.members[role]
		if player and player.Parent == Players then
			table.insert(members, player)
		end
	end
	return members
end

function PartyService.SetStatus(partyId, status, message)
	local party = parties[partyId]
	if not party then
		return
	end
	party.status = status
	publish(party, message)
end

function PartyService.HandlePlayerRemoving(player)
	local partyId = memberParty[player.UserId]
	local party = partyId and parties[partyId]
	if not party then
		return
	end
	for role, member in pairs(party.members) do
		if member == player then
			party.members[role] = nil
			break
		end
	end
	memberParty[player.UserId] = nil
	if next(party.members) == nil then
		parties[party.id] = nil
	elseif party.status ~= "launching" then
		party.status = "forming"
		publish(party, "A player left; the party is forming again.")
	end
end

return PartyService
