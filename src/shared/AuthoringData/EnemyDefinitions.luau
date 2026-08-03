local ServerScriptService = game:GetService("ServerScriptService")

-- Get Constants
local CONSTANTS = require(ServerScriptService.SharedServer.Constants)

local Enemies = {
	Dummy = 1,
	Robot = 2,
}

-- Endgame Setup = csv file
local EnemiesDefinitions = {
	{
		Name = "Dummy",
		MaxLife = 100,
	},
	{
		Name = "Robot",
		MaxLife = 100,
		Damage = 10,
		AttackSpeed = 1,
		MovementSpeed = 5,
	},
}

local EnemiesPrefabs = {
	CONSTANTS.PREFABS_FOLDER.Enemies:FindFirstChild("Dummy"),
	CONSTANTS.PREFABS_FOLDER.Enemies:FindFirstChild("Robot"),
}

local Archetypes = {
	{
		name = "Dummy",
		definitionId = 1,
		count = 100,
		setup = {},
		components = {
			CONSTANTS.EcsStorages.gameObject,
			CONSTANTS.EcsStorages.unit,
			CONSTANTS.EcsStorages.lifeBar,
		},
		startIndex = 0,
		endIndex = 0,
		activeCount = 0,
	},
	{
		name = "Robot",
		definitionId = 2,
		count = 100,
		setup = {},
		components = {
			CONSTANTS.EcsStorages.gameObject,
			CONSTANTS.EcsStorages.unit,
			CONSTANTS.EcsStorages.lifeBar,
			-- CONSTANTS.EcsStorages.mobBehavior,
		},
		startIndex = 0,
		endIndex = 0,
		activeCount = 0,
	},
}

local archetypesTotalSize = 200

return {
	Enemies = Enemies,
	EnemiesDefinitions = EnemiesDefinitions,
	EnemiesPrefabs = EnemiesPrefabs,
	Archetypes = Archetypes,
}
