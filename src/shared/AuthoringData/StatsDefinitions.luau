-- Stats that can be Upgraded
local STATS_STORE = {
	increasedAttackDamage = "increasedAttackDamage",
	critChance = "critChance",
	critMultiplier = "critMultiplier",
	increasedAttackSpeed = "increasedAttackSpeed",
	increasedAoe = "increasedAoe",
	maxLife = "maxLife",
	lifeRegen = "lifeRegen",
	damageReduction = "damageReduction",
	mobility = "mobility",
	luck = "luck",
	increasedXp = "increasedXp",
	increasedPickupRange = "increasedPickupRange",
}

local DISPLAY_TEXT = {
	increasedAttackDamage = "% Attack Damage",
	critChance = "% Crit Chance",
	critMultiplier = "% Crit Multiplier",
	increasedAttackSpeed = "% Attack Speed",
	increasedAoe = "% increasedAoe",
	maxLife = "Max Life",
	lifeRegen = "Life Regen",
	damageReduction = "% Damage Reduction",
	mobility = "mobility",
	luck = "luck",
	increasedXp = "% increasedXp",
	increasedPickupRange = "% Pickup Range",
}

local META_UPGRADES = {
	increasedAttackDamage = {
		IncrementValue = 5,
		BaseCost = 10,
		MaxIncrement = 20,
		CostMultiplier = 1.1,
	},
	critChance = {
		Increment = 2,
		BaseCost = 100,
		MaxIncrement = 10,
		CostMultiplier = 1.4,
	},
	critMultiplier = {
		Increment = 2,
		BaseCost = 100,
		MaxIncrement = 10,
		CostMultiplier = 1.4,
	},
	increasedAttackSpeed = {
		Increment = 2,
		BaseCost = 100,
		MaxIncrement = 10,
		CostMultiplier = 1.4,
	},
	increasedAoe = {
		Increment = 2,
		BaseCost = 100,
		MaxIncrement = 10,
		CostMultiplier = 1.4,
	},
	maxLife = {
		Increment = 5,
		BaseCost = 100,
		MaxIncrement = 10,
		CostMultiplier = 1.4,
	},
	lifeRegen = {
		Increment = 1,
		BaseCost = 100,
		MaxIncrement = 10,
		CostMultiplier = 1.4,
	},
	damageReduction = {
		Increment = 2,
		BaseCost = 100,
		MaxIncrement = 10,
		CostMultiplier = 1.4,
	},
	mobility = {
		Increment = 0.5,
		BaseCost = 100,
		MaxIncrement = 10,
		CostMultiplier = 1.4,
	},
	luck = {
		Increment = 1,
		BaseCost = 100,
		MaxIncrement = 10,
		CostMultiplier = 1.4,
	},
	increasedXp = {
		Increment = 2,
		BaseCost = 100,
		MaxIncrement = 10,
		CostMultiplier = 1.4,
	},
	increasedPickupRange = {
		Increment = 2,
		BaseCost = 100,
		MaxIncrement = 10,
		CostMultiplier = 1.4,
	},
}

local AUGMENTS = {
	baseLuckValue = 200,
	luckPoints = { 0, 75, 150, 180, 195 },
	rarity = {
		Common = "Common",
		Uncommon = "Uncommon",
		Rare = "Rare",
		Epic = "Epic",
		Legendary = "Legendary",
	},
	colors = {
		Common = Color3.fromRGB(155, 155, 155),
		Uncommon = Color3.fromRGB(0, 255, 0),
		Rare = Color3.fromRGB(0, 0, 255),
		Epic = Color3.fromRGB(116, 2, 116),
		Legendary = Color3.fromRGB(211, 4, 4),
	},
	increasedAttackDamage = {
		Common = 10,
		Uncommon = 15,
		Rare = 20,
		Epic = 25,
		Legendary = 35,
	},
	critChance = {
		Common = 3,
		Uncommon = 6,
		Rare = 9,
		Epic = 12,
		Legendary = 15,
	},
	critMultiplier = {
		Uncommon = 10,
		Rare = 15,
		Epic = 20,
		Legendary = 25,
	},
	increasedAttackSpeed = {
		Common = 3,
		Uncommon = 6,
		Rare = 9,
		Epic = 12,
		Legendary = 15,
	},
	increasedAoe = {
		Uncommon = 10,
		Rare = 15,
		Epic = 20,
		Legendary = 25,
	},
	maxLife = {
		Uncommon = 30,
		Rare = 45,
		Epic = 60,
		Legendary = 75,
	},
	lifeRegen = {
		Common = 1,
		Uncommon = 3,
		Rare = 5,
		Epic = 7,
		Legendary = 9,
	},
	damageReduction = {
		Uncommon = 5,
		Rare = 7,
		Epic = 9,
		Legendary = 11,
	},
	mobility = {
		Rare = 1,
		Epic = 2,
		Legendary = 3,
	},
	luck = {
		Rare = 5,
		Epic = 10,
	},
	increasedXp = {
		Rare = 10,
		Epic = 15,
		Legendary = 20,
	},
	increasedPickupRange = {
		Uncommon = 10,
		Rare = 15,
		Epic = 20,
		Legendary = 25,
	},
}

return {
	STATS_STORE = STATS_STORE,
	DISPLAY_TEXT = DISPLAY_TEXT,
	META_UPRGADES = META_UPGRADES,
	AUGMENTS = AUGMENTS,
}
