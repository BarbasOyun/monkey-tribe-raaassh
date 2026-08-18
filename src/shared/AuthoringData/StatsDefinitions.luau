local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Gears = require(ReplicatedStorage.Shared.Gears)

-- TODO : PlayerDefinition = Client Side, StatsDefinition = ServerSide

-- #region DATA STRUCTS

export type Stats = {
	-- Offensive
	increasedAttackDamage: number,
	-- moreAttackDamageLayers = {}
	attackDamage: number,
	increasedAttackSpeed: number,
	attackSpeed: number, -- Attacks / Second
	animationTime: number, -- Get lower as attackSpeed get higher
	critChance: number,
	critMultiplier: number,
	increasedAoe: number,
	aoe: number,
	-- Defensive
	-- baseLife: number,
	-- increasedLife: number,
	maxLife: number,
	lifeRegen: number,
	damageReduction: number,
	-- Utility
	mobility: number,
	luck: number,
	increasedXp: number,
	basePickupRange: number,
	increasedPickupRange: number,
	pickupRange: number,
}

-- Stats that can be Modified by Power Systems
export type ModStats = {
	-- Offense
	increasedAttackDamage: number,
	increasedAttackSpeed: number,
	critChance: number,
	critMultiplier: number,
	increasedAoe: number,
	-- Defense
	maxLife: number,
	lifeRegen: number,
	damageReduction: number,
	-- Utility
	mobility: number,
	luck: number,
	increasedXp: number,
	increasedPickupRange: number,
}

export type Augment = {
	modStat: string,
	rarity: string,
	value: number,
}

export type WeaponData = {
	name: string,
	-- Model
	weaponSize: number,
	attackPoint: Vector3,
	-- Offense
	damage: number, -- Calculate using Weapon Definition + Weapon Modifiers
	attackSpeed: number,
	-- Utility
	aoe: number,
	-- Misc
	attackVFX: ParticleEmitter,
	maxCombo: number,
	-- Rarity: string,
	-- Modifiers: { mod: Modifier },
}

export type Player = {
	username: string,
	state: string,
	isMusicEnabled: boolean,
	isDead: boolean,
	-- Currencies
	bananas: number,
	sticks: number,
	stones: number,
	-- Score
	kills: number,
	destruction: number,
	-- Level
	level: number,
	waitingLevel: number,
	currentXp: number,
	xpRequired: number,
	-- Stats
	stats: Stats,
	metaUpgradesLevel: ModStats,
	metaUpgradesCost: ModStats,
	metaUpgrades: ModStats,
	augments: ModStats,
	currentAugments: { Augment }, -- 3+ choice cards
	weaponData: {}, -- WeaponData
	-- gearData
}

-- #endregion

-- #region DEFAULT VALUES

local DEFAULT_STATS: Stats = {
	-- Offensive
	increasedAttackDamage = 0,
	-- moreAttackDamageLayers = {}
	attackDamage = 0,
	increasedAttackSpeed = 0,
	attackSpeed = 0, -- Attacks / Second
	animationTime = 1, -- Get lower as attackSpeed get higher
	critChance = 5,
	critMultiplier = 50,
	increasedAoe = 0,
	aoe = 0,
	-- Defensive
	-- baseLife = 100,
	-- increasedLife = 0,
	maxLife = 100,
	lifeRegen = 1,
	damageReduction = 0,
	-- Utility
	mobility = 15,
	luck = 0,
	increasedXp = 0,
	basePickupRange = 10,
	increasedPickupRange = 0,
	pickupRange = 10,
}

local MOD_STATS: ModStats = {
	-- Offense
	increasedAttackDamage = 0,
	increasedAttackSpeed = 0,
	critChance = 0,
	critMultiplier = 0,
	increasedAoe = 0,
	-- Defense
	maxLife = 0,
	lifeRegen = 0,
	damageReduction = 0,
	-- Utility
	mobility = 0,
	luck = 0,
	increasedXp = 0,
	increasedPickupRange = 0,
}

