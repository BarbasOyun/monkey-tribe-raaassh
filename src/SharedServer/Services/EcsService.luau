local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages._Index["sleitnick_signal@1.5.0"].signal)

-- Entities
local entitiesId = {}
local entitiesBitmask = {}
local versions = {}

local disabledEntitiesFolder = ServerStorage.DisabledEntities

-- TODO : Move to HubManager
local dummy1 = workspace.WeaponHit[1]
local dummy2 = workspace.WeaponHit[2]

-- Systems
-- local systemCount = 0

-- Metatable
local system = {
	id = 0,
	isDisabled = {},
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
	enableComponent = function(self, entityId)
		local componentId = self.sparse[entityId]
		self.isDisabled[componentId] = false
	end,
	disableComponent = function(self, entityId)
		local componentId = self.sparse[entityId]
		self.isDisabled[componentId] = true
	end,
}
system.__index = system

local gameObjectSystem = {
	gameObjects = {},
	clearComponents = function(self)
		self:clearComponents()
		table.clear(self.gameObjects)
	end,
	addComponentToEntity = function(self, entityId, gameobject)
		self:addComponentToEntity(entityId)
		table.insert(self.gameObjects, gameobject)
	end,
	removeComponent = function(self, entityId)
		local componentId = self:removeComponent(entityId)
		table.remove(self.gameObjects, componentId)
	end,
}

setmetatable(gameObjectSystem, system)

local systems = {
	gameObjectSystem,
}

-- Archetypes
-- struct
local archetype = {
	name = "",
	systems = {},
	startIndex = 0,
	maxEntities = 100,
	activeCount = 0,
}

-- TODO : Archetypes : Dummy, RobotMob

local archetypes = {}
local archetypesTotalSize = 0

local EcsService = Knit.CreateService({
	Name = "EcsService",
	SystemMetatable = system,
	Archetype = archetype,
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
	for i = 1, #systems, 1 do
		systems[i]:clearComponents()
	end

	table.clear(entitiesId)
	table.clear(entitiesBitmask)
end

-- #endregion

-- #region ENTITIES ARCHETYPES / POOLING

-- Create a pool of Entity of an Archetype
function EcsService:CreatePool(archetype)
	for i = 0, archetype.maxEntities, 1 do
		local entityId = EcsService:CreateEntity()

		-- Add a Component of Every Archertype's Systems to each Entity
		for j = 0, #archetype.systems, 1 do
			archetype.systems[j].addComponentToEntity(entityId)
		end
	end

	table.insert(archetypes, archetype)
end

function EcsService:GetArchetype(entityId)
	for i = 1, #archetypes, 1 do
		if entityId <= archetype[i].maxEntities then
			return archetype[i]
		end
	end

	return nil
end

-- Enable an Entity of an Archetype
function EcsService:EnableEntity(archetypeId)
	local indexCount = 0
	local archetype = nil

	for i = 1, #archetypes, 1 do
		if i == archetypeId then
			archetype = archetypes[i]
			break
		end

		indexCount += archetypes[i].maxEntities
	end

	-- Enable Last Entity
	local entityId = indexCount + archetype.currentEntities

	for i = 1, #systems, 1 do
		if EcsService:HasComponent(entityId, i) then
			systems[i]:enableComponent(entityId)
		end
	end
end

-- Disable an Entity and Move the Last Entity of an Archetype to its place
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
	versions[entityId] += 1
	archetype.activeCount -= 1

	-- Swap Last Entity to entityId
	-- TODO : Optimize
	local lastEntityIndex = archetype.startIndex + archetype.activeCount

	if entityId == lastEntityIndex then
		return
	end

	-- TODO : per system
	local otherGameObjectId = gameObjectSystem:getComponentId(lastEntityIndex)
	-- local movedEntity = gameObjectSystem.gameObjects[otherGameObjectId]
	gameObjectSystem.entities[otherGameObjectId] = entityId

	gameObjectSystem.entities[gameObjectId] = lastEntityIndex

	--             // Update Entity
	--             if (movedEnemy.TryGetComponent(out Entity entity))
	--             {
	--                 entity.index = indexToRemove;
	--                 entity.version = state.versions[indexToRemove];
	--             }
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

function EcsService:KnitStart() end

return EcsService
