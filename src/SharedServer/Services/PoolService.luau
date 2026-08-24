local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- local Gears = require(ReplicatedStorage.Shared.Gears)

-- Get Constants
local CONSTANTS = require(ServerScriptService.SharedServer.Constants)

local EnemyDefinitions = require(ReplicatedStorage.Shared.AuthoringData.EnemyDefinitions)
local Enemies = EnemyDefinitions.Enemies
local EnemiesPrefabs = EnemyDefinitions.EnemiesPrefabs

-- Get State
-- local RoduxStore = require(ReplicatedStorage.Shared.RoduxStore)
-- local Store = RoduxStore.Store
-- local StoreActions = RoduxStore.Actions
-- local Selectors = RoduxStore.Selectors

-- Get Mutable State
local MutState = require(ServerScriptService.SharedServer.MutableState)
local PoolServiceState = MutState.PoolServiceState

-- Knit
local Knit = require(ReplicatedStorage.Packages.Knit)
-- local Signal = require(ReplicatedStorage.Packages._Index["sleitnick_signal@1.5.0"].signal)

local EcsService -- , EnemyService

local PoolService = Knit.CreateService({
	Name = "PoolService",
	-- Client = {},
})

function PoolService:KnitInit()
	print("PoolService Init")
end

function PoolService:KnitStart()
	-- EnemyService = Knit.GetService("EnemyService")
	EcsService = Knit.GetService("EcsService")
end

export type Pool = {
	name: string,
	-- definitionId: number,
	-- prefab: Model,
	size: number,
	startIndex: number,
	endIndex: number,
	activeCount: number,
}

-- #region POOLS

-- spawnFunc
--- Create, Register and Spawn a Pool of GameObject
function PoolService.CreatePool(name, typeID, definitionID, prefab, onSpawn, size) -- enemyId
	-- local pool = EnemyDefinitions.EnemiesPool[enemyId]

	-- TODO : Prevent Creating the same Pool

	-- Create Pool
	-- Update Pool
	local startIndex = #PoolServiceState.entitiesPool
	-- local endIndex = startIndex + pool.size
	local endIndex = startIndex + size

	-- pool.startIndex = startIndex
	-- pool.endIndex = endIndex

	local pool = {
		name = name,
		size = size,
		startIndex = startIndex,
		endIndex = endIndex,
		activeCount = 0,
	}

	-- Register Pool
	table.insert(PoolServiceState.pools, pool)

	local poolIndex = #PoolServiceState.pools

	-- Create Missing Table
	local poolType = PoolServiceState.poolsLookups[typeID]

	if not poolType then
		PoolServiceState.poolsLookups[typeID] = {}
	end

	PoolServiceState.poolsLookups[typeID][definitionID] = poolIndex
	-- PoolServiceState.poolsLookups[enemyId] = poolIndex

	-- Spawn Pool
	warn("Spawn Pool : " .. pool.name .. ", StartIndex = " .. startIndex .. ", EndIndex = " .. endIndex)
	local GameObjectStorage = EcsService.GetStorage(CONSTANTS.EcsStorages.gameObject)

	for _ = 1, pool.size do
		-- local entityId = EnemyService.CEnemy(pool.definitionId, Vector3.zero)

		local entityId = EcsService.CreateEntity()
		table.insert(PoolServiceState.entitiesPool, entityId)

		-- local model = pool.prefab:Clone()
		local model = prefab:Clone()

		GameObjectStorage.AddComponentToEntity(entityId, model)

		-- OnSpawn Functions
		if onSpawn then
			local onSpawnCtx = {
				entityId = entityId,
				definitionId = definitionID,
				model = model,
			}

			for i = 1, #onSpawn do
				onSpawn[i](onSpawnCtx)
			end
		end

		-- Disable
		-- GameObjectStorage.OnDisable(entityId)
		PoolService.Disable(entityId)
	end

	return pool
end

--- return the pool of an Entity
function PoolService.GetPool(entityId)
	-- warn("Get Pool of EntityId = " .. entityId)

	local pools = PoolServiceState.pools

	for i = 1, #pools do
		local pool = pools[i]
		local threshold = pool.endIndex + 1

		if entityId <= threshold then
			return pool
		end
	end

	warn("EntityId = " .. entityId .. " No Pool found")
	return nil
end

--- Disable every GameObjects in a Pool
function PoolService.ClearPool(pool)
	for i = 1, pool.activeCount do
		local index = pool.startIndex + i
		local entityId = PoolServiceState.entitiesPool[index]
		PoolService.DisableEntity(entityId)
	end
end

--- Disable every GameObjects in Pools
function PoolService.ClearPools()
	for i = 1, #PoolServiceState.pools do
		local pool = PoolServiceState.pools[i]
		PoolService.ClearPool(pool)
	end
end

