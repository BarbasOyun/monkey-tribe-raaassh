-- Dynamic State
-- Mutable Data != RoduxStore
-- For High Frequency Data eg ECS Components
-- This Data might be sent to the Rodux Store in the Throttled Update -> Use Commands Buffer

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Gears = require(ReplicatedStorage.Shared.Gears)

-- Get Constants
local EnemyDefinitions = require(ReplicatedStorage.Shared.AuthoringData.EnemyDefinitions)
local Enemies = EnemyDefinitions.Enemies
local EnemiesStats = EnemyDefinitions.EnemiesStats

local LevelState = {
	-- Map
	currentMapId = 1,
	totalParts = 0,
	partsCount = 0,
	-- Stage
	stageProgress = 0,
	isWaitingForNextStage = false,
	currentStage = 1,
	buildingAmount = 3,
	-- Events
	maxEvents = 0,
	currentEventIndex = 1,
}

local StatState = {
	totalXp = 0, -- Add to joining players
	positionStart = {},
	playersLife = {},
	lifeRegenUpdates = {},
}

local EnemyServiceState = {
	enemiesDeathCount = 0,
	currentRobotStats = Gears.DeepCopy(EnemiesStats[Enemies.Robot]),
	-- Stream Spawn
	streamSpawnNbr = 2,
	streamSpawnDelta = 0,
	streamSpawnTimer = 0,
	-- SwarmSpawn
	swarmWaves = 0,
	swarmSpawnTimer = 0,
}

-- #region ECS STATE

-- Storage State Meta Table
local StorageState = {}

function StorageState.new(id, name)
	local self = {
		id = id,
		name = name,
		sparse = {},
		entities = {},
		-- customProperties = {}
	}

	setmetatable(self, StorageState)
	return self
end

-- GameObject
local GameObjectStorageState = StorageState.new(1, "GameObjectSystem")
GameObjectStorageState.gameObjects = {}

-- Unit
local UnitStorageState = StorageState.new(2, "UnitStorageState")
UnitStorageState.definitionId = {}
UnitStorageState.life = {}
UnitStorageState.lifeChanged = {}
UnitStorageState.deathEvent = {}
UnitStorageState.attackCd = {}

-- LifeBar
local LifeBarStorageState = StorageState.new(3, "LifeBarStorageState")
LifeBarStorageState.lifeBar = {}

-- Custom
local CustomStorageState = StorageState.new(4, "CustomStorageState")
CustomStorageState.customProperties = {}

-- MobBehavior
local MobBehaviorStorageState = StorageState.new(5, "MobBehaviorStorageState")
MobBehaviorStorageState.timer = 0
MobBehaviorStorageState.timerDelta = 0.5
MobBehaviorStorageState.target = {}
-- MobBehaviorStorageState.damage = {}
-- MobBehaviorStorageState.attackRange = {}

local EcsState = {
	entitiesId = {},
	entitiesBitmask = {},
	versions = {},
	-- Storages
	storages = {},
	GameObjectStorageState = GameObjectStorageState,
	UnitStorageState = UnitStorageState,
	LifeBarStorageState = LifeBarStorageState,
	CustomStorageState = CustomStorageState,
	MobBehaviorStorageState = MobBehaviorStorageState,
	-- Archetypes
	archetypes = {},
}

-- #endregion

local CombatState = {
	playersClosestEnemy = {},
	expectingAttack = {},
	attackBuffer = {},
	lastAttacks = {},
	comboIndexes = {}, -- For Weapon Animation
	comboReset = {},
}

local MutState = {
	-- globalTimer = 0,
	gameTimer = 0,
	gameTimerCount = 0,
	frameCount = 0,
	playersDetections = {}, -- TODO : Flatten -> use playersDetectionCount
	LevelState = LevelState,
	CombatState = CombatState,
	StatState = StatState,
	EnemyServiceState = EnemyServiceState,
	EcsState = EcsState,
	-- Current Place State (Hub or Level)
}

return MutState
