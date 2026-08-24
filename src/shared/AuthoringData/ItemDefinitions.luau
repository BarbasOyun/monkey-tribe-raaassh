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

-- ITEMS TYPES

local ItemTypes = {
	orb = "Orb",
	weapon = "Weapon",
	-- equipment
}

local DataSourceType = {
	Defined = "Defined",
	Instance = "Instance",
}

local PickupType = {
	Auto = "Auto",
	Vacuum = "Vacuum",
}

local itemTypeDefinition = {
	["Orb"] = { DataSourceType.Defined, PickupType.Vacuum },
	["Weapon"] = { DataSourceType.Instance, PickupType.Auto },
	-- equipment
}

-- ITEMS DEFINITIONS

local Usables = {
	{
		name = "SmallXpOrb",
		itemType = ItemTypes.orb,
		xp = 10,
	},
	{
		name = "Banana",
		itemType = ItemTypes.orb,
		banana = 1,
	},
	{
		name = "Stick",
		itemType = ItemTypes.orb,
		stick = 1,
	},
	{
		name = "Stone",
		itemType = ItemTypes.orb,
		stone = 1,
	},
}

local Weapons = {
	{
		name = "WoodenClub",
		displayName = "Wooden Club",
		itemType = ItemTypes.weapon,
		weaponType = "Mace",
		damage = 25,
		attackSpeed = 0.75,
		range = 6,
		maxCombo = 2,
	},
	{
		name = "IronMace",
		displayName = "Iron Mace",
		itemType = ItemTypes.weapon,
		weaponType = "Mace",
		damage = 35,
		attackSpeed = 0.8,
		range = 8,
		maxCombo = 2,
	},
	{
		name = "IronAxe",
		displayName = "Iron Axe",
		itemType = ItemTypes.weapon,
		weaponType = "Axe",
		damage = 30,
		attackSpeed = 1,
		range = 7,
		maxCombo = 2,
	},
	--[[
	["IronSword"] = {
		weaponType = "Sword",
		damage = 20,
		attackSpeed = 1,
		range = 6,
	},
    ]]
}

local CategoryDefinitions = {
	Usables,
	Weapons,
}

-- ITEMS REGISTRIES
-- TODO : Move to ItemService

local globalIdCount = 0

--- Build an item Registry -> Link item Definitions + Prefabs
local function buildRegistry(baseDefinitions)
	local registry = {}

	-- start & end Index?

	for i = 1, #baseDefinitions do
		local definition = baseDefinitions[i]

		local item = {
			id = globalIdCount + i,
			definition = definition,
			prefab = prefabs:FindFirstChild(definition.name),
		}

		registry[definition.name] = item -- TODO : Build Registry + Registry Lookup
	end

	globalIdCount += #baseDefinitions

	return registry
end

local UsablesRegistry = buildRegistry(Usables)
local WeaponsRegistry = buildRegistry(Weapons)

local CategoryRegistries = {
	UsablesRegistry,
	WeaponsRegistry,
}

local CategoryStore = {
	Usable = 1,
	Weapons = 2,
}

return {
	itemTypes = ItemTypes,
	CategoryStore = CategoryStore,
	CategoryDefinitions = CategoryDefinitions,
	CategoryRegistries = CategoryRegistries,
}
