local ReplicatedStorage = game:GetService("ReplicatedStorage")
local prefabs = ReplicatedStorage.Shared.Prefabs

-- ITEM SYSTEM DESIGN
-- Endgame setup = csv file

-- Equipment = Can go in Inventory + Interaction

-- Item Data Types :
-- 1) Defined Items = Item instance use definition Data eg minor health potion
-- 2) Instance Items = Item Instance use instantiated Data (from definition) eg iron sword

-- Pickup Behaviors :
-- 1) Auto = Walk on top of it
-- 2) Vacuum

-- Item Types :
-- 1) Equipment :
--  Can be placed in appropriate equipment Slot
--  Data Type = Instance Items
--  Pickup Behavior = Auto

-- 2) AutoPickup Usables
-- 	Subtype = Orb -> consumed on pickup eg XpOrbs

-- TODO : Split per type -> avoid Item Editing Nightmare
local itemDefinitions = {
	-- Usables
	{
		id = 1,
		name = "Small XP Orb",
		itemType = "Orb",
		xp = 10,
	},
	{
		id = 2,
		name = "Banana",
		itemType = "Orb",
		banana = 1,
	},
	{
		id = 3,
		name = "Stick",
		itemType = "Orb",
		stick = 1,
	},
	{
		id = 4,
		name = "Stone",
		itemType = "Orb",
		stone = 1,
	},

	-- Weapons
	{
		id = 5,
		name = "Wooden Club",
		itemType = "Weapon",
		equipmentType = "Mace",
		damage = 25,
		attackSpeed = 0.75,
		range = 6,
		maxCombo = 2,
	},
	{
		id = 6,
		name = "Iron Mace",
		itemType = "Weapon",
		weaponType = "Mace",
		damage = 35,
		attackSpeed = 0.8,
		range = 8,
	},
	{
		id = 7,
		name = "Iron Axe",
		itemType = "Weapon",
		weaponType = "Axe",
		damage = 30,
		attackSpeed = 1,
		range = 7,
	},
	--[[
	["IronSword"] = {
		weaponType = "Sword",
		damage = 20,
		attackSpeed = 1,
		range = 6,
	},
    ]]

	-- Equipment
}

-- Item name to ID
local itemStore = {
	SmallXPOrb = 1,
	Banana = 2,
	Stick = 3,
	Stone = 4,
	WoodenClub = 5,
	IronMace = 6,
	IronAxe = 7,
}

local itemTypes = {
	orb = "Orb",
	weapon = "Weapon",
	-- equipment
}

local itemTypeTags = {
	-- Data source type
	Defined = "Defined",
	Instance = "Instance",
	-- Pickup Behavior
	Auto = "Auto",
	Vacuum = "Vacuum",
}

local itemTypeDefinition = {
	["Orb"] = { itemTypeTags.Defined, itemTypeTags.Vacuum },
	["Weapon"] = { itemTypeTags.Instance, itemTypeTags.Manual },
	-- equipment
}

local itemVisualDefinitions = {
	prefabs.SmallXpOrb,
	prefabs.Banana,
	prefabs.Stick,
	prefabs.Rock,
	prefabs.WoodenClub,
	prefabs.IronMace,
	prefabs.IronAxe,
}

return {
	itemDefinitions = itemDefinitions,
	itemStore = itemStore,
	itemTypes = itemTypes,
	itemTypeTags = itemTypeTags,
	itemTypeDefinition = itemTypeDefinition,
	itemVisualDefinitions = itemVisualDefinitions,
}
