-- ECS Components Storages Implementation / Logic

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages._Index["sleitnick_signal@1.5.0"].signal)
local Gears = require(ReplicatedStorage.Shared.Gears)

-- Get Constants
local CONSTANTS = require(ServerScriptService.SharedServer.Constants)

-- Get Mutable State
local MutState = require(ServerScriptService.SharedServer.MutableState)
local EcsState = MutState.EcsState

-- #region STORAGE META TABLE

local Storage = {}

function Storage.AddComponentToEntity(ecsState, storageState, entityId)
	table.insert(storageState.entities, entityId)

	local componentId = #storageState.entities
	storageState.sparse[entityId] = componentId

	-- Update Entity Bitmask
	ecsState.entitiesBitmask[entityId] =
		Gears.AddMask(ecsState.entitiesBitmask[entityId], Gears.GetMask(storageState.id))

	return componentId
end

function Storage.GetComponentId(storageState, entityId)
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

function Storage.UpdateComponent(storageState, entityId)
	-- implement in child tables
end

--- @param ecsState any
--- @param storageState any
--- @param entityId any
function Storage.RemoveComponent(ecsState, storageState, entityId)
	local componentId = storageState.sparse[entityId]

	-- Update Entities
	table.remove(storageState.entities, componentId)

	-- Update Sparse
	storageState.sparse[entityId] = 0

	-- Update Entity Bitmask
	ecsState.entitiesBitmask[entityId] =
		Gears.RemoveMask(ecsState.entitiesBitmask[entityId], Gears.GetMask(storageState.id))

	return componentId
end

function Storage.RemoveEntity(storageState, entityId)
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

function Storage.ClearComponents(storageState)
	table.clear(storageState.sparse)
	table.clear(storageState.entities)
end

Storage.__index = Storage

function Storage.new()
	local self = {}

	setmetatable(self, Storage)
	return self
end

-- #endregion

-- #region GAMEOBJECT COMPONENTS STORAGE IMPL

local GameObjectStorage = Storage.new()

function GameObjectStorage.GetState()
	return EcsState.GameObjectStorageState
end

function GameObjectStorage.AddComponentToEntity(ecsState, entityId, gameobject)
	local storageState = GameObjectStorage.GetState() -- Selector

	local componentId = Storage.AddComponentToEntity(ecsState, storageState, entityId)

	gameobject:SetAttribute("EntityId", entityId)
	gameobject:SetAttribute("Version", ecsState.versions[entityId])

	table.insert(storageState.gameObjects, gameobject)

	return componentId
end

function GameObjectStorage.RemoveComponent(storageState, entityId)
	local gameObject = GameObjectStorage.GetGameObject(entityId)
	gameObject:Destroy()

	Storage.RemoveComponent(EcsState, storageState, entityId)
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
function GameObjectStorage.RemoveEntity(storageState, entityId)
	local componentId, lastCompId, hasComp = Storage.RemoveEntity(storageState, entityId)
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

	-- Update GameObject EntityId
	lastGameObject:SetAttribute("EntityId", entityId)
	lastGameObject:SetAttribute("Version", EcsState.versions[entityId])
end

function GameObjectStorage.ClearComponents(storageState)
	Storage.ClearComponents(storageState)
	local gameObjects = storageState.gameObjects

	-- Destroy All Entities Gameobjects
	for i = 1, #gameObjects, 1 do
		gameObjects[i]:Destroy()
	end

	table.clear(gameObjects)
end

function GameObjectStorage.GetGameObject(entityId)
	local GameObjectStorageState = GameObjectStorage.GetState()
	local gameObjectId = GameObjectStorage.GetComponentId(GameObjectStorageState, entityId)

	local gameObject = GameObjectStorageState.gameObjects[gameObjectId]
	return gameObject
end

--- Disable Gameobject
function GameObjectStorage.DisableEntity(entityId)
	local gameObject = GameObjectStorage.GetGameObject(entityId)

	for _, child in pairs(gameObject:GetChildren()) do
		if child:IsA("Part") then
			child.Anchored = true
		end
	end

	gameObject:PivotTo(CFrame.new(CONSTANTS.DISABLED_POSITION))
	gameObject.Parent = CONSTANTS.DISABLED_ENTITIES_FOLDER
end

-- #endregion

-- #region UNIT STORAGE

local UnitStorage = Storage.new()

function UnitStorage.GetState()
	return EcsState.UnitStorageState
end

function UnitStorage.AddComponentToEntity(ecsState, entityId, definitionId, life, lifeBar)
	local storageState = ecsState.UnitStorageState

	local componentId = Storage.AddComponentToEntity(ecsState, storageState, entityId)

	table.insert(storageState.definitionId, definitionId)
	table.insert(storageState.life, life)
	table.insert(storageState.lifeBar, lifeBar)
	table.insert(storageState.deathEvent, Signal.new())

	return componentId
end

function UnitStorage.UpdateComponent(storageState, entityId, life)
	local componentId = Storage.GetComponentId(storageState, entityId)
	storageState.life[componentId] = life
end

function UnitStorage.RemoveComponent(storageState, entityId)
	-- TODO
end

function UnitStorage.RemoveEntity(storageState, entityId)
	local componentId, lastCompId, hasComp = Storage.RemoveEntity(storageState, entityId)

	-- warn("Delete Unit Component : EntityId = " .. entityId .. " componentId = " .. componentId)

	if not hasComp then
		-- Delete at compId
		table.remove(storageState.life, componentId)
		table.remove(storageState.lifeBar, componentId)
		table.remove(storageState.deathEvent, componentId)
		return
	end

	-- Swap Values + Delete Last
	Gears.MoveLastElement(storageState.life, componentId)
	Gears.MoveLastElement(storageState.lifeBar, componentId)
	Gears.MoveLastElement(storageState.deathEvent, componentId)
end

function UnitStorage.ClearComponents(storageState)
	Storage.ClearComponents(storageState)

	table.clear(storageState.life)
	table.clear(storageState.lifeBar)
	table.clear(storageState.deathEvent)
end

-- #endregion

-- TODO : MOB BEHAVIOR STORAGE

local EcsStorages = {
	GameObjectStorage,
	UnitStorage,
}

return EcsStorages
