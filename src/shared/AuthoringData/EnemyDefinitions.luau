local ServerScriptService = game:GetService("ServerScriptService")

-- Get Constants
local CONSTANTS = require(ServerScriptService.SharedServer.Constants)

local Enemies = {
	Dummy = 1,
	Robot = 2,
}

-- Cap Definition
local MAX_MOVEMENT_SPEED = 16

-- Scaling Definition
local DAMAGE_INCREMENT = 3
local LIFE_INCREMENT = 5
local MOVEMENT_SPEED_INCREMENT = 1

-- Endgame Setup = csv file
local EnemiesStats = {
	{
		Name = "Dummy",
		MaxLife = 100,
	},
	{
		Name = "Robot",
		MaxLife = 100,
		Damage = 10,
		AttackSpeed = 1,
		Range = 9,
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
			CONSTANTS.EcsStorages.custom,
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

local EnemyDefinitions = {
	Enemies = Enemies,
	EnemiesStats = EnemiesStats,
	EnemiesPrefabs = EnemiesPrefabs,
	Archetypes = Archetypes,
	MAX_MOVEMENT_SPEED = MAX_MOVEMENT_SPEED,
	DAMAGE_INCREMENT = DAMAGE_INCREMENT,
	LIFE_INCREMENT = LIFE_INCREMENT,
	MOVEMENT_SPEED_INCREMENT = MOVEMENT_SPEED_INCREMENT,
}

return EnemyDefinitions
