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

function Storage.AddComponentToEntity(storageState, entityId)
	-- Update Storage : Entities + Sparse
	table.insert(storageState.entities, entityId)

	local componentId = #storageState.entities
	storageState.sparse[entityId] = componentId

	-- Update Entity Bitmask
	local mask = Gears.AddMask(EcsState.entitiesBitmask[entityId], Gears.GetMask(storageState.id))
	EcsState.entitiesBitmask[entityId] = mask

	return componentId
end

--- Get ComponentId of an Entity using Sparse -> Doesn't work for Archetype
function Storage.GetComponentId(storageState, entityId)
	-- warn(storageState.name .. " Get Component ID = " .. entityId)
	local componentId = storageState.sparse[entityId]

	if not componentId then
		warn("EntityId = " .. entityId .. " Is out of Sparse Range of : " .. storageState.name)
	end

	if componentId == 0 then
		warn("EntityId = " .. entityId .. " Doesn't have Component " .. storageState.name)
	end

	return componentId
end

function Storage.UpdateComponent(storageState, entityId)
	-- implement in child tables
end

--- @param storageState any
--- @param entityId any
function Storage.RemoveComponent(storageState, entityId)
	local componentId = Storage.GetComponentId(storageState, entityId)

	-- Update ECS : Entities + Sparse
	table.remove(storageState.entities, componentId)
	storageState.sparse[entityId] = 0

	-- Update Entity Bitmask
	local mask = Gears.RemoveMask(EcsState.entitiesBitmask[entityId], Gears.GetMask(storageState.id))
	EcsState.entitiesBitmask[entityId] = mask

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

-- #region GAMEOBJECT ID = 1

local GameObjectStorage = Storage.new()

--- Selector
function GameObjectStorage.GetState()
	return EcsState.GameObjectStorageState
end

function GameObjectStorage.AddComponentToEntity(entityId, gameobject)
	local storageState = GameObjectStorage.GetState()
	local componentId = Storage.AddComponentToEntity(storageState, entityId)

	gameobject:SetAttribute("EntityId", entityId)
	-- gameobject:SetAttribute("Version", EcsState.versions[entityId])

	table.insert(storageState.gameObjects, gameobject)

	return componentId
end

function GameObjectStorage.RemoveComponent(storageState, entityId)
	local gameObject = GameObjectStorage.GetGameObject(entityId)
	gameObject:Destroy()

	Storage.RemoveComponent(storageState, entityId)
end

--- Remove Entity : Swap Last
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
	-- lastGameObject:SetAttribute("Version", EcsState.versions[entityId])
end

function GameObjectStorage.ClearComponents(storageState)
	Storage.ClearComponents(storageState)
	local gameObjects = storageState.gameObjects

	-- Destroy All Entities Gameobjects
	for i = 1, #gameObjects do
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

-- TODO : OnEnabled

--- System Disable Gameobject
function GameObjectStorage.OnDisable(entityId)
	local gameObject = GameObjectStorage.GetGameObject(entityId)

	Gears.AnchorModel(gameObject, true)

	gameObject:PivotTo(CFrame.new(CONSTANTS.DISABLED_POSITION))
	gameObject.Parent = CONSTANTS.DISABLED_ENTITIES_FOLDER
end

-- #endregion

-- #region UNIT ID = 2

local UnitStorage = Storage.new()

function UnitStorage.GetState()
	return EcsState.UnitStorageState
end

function UnitStorage.AddComponentToEntity(entityId, definitionId, life)
	local storageState = UnitStorage.GetState()

	local componentId = Storage.AddComponentToEntity(storageState, entityId)

	table.insert(storageState.definitionId, definitionId)
	table.insert(storageState.life, life)
	table.insert(storageState.lifeChanged, Signal.new())
	table.insert(storageState.deathEvent, Signal.new())
	table.insert(storageState.attackCd, 1)

	return componentId
end

function UnitStorage.UpdateComponent(storageState, entityId, life)
	local componentId = Storage.GetComponentId(storageState, entityId)
	storageState.life[componentId] = life
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
	Gears.ReplaceWithLastElement(storageState.life, componentId)
	Gears.ReplaceWithLastElement(storageState.lifeBar, componentId)
	Gears.ReplaceWithLastElement(storageState.deathEvent, componentId)
end

function UnitStorage.ClearComponents(storageState)
	Storage.ClearComponents(storageState)

	table.clear(storageState.life)
	table.clear(storageState.lifeBar)
	table.clear(storageState.deathEvent)
end

-- #endregion

-- #region LIFE BAR ID = 3
-- Components Dependancies : Gameobject, Unit