local DEFAULT_PLAYER: Player = {
	username = "",
	state = "Playing", -- TODO : rename logicState
	isMusicEnabled = true,
	isDead = false,
	-- Currencies
	bananas = 0,
	bananasSavedToDb = 0,
	sticks = 0,
	stones = 0,
	-- Score
	kills = 0,
	destruction = 0,
	-- Level
	level = 1,
	waitingLevel = 0,
	currentXp = 0,
	xpRequired = 100,
	-- Stats
	stats = Gears.DeepCopy(DEFAULT_STATS),
	metaUpgradesLevel = Gears.DeepCopy(MOD_STATS),
	metaUpgradesCost = Gears.DeepCopy(MOD_STATS),
	metaUpgrades = Gears.DeepCopy(MOD_STATS),
	augments = Gears.DeepCopy(MOD_STATS),
	currentAugments = {}, -- 3+ choice cards
	weaponData = {},
}

-- #endregion

-- #region ENUMS

-- Stats as objects
local STATS_STORE = {
	-- Offense
	attackDamage = "attackDamage",
	attackSpeed = "attackSpeed",
	critChance = "critChance",
	critMultiplier = "critMultiplier",
	aoe = "aoe",
	-- Defense
	maxLife = "maxLife",
	lifeRegen = "lifeRegen",
	damageReduction = "damageReduction",
	-- Utility
	mobility = "mobility",
	luck = "luck",
	xp = "xp",
	pickupRange = "pickupRange",
}

local TO_STAT_OBJECT = {
	-- Offense
	increasedAttackDamage = "attackDamage",
	attackDamage = "attackDamage",
	increasedAttackSpeed = "attackSpeed",
	attackSpeed = "attackSpeed",
	animationTime = "attackSpeed",
	critChance = "critChance",
	critMultiplier = "critMultiplier",
	increasedAoe = "aoe",
	aoe = "aoe",
	-- Defense
	maxLife = "maxLife",
	lifeRegen = "lifeRegen",
	damageReduction = "damageReduction",
	-- Utility
	mobility = "mobility",
	luck = "luck",
	increasedXp = "xp",
	basePickupRange = "pickupRange",
	increasedPickupRange = "pickupRange",
	pickupRange = "pickupRange",
}

-- Every Stats mutated by power systems (Meta Upgrades & Augments) -> Input
-- TODO : Replace with STATS = Index
local MOD_STATS_STORE = {
	-- Offense
	increasedAttackDamage = "increasedAttackDamage",
	increasedAttackSpeed = "increasedAttackSpeed",
	critChance = "critChance",
	critMultiplier = "critMultiplier",
	increasedAoe = "increasedAoe",
	-- Defense
	maxLife = "maxLife",
	lifeRegen = "lifeRegen",
	damageReduction = "damageReduction",
	-- Utility
	mobility = "mobility",
	luck = "luck",
	increasedXp = "increasedXp",
	basePickupRange = "basePickupRange",
	increasedPickupRange = "increasedPickupRange",
}

local MOD_STATS_INDEX = {
	-- Offense
	"increasedAttackDamage",
	"increasedAttackSpeed",
	"critChance",
	"critMultiplier",
	"increasedAoe",
	-- Defense
	"maxLife",
	"lifeRegen",
	"damageReduction",
	-- Utility
	"mobility",
	"luck",
	"increasedXp",
	"increasedPickupRange",
}

-- #endregion

local STATS_DISPLAY = {
	increasedAttackDamage = "% Attack Damage",
	increasedAttackSpeed = "% Attack Speed",
	critChance = "% Crit Chance",
	critMultiplier = "% Crit Multiplier",
	increasedAoe = "% Aoe",
	maxLife = "Max Life",
	lifeRegen = "Life Regen",
	damageReduction = "% Damage Reduction",
	mobility = "Mobility",
	luck = "Luck",
	increasedXp = "% Xp",
	increasedPickupRange = "% Pickup Range",
}

