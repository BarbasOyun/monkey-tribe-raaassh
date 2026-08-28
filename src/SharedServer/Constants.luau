-- Shared Server Side Game Constants + enums

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Load Authoring Data
local EnemyDefinitions = require(ReplicatedStorage.Shared.AuthoringData.EnemyDefinitions)
local itemDef = require(ReplicatedStorage.Shared.AuthoringData.ItemDefinitions)
local statsDefinition = require(ReplicatedStorage.Shared.AuthoringData.StatsDefinitions)

-- #region GLOBAL

local MAX_RADIANT = math.pi * 2

local PREFABS_FOLDER = ReplicatedStorage.Shared.Prefabs
local HUB_PLACE_ID = 95975992291805

-- Types of GameObjects with a Definition
local DefinedTypes = {
	Unit = 1,
	Items = 2,
}

local THROTTLED_UPDATE_FRAMES = 5

-- #endregion

-- #region PLAYER SERVICE

-- TODO : Rename (enum)
local PLAYER_STATES = {
	playing = "Playing",
	pickingAugment = "PickingAugment",
	-- menuing
}

-- TODO : Prevent Weapon Swap when Player is Attacking
-- local UNIT_STATES = {
-- 	Idle = 1,
-- 	PerformingAction = 2,
-- }

-- TODO : Object Currency

local CURRENCIES = {
	bananas = 1,
	sticks = 2,
	stones = 3,
}

local CURRENCIES_NAMES = {
	"bananas",
	"sticks",
	"stones",
}

local MAX_CURRENCIES = {
	100_000,
	10_000,
	10_000,
}

local ENEMIES_DETECTION_RADIUS = 150

-- local PlayerConsts = {
-- 	ENEMIES_DETECTION_RADIUS = ENEMIES_DETECTION_RADIUS,
-- 	PLAYER_STATES = PLAYER_STATES,
-- 	CURRENCIES = CURRENCIES,
-- 	CURRENCIES_NAMES = CURRENCIES_NAMES,
-- 	MAX_CURRENCIES = MAX_CURRENCIES,
-- }

-- #endregion

local LevelConst = {
	NEXT_STAGE_COUNTDOWN = 10,
}

-- ECS
local EcsStorages = {
	gameObject = 1,
	unit = 2,
	lifeBar = 3,
	custom = 4,
	mobBehavior = 5,
	definition = 6,
}

-- PoolService
local DISABLED_ENTITIES_FOLDER = ReplicatedStorage.DisabledEntities -- workspace.DisabledEntities ReplicatedStorage.DisabledEntities
local DISABLED_POSITION = Vector3.new(10_000, 0, 0) -- Test Pos = Vector3.new(0, 20, 0), Vector3.new(400, 0, 0), Vector3.new(10_000, 0, 0)

-- Item Service
local AUTOPICKUP_FOLDER = workspace.AutoPickup
local itemTypes = itemDef.itemTypes
local CategoryStore = itemDef.CategoryStore
local CategoryDefinitions = itemDef.CategoryDefinitions
local CategoryRegistries = itemDef.CategoryRegistries

local RpgConst = {
	-- Level
	ADDITIONAL_XP = 20,
	MULTIPLIER_XP = 1.2,

	-- Stats
	STATS_STORE = statsDefinition.STATS_STORE,
	MOD_STATS_STORE = statsDefinition.MOD_STATS_STORE,
	TO_STAT_OBJECT = statsDefinition.TO_STAT_OBJECT,
	MOD_STATS_INDEX = statsDefinition.MOD_STATS_INDEX,
	DEFAULT_STATS = statsDefinition.DEFAULT_STATS,
	STATS_DISPLAY = statsDefinition.STATS_DISPLAY,

	META_UPRGADES = statsDefinition.META_UPRGADES,
	AUGMENTS = statsDefinition.AUGMENTS,
}

-- #region ENEMY SERVICE CONST

local EnemyConst = {
	Enemies = EnemyDefinitions.Enemies,
	EnemiesStats = EnemyDefinitions.EnemiesStats,
	EnemiesPrefabs = {
		PREFABS_FOLDER.Enemies:FindFirstChild("Dummy"),
		PREFABS_FOLDER.Enemies:FindFirstChild("Mobot"),
	},

	-- Spawn
	SPAWN_RADIUS = 40,
	SPAWN_RADIUS_RANGE = 30,

	-- Stream Spawn
	STREAM_SPAWN_INITIAL_TIME = 7,
	STREAM_SPAWN_MIN_CD = 1,
	STREAM_SPAWN_LVL_BREAKPOINT = 3,
	STREAM_SPAWN_INCREMENT = 2,

	-- Swarm Spawn
	SWARM_WAVES = 4,
	SWARM_NBR = 4,
	SWARM_NBR_RANGE = 2,

	-- Cap
	MAX_MOVEMENT_SPEED = 16,

	-- Stats Scaling
	ENEMY_LVL_UP_BREAKPOINT = 30,
	DAMAGE_MULTIPLIER = 1.2,
	LIFE_MULTIPLIER = 1.2,
	MOVEMENT_SPEED_INCREMENT = 0.2,
}

-- #endregion

-- Augment Const

-- Combat Service
local WEAPON_HIT_FOLDER = workspace.WeaponHit

local CONSTANTS = {
	-- Global
	DefinedTypes = DefinedTypes,
	MAX_RADIANT = MAX_RADIANT,
	HUB_PLACE_ID = HUB_PLACE_ID,
	THROTTLED_UPDATE_FRAMES = THROTTLED_UPDATE_FRAMES,
	PREFABS_FOLDER = PREFABS_FOLDER,

	-- Full Services
	-- Players
	ENEMIES_DETECTION_RADIUS = ENEMIES_DETECTION_RADIUS,
	PLAYER_STATES = PLAYER_STATES,
	CURRENCIES = CURRENCIES,
	CURRENCIES_NAMES = CURRENCIES_NAMES,
	MAX_CURRENCIES = MAX_CURRENCIES,

	LevelConst = LevelConst,
	-- Ecs
	EcsStorages = EcsStorages,
	-- Pool
	DISABLED_ENTITIES_FOLDER = DISABLED_ENTITIES_FOLDER,
	DISABLED_POSITION = DISABLED_POSITION,

	-- Item
	AUTOPICKUP_FOLDER = AUTOPICKUP_FOLDER,
	itemTypes = itemTypes,
	CategoryStore = CategoryStore,
	CategoryDefinitions = CategoryDefinitions,
	CategoryRegistries = CategoryRegistries,

	RpgConst = RpgConst,
	EnemyConst = EnemyConst,

	-- Combat
	WEAPON_HIT_FOLDER = WEAPON_HIT_FOLDER,
}

return CONSTANTS
