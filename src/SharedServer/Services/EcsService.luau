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
local EcsState = MutState.EcsState

local entitiesId = EcsState.entitiesId
local entitiesBitmask = EcsState.entitiesBitmask
local versions = EcsState.versions

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

--- Create a new ECS Entity
--- @return number entityId of created Entity
function EcsService.CreateEntity()
	local entityId = #EcsState.entitiesId + 1

	table.insert(EcsState.entitiesId, entityId)
	table.insert(EcsState.entitiesBitmask, 0)
	table.insert(EcsState.versions, 0)

	-- Update sparse of every Storage
	for i = 1, #EcsState.storages, 1 do
		table.insert(EcsState.storages[i].GetState().sparse, 0)
	end

	return entityId
end

--- Remove Entity at Specified ID,
--- Cascade Delete every Components linked to it
function EcsService.RemoveEntity(entityId)
	-- warn("Remove Entity : " .. entityId)

	-- Remove components
	for i = 1, #EcsState.storages, 1 do
		if EcsService.HasComponent(entityId, i) then
			local storage = EcsState.storages[i]
			-- warn("EntityID = " .. entityId .. " Has Component = " .. storage.getState().name)
			storage.RemoveEntity(storage.GetState(), entityId)
		end
	end

	-- Remove Entity
	moveLastElement(EcsState.entitiesId, entityId)
	moveLastElement(EcsState.entitiesBitmask, entityId)
	moveLastElement(EcsState.versions, entityId)
end

function EcsService.ClearEntities()
	-- Clear all components
	for i = 1, #EcsState.storages, 1 do
		local storage = EcsState.storages[i]
		storage.ClearComponents(storage.GetState())
	end

	table.clear(entitiesId)
	table.clear(entitiesBitmask)
end

-- #endregion

-- #region ENTITIES ARCHETYPES / POOLING

function EcsService.AddArchetype(archetype)
	table.insert(EcsState.archetypes, archetype)
end

--- Create a pool of Entity of an Archetype
function EcsService.CreatePool(archetype, startIndex)
	local endIndex = startIndex + archetype.count
	archetype.startIndex = startIndex
	archetype.endIndex = endIndex

	for i = startIndex, endIndex, 1 do
		local entityId = EcsService.CreateEntity()

		-- Call Archetype's custom setup functions
		for j = 1, #archetype.setup, 1 do
			local setupFunc = archetype.setup[j]
			setupFunc(entityId, archetype.definitionId)
		end
	end
end

--- Create every pools of added Archetypes
function EcsService.CreatePools()
	local archetypes = EcsState.archetypes
	local totalEntitiesCount = 0 -- Archetype Entities Should Always be The Firsts

	for i = 1, #archetypes, 1 do
		local archetype = archetypes[i]

		warn("Create Pool : " .. archetype.name .. ", Entities = " .. archetype.count)
		EcsService.CreatePool(archetype, totalEntitiesCount)
		totalEntitiesCount += archetype.count + 1
	end
end

--- @return Archetype archetype of an Entity
function EcsService.GetArchetype(entityId)
	local archetypes = EcsState.archetypes
	local count = 0

	for i = 1, #archetypes, 1 do
		local threshold = count + archetypes[i].endIndex

		if entityId <= threshold then
			return archetypes[i]
		end

		count += archetypes[i].endIndex
	end

	return nil
end

-- Enable an Entity of an Archetype
function EcsService.EnableArchetypeEntity(archetypeId)
	local archetype = EcsState.archetypes[archetypeId]
	archetype.activeCount += 1

	local index = archetype.startIndex + archetype.activeCount
	local entityId = EcsState.entitiesId[index]
	local entityVersion = EcsState.versions[entityId]
	entityVersion += 1

	-- warn("Enable Entity in Archetype = " .. archetype.name .. ", Entity ID = " .. entityId)
	return entityId, entityVersion
end

-- Disable Entity Replace with Last Entity within an Archetype
function EcsService.DisableEntity(entityId)
	if not EcsService.HasComponent(entityId, 1) then
		warn(entityId .. " Doesn't have Gameobject Component")
		return
	end

	local archetype = EcsService.GetArchetype(entityId)
	local lastEntityIndex = archetype.startIndex + archetype.activeCount
	local lastEntityId = EcsState.entitiesId[lastEntityIndex]

	-- Update
	versions[entityId] += 1
	archetype.activeCount -= 1

	-- Update Components
	-- TODO : Per Archetype's Component
	local gameObjectStorage = EcsService.GetStorage(CONSTANTS.EcsStorages.gameObject)
	gameObjectStorage.DisableEntity(entityId)

	-- If not last Entity : Swap Last
	if entityId == lastEntityId then
		return
	end

	-- warn("Disable Entity : Swap Entity ID = " .. entityId .. " With Last ID = " .. lastEntityId)

	versions[lastEntityId] += 1

	-- Swap Entities
	local entityIdIndex = EcsState.entitiesId[entityId]
	EcsState.entitiesId[entityIdIndex] = lastEntityId
	EcsState.entitiesId[lastEntityIndex] = entityId
end

-- #endregion

-- #region STORAGES + COMPONENTS

function EcsService.GetStorage(storageId)
	return EcsState.storages[storageId]
end

function EcsService.HasComponent(entityId, systemId)
	local entityMask = EcsState.entitiesBitmask[entityId]
	local systemMask = Gears.GetMask(systemId)

	return bit32.btest(entityMask, systemMask)
end

--TODO : Custom Param
function EcsService.AddComponent(entityId, systemId)
	if EcsService.HasComponent(entityId, systemId) then
		warn("Entity = " .. entityId .. " Already has = " .. systemId)
		return
	end

	EcsState.storages[systemId].AddComponentToEntity(EcsState, entityId)
end

-- #endregion

-- Start Service
function EcsService:KnitInit()
	print("EcsService Initialized")

	EcsState.storages = ECSStorages
end

function EcsService:KnitStart()
	-- Start
end

return EcsService