-- #endregion

-- #region ENTITIES

--- Spawn a GameObject from a Pool
function PoolService.EnableNextInPool(typeID, definitionID, parent, position)
	-- Validation
	local poolIndex = PoolServiceState.poolsLookups[typeID][definitionID]
	local pool = PoolServiceState.pools[poolIndex]

	local hasReachedMax = pool.activeCount >= pool.size -- - 1

	if hasReachedMax then
		warn(pool.name .. " Reached Limit of : " .. pool.size)
		return
	end

	pool.activeCount += 1

	-- Get State
	local index = pool.startIndex + pool.activeCount
	local entityId = PoolServiceState.entitiesPool[index]

	local GameObjectStorage = EcsService.GetStorage(CONSTANTS.EcsStorages.gameObject)
	local model = GameObjectStorage.GetGameObject(entityId)

	-- warn("Enable Object in Pool = " .. pool.name .. ", Entity ID = " .. entityId)

	-- Move
	model:PivotTo(CFrame.new(position))
	model.Parent = parent

	return entityId, model
end

--[[
function PoolService.EnableNextInPool(enemyId, position)
	-- Validation
	local poolIndex = PoolServiceState.poolsLookups[enemyId]
	local pool = PoolServiceState.pools[poolIndex]

	local hasReachedMax = pool.activeCount >= pool.size - 1

	if hasReachedMax then
		warn(pool.name .. " Reached Limit of : " .. pool.size)
		return
	end

	pool.activeCount += 1

	-- Get State
	local index = pool.startIndex + pool.activeCount
	local entityId = PoolServiceState.entitiesPool[index]

	local GameObjectStorage = EcsService.GetStorage(CONSTANTS.EcsStorages.gameObject)
	local character = GameObjectStorage.GetGameObject(entityId)

	-- warn("Enable Object in Pool = " .. pool.name .. ", Entity ID = " .. entityId)

	-- Per Type OnEnabled
	local componentsOnEnabled = EnemyService.enemiesOnEnabled[enemyId]
	for i = 1, #componentsOnEnabled do
		local onEnabled = componentsOnEnabled[i]

		if onEnabled then
			onEnabled(entityId, character, position)
		end
	end

	return entityId, character
end
]]

--- Disable a GameObject in Pool
function PoolService.Disable(entityId)
	-- Disable GameObject
	local GameObjectStorage = EcsService.GetStorage(CONSTANTS.EcsStorages.gameObject)
	local gameObject = GameObjectStorage.GetGameObject(entityId)

	gameObject:PivotTo(CFrame.new(CONSTANTS.DISABLED_POSITION))
	gameObject.Parent = CONSTANTS.DISABLED_ENTITIES_FOLDER
end

--- Disable + Update Pool
function PoolService.DisableEntity(entityId)
	if not EcsService.HasComponent(entityId, 1) then
		warn(entityId .. " Doesn't have Gameobject Component")
		return
	end

	local pool = PoolService.GetPool(entityId)

	if not pool then
		return
	end

	-- warn("Disable .. " .. pool.name)

	PoolService.Disable(entityId)

	-- If entityId not last Entity : Swap Last
	local lastIndex = pool.startIndex + pool.activeCount
	local lastEntityId = PoolServiceState.entitiesPool[lastIndex]
	local isLastEntity = entityId == lastEntityId

	-- Update Pool
	pool.activeCount -= 1

	if isLastEntity then
		return
	end

	-- Swap Entities
	local index = table.find(PoolServiceState.entitiesPool, entityId) -- TODO : replace with : entityId index array

	if not index then
		warn("EntityId = " .. entityId .. " Not Found in entitiesPool")
		return
	end

	PoolServiceState.entitiesPool[index] = lastEntityId
	PoolServiceState.entitiesPool[lastIndex] = entityId
end

-- TODO : prefab param
--- Call when a GameObject got OOB and Destroyed by Roblox
function PoolService.ResetGameObject(entityId, character)
	-- Replace GameObject
	character:Destroy()

	-- Create new model
	local enemy = EnemiesPrefabs[Enemies.Robot]:Clone() -- TODO : prefab:clone()
	enemy.Parent = CONSTANTS.WEAPON_HIT_FOLDER
	enemy.Name = enemy.Name .. entityId
	enemy:SetAttribute("EntityId", entityId)

	-- Replace old model
	local GameObjectStorage = EcsService.GetStorage(CONSTANTS.EcsStorages.gameObject)
	local GameObjectStorageState = GameObjectStorage.GetState()
	local gameObjectId = GameObjectStorage.GetComponentId(GameObjectStorageState, entityId)
	GameObjectStorageState.gameObjects[gameObjectId] = enemy

	-- Disable
	GameObjectStorage.OnDisable(entityId)
end

-- #endregion

return PoolService
