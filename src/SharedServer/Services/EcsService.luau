local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages._Index["sleitnick_signal@1.5.0"].signal)

-- Entities
local entitiesId = {}
local entitiesBitmask = {}
local versions = {}

local disabledEntitiesFolder = ServerStorage.DisabledEntities

local EcsService = Knit.CreateService({
	Name = "EcsService",
	SystemMetatable = nil,
	-- Archetype = archetype,
	GameobjectSystem = nil,
	UnitSystem = nil,
	-- Client = {},
})

-- Systems
-- local systemCount = 0

-- Metatable
local system = {
	addComponentToEntity = function(self, entityId)
		table.insert(self.entities, entityId)

		local componentId = #self.entities
		table.insert(self.sparse, entityId, componentId)

		-- Update Entity Bitmask
		entitiesBitmask[entityId] = EcsService:AddMask(entitiesBitmask[entityId], EcsService:GetSystemMask(self.id))

		return componentId
	end,
	getComponentId = function(self, entityId)
		local componentId = self.sparse[entityId]

		if componentId == 0 then
			warn("EntityId = " .. entityId .. " Doesn't have Component Id = " .. self.id)
		end

		return componentId
	end,
	updateComponent = function(self, entityId)
		-- implement in child tables
	end,
	removeComponent = function(self, entityId)
		local componentId = self.sparse[entityId]

		-- Update Entities
		table.remove(self.entities, componentId)

		-- Update Sparse
		self.sparse[entityId] = 0
		for i = entityId + 1, #self.sparse, 1 do
			if self.sparse[i] > 0 then
				self.sparse[i] -= 1
			end
		end

		-- Update Entity Bitmask
		entitiesBitmask[entityId] = EcsService:RemoveMask(entitiesBitmask[entityId], EcsService:GetSystemMask(self.id))

		return componentId
	end,
	clearComponents = function(self)
		table.clear(self.sparse)
		table.clear(self.entities)
	end,
	swapLast = function(self, entityId)
		local lastEntityIndex = #self.entities

		local componentId = self.sparse[entityId]
		local lastComponentId = self.sparse[entityId]

		-- Swap Entities
		self.entities[componentId] = lastEntityIndex
		self.entities[lastComponentId] = entityId

		-- Swap Sparse
		self.sparse[entityId] = lastComponentId
		self.sparse[lastEntityIndex] = componentId

		return componentId, lastComponentId
	end,
}
system.__index = system

function system.new(id)
	local self = {
		id = id,
		sparse = {},
		entities = {},
	}

	setmetatable(self, system)
	return self
end

-- Gameobject System
local gameObjectSystem = system.new(1)
gameObjectSystem.gameObjects = {}

function gameObjectSystem:addComponentToEntity(entityId, gameobject)
	local componentId = system.addComponentToEntity(self, entityId)

	gameobject:SetAttribute("EntityId", entityId)
	gameobject:SetAttribute("Version", versions[entityId])

	table.insert(self.gameObjects, gameobject)

	return componentId
end

function gameObjectSystem:swapLast(entityId)
	local componentId, lastComponentId = system.swapLast(self, entityId)

	local gameobjects = self.gameObjects

	local otherGameObject = gameObjectSystem.gameObjects[lastComponentId]
	gameobjects[lastComponentId] = gameobjects[componentId]
	gameobjects[componentId] = otherGameObject

	-- Update Moved Entity
	otherGameObject:SetAttribute("EntityId", entityId)
	otherGameObject:SetAttribute("Version", versions[entityId])
end

function gameObjectSystem:removeComponent(entityId)
	local componentId = system.removeComponent(self, entityId)
	self.gameObjects[componentId]:Destroy()
	table.remove(self.gameObjects, componentId)
end

function gameObjectSystem:clearComponents()
	system.clearComponents(self)

	-- Destroy All Entities Gameobjects
	for i = 1, #self.gameObjects, 1 do
		self.gameObjects[i]:Destroy()
	end

	table.clear(self.gameObjects)
end

-- Unit System
local unitSystem = system.new(2)
unitSystem.definitionId = {}
unitSystem.life = {}
unitSystem.lifeBar = {}
unitSystem.deathEvent = {}

function unitSystem:addComponentToEntity(entityId, definitionId, life, lifeBar)
	local componentId = system.addComponentToEntity(self, entityId)

	table.insert(self.definitionId, definitionId)
	table.insert(self.life, life)
	table.insert(self.lifeBar, lifeBar)
	table.insert(self.deathEvent, Signal.new())

	return componentId
end

function unitSystem:updateComponent(entityId, life)
	local componentId = system.getComponentId(self, entityId)
	self.life[componentId] = life
end

function unitSystem:swapLast(entityId)
	-- TODO : Swap Values
end

function unitSystem:removeComponent(entityId)
	local componentId = system.removeComponent(self, entityId)

	table.remove(self.life, componentId)
	table.remove(self.lifeBar, componentId)
	table.remove(self.deathEvent, componentId)
end

function unitSystem:clearComponents()
	system.clearComponents(self)

	table.clear(self.life)
	table.clear(self.lifeBar)
	table.clear(self.deathEvent)
end

-- TODO : MobBehaviorSystem

local systems = {
	gameObjectSystem,
	unitSystem,
}

-- Archetypes
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
	return bit32.bor(entityMask, systemMask)
end

function EcsService:RemoveMask(entityMask, systemMask)
	return bit32.band(entityMask, systemMask)
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

-- Swap Entity with the last
-- Only update the LastEntity
function EcsService:SwapLast(entityId)
	local lastEntityIndex = #entitiesId

	if entityId == lastEntityIndex then
		return
	end

	local lastEntityBitmask = entitiesBitmask[#entitiesBitmask]
	entitiesBitmask[entityId] = lastEntityBitmask

	for i = 1, #systems, 1 do
		if EcsService:HasComponent(lastEntityIndex, i) then
			systems[i]:swapLast(entityId)
		end
	end
end

function EcsService:RemoveEntity(entityId)
	-- 1] Swap Entity -> Last Entity
	EcsService:SwapLast(entityId)

	-- 2] Delete now Last Entity
	local lastEntityIndex = #entitiesId

	-- Remove components
	for i = 1, #systems, 1 do
		if EcsService:HasComponent(lastEntityIndex, i) then
			systems[i]:removeComponent(lastEntityIndex)
		end
	end

	table.remove(entitiesId, lastEntityIndex)
	table.remove(entitiesBitmask, lastEntityIndex)
	table.remove(versions, lastEntityIndex)
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

-- Archetype : Disable Entity Replace with Last Entity
function EcsService:DisableEntity(entityId)
	if not EcsService:HasComponent(entityId, 1) then
		warn(entityId .. " Doesn't have Gameobject Component")
		return
	end

	-- Disable Gameobject
	local gameObjectId = gameObjectSystem:getComponentId(entitiesId)
	gameObjectSystem.gameObjects[gameObjectId].parent = disabledEntitiesFolder

	local archetype = EcsService:GetArchetype(entityId)
	local lastEntityIndex = archetype.startIndex + archetype.activeCount
	archetype.activeCount -= 1

	-- Update Version
	versions[entityId] += 1

	if entityId == lastEntityIndex then
		return
	end

	versions[lastEntityIndex] += 1

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

	EcsService.SystemMetatable = systems
	EcsService.GameobjectSystem = gameObjectSystem
	EcsService.UnitSystem = unitSystem
end

function EcsService:KnitStart()
	-- createPools()
end

return EcsService
