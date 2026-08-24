-- Shared Server Side Game Constants
-- eg Authoring Data

local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- local ServerStorage = game:GetService("ServerStorage")

-- Get Authoring Data
-- local statsDefinition = require(ReplicatedStorage.Shared.AuthoringData.StatsDefinitions)

-- Folders
local PREFABS_FOLDER = ReplicatedStorage.Shared.Prefabs
local WEAPON_HIT_FOLDER = workspace.WeaponHit
local DISABLED_ENTITIES_FOLDER = workspace.DisabledEntities
local AUTOPICKUP_FOLDER = workspace.AutoPickup

-- #region PlayerService

-- TODO : Rename (enum)
local PLAYER_STATES = {
	playing = "Playing",
	pickingAugment = "PickingAugment",
	-- menuing
}

-- TODO : Prevent Weapon Swap when Player is Attacking
local UNIT_STATES = {
	Idle = 1,
	PerformingAction = 2,
}

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

local ENEMIES_DETECTION_RADIUS = 200

-- #endregion

local RpgConst = {
	ADDITIONAL_XP = 20,
	MULTIPLIER_XP = 1.2,
}

local LevelConst = {
	COLLISIONS_DETECTIONS_ITERATIONS = 15,
	SOLVER_ITERATIONS = 10,
}

-- EnemyService
local DISABLED_POSITION = Vector3.new(400, 0, 0) -- Vector3.new(0, 20, 0) Vector3.new(300, 0, 0)

local EnemyConst = {
	ENEMY_LVL_UP_BREAKPOINT = 30,

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

-- Types of GameObjects that have a Definition
local DefinedTypes = {
	Unit = 1,
	Items = 2,
}

-- Constants struct -> Too hard to maintain
--[[
type Constants = {
	HUB_PLACE_ID: number,
	THROTTLED_UPDATE_FRAMES: number,
	MAX_DISTANCE: number,
	-- Folders
	PREFABS_FOLDER: any, -- Folder -> any = prevent errors
	WEAPON_HIT_FOLDER: Folder,
	DISABLED_ENTITIES_FOLDER: Folder,
	-- Overlap Param
	AUTO_PICKUP_PARAM: OverlapParams,
	DETECTION_PARAM: OverlapParams,
	WEAPON_HIT_PARAM: OverlapParams,
	-- Enums
	PLAYER_STATES: {},
	CURRENCIES: { bananas: number, sticks: number, stones: number },
	CURRENCIES_NAMES: { string },
	MAX_CURRENCIES: { number },
	-- Services
	-- Enemy
	STREAM_SPAWN_DELTA_TIME: number,
	STREAM_SPAWN_DELTA_TIME_RANGE: number,
	STREAM_SPAWN_NBR: number,
	STREAM_SPAWN_NBR_RANGE: number,
	SWARM_WAVES: number,
	SWARM_NBR: number,
	-- Ecs
	DISABLED_POSITION: Vector3,
	EcsStorages: any,
}
--]]

local CONSTANTS = {
	DefinedTypes = DefinedTypes,
	MAX_RADIANT = math.pi * 2,
	HUB_PLACE_ID = 95975992291805,
	THROTTLED_UPDATE_FRAMES = 5,
	-- Folders
	PREFABS_FOLDER = PREFABS_FOLDER,
	WEAPON_HIT_FOLDER = WEAPON_HIT_FOLDER,
	DISABLED_ENTITIES_FOLDER = DISABLED_ENTITIES_FOLDER,
	AUTOPICKUP_FOLDER = AUTOPICKUP_FOLDER,
	-- Players
	ENEMIES_DETECTION_RADIUS = ENEMIES_DETECTION_RADIUS,
	PLAYER_STATES = PLAYER_STATES,
	CURRENCIES = CURRENCIES,
	CURRENCIES_NAMES = CURRENCIES_NAMES,
	MAX_CURRENCIES = MAX_CURRENCIES,
	-- Ecs
	DISABLED_POSITION = DISABLED_POSITION,
	EcsStorages = EcsStorages,
	-- Full Services
	RpgConst = RpgConst,
	LevelConst = LevelConst,
	EnemyConst = EnemyConst,
}

return CONSTANTS
