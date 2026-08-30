-- MutableState = Dynamic State
-- Mutable Data != RoduxStore
-- For High Frequency Data eg ECS Components
-- This Data might be sent infrequently to the Rodux Store -> Use Commands Buffer
-- Create 1 File / Service Slice -> Combine all in this file?

-- Services Global Order :
-- System Services :
-- 1) PlayerService
-- 2) LevelService
-- 3) EcsService
-- 4) PoolService
-- 5) ItemService

-- Gameplay Services :
-- 6) RpgService
-- 7) EnemyService
-- 8) AugmentService
-- 9) CombatService

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Gears = require(ReplicatedStorage.Shared.Gears)

-- Get Constants
local CONSTANTS = require(ServerScriptService.SharedServer.Constants)
local EnemyConst = CONSTANTS.EnemyConst
local Enemies = EnemyConst.Enemies
local EnemiesStats = EnemyConst.EnemiesStats

local mainSounds = CONSTANTS.PREFABS_FOLDER.Sounds.MainSounds

-- #region PLAYER SERVICE STATE

local enemiesDetectionParam = OverlapParams.new()
enemiesDetectionParam.FilterType = Enum.RaycastFilterType.Include
enemiesDetectionParam.FilterDescendantsInstances = { CONSTANTS.WEAPON_HIT_FOLDER }
enemiesDetectionParam.MaxParts = 1200 -- MaxEnemies * averagePartsCount

local autoPickupParam = OverlapParams.new()
autoPickupParam.FilterType = Enum.RaycastFilterType.Include
autoPickupParam.FilterDescendantsInstances = { workspace.AutoPickup }
autoPickupParam.MaxParts = 100

local PlayerServiceState = {
	secondTimer = 0,
	enemiesDetectionParam = enemiesDetectionParam,
	autoPickupParam = autoPickupParam,
	playersDetections = {},
	buildingsDetections = {},
	autoPickups = {},
}

-- #endregion

-- Level Service State
local LevelState = {
	-- Map
	currentMapId = 0,
	addMusicHandle = nil,
	addMusicHandles = {},
	stageRadius = 200,

	-- Stage
	stageProgress = 0,
	stageCountDownTime = 0,
	stageCountDown = 0,
	countdownHandle = nil,
	isWaitingForNextStage = false,

	-- Buildings
	buildingFolder = nil, -- TODO : Move to GameState
	buildingsDetectionParam = nil,
	buildingsHealth = {}, -- TODO : Use ECS instead
	buildingAmount = 3,
	currentBuildings = {},
	totalParts = 0,
	partsCount = 0,

	-- Events
	maxEvents = 0,
	currentEventIndex = 1,
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
UnitStorageState.dispawnCd = {}
UnitStorageState.onDispawn = {}
UnitStorageState.attackCd = {}

-- LifeBar
local LifeBarStorageState = StorageState.new(3, "LifeBarStorageState")
LifeBarStorageState.lifeBar = {}

-- Custom
local CustomStorageState = StorageState.new(4, "CustomStorageState")
CustomStorageState.customProperties = {}

-- MobBehavior
local MobBehaviorStorageState = StorageState.new(5, "MobBehaviorStorageState")
-- MobBehaviorStorageState.target = {}
-- MobBehaviorStorageState.targetPos = {} -- TODO : Movement Component
-- MobBehaviorStorageState.damage = {}
-- MobBehaviorStorageState.attackRange = {}

-- Definition
local DefinitionStorageState = StorageState.new(6, "DefinitionStorageState")
DefinitionStorageState.types = {}
DefinitionStorageState.definitionIDs = {}

local EcsState = {
	entitiesId = {},
	entitiesBitmask = {},
	-- versions = {},

	-- Storages
	storages = {},
	GameObjectStorageState = GameObjectStorageState,
	UnitStorageState = UnitStorageState,
	LifeBarStorageState = LifeBarStorageState,
	CustomStorageState = CustomStorageState,
	MobBehaviorStorageState = MobBehaviorStorageState,
	DefinitionStorageState = DefinitionStorageState,

	-- Archetypes
	-- archetypes = {},
}

-- #endregion

local PoolServiceState = {
	pools = {},
	entitiesPool = {},
}

local ItemServiceState = {
	bananaLootChance = 25, -- TODO : Per Player
	stickLootChance = 10, -- TODO : Per Player
	poolIDs = {},
	groundItemsModels = {},
	itemsMovement = {},
}

local RpgState = {
	totalXp = 0, -- Add to joining players
	positionStart = {},
	playersLife = {},
	lifeRegenUpdates = {},
}

local EnemyServiceState = {
	currentRobotStats = Gears.DeepCopy(EnemiesStats[Enemies.Robot]),
	poolIDs = {},

	-- Stream Spawn
	streamSpawnNbr = 1,
	streamSpawnNbrRange = 1,
	streamSpawnDeltaTime = 7,
	streamSpawnDeltaTimeRange = 2,
	streamSpawnDelta = 0,
	streamSpawnTimer = 0,

	-- SwarmSpawn
	swarmWaves = 0,
	swarmAmount = 2,
	swarmAmountRange = 1,
}

-- AugmentState

-- #region COMBAT STATE

local weaponHitParam = OverlapParams.new()
weaponHitParam.FilterType = Enum.RaycastFilterType.Include
weaponHitParam.FilterDescendantsInstances = { CONSTANTS.WEAPON_HIT_FOLDER }
weaponHitParam.MaxParts = 100

local CombatState = {
	weaponHitParam = weaponHitParam,
	playersClosestEnemy = {},
	playersClosestBuilding = {},
	expectingAttack = {},
	attackBuffer = {},
	lastAttacks = {},
	comboIndexes = {}, -- For Weapon Animation
	comboReset = {},
}

-- #endregion

local MutState = {
	-- Global
	gameTimer = 0,
	gameTimerCount = 0,
	frameCount = 0,
	mainSounds = mainSounds,

	-- TODO : Current Place State (Hub or Game)

	-- Services
	PlayerServiceState = PlayerServiceState,
	LevelState = LevelState,
	EcsState = EcsState,
	PoolServiceState = PoolServiceState,
	ItemServiceState = ItemServiceState,

	RpgState = RpgState,
	EnemyServiceState = EnemyServiceState,
	CombatState = CombatState,
}

return MutState
