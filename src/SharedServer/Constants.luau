-- Shared Server Side Game Constants
-- eg Authoring Data

local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- local ServerStorage = game:GetService("ServerStorage")

-- Get Authoring Data
-- local statsDefinition = require(ReplicatedStorage.Shared.AuthoringData.StatsDefinitions)

local MAX_RADIANT = math.pi * 2

-- Folders
local WEAPON_HIT_FOLDER = workspace.WeaponHit
local PREFABS_FOLDER = ReplicatedStorage.Shared.Prefabs
local DISABLED_ENTITIES_FOLDER = workspace.DisabledEntities

-- #region Player

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

-- TODO : Rename
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
DETECTION_PARAM.MaxParts = 50

-- #endregion

-- Combat
local WEAPON_HIT_PARAM = OverlapParams.new()
WEAPON_HIT_PARAM.FilterType = Enum.RaycastFilterType.Include
WEAPON_HIT_PARAM.FilterDescendantsInstances = { workspace.WeaponHit }
WEAPON_HIT_PARAM.MaxParts = 100

-- EnemyService
local SPAWN_RADIUS = 5
local SPAWN_RADIUS_RANGE = 5

local STREAM_SPAWN_DELTA_TIME = 7
local STREAM_SPAWN_DELTA_TIME_RANGE = 2
local STREAM_SPAWN_NBR = 2
local STREAM_SPAWN_NBR_RANGE = 1

local SWARM_WAVES = 4
local SWARM_NBR = 4
local SWARM_NBR_RANGE = 2

-- ECS & Object Pooling
local DISABLED_POSITION = Vector3.new(0, -5000, 0)
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

-- : Constants
local CONSTANTS = {
	MAX_RADIANT = MAX_RADIANT,
	HUB_PLACE_ID = 95975992291805,
	THROTTLED_UPDATE_FRAMES = 5,
	MAX_DISTANCE = 250,
	-- Folders
	PREFABS_FOLDER = PREFABS_FOLDER,
	WEAPON_HIT_FOLDER = WEAPON_HIT_FOLDER,
	DISABLED_ENTITIES_FOLDER = DISABLED_ENTITIES_FOLDER,
	-- Overlap Param
	AUTO_PICKUP_PARAM = AUTO_PICKUP_PARAM,
	DETECTION_PARAM = DETECTION_PARAM,
	WEAPON_HIT_PARAM = WEAPON_HIT_PARAM,
	-- Enums
	PLAYER_STATES = PLAYER_STATES,
	CURRENCIES = CURRENCIES,
	CURRENCIES_NAMES = CURRENCIES_NAMES,
	MAX_CURRENCIES = MAX_CURRENCIES,
	-- Services
	-- Enemy
	SPAWN_RADIUS = SPAWN_RADIUS,
	SPAWN_RADIUS_RANGE = SPAWN_RADIUS_RANGE,
	STREAM_SPAWN_DELTA_TIME = STREAM_SPAWN_DELTA_TIME,
	STREAM_SPAWN_DELTA_TIME_RANGE = STREAM_SPAWN_DELTA_TIME_RANGE,
	STREAM_SPAWN_NBR = STREAM_SPAWN_NBR,
	STREAM_SPAWN_NBR_RANGE = STREAM_SPAWN_NBR_RANGE,
	SWARM_WAVES = SWARM_WAVES,
	SWARM_NBR = SWARM_NBR,
	SWARM_NBR_RANGE = SWARM_NBR_RANGE,
	-- Ecs
	DISABLED_POSITION = DISABLED_POSITION,
	EcsStorages = EcsStorages,
}

return CONSTANTS
