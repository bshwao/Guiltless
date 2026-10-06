-- Shared settings. Replace DungeonPlaceId with the published dungeon place ID
-- before enabling reserved-server dungeon runs.
local GameConfig = {
	GameName = "Crownless",
	HubMaxPlayers = 40,
	LevelCap = 30,
	PartySize = 4,
	PartyRoles = { "Tank", "Healer", "Damage", "Controller" },
	DungeonPlaceId = 0,
	DungeonDifficulty = "Normal",
	EnemyAITickSeconds = 0.2,
	DataStoreName = "CrownlessPlayerData_v1",
	UseStudioMockData = true,
	SessionLockSeconds = 180,
	AutosaveSeconds = 60,
}

GameConfig.RoleDefinitions = {
	Tank = {
		Description = "Protects the party and controls enemy threat.",
		ThreatMultiplier = 3,
	},
	Healer = {
		Description = "Keeps allies alive; healing can draw enemy threat.",
		ThreatMultiplier = 1,
	},
	Damage = {
		Description = "Deals focused damage to enemies.",
		ThreatMultiplier = 1,
	},
	Controller = {
		Description = "Interrupts, stuns, and controls dangerous enemies.",
		ThreatMultiplier = 1,
	},
}

return GameConfig
