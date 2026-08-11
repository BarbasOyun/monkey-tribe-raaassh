local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Gears = require(ReplicatedStorage.Shared.Gears)
local ECSStorages = require(ServerScriptService.SharedServer.ECSStorages)

-- Get Constants
local CONSTANTS = require(ServerScriptService.SharedServer.Constants)

-- Get Mutable State
local MutState = require(ServerScriptService.SharedServer.MutableState)
local EcsState = MutState.EcsState

-- Knit
local Knit = require(ReplicatedStorage.Packages.Knit)
-- local Signal = require(ReplicatedStorage.Packages._Index["sleitnick_signal@1.5.0"].signal)

local EcsService = Knit.CreateService({
	Name = "EcsService",
	-- Client = {},
})

export type Pool = {
	name: string,
	definitionId: number,
	entities: {}, -- Store active entitiesID
	count: number,
	startIndex: number,
	endIndex: number,
	activeCount: number,
}

-- #region ENTITIES

--- Create a new ECS Entity
--- @return number entityId of created Entity
function EcsService.CreateEntity()
	local EcsState = MutState.EcsState
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
	local EcsState = MutState.EcsState

	-- Remove components
	for i = 1, #EcsState.storages, 1 do
		if EcsService.HasComponent(entityId, i) then
			local storage = EcsState.storages[i]
			-- warn("EntityID = " .. entityId .. " Has Component = " .. storage.getState().name)
			storage.RemoveEntity(storage.GetState(), entityId)
		end
	end

	-- Remove Entity
	Gears.ReplaceWithLastElement(EcsState.entitiesId, entityId)
	Gears.ReplaceWithLastElement(EcsState.entitiesBitmask, entityId)
	Gears.ReplaceWithLastElement(EcsState.versions, entityId)
end

function EcsService.ClearEntities()
	local EcsState = MutState.EcsState

	-- Clear all components
	for i = 1, #EcsState.storages, 1 do
		local storage = EcsState.storages[i]
		storage.ClearComponents(storage.GetState())
	end

	table.clear(EcsState.entitiesId)
	table.clear(EcsState.entitiesBitmask)
end

-- #endregion

-- #region STORAGES + COMPONENTS

function EcsService.GetStorage(storageId)
	local EcsState = MutState.EcsState
	return EcsState.storages[storageId]
end

function EcsService.HasComponent(entityId, storageId)
	local EcsState = MutState.EcsState
	local entityMask = EcsState.entitiesBitmask[entityId]
	local systemMask = Gears.GetMask(storageId)

	return bit32.btest(entityMask, systemMask)
end

-- TODO : Custom Param -> Component param
function EcsService.AddComponent(entityId, storageId)
	if EcsService.HasComponent(entityId, storageId) then
		warn("Entity = " .. entityId .. " Already has = " .. storageId)
		return
	end

	local EcsState = MutState.EcsState
	EcsState.storages[storageId].AddComponentToEntity(EcsState, entityId)
end

-- TODO : RemoveComponent -> EcsService.UpdateEntityArchetype()

-- #endregion

-- #region ARCHETYPES

-- TODO : EcsService.UpdateEntityArchetype(entityId)
-- -> GetEntityMask -> Place in the right Archetype

--- @return Archetype archetype of an Entity
function EcsService.GetArchetype(entityId)
	local EcsState = MutState.EcsState
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

-- TODO : Move Pool to EnemyService
--- Register a Pool to use Later
function EcsService.AddArchetype(archetype)
	table.insert(EcsState.archetypes, archetype)
	EcsState.archetypesLookups[archetype.definitionId] = #EcsState.archetypes
end

--- Spawn Pool of Entity
function EcsService.CreatePool(archetype, startIndex)
	-- Get Start & End Index
	local endIndex = startIndex + archetype.count - 1

	warn(
		"Create Pool : "
			.. archetype.name
			.. ", Entities = "
			.. archetype.count
			.. ", StartIndex = "
			.. startIndex
			.. ", EndIndex = "
			.. endIndex
	)

	archetype.startIndex = startIndex
	archetype.endIndex = endIndex

	-- Create Entities
	for i = startIndex, endIndex, 1 do
		local entityId = EcsService.CreateEntity()

		-- Call Archetype's custom OnSpawn functions
		for j = 1, #archetype.setup do
			local setupFunc = archetype.setup[j]
			setupFunc(entityId, archetype.definitionId)
		end
	end
end

--- Create every Pools
function EcsService.CreatePools()
	local EcsState = MutState.EcsState
	local archetypes = EcsState.archetypes
	local currentIndex = 1 -- Archetype Entities Should Always be The Firsts

	for i = 1, #archetypes do
		local archetype = archetypes[i]

		EcsService.CreatePool(archetype, currentIndex)
		currentIndex += archetype.count
	end
end

--- Enable next Entity of an Archetype
function EcsService.EnableArchetypeEntity(archetypeId)
	-- Validation
	local archetypeIndex = EcsState.archetypesLookups[archetypeId]
	local archetype = EcsState.archetypes[archetypeIndex]

	local hadReachedMaxEntities = archetype.activeCount >= archetype.count

	if hadReachedMaxEntities then
		warn(archetype.name .. " Reached Entities Limit of : " .. archetype.count)
		return
	end

	archetype.activeCount += 1

	local index = archetype.startIndex + archetype.activeCount
	local entityId = EcsState.entitiesId[index]

	local entityVersion = EcsState.versions[entityId]
	entityVersion += 1

	-- warn("Enable Entity in Archetype = " .. archetype.name .. ", Entity ID = " .. entityId)
	return entityId, entityVersion
end

--- Disable Entity Replace with Last Entity within an Archetype
function EcsService.DisableEntity(entityId)
	if not EcsService.HasComponent(entityId, 1) then
		warn(entityId .. " Doesn't have Gameobject Component")
		return
	end

	local EcsState = MutState.EcsState

	local archetype = EcsService.GetArchetype(entityId)
	local lastEntityIndex = archetype.startIndex + archetype.activeCount
	local lastEntityId = EcsState.entitiesId[lastEntityIndex]

	-- Update ECS
	EcsState.versions[entityId] += 1
	archetype.activeCount -= 1

	-- Update Components
	-- TODO : Per Archetype's Component

	local GameObjectStorage = EcsService.GetStorage(CONSTANTS.EcsStorages.gameObject)
	GameObjectStorage.OnDisable(entityId)

	-- If entityId not last Entity : Swap Last
	if entityId == lastEntityId then
		return
	end

	-- warn("Disable Entity : Swap Entity ID = " .. entityId .. " With Last ID = " .. lastEntityId)

	EcsState.versions[lastEntityId] += 1

	-- Swap Entities
	-- local entityIdIndex = EcsState.entitiesId[entityId]
	-- EcsState.entitiesId[entityIdIndex] = lastEntityId
	-- EcsState.entitiesId[lastEntityIndex] = entityId
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
