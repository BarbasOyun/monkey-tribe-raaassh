-- STORES (Lookup tables)

-- Stats as objects
local STATS_STORE = {
	-- Offense
	attackDamage = "attackDamage",
	attackSpeed = "attackSpeed",
	critChance = "critChance",
	critMultiplier = "critMultiplier",
	aoe = "aoe",
	-- Defense
	maxLife = "life",
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
	maxLife = "life",
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

-- Every Stats mutated by other systems (Meta Upgrades & Augments) -> Input
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

-- Stats that need to be multiplied
-- > Can use STAT_STORE instead
--[[
local MULT_STATS_STORE = {
	attackDamage = "attackDamage",
	attackSpeed = "attackSpeed",
	animationTime = "animationTime",
	aoe = "aoe",
	pickupRange = "pickupRange",
}
]]

-- AUTHORING DATA

-- Only for ModStats
local DEFAULT_STATS = {
	-- Offense
	increasedAttackDamage = 0,
	critChance = 5,
	critMultiplier = 50,
	increasedAttackSpeed = 0,
	increasedAoe = 0,
	-- Defense
	maxLife = 100,
	lifeRegen = 1,
	damageReduction = 0,
	-- Utility
	mobility = 15,
	luck = 0,
	increasedXp = 0,
	basePickupRange = 10,
	increasedPickupRange = 0,
}

local STATS_DISPLAY = {
	increasedAttackDamage = "% Attack Damage",
	critChance = "% Crit Chance",
	critMultiplier = "% Crit Multiplier",
	increasedAttackSpeed = "% Attack Speed",
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
		common = "Common",
		uncommon = "Uncommon",
		rare = "Rare",
		epic = "Epic",
		legendary = "Legendary",
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

return {
	-- Stores
	STATS_STORE = STATS_STORE,
	MOD_STATS_STORE = MOD_STATS_STORE,
	-- MULT_STATS_STORE = MULT_STATS_STORE,
	TO_STAT_OBJECT = TO_STAT_OBJECT,
	-- Authoring Data
	DEFAULT_STATS = DEFAULT_STATS,
	STATS_DISPLAY = STATS_DISPLAY,
	META_UPRGADES = META_UPGRADES,
	AUGMENTS = AUGMENTS,
}
