local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Get Constants
local CONSTANTS = require(ServerScriptService.SharedServer.Constants)
local EnemyConst = CONSTANTS.EnemyConst
local Enemies = EnemyConst.Enemies

-- Get Mutable State
local MutState = require(ServerScriptService.SharedServer.MutableState)
local PoolServiceState = MutState.PoolServiceState

-- Knit
local Knit = require(ReplicatedStorage.Packages.Knit)
-- local Signal = require(ReplicatedStorage.Packages._Index["sleitnick_signal@1.5.0"].signal)

local EcsService

local PoolService = Knit.CreateService({
	Name = "PoolService",
	-- Client = {},
})

function PoolService:KnitInit()
	print("PoolService Init")
end

function PoolService:KnitStart()
	EcsService = Knit.GetService("EcsService")
end

export type Pool = {
	name: string,
	size: number,
	startIndex: number,
	endIndex: number,
	activeCount: number,
}

-- #region POOLS

--- Create, Register and Spawn a Pool of GameObject
function PoolService.CreatePool(name, definitionID, prefab, onSpawn, size)
	-- TODO : Prevent Creating the same Pool

	-- Create Pool
	local startIndex = 1 + #PoolServiceState.entitiesPool
	local endIndex = startIndex + size - 1

	local pool: Pool = {
		name = name,
		size = size,
		startIndex = startIndex,
		endIndex = endIndex,
		activeCount = 0,
	}

	-- Register Pool
	table.insert(PoolServiceState.pools, pool)
	local poolIndex = #PoolServiceState.pools

	-- Spawn Pool
	-- warn("Spawn Pool : " .. pool.name .. ", Index = " .. poolIndex)
	-- warn("definitionID = " .. definitionID)
	-- warn("Size = " .. size .. ", StartIndex = " .. startIndex .. ", EndIndex = " .. endIndex)

	local GameObjectStorage = EcsService.GetStorage(CONSTANTS.EcsStorages.gameObject)

	for _ = 1, pool.size do
		PoolService.SpawnEntity(GameObjectStorage, definitionID, prefab, onSpawn)
	end

	return pool, poolIndex
end

function PoolService.SpawnEntity(GameObjectStorage, definitionID, prefab, onSpawn)
	local entityId = EcsService.CreateEntity()
	table.insert(PoolServiceState.entitiesPool, entityId)

	local model = prefab:Clone()

	GameObjectStorage.AddComponentToEntity(entityId, model)

	-- OnSpawn Functions
	if onSpawn then
		local spawnCtx = {
			entityId = entityId,
			definitionId = definitionID,
			model = model,
		}

		onSpawn(spawnCtx)
	end

	-- Disable
	PoolService.Disable(entityId)
end

--- Disable every GameObjects in a Pool
function PoolService.DisablePool(pool)
	for i = 0, pool.activeCount - 1 do
		local index = pool.startIndex + i
		local entityId = PoolServiceState.entitiesPool[index]
		PoolService.Disable(entityId)
	end

	pool.activeCount = 0
end

function PoolService.DisableAllPools()
	for i = 1, #PoolServiceState.pools do
		local pool = PoolServiceState.pools[i]
		PoolService.DisablePool(pool)
	end
end

-- #endregion

-- #region ENTITIES

--- return the pool of entity index
function PoolService.GetPool(index)
	-- warn("Get Pool of EntityId = " .. entityId)

	-- Check all Existing Pools
	local pools = PoolServiceState.pools

	for i = 1, #pools do
		local pool = pools[i]

		if index <= pool.endIndex then
			return pool
		end
	end

	warn("Index = " .. index .. " No Pool found")
	return nil
end

--- Spawn a GameObject from a Pool
function PoolService.EnableNextInPool(poolIndex, parent, position)
	-- Validation
	local pool = PoolServiceState.pools[poolIndex]
	assert(pool, "Enable Next in Pool : Pool Not Found")

	local hasReachedMax = pool.activeCount >= pool.size

	-- FIXME : param
	local loop = true

	if hasReachedMax and not loop then
		warn(pool.name .. " Reached Limit of : " .. pool.size)
		return
	end

	-- Get State
	local nextIndex = pool.startIndex + pool.activeCount

	if hasReachedMax and loop then
		nextIndex = pool.startIndex
	end

	local entityId = PoolServiceState.entitiesPool[nextIndex]

	local GameObjectStorage = EcsService.GetStorage(CONSTANTS.EcsStorages.gameObject)
	local model = GameObjectStorage.GetGameObject(entityId)

	-- warn("ENABLE in " .. pool.name .. ", At Index = " .. nextIndex .. ", Entity ID = " .. entityId)

	-- Move
	model:PivotTo(CFrame.new(position))
	model.Parent = parent

	if not hasReachedMax then
		pool.activeCount += 1
	end

	return entityId, model
end

--- Disable a GameObject in Pool
function PoolService.Disable(entityId)
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

	local index = table.find(PoolServiceState.entitiesPool, entityId) -- TODO : replace with : entityId index array

	if not index then
		warn("EntityId = " .. entityId .. " Not Found in entitiesPool")
		return
	end

	local pool = PoolService.GetPool(index)

	if not pool or pool.activeCount == 0 then
		return
	end

	PoolService.Disable(entityId)
	pool.activeCount -= 1

	-- If entityId not last Entity : Swap Last
	local lastIndex = pool.startIndex + pool.activeCount
	local lastEntityId = PoolServiceState.entitiesPool[lastIndex]
	local isLastEntity = entityId == lastEntityId

	-- warn("DISABLE in " .. pool.name)
	-- warn(", EntityID = " .. entityId .. ", Index = " .. index .. ", lastIndex = " .. lastIndex)

	if isLastEntity then
		return
	end

	-- Swap Entities
	PoolServiceState.entitiesPool[index] = lastEntityId
	PoolServiceState.entitiesPool[lastIndex] = entityId
end

-- TODO : Modular = prefab param
--- Call when a GameObject got OOB and Destroyed by Roblox
function PoolService.ResetGameObject(entityId, character)
	-- Replace GameObject
	character:Destroy()

	-- Create new model
	local enemy = EnemyConst.EnemiesPrefabs[Enemies.Robot]:Clone() -- TODO : prefab:clone()
	enemy.Parent = CONSTANTS.WEAPON_HIT_FOLDER
	enemy.Name = enemy.Name .. entityId
	enemy:SetAttribute("EntityId", entityId)

	-- Replace old model
	local GameObjectStorage = EcsService.GetStorage(CONSTANTS.EcsStorages.gameObject)
	local GameObjectStorageState = GameObjectStorage.GetState()
	local gameObjectId = GameObjectStorage.GetComponentId(GameObjectStorageState, entityId)
	GameObjectStorageState.gameObjects[gameObjectId] = enemy

	-- Disable
	PoolService.Disable(entityId)
end

-- #endregion

return PoolService