local META_UPGRADES = {
	increasedAttackDamage = {
		incrementValue = 5,
		baseCost = 20,
		maxLevel = 20,
		costMultiplier = 1.15,
	},
	increasedAttackSpeed = {
		incrementValue = 5,
		baseCost = 20,
		maxLevel = 20,
		costMultiplier = 1.2,
	},
	critChance = {
		incrementValue = 2,
		baseCost = 100,
		maxLevel = 10,
		costMultiplier = 1.4,
	},
	critMultiplier = {
		incrementValue = 2,
		baseCost = 100,
		maxLevel = 10,
		costMultiplier = 1.4,
	},
	increasedAoe = {
		incrementValue = 4,
		baseCost = 150,
		maxLevel = 7,
		costMultiplier = 1.4,
	},
	maxLife = {
		incrementValue = 5,
		baseCost = 10,
		maxLevel = 30,
		costMultiplier = 1.05,
	},
	lifeRegen = {
		incrementValue = 1,
		baseCost = 100,
		maxLevel = 10,
		costMultiplier = 1.4,
	},
	damageReduction = {
		incrementValue = 5,
		baseCost = 200,
		maxLevel = 5,
		costMultiplier = 1.4,
	},
	mobility = {
		incrementValue = 0.5,
		baseCost = 80,
		maxLevel = 10,
		costMultiplier = 1.5,
	},
	luck = {
		incrementValue = 1,
		baseCost = 150,
		maxLevel = 10,
		costMultiplier = 1.3,
	},
	increasedXp = {
		incrementValue = 2,
		baseCost = 100,
		maxLevel = 10,
		costMultiplier = 1.4,
	},
	increasedPickupRange = {
		incrementValue = 2,
		baseCost = 100,
		maxLevel = 12,
		costMultiplier = 1.2,
	},
}

local AUGMENTS = {
	baseLuckValue = 200,
	luckPoints = { 0, 75, 150, 180, 195 },
	rarity = {
		"common",
		"uncommon",
		"rare",
		"epic",
		"legendary",
	},
	colors = {
		common = Color3.fromRGB(155, 155, 155),
		uncommon = Color3.fromRGB(0, 255, 0),
		rare = Color3.fromRGB(0, 0, 255),
		epic = Color3.fromRGB(116, 2, 116),
		legendary = Color3.fromRGB(211, 4, 4),
	},
	increasedAttackDamage = {
		common = 10,
		uncommon = 15,
		rare = 20,
		epic = 25,
		legendary = 35,
	},
	increasedAttackSpeed = {
		common = 3,
		uncommon = 6,
		rare = 9,
		epic = 12,
		legendary = 15,
	},
	critChance = {
		common = 3,
		uncommon = 6,
		rare = 9,
		epic = 12,
		legendary = 15,
	},
	critMultiplier = {
		uncommon = 10,
		rare = 15,
		epic = 20,
		legendary = 25,
	},
	increasedAoe = {
		uncommon = 10,
		rare = 15,
		epic = 20,
		legendary = 25,
	},
	maxLife = {
		uncommon = 30,
		rare = 45,
		epic = 60,
		legendary = 75,
	},
	lifeRegen = {
		common = 1,
		uncommon = 3,
		rare = 5,
		epic = 7,
		legendary = 9,
	},
	damageReduction = {
		uncommon = 5,
		rare = 7,
		epic = 9,
		legendary = 11,
	},
	mobility = {
		rare = 1,
		epic = 2,
		legendary = 3,
	},
	luck = {
		rare = 5,
		epic = 10,
	},
	increasedXp = {
		rare = 10,
		epic = 15,
		legendary = 20,
	},
	increasedPickupRange = {
		uncommon = 10,
		rare = 15,
		epic = 20,
		legendary = 25,
	},
}

local statsDefinition = {
	DEFAULT_PLAYER = DEFAULT_PLAYER,
	-- Enums
	STATS_STORE = STATS_STORE,
	MOD_STATS_STORE = MOD_STATS_STORE,
	-- MULT_STATS_STORE = MULT_STATS_STORE,
	TO_STAT_OBJECT = TO_STAT_OBJECT,
	MOD_STATS_INDEX = MOD_STATS_INDEX,
	-- Authoring Data
	DEFAULT_STATS = DEFAULT_STATS,
	STATS_DISPLAY = STATS_DISPLAY,
	META_UPRGADES = META_UPGRADES,
	AUGMENTS = AUGMENTS,
}

return statsDefinition
