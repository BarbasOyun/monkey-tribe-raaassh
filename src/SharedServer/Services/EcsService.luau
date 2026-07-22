local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
-- local Signal = require(ReplicatedStorage.Packages._Index["sleitnick_signal@1.5.0"].signal)

-- Entities
local entitiesId = {}
local entitiesBitmask = {}
local versions = {}

local disabledEntitiesFolder = ServerStorage.DisabledEntities

-- Systems
-- local systemCount = 0

-- Metatable
local system = {
	id = 0,
	sparse = {},
	entities = {},
	clearComponents = function(self)
		table.clear(self.sparse)
		table.clear(self.entities)
	end,
	addComponentToEntity = function(self, entityId)
		local componentId = #self.entities + 1

		table.insert(self.sparse, entityId, componentId)
		table.insert(self.entities, entityId)

		return componentId
	end,
	updateComponent = function(self, entityId)
		-- implement in child tables
	end,
	removeComponent = function(self, entityId)
		local componentId = self.sparse[entityId]

		table.remove(self.entities, componentId)
		table.remove(self.sparse, entityId)

		return componentId
	end,
	getComponentId = function(self, entityId)
		return self.sparse[entityId]
	end,
}
system.__index = system

local gameObjectSystem = {
	id = 1,
	gameObjects = {},
	clearComponents = function(self)
		system:clearComponents()

		-- Destroy All Entities Gameobjects
		for i = 1, #self.gameObjects, 1 do
			self.gameObjects[i]:Destroy()
		end

		table.clear(self.gameObjects)
	end,
	addComponentToEntity = function(self, entityId, gameobject)
		local componentId = system:addComponentToEntity(entityId)

		gameobject:SetAttribute("EntityId", entityId)
		gameobject:SetAttribute("Version", versions[entityId])

		-- table.insert(self.gameObjects, gameobject)

		return componentId
	end,
	removeComponent = function(self, entityId)
		local componentId = system:removeComponent(entityId)
		table.remove(self.gameObjects, componentId)
	end,
}

setmetatable(gameObjectSystem, system)

local unitSystem = {
	id = 2,
	definitionId = {},
	life = {},
	lifeBar = {},
	deathEvent = {},
	clearComponents = function(self)
		system:clearComponents()

		table.clear(self.life)
		table.clear(self.lifeBar)
		table.clear(self.deathEvent)
	end,
	addComponentToEntity = function(self, entityId, definitionId, life, lifeBar, deathEvent)
		local componentId = system:addComponentToEntity(entityId)

		table.insert(self.definitionId, definitionId)
		table.insert(self.life, life)
		table.insert(self.lifeBar, lifeBar)
		table.insert(self.deathEvent, deathEvent)

		return componentId
	end,
	updateComponent = function(self, entityId, life)
		local componentId = system:getComponentId(entityId)
		self.life[componentId] = life
	end,
	removeComponent = function(self, entityId)
		local componentId = system:removeComponent(entityId)

		table.remove(self.life, componentId)
		table.remove(self.lifeBar, componentId)
		table.remove(self.deathEvent, componentId)
	end,
}

setmetatable(unitSystem, system)

-- TODO : MobBehaviorSystem

local systems = {
	gameObjectSystem,
	unitSystem,
}

-- Archetypes
-- struct
-- local archetype = {
-- 	name = "",
-- 	systems = {},
-- 	startIndex = 0,
-- 	maxEntities = 100,
-- 	activeCount = 0,
-- }

-- TODO : Combine Archetype + Enemy Definition
local dummyArchetype = {
	name = "Dummy",
	systemsId = {
		1,
		2,
	},
	startIndex = 1,
	endIndex = 100,
	activeCount = 0,
}

local robotMobArchetype = {
	name = "Robot",
	systemsId = {
		1,
		2,
		-- 3,
	},
	startIndex = 101,
	endIndex = 200,
	activeCount = 0,
}

local archetypesTotalSize = 200

local archetypes = {
	dummyArchetype,
	robotMobArchetype,
}

local EcsService = Knit.CreateService({
	Name = "EcsService",
	SystemMetatable = system,
	-- Archetype = archetype,
	GameobjectSystem = gameObjectSystem,
	UnitSystem = unitSystem,
	-- Client = {},
})

-- #region SYSTEMS

-- Register a System + Return SystemId
function EcsService:RegisterSystem(system)
	table.insert(system)
	return #systems
end

function EcsService:GetSystemMask(system_id)
	return bit32.lshift(1, system_id)
end

