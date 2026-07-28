-- Dynamic State
-- > Data is Mutable != RoduxStore
-- For High Frequency Data eg ECS Components
-- This Data might be sent to the Rodux Store in the Throttled Update -> Use Commands Buffer

local combatState = {
	playersClosestEnemy = {},
	expectingAttack = {},
	attackBuffer = {},
	lastAttacks = {},
	comboIndexes = {}, -- For Weapon Animation
	comboReset = {},
}

local statState = {
	totalXp = 0, -- Add to joining players
	positionStart = {},
	playersLife = {},
	lifeRegenUpdates = {},
}

-- ECS State
-- local storageCount = 0

-- Meta Table
local storageState = {}

function storageState.new(id, name)
	local self = {
		id = id,
		name = name,
		sparse = {},
		entities = {},
	}

	setmetatable(self, storageState)
	return self
end

-- GameObject Storage Struct
local gameObjectStorageState = storageState.new(1, "GameObjectSystem")
gameObjectStorageState.gameObjects = {}

-- Unit Storage Struct
local unitStorageState = storageState.new(2, "unitStorageState")
unitStorageState.definitionId = {}
unitStorageState.life = {}
unitStorageState.lifeBar = {}
unitStorageState.deathEvent = {}

local EcsState = {
	entitiesId = {},
	entitiesBitmask = {},
	versions = {},
	storages = {},
	gameObjectStorageState = gameObjectStorageState,
	unitStorageState = unitStorageState,
}

local MutState = {
	frameCount = 0,
	playersDetections = {}, -- TODO : Flatten -> use playersDetectionCount
	combatState = combatState,
	statState = statState,
	ecsState = EcsState,
}

return MutState
