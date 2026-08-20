local ServerScriptService = game:GetService("ServerScriptService")

-- Get Constants
local CONSTANTS = require(ServerScriptService.SharedServer.Constants)

-- Cap Definition
local MAX_MOVEMENT_SPEED = 16

-- Scaling Definition
local DAMAGE_MULTIPLIER = 1.2
local LIFE_MULTIPLIER = 1.2
local MOVEMENT_SPEED_INCREMENT = 0.2

local Enemies = {
	Dummy = 1,
	Robot = 2,
}

local EnemiesStats = {
	{
		Name = "Dummy",
		MaxLife = 100,
	},
	{
		Name = "Robot",
		MaxLife = 100,
		Damage = 3,
		AttackSpeed = 1,
		Range = 9,
		MovementSpeed = 5,
	},
}

local EnemiesPrefabs = {
	CONSTANTS.PREFABS_FOLDER.Enemies:FindFirstChild("Dummy"),
	CONSTANTS.PREFABS_FOLDER.Enemies:FindFirstChild("Mobot"),
}

-- POOLS

export type Pool = {
	name: string,
	definitionId: number,
	size: number,
	startIndex: number,
	endIndex: number,
	activeCount: number,
}

local EnemiesPool = {
	{
		name = "Dummy",
		definitionId = 1,
		size = 100,
		startIndex = 0,
		endIndex = 0,
		activeCount = 0,
	},
	{
		name = "Robot",
		definitionId = 2,
		size = 200,
		startIndex = 0,
		endIndex = 0,
		activeCount = 0,
	},
}

local EnemyDefinitions = {
	Enemies = Enemies,
	EnemiesStats = EnemiesStats,
	EnemiesPrefabs = EnemiesPrefabs,
	EnemiesPool = EnemiesPool,
	-- Constants
	MAX_MOVEMENT_SPEED = MAX_MOVEMENT_SPEED,
	DAMAGE_MULTIPLIER = DAMAGE_MULTIPLIER,
	LIFE_MULTIPLIER = LIFE_MULTIPLIER,
	MOVEMENT_SPEED_INCREMENT = MOVEMENT_SPEED_INCREMENT,
}

return EnemyDefinitions