-- Add a SystemMask to an Entity's bitmask
function EcsService:AddMask(entityMask, systemMask)
	entityMask = bit32.bor(entityMask, systemMask)
end

function EcsService:RemoveMask(entityMask, systemMask)
	entityMask = bit32.band(entityMask, systemMask)
end

-- #endregion

-- #region ENTITIES

function EcsService:CreateEntity()
	local entityId = #entitiesId + 1

	table.insert(entitiesId, entityId)
	table.insert(entitiesBitmask, 0)
	table.insert(versions, 0)

	return entityId
end

function EcsService:RemoveEntity(entityId)
	for i = 1, #systems, 1 do
		if EcsService:HasComponent(entityId, i) then
			systems[i]:RemoveComponent(entityId)
		end
	end

	table.remove(entitiesId, entityId)
	table.remove(entitiesBitmask, entityId)
end

function EcsService:ClearEntities()
	-- Clear all components
	for i = 1, #systems, 1 do
		systems[i]:clearComponents()
	end

	table.clear(entitiesId)
	table.clear(entitiesBitmask)
end

-- #endregion

-- #region ENTITIES ARCHETYPES / POOLING

local function createPools()
	for i = 1, #archetypes, 1 do
		EcsService:CreatePool(archetypes[i])
	end
end

-- Create a pool of Entity of an Archetype
function EcsService:CreatePool(archetype)
	for i = archetype.startIndex, archetype.endIndex, 1 do
		local entityId = EcsService:CreateEntity()

		-- Add a Component of Every Archertype's Systems to each Entity
		for j = 1, #archetype.systems, 1 do
			archetype.systems[j].addComponentToEntity(entityId)
		end
	end
end

function EcsService:GetArchetype(entityId)
	for i = 1, #archetypes, 1 do
		if entityId <= archetypes[i].maxEntities then
			return archetypes[i]
		end
	end

	return nil
end

-- Enable an Entity of an Archetype
function EcsService:EnableEntity(archetypeId)
	-- local archetype = nil

	-- for i = 1, #archetypes, 1 do
	-- 	if i == archetypeId then
	-- 		archetype = archetypes[i]
	-- 		break
	-- 	end
	-- end

	-- Enable Last Entity
	-- local entityId = archetype.startIndex + archetype.activeCount

	-- Enable GameObject
	local gameObjectId = gameObjectSystem:getComponentId(entitiesId)
	gameObjectSystem.gameObjects[gameObjectId].parent = workspace.WeaponHit

	-- TODO : Define Default Entity / Archetype -> Reset Entity
end

-- Archetype : Swap Entity -> Last Entity
function EcsService:DisableEntity(entityId)
	if not EcsService:HasComponent(entityId, 1) then
		warn(entityId .. " Doesn't have Gameobject Component")
		return
	end

	-- Disable Components
	for i = 2, #systems, 1 do
		if EcsService:HasComponent(entityId, i) then
			systems[i]:disableComponent(entityId)
		end
	end

	-- Disable Gameobject
	local gameObjectId = gameObjectSystem:getComponentId(entitiesId)
	gameObjectSystem.gameObjects[gameObjectId].parent = disabledEntitiesFolder

	local archetype = EcsService:GetArchetype(entityId)

	-- Update Version
	local lastEntityIndex = archetype.startIndex + archetype.activeCount

	versions[entityId] += 1
	versions[lastEntityIndex] += 1
	archetype.activeCount -= 1

	if entityId == lastEntityIndex then
		return
	end

	-- Swap Last Entity to entityId
	local otherGameObjectId = gameObjectSystem:getComponentId(lastEntityIndex)
	gameObjectSystem.entities[otherGameObjectId] = entityId
	gameObjectSystem.entities[gameObjectId] = lastEntityIndex

	-- Update Other GameObject
	local otherGameObject = gameObjectSystem.gameObjects[otherGameObjectId]
	otherGameObject:SetAttribute("EntityId", entityId)
	otherGameObject:SetAttribute("Version", versions[entityId])
end

-- #endregion

-- #region COMPONENTS

function EcsService:HasComponent(entityId, systemId)
	local entityMask = entitiesBitmask[entityId]
	local systemMask = EcsService:GetSystemMask(systemId)

	return bit32.band(entityMask, systemMask) ~= 0
end

function EcsService:RemoveComponent(entityId, systemId)
	systems[systemId]:removeComponent(entityId)
end

-- #endregion

-- Start Service
function EcsService:KnitInit()
	print("EcsService Initialized")
end

function EcsService:KnitStart()
	-- createPools()
end

return EcsService
