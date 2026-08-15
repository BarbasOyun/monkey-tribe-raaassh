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

-- #region Player

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

-- PickupRange Parameters
local AUTO_PICKUP_PARAM = OverlapParams.new()
AUTO_PICKUP_PARAM.FilterType = Enum.RaycastFilterType.Include
AUTO_PICKUP_PARAM.FilterDescendantsInstances = { workspace.AutoPickup }
AUTO_PICKUP_PARAM.MaxParts = 50

-- Enemies Detection
local DETECTION_PARAM = OverlapParams.new()
DETECTION_PARAM.FilterType = Enum.RaycastFilterType.Include
DETECTION_PARAM.FilterDescendantsInstances = { workspace.WeaponHit }
DETECTION_PARAM.MaxParts = 500
local DETECTION_RADIUS = 100

-- #endregion

local RpgConst = {
	ADDITIONAL_XP = 20,
	MULTIPLIER_XP = 1.2,
}

-- Combat
local WEAPON_HIT_PARAM = OverlapParams.new()
WEAPON_HIT_PARAM.FilterType = Enum.RaycastFilterType.Include
WEAPON_HIT_PARAM.FilterDescendantsInstances = { workspace.WeaponHit }
WEAPON_HIT_PARAM.MaxParts = 100

-- EnemyService
-- local DISABLED_POSITION = Vector3.new(0, 20, 0)
local DISABLED_POSITION = Vector3.new(300, 0, 0)
local EnemyConst = {
	ENEMY_LVL_UP_BREAKPOINT = 30,

	-- Spawn
	SPAWN_RADIUS = 20,
	SPAWN_RADIUS_RANGE = 20,

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
	MAX_RADIANT = math.pi * 2,
	HUB_PLACE_ID = 95975992291805,
	THROTTLED_UPDATE_FRAMES = 5,
	-- Folders
	PREFABS_FOLDER = PREFABS_FOLDER,
	WEAPON_HIT_FOLDER = WEAPON_HIT_FOLDER,
	DISABLED_ENTITIES_FOLDER = DISABLED_ENTITIES_FOLDER,
	-- Overlap Param
	AUTO_PICKUP_PARAM = AUTO_PICKUP_PARAM,
	DETECTION_PARAM = DETECTION_PARAM,
	DETECTION_RADIUS = DETECTION_RADIUS,
	WEAPON_HIT_PARAM = WEAPON_HIT_PARAM,
	-- Enums
	PLAYER_STATES = PLAYER_STATES,
	CURRENCIES = CURRENCIES,
	CURRENCIES_NAMES = CURRENCIES_NAMES,
	MAX_CURRENCIES = MAX_CURRENCIES,
	-- Services
	RpgConst = RpgConst,
	EnemyConst = EnemyConst,
	-- Ecs
	DISABLED_POSITION = DISABLED_POSITION,
	EcsStorages = EcsStorages,
}

return CONSTANTS
