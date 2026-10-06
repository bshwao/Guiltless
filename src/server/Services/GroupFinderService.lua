local GroupFinderService = {}

function GroupFinderService.Init(partyService, dungeonService)
	partyService.GetReadyEvent():Connect(function(partyId)
		dungeonService.LaunchParty(partyId)
	end)
end

return GroupFinderService