local LifeBarStorage = Storage.new()

function LifeBarStorage.GetState()
	return EcsState.LifeBarStorageState
end

function LifeBarStorage.AddComponentToEntity(entityId, EcsService)
	local hasGameObject = EcsService.HasComponent(entityId, CONSTANTS.EcsStorages.gameObject)
	local hasUnit = EcsService.HasComponent(entityId, CONSTANTS.EcsStorages.unit)

	if not hasGameObject or not hasUnit then
		warn(entityId .. " Need Unit Component Before Adding LifeBar")
		return
	end

	-- Register LifeBar
	local storageState = LifeBarStorage.GetState()
	local componentId = Storage.AddComponentToEntity(storageState, entityId)

	-- Create LifeBar
	local lifeBar = CONSTANTS.PREFABS_FOLDER.LifeBar:clone()
	local bar = lifeBar:FindFirstChild("LifeBar")
	table.insert(storageState.lifeBar, bar)

	-- Link LifeBar to GameObject & Unit
	local gameObject = GameObjectStorage.GetGameObject(entityId)
	lifeBar.Parent = gameObject

	lifeBar.Adornee = gameObject.Head

	local unitStorageState = UnitStorage.GetState()
	local unitId = UnitStorage.GetComponentId(unitStorageState, entityId)

	unitStorageState.lifeChanged[unitId]:Connect(function(percent)
		Gears.UpdateBar(bar, percent)
	end)

	return componentId
end

-- TODO : Rename OnRemoveEntity
function LifeBarStorage.RemoveEntity(storageState, entityId)
	local componentId, lastCompId, hasComp = Storage.RemoveEntity(storageState, entityId)

	if not hasComp then
		-- Delete at compId
		table.remove(storageState.lifeBar, componentId)
		return
	end

	-- Swap Values + Delete Last
	Gears.ReplaceWithLastElement(storageState.lifeBar, componentId)
end

function LifeBarStorage.ClearComponents(storageState)
	Storage.ClearComponents(storageState)

	-- TODO : Delete All LifeBars
	table.clear(storageState.lifeBar)
end

-- #endregion

-- #region CUSTOM ID = 4

local CustomStorage = Storage.new()

function CustomStorage.GetState()
	return EcsState.CustomStorageState
end

function CustomStorage.AddComponentToEntity(entityId, customProperties)
	local storageState = CustomStorage.GetState()

	local componentId = Storage.AddComponentToEntity(storageState, entityId)

	-- Register Properties
	table.insert(storageState.customProperties, customProperties)

	return componentId
end

function CustomStorage.RemoveEntity(storageState, entityId)
	local componentId, lastCompId, lastHasComp = Storage.RemoveEntity(storageState, entityId)

	if not lastHasComp then
		table.remove(storageState.customProperties, componentId)
		return
	end

	-- Swap Values + Delete Last
	Gears.ReplaceWithLastElement(storageState.customProperties, componentId)
end

function CustomStorage.GetCustomProperties(entityId)
	local CustomStorageState = CustomStorage.GetState()
	local componentId = Storage.GetComponentId(CustomStorageState, entityId)
	return CustomStorageState.customProperties[componentId]
end

-- #endregion

-- #region MOB BEHAVIOR ID = 5

local MobBehaviorStorage = Storage.new()

function MobBehaviorStorage.GetState()
	return EcsState.MobBehaviorStorageState
end

function MobBehaviorStorage.AddComponentToEntity(entityId)
	local MobBehaviorStorageState = MobBehaviorStorage.GetState()

	local componentId = Storage.AddComponentToEntity(MobBehaviorStorageState, entityId)

	-- Register Properties
	table.insert(MobBehaviorStorageState.target, nil)

	return componentId
end

function MobBehaviorStorage.RemoveEntity(storageState, entityId)
	local componentId, lastCompId, lastHasComp = Storage.RemoveEntity(storageState, entityId)

	if not lastHasComp then
		table.remove(storageState.target, componentId)
		return
	end

	-- Swap Values + Delete Last
	Gears.ReplaceWithLastElement(storageState.target, componentId)
end

function MobBehaviorStorage.DisableEntity(entityId)
	-- TODO : Disable Behavior
end

-- #endregion

-- TODO : Component SKILLS ID = 6

-- TODO : Component AutoPickup

-- TODO : Archetypes = table key = bitmask, value = table of EntityId

local EcsStorages = {
	GameObjectStorage,
	UnitStorage,
	LifeBarStorage,
	CustomStorage,
	MobBehaviorStorage,
}

return EcsStorages
