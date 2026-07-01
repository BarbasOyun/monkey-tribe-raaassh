-- Stats that can be Upgraded
local STATS_STORE = {
	-- Offense
	increasedAttackDamage = "increasedAttackDamage",
	critChance = "critChance",
	critMultiplier = "critMultiplier",
	increasedAttackSpeed = "increasedAttackSpeed",
	increasedAoe = "increasedAoe",
	-- Defense
	maxLife = "maxLife",
	lifeRegen = "lifeRegen",
	damageReduction = "damageReduction",
	-- Utility
	mobility = "mobility",
	luck = "luck",
	increasedXp = "increasedXp",
	increasedPickupRange = "increasedPickupRange",
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
		baseCost = 10,
		maxLevel = 20,
		costMultiplier = 1.1,
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
	increasedAttackSpeed = {
		incrementValue = 2,
		baseCost = 100,
		maxLevel = 10,
		costMultiplier = 1.4,
	},
	increasedAoe = {
		incrementValue = 2,
		baseCost = 100,
		maxLevel = 10,
		costMultiplier = 1.4,
	},
	maxLife = {
		incrementValue = 5,
		baseCost = 100,
		maxLevel = 10,
		costMultiplier = 1.4,
	},
	lifeRegen = {
		incrementValue = 1,
		baseCost = 100,
		maxLevel = 10,
		costMultiplier = 1.4,
	},
	damageReduction = {
		incrementValue = 2,
		baseCost = 100,
		maxLevel = 10,
		costMultiplier = 1.4,
	},
	mobility = {
		incrementValue = 0.5,
		baseCost = 100,
		maxLevel = 10,
		costMultiplier = 1.4,
	},
	luck = {
		incrementValue = 1,
		baseCost = 100,
		maxLevel = 10,
		costMultiplier = 1.4,
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
		maxLevel = 10,
		costMultiplier = 1.4,
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
	increasedAttackSpeed = {
		common = 3,
		uncommon = 6,
		rare = 9,
		epic = 12,
		legendary = 15,
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
	STATS_STORE = STATS_STORE,
	STATS_DISPLAY = STATS_DISPLAY,
	META_UPRGADES = META_UPGRADES,
	AUGMENTS = AUGMENTS,
}
