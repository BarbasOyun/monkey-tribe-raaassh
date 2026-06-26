-- Default Stats
local PLAYER_STATS_STRUCT = {
	-- Level
	level = 1,
	currentXp = 0,
	increasedXp = 0,
	levelUpXp = 10,
	-- Offensive
	increasedAttackDamage = 0,
	attackDamage = 0,
	critChance = 5,
	critMultiplier = 50,
	increasedAttackSpeed = 0,
	attackSpeed = 0, -- Attacks / Second
	animationTime = 1, -- Get lower as attackSpeed get higher
	increasedAoe = 0,
	aoe = 0,
	-- Defensive
	-- baseLife = 100,
	-- increasedLife = 0,
	maxLife = 100,
	life = 100,
	lifeRegen = 1,
	damageReduction = 0,
	-- Utility
	mobility = 10,
	movementSpeed = 15,
	luck = 0,
	basePickupRange = 10,
	increasedPickupRange = 0,
	pickupRange = 10,
}

-- Stats that can be Upgraded
local STATS_STORE = {
	AttackDamage = "AttackDamage",
	CritChance = "CritChance",
	CritMulti = "CritMulti",
	AttackSpeed = "AttackSpeed",
	Aoe = "Aoe",
	MaxLife = "MaxLife",
	LifeRegen = "LifeRegen",
	DamageReduction = "DamageReduction",
	Mobility = "Mobility",
	Luck = "Luck",
	Xp = "Xp",
	PickupRange = "PickupRange",
}

local DISPLAY_TEXT = {
	AttackDamage = "% Attack Damage",
	CritChance = "% Crit Chance",
	CritMulti = "% Crit Multiplier",
	AttackSpeed = "% Attack Speed",
	Aoe = "% AOE",
	MaxLife = "Max Life",
	LifeRegen = "Life Regen",
	DamageReduction = "% Damage Reduction",
	Mobility = "Mobility",
	Luck = "Luck",
	Xp = "% XP",
	PickupRange = "% Pickup Range",
}

local META_UPGRADES = {
	AttackDamage = {
		IncrementValue = 5,
		BaseCost = 10,
		MaxIncrement = 20,
		CostMultiplier = 1.1,
	},
	CritChance = {
		Increment = 2,
		BaseCost = 100,
		MaxIncrement = 10,
		CostMultiplier = 1.4,
	},
	["critMultiplier"] = {
		Increment = 2,
		BaseCost = 100,
		MaxIncrement = 10,
		CostMultiplier = 1.4,
	},
	["attackSpeed"] = {
		Increment = 2,
		BaseCost = 100,
		MaxIncrement = 10,
		CostMultiplier = 1.4,
	},
	["aoe"] = {
		Increment = 2,
		BaseCost = 100,
		MaxIncrement = 10,
		CostMultiplier = 1.4,
	},
	["maxHealth"] = {
		Increment = 5,
		BaseCost = 100,
		MaxIncrement = 10,
		CostMultiplier = 1.4,
	},
	["lifeRegen"] = {
		Increment = 1,
		BaseCost = 100,
		MaxIncrement = 10,
		CostMultiplier = 1.4,
	},
	["damageReduction"] = {
		Increment = 2,
		BaseCost = 100,
		MaxIncrement = 10,
		CostMultiplier = 1.4,
	},
	["mobility"] = {
		Increment = 0.5,
		BaseCost = 100,
		MaxIncrement = 10,
		CostMultiplier = 1.4,
	},
	["luck"] = {
		Increment = 1,
		BaseCost = 100,
		MaxIncrement = 10,
		CostMultiplier = 1.4,
	},
	["increasedXp"] = {
		Increment = 2,
		BaseCost = 100,
		MaxIncrement = 10,
		CostMultiplier = 1.4,
	},
	["increasedPickupRange"] = {
		Increment = 2,
		BaseCost = 100,
		MaxIncrement = 10,
		CostMultiplier = 1.4,
	},
}

local AUGMENTS = {
	BaseLuckValue = 200,
	LuckPoints = { 0, 75, 150, 180, 195 },
	Rarity = {
		Common = "Common",
		Uncommon = "Uncommon",
		Rare = "Rare",
		Epic = "Epic",
		Legendary = "Legendary",
	},
	Colors = {
		Common = Color3.fromRGB(155, 155, 155),
		Uncommon = Color3.fromRGB(0, 255, 0),
		Rare = Color3.fromRGB(0, 0, 255),
		Epic = Color3.fromRGB(116, 2, 116),
		Legendary = Color3.fromRGB(211, 4, 4),
	},
	AttackDamage = {
		Common = 10,
		Uncommon = 15,
		Rare = 20,
		Epic = 25,
		Legendary = 35,
	},
	CritChance = {
		Common = 3,
		Uncommon = 6,
		Rare = 9,
		Epic = 12,
		Legendary = 15,
	},
	["critMultiplier"] = {
		Uncommon = 10,
		Rare = 15,
		Epic = 20,
		Legendary = 25,
	},
	["attackSpeed"] = {
		Common = 3,
		Uncommon = 6,
		Rare = 9,
		Epic = 12,
		Legendary = 15,
	},
	["aoe"] = {
		Uncommon = 10,
		Rare = 15,
		Epic = 20,
		Legendary = 25,
	},
	["maxHealth"] = {
		Uncommon = 30,
		Rare = 45,
		Epic = 60,
		Legendary = 75,
	},
	["lifeRegen"] = {
		Common = 1,
		Uncommon = 3,
		Rare = 5,
		Epic = 7,
		Legendary = 9,
	},
	["damageReduction"] = {
		Uncommon = 5,
		Rare = 7,
		Epic = 9,
		Legendary = 11,
	},
	["mobility"] = {
		Rare = 1,
		Epic = 2,
		Legendary = 3,
	},
	["luck"] = {
		Rare = 5,
		Epic = 10,
	},
	["increasedXp"] = {
		Rare = 10,
		Epic = 15,
		Legendary = 20,
	},
	["increasedPickupRange"] = {
		Uncommon = 10,
		Rare = 15,
		Epic = 20,
		Legendary = 25,
	},
}

return {
	PLAYER_STATS_STRUCT = PLAYER_STATS_STRUCT,
	STATS_STORE = STATS_STORE,
	META_UPRGADES = META_UPGRADES,
	AUGMENTS = AUGMENTS,
}
