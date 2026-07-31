-- Shared Server Side Game Constants
-- eg Authoring Data

-- local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

-- Get Authoring Data
-- local statsDefinition = require(ReplicatedStorage.Shared.AuthoringData.StatsDefinitions)

-- #region Player

local PLAYER_STATES = {
	playing = "Playing",
	pickingAugment = "PickingAugment",
	-- menuing
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

-- Enemies
local WEAPON_HIT_FOLDER = workspace.WeaponHit

-- ECS
-- local DISABLED_ENTITIES_FOLDER = ServerStorage.DisabledEntities
local DISABLED_ENTITIES_FOLDER = workspace.DisabledEntities
local DISABLED_POSITION = Vector3.new(0, -5000, 0)
local STORAGE_STORE = {
	gameObject = 1,
	unit = 2,
}

type Constants = {
	HUB_PLACE_ID: number,
	THROTTLED_UPDATE_FRAMES: number,
	MAX_DISTANCE: number,
	-- Overlap Param
	AUTO_PICKUP_PARAM: OverlapParams,
	DETECTION_PARAM: OverlapParams,
	WEAPON_HIT_PARAM: OverlapParams,
	-- Enums
	PLAYER_STATES: {},
	CURRENCIES: { bananas: number, sticks: number, stones: number },
	CURRENCIES_NAMES: { string },
	MAX_CURRENCIES: { number },
	-- Slices
	-- statsDefinition: {},
	WEAPON_HIT_FOLDER: Folder,
	DISABLED_ENTITIES_FOLDER: Folder,
	DISABLED_POSITION: Vector3,
	STORAGE_STORE: { gameObject: number, unit: number },
}

local CONSTANTS: Constants = {
	HUB_PLACE_ID = 95975992291805,
	THROTTLED_UPDATE_FRAMES = 5,
	MAX_DISTANCE = 250,
	-- Overlap Param
	AUTO_PICKUP_PARAM = AUTO_PICKUP_PARAM,
	DETECTION_PARAM = DETECTION_PARAM,
	WEAPON_HIT_PARAM = WEAPON_HIT_PARAM,
	-- Enums
	PLAYER_STATES = PLAYER_STATES,
	CURRENCIES = CURRENCIES,
	CURRENCIES_NAMES = CURRENCIES_NAMES,
	MAX_CURRENCIES = MAX_CURRENCIES,
	-- Slices
	-- statsDefinition = statsDefinition,
	WEAPON_HIT_FOLDER = WEAPON_HIT_FOLDER,
	DISABLED_ENTITIES_FOLDER = DISABLED_ENTITIES_FOLDER,
	DISABLED_POSITION = DISABLED_POSITION,
	STORAGE_STORE = STORAGE_STORE,
}

return CONSTANTS
