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

-- #region ENTITIES

--- Create a new ECS Entity
--- @return number entityId of created Entity
function EcsService.CreateEntity()
	local EcsState = MutState.EcsState
	local entityId = #EcsState.entitiesId + 1

	table.insert(EcsState.entitiesId, entityId)
	table.insert(EcsState.entitiesBitmask, 0)
	-- table.insert(EcsState.versions, 0)

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
	-- Gears.ReplaceWithLastElement(EcsState.versions, entityId)
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
