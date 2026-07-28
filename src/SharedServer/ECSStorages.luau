local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages._Index["sleitnick_signal@1.5.0"].signal)
local Gears = require(ReplicatedStorage.Shared.Gears)

-- Get Mutable State
local MutState = require(ServerScriptService.SharedServer.MutableState)
local ecsState = MutState.ecsState

-- STORAGES IMPL

-- #region META TABLE

local storage = {}

function storage.addComponentToEntity(ecsState, storageState, entityId)
	table.insert(storageState.entities, entityId)

	local componentId = #storageState.entities
	storageState.sparse[entityId] = componentId

	-- Update Entity Bitmask
	ecsState.entitiesBitmask[entityId] =
		Gears:AddMask(ecsState.entitiesBitmask[entityId], Gears:GetMask(storageState.id))

	return componentId
end

function storage.getComponentId(storageState, entityId)
	-- warn(storageState.name .. " Get Component ID = " .. entityId)
	local componentId = storageState.sparse[entityId]

	if componentId == 0 then
		warn("EntityId = " .. entityId .. " Doesn't have Component " .. storageState.name)
	end

	if not componentId then
		warn("EntityId = " .. entityId .. " Is out of Sparse Range of : " .. storageState.name)
	end

	return componentId
end

function storage.updateComponent(storageState, entityId)
	-- implement in child tables
end

function storage.removeComponent(ecsState, storageState, entityId)
	local componentId = storageState.sparse[entityId]

	-- Update Entities
	table.remove(storageState.entities, componentId)

	-- Update Sparse
	storageState.sparse[entityId] = 0

	-- Update Entity Bitmask
	ecsState.entitiesBitmask[entityId] =
		Gears:RemoveMask(ecsState.entitiesBitmask[entityId], Gears:GetMask(storageState.id))

	return componentId
end

function storage.removeEntity(storageState, entityId)
	local sparse = storageState.sparse
	local entities = storageState.entities

	local componentId = sparse[entityId]
	local lastCompId = sparse[#sparse]
	local hasComp = lastCompId ~= 0

	-- Update Entities
	table.remove(entities, lastCompId)

	-- Delete Comp if last Entity doesn't have it, else keep
	if not hasComp then
		table.remove(entities, entityId)
		sparse[entityId] = 0

		for i = entityId, #entities, 1 do
			sparse[entities[i]] -= 1
		end
	end

	-- Update Sparse
	table.remove(sparse, #sparse)

	return componentId, lastCompId, hasComp
end

function storage.clearComponents(storageState)
	table.clear(storageState.sparse)
	table.clear(storageState.entities)
end

storage.__index = storage

function storage.new()
	local self = {}

	setmetatable(self, storage)
	return self
end

-- #endregion

-- #region GAMEOBJECT IMPL

local gameObjectStorage = storage.new()

function gameObjectStorage.getState()
	return ecsState.gameObjectStorageState
end

function gameObjectStorage.addComponentToEntity(ecsState, entityId, gameobject)
	local storageState = gameObjectStorage.getState() -- Selector

	local componentId = storage.addComponentToEntity(ecsState, storageState, entityId)

	gameobject:SetAttribute("EntityId", entityId)
	gameobject:SetAttribute("Version", ecsState.versions[entityId])

	table.insert(storageState.gameObjects, gameobject)

	return componentId
end

function gameObjectStorage.removeComponent(storageState, entityId)
	-- TODO
end

-- Remove Entity : Full Entities Update
--[[
function gameObjectStorage:removeEntity(entityId)
	local componentId = system.removeEntity(self, entityId)

	warn("Delete Gameobject Component : EntityId = " .. entityId .. " componentId = " .. componentId)

	self.gameObjects[componentId]:Destroy()
	table.remove(self.gameObjects, componentId)

	for i = entityId, #self.entities, 1 do
		self.gameObjects[i]:SetAttribute("EntityId", self.entities[i])
		-- self.gameObjects[i]:SetAttribute("Version", versions[entityId])
	end
end
]]

-- Remove Entity : Swap Last
function gameObjectStorage.removeEntity(storageState, entityId)
	local componentId, lastCompId, hasComp = storage.removeEntity(storageState, entityId)
	local gameObjects = storageState.gameObjects

	-- warn("Delete GameObject Component : EntityId = " .. entityId .. " componentId = " .. componentId)

	gameObjects[componentId]:Destroy()

	if not hasComp then
		-- Delete at compId
		table.remove(gameObjects, componentId)
		return
	end

	-- Swap Values + Delete Last
	local lastGameObject = table.remove(gameObjects, lastCompId)
	gameObjects[componentId] = lastGameObject

	-- local lastGameObject = moveLastElement(gameObjects, componentId)

	-- Update GameObject EntityId
	lastGameObject:SetAttribute("EntityId", entityId)
	-- lastGameObject:SetAttribute("Version", versions[entityId])
end

function gameObjectStorage.clearComponents(storageState)
	storage.clearComponents(storageState)
	local gameObjects = storageState.gameObjects

	-- Destroy All Entities Gameobjects
	for i = 1, #gameObjects, 1 do
		gameObjects[i]:Destroy()
	end

	table.clear(gameObjects)
end

-- #endregion

-- #region UNIT STORAGE

local unitStorage = storage.new()

function unitStorage.getState()
	return ecsState.unitStorageState
end

function unitStorage.addComponentToEntity(ecsState, entityId, definitionId, life, lifeBar)
	local storageState = ecsState.unitStorageState

	local componentId = storage.addComponentToEntity(ecsState, storageState, entityId)

	table.insert(storageState.definitionId, definitionId)
	table.insert(storageState.life, life)
	table.insert(storageState.lifeBar, lifeBar)
	table.insert(storageState.deathEvent, Signal.new())

	return componentId
end

function unitStorage.updateComponent(storageState, entityId, life)
	local componentId = storage.getComponentId(storageState, entityId)
	storageState.life[componentId] = life
end

function unitStorage.removeComponent(storageState, entityId)
	-- TODO
end

function unitStorage.removeEntity(storageState, entityId)
	local componentId, lastCompId, hasComp = storage.removeEntity(storageState, entityId)

	-- warn("Delete Unit Component : EntityId = " .. entityId .. " componentId = " .. componentId)

	if not hasComp then
		-- Delete at compId
		table.remove(storageState.life, componentId)
		table.remove(storageState.lifeBar, componentId)
		table.remove(storageState.deathEvent, componentId)
		return
	end

	-- Swap Values + Delete Last
	Gears.moveLastElement(storageState.life, componentId)
	Gears.moveLastElement(storageState.lifeBar, componentId)
	Gears.moveLastElement(storageState.deathEvent, componentId)
end

function unitStorage.clearComponents(storageState)
	storage.clearComponents(storageState)

	table.clear(storageState.life)
	table.clear(storageState.lifeBar)
	table.clear(storageState.deathEvent)
end

-- #endregion

-- TODO : MOB BEHAVIOR STORAGE

local EcsStorages = {
	gameObjectStorage,
	unitStorage,
}

return EcsStorages
