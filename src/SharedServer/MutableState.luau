-- Dynamic State
-- Mutable Data != RoduxStore
-- For High Frequency Data eg ECS Components
-- This Data might be sent to the Rodux Store in the Throttled Update -> Use Commands Buffer

local CombatState = {
	playersClosestEnemy = {},
	expectingAttack = {},
	attackBuffer = {},
	lastAttacks = {},
	comboIndexes = {}, -- For Weapon Animation
	comboReset = {},
}

local StatState = {
	totalXp = 0, -- Add to joining players
	positionStart = {},
	playersLife = {},
	lifeRegenUpdates = {},
}

-- ECS State
-- local storageCount = 0

-- Meta Table
local StorageState = {}

function StorageState.new(id, name)
	local self = {
		id = id,
		name = name,
		sparse = {},
		entities = {},
	}

	setmetatable(self, StorageState)
	return self
end

-- GameObject Storage Struct
local GameObjectStorageState = StorageState.new(1, "GameObjectSystem")
GameObjectStorageState.gameObjects = {}

-- Unit Storage Struct
local UnitStorageState = StorageState.new(2, "UnitStorageState")
UnitStorageState.definitionId = {}
UnitStorageState.life = {}
UnitStorageState.lifeBar = {}
UnitStorageState.deathEvent = {}

local EcsState = {
	entitiesId = {},
	entitiesBitmask = {},
	versions = {},
	-- Storages
	storages = {},
	GameObjectStorageState = GameObjectStorageState,
	UnitStorageState = UnitStorageState,
	-- Archetypes
	archetypes = {},
}

local MutState = {
	frameCount = 0,
	playersDetections = {}, -- TODO : Flatten -> use playersDetectionCount
	CombatState = CombatState,
	StatState = StatState,
	EcsState = EcsState,
	-- Current Place State (Hub / Level)
}

return MutState
