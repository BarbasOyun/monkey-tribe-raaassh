local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
-- local Signal = require(ReplicatedStorage.Packages._Index["sleitnick_signal@1.5.0"].signal)
local Gears = require(ReplicatedStorage.Shared.Gears)

-- Get Constants
local CONSTANTS = require(ServerScriptService.SharedServer.Constants)
local ECSStorages = require(ServerScriptService.SharedServer.ECSStorages)

-- Get Mutable State
local MutState = require(ServerScriptService.SharedServer.MutableState)
local ecsState = MutState.ecsState

local gameObjectStorage = ecsState.storages[1] -- TODO : Move

local entitiesId = ecsState.entitiesId
local entitiesBitmask = ecsState.entitiesBitmask
local versions = ecsState.versions

local EcsService = Knit.CreateService({
	Name = "EcsService",
	-- Client = {},
})

-- Replace index with Last Element
local function moveLastElement(t, index)
	local lastElement = table.remove(t, #t)
	t[index] = lastElement

	return lastElement
end

-- Archetypes
export type Archetype = {
	name: string,
	count: number,
	startIndex: number,
	endIndex: number,
	activeCount: number,
}

-- #region ENTITIES

function EcsService.CreateEntity()
	local entityId = #ecsState.entitiesId + 1

	table.insert(ecsState.entitiesId, entityId)
	table.insert(ecsState.entitiesBitmask, 0)
	table.insert(ecsState.versions, 0)

	-- Update sparse of every Storage
	for i = 1, #ecsState.storages, 1 do
		table.insert(ecsState.storages[i].GetState().sparse, 0)
	end

	return entityId
end

function EcsService.RemoveEntity(entityId)
	-- warn("Remove Entity : " .. entityId)

	-- Remove components
	for i = 1, #ecsState.storages, 1 do
		if EcsService.HasComponent(entityId, i) then
			local storage = ecsState.storages[i]
			-- warn("EntityID = " .. entityId .. " Has Component = " .. storage.getState().name)
			storage.RemoveEntity(storage.GetState(), entityId)
		end
	end

	-- Remove Entity
	moveLastElement(ecsState.entitiesId, entityId)
	moveLastElement(ecsState.entitiesBitmask, entityId)
	moveLastElement(ecsState.versions, entityId)
end

function EcsService.ClearEntities()
	-- Clear all components
	for i = 1, #ecsState.storages, 1 do
		local storage = ecsState.storages[i]
		storage.ClearComponents(storage.GetState())
	end

	table.clear(entitiesId)
	table.clear(entitiesBitmask)
end

-- #endregion

-- #region ENTITIES ARCHETYPES / POOLING

function EcsService.AddArchetype(archetype)
	table.insert(ecsState.archetypes, archetype)
end

function EcsService.CreatePools()
	local archetypes = ecsState.archetypes
	local totalEntitiesCount = 0 -- #ecsState.entitiesId Archetype Entities Should Always be The Firsts

	for i = 1, #archetypes, 1 do
		local archetype = archetypes[i]

		warn("Create Pool : " .. archetype.name .. ", Entities = " .. archetype.count)
		EcsService.CreatePool(archetype, totalEntitiesCount)
		totalEntitiesCount += archetype.count
	end
end

-- Create a pool of Entity of an Archetype
-- TODO : Add Component Function List
function EcsService.CreatePool(archetype, startIndex)
	local endIndex = startIndex + archetype.count
	archetype.startIndex = startIndex
	archetype.endIndex = endIndex

	for i = startIndex, endIndex, 1 do
		local entityId = EcsService.CreateEntity()

		-- Add a Component of Every Archertype's storages to each Entity
		for j = 1, #archetype.setup, 1 do
			local setupFunc = archetype.setup[j]
			setupFunc(entityId)

			-- EcsService.GetStorage(storageId).addComponentToEntity(ecsState, entityId)
		end
	end
end

-- Return the Archetype of an Entity
function EcsService.GetArchetype(entityId)
	local archetypes = ecsState.archetypes
	local count = 0

	for i = 1, #archetypes, 1 do
		local threshold = count + archetypes[i].maxEntities

		if entityId <= threshold then
			return archetypes[i]
		end

		count += archetypes[i].maxEntities
	end

	return nil
end

-- Enable an Entity of an Archetype
function EcsService.EnableEntity(archetypeId)
	local archetype = ecsState.archetypes[archetypeId]
	archetype.activeCount += 1

	local entityId = archetype.startIndex + archetype.activeCount
	local entityVersion = ecsState.versions[entityId]
	entityVersion += 1

	-- Reset Components

	-- Enable Last Entity

	return entityId, entityVersion
end

-- Archetype : Disable Entity Replace with Last Entity
-- Use RemoveComponent
function EcsService.DisableEntity(entityId)
	if not EcsService.HasComponent(entityId, 1) then
		warn(entityId .. " Doesn't have Gameobject Component")
		return
	end

	-- Disable Gameobject
	local gameObjectStorageState = gameObjectStorage.GetState()
	local gameObjectId = gameObjectStorage.GetComponentId(gameObjectStorageState, entityId)
	gameObjectStorage.gameObjects[gameObjectId].parent = CONSTANTS.DISABLED_ENTITIES_FOLDER

	local archetype = EcsService.GetArchetype(entityId)
	local lastEntityIndex = archetype.startIndex + archetype.activeCount
	archetype.activeCount -= 1

	-- Update Version
	local versions = ecsState.versions
	versions[entityId] += 1

	if entityId == lastEntityIndex then
		return
	end

	versions[lastEntityIndex] += 1

	-- Swap Last Entity to entityId
	local otherGameObjectId = gameObjectStorage.GetComponentId(lastEntityIndex)
	gameObjectStorage.entities[otherGameObjectId] = entityId
	gameObjectStorage.entities[gameObjectId] = lastEntityIndex

	-- Update Other GameObject
	local otherGameObject = gameObjectStorage.gameObjects[otherGameObjectId]
	otherGameObject:SetAttribute("EntityId", entityId)
	otherGameObject:SetAttribute("Version", versions[entityId])
end

-- #endregion

-- #region STORAGES + COMPONENTS

function EcsService.GetStorage(storageId)
	return ecsState.storages[storageId]
end

function EcsService.HasComponent(entityId, systemId)
	local entityMask = ecsState.entitiesBitmask[entityId]
	local systemMask = Gears:GetMask(systemId)

	return bit32.btest(entityMask, systemMask)
end

--TODO : Custom Param
function EcsService.AddComponent(entityId, systemId)
	if EcsService.HasComponent(entityId, systemId) then
		warn("Entity = " .. entityId .. " Already has = " .. systemId)
		return
	end

	ecsState.storages[systemId].AddComponentToEntity(ecsState, entityId)
end

-- #endregion

-- Start Service
function EcsService:KnitInit()
	print("EcsService Initialized")

	ecsState.storages = ECSStorages
end

function EcsService:KnitStart()
	-- createPools()
end

return EcsService
