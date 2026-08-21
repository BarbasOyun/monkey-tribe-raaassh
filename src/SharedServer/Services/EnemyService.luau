local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Gears = require(ReplicatedStorage.Shared.Gears)

-- Get Constants
local CONSTANTS = require(ServerScriptService.SharedServer.Constants)
local EnemyConst = CONSTANTS.EnemyConst

local EnemyDefinitions = require(ReplicatedStorage.Shared.AuthoringData.EnemyDefinitions)
local Enemies = EnemyDefinitions.Enemies
local EnemiesStats = EnemyDefinitions.EnemiesStats
local EnemiesPrefabs = EnemyDefinitions.EnemiesPrefabs

-- Get State
local RoduxStore = require(ReplicatedStorage.Shared.RoduxStore)
local Store = RoduxStore.Store
local StoreActions = RoduxStore.Actions
local Selectors = RoduxStore.Selectors

-- Get Mutable State
local MutState = require(ServerScriptService.SharedServer.MutableState)
local EnemyServiceState = MutState.EnemyServiceState
local EcsState = MutState.EcsState
local PlayerServiceState = MutState.PlayerServiceState

-- Get Knit
local Knit = require(ReplicatedStorage.Packages.Knit)
-- local Signal = require(ReplicatedStorage.Packages._Index["sleitnick_signal@1.5.0"].signal)

local PlayerService, LevelService, RpgService, EcsService, ItemService

local EnemyService = Knit.CreateService({
	Name = "EnemyService",
	-- Client = {},
})

-- TODO : EnemyContext struct : entityId, character, position

-- #region ENEMIES LOGIC

local defaultOnDeath = function(entityId, character, player)
	-- warn("Default OnDeath")

	Gears.Dismember(character)
	-- local entityId = character:GetAttribute("EntityId")

	-- Update Dispawn Cooldown
	local UnitStorage = EcsState.storages[CONSTANTS.EcsStorages.unit]
	local UnitStorageState = EcsState.UnitStorageState
	local unitId = UnitStorage.GetComponentId(UnitStorageState, entityId)

	UnitStorageState.dispawnCd[unitId] = 1
end

local defaultOnDisabled = function(entityId)
	-- warn("Default On Disabled")
	EnemyService.DisableEntity(entityId)
end

-- #endregion

-- #region ON SPAWN SYSTEMS

local gameObjectSetup = function(entityId, definitionId)
	-- Spawn Disabled Enemy
	local enemy = EnemiesPrefabs[definitionId]:Clone()
	enemy.Parent = CONSTANTS.WEAPON_HIT_FOLDER
	enemy.Name = enemy.Name .. entityId

	local GameObjectStorage = EcsState.storages[CONSTANTS.EcsStorages.gameObject]
	GameObjectStorage.AddComponentToEntity(entityId, enemy)
	GameObjectStorage.OnDisable(entityId)
end

local unitSetup = function(entityId, definitionId)
	-- Add Unit Component
	local enemyDefinition = EnemiesStats[definitionId]
	local UnitStorage = EcsState.storages[CONSTANTS.EcsStorages.unit]

	local unitId = UnitStorage.AddComponentToEntity(entityId, Enemies.Dummy, enemyDefinition.MaxLife)

	local UnitStorageState = UnitStorage.GetState()

	-- Setup OnDeath
	local onDeath = EnemyService.enemiesOnDeath[definitionId]
	UnitStorageState.deathEvent[unitId]:Connect(onDeath)

	-- Setup OnDisable
	local onDisabled = EnemyService.enemiesOnDisabled[definitionId]
	UnitStorageState.onDispawn[unitId]:Connect(function(entityId)
		onDisabled(entityId)
	end)
end

local lifeBarSetup = function(entityId, definitionId)
	local LifeBarStorage = EcsState.storages[CONSTANTS.EcsStorages.lifeBar]
	LifeBarStorage.AddComponentToEntity(entityId, EcsService)
end

local mobBehaviorSetup = function(entityId, definitionId)
	local MobBehaviorStorage = EcsState.storages[CONSTANTS.EcsStorages.mobBehavior]
	MobBehaviorStorage.AddComponentToEntity(entityId)
end

local respawnSetup = function(entityId, definitionId)
	-- Add Custom Component (Storing respawnPos)
	local CustomStorage = EcsState.storages[CONSTANTS.EcsStorages.custom]
	local customProperties = {
		respawnPos = Vector3.zero,
		-- respawnPrefab = EnemiesPrefabs[definitionId],
	}

	CustomStorage.AddComponentToEntity(entityId, customProperties)

	-- TODO : Unit OnDeath + OnDispawn
	-- Connect to Unit OnDeath
	-- local UnitStorage = EcsState.storages[CONSTANTS.EcsStorages.unit]
	-- local UnitStorageState = UnitStorage.GetState()
	-- local unitId = UnitStorage.GetComponentId(UnitStorageState, entityId)

	-- UnitStorageState.deathEvent[unitId]:Connect(function(character, _player)
	-- 	task.wait(1)
	-- 	-- Get Back respawnPos
	-- 	local id = character:GetAttribute("EntityId")
	-- 	local respawnPos = CustomStorage.GetCustomProperties(id).respawnPos

	-- 	EnemyService.SpawnArchetypeEnemy(Enemies.Dummy, respawnPos) -- Respawn
	-- end)
end

-- #endregion

-- #region ON ENABLED SYSTEMS

local gameObjectOnEnabled = function(entityId, character, position)
	-- Move
	character:PivotTo(CFrame.new(position))
	character.Parent = CONSTANTS.WEAPON_HIT_FOLDER

	-- character:SetAttribute("Version", entityVersion)
	Gears.AnchorModel(character, false)
end

local unitOnEnabled = function(entityId, character, position)
	local UnitStorage = EcsState.storages[CONSTANTS.EcsStorages.unit]
	local UnitStorageState = UnitStorage.GetState()

	-- Movement Speed
	local movementSpeed = EnemyServiceState.currentRobotStats.MovementSpeed
	local humanoid = character.Humanoid :: Humanoid
	humanoid.WalkSpeed = movementSpeed

	-- Life
	local maxLife = EnemiesStats[Enemies.Robot].MaxLife
	UnitStorageState.life[entityId] = maxLife
end

local lifeBarOnEnabled = function(entityId, character, position)
	local lifeBar = EnemyService.TryToFindLifeBar(character)
	local billboardGui = lifeBar.Parent

	Gears.UpdateBar(lifeBar, 1)

	-- Force Re render of lifebar
	billboardGui.Enabled = true
end

local respawnOnEnabled = function(entityId, character, position)
	local CustomStorage = EcsState.storages[CONSTANTS.EcsStorages.custom]
	CustomStorage.GetCustomProperties(entityId).respawnPos = position
end

-- #endregion

-- #region DUMMY

local dummyOnDeath = defaultOnDeath

local dummyOnDisabled = function(entityId)
	-- Respawn -> Get Back respawnPos
	local CustomStorage = EcsState.storages[CONSTANTS.EcsStorages.custom]
	local respawnPos = CustomStorage.GetCustomProperties(entityId).respawnPos
	EnemyService.EnableNextInPool(Enemies.Dummy, respawnPos)

	defaultOnDisabled(entityId)
end

local dummyOnSpawn = {
	gameObjectSetup,
	unitSetup,
	lifeBarSetup,
	respawnSetup,
}

local dummyOnEnabled = {
	gameObjectOnEnabled,
	unitOnEnabled,
	lifeBarOnEnabled,
	respawnOnEnabled,
}

-- #endregion

-- #region ROBOT

local robotOnDeath = defaultOnDeath

local robotOnSpawn = {
	gameObjectSetup,
	unitSetup,
	lifeBarSetup,
	mobBehaviorSetup,
	-- respawnSetup,
}

local robotOnEnabled = {
	gameObjectOnEnabled,
	unitOnEnabled,
	lifeBarOnEnabled,
}

-- #endregion

-- #region ENEMIES REGISTRIES
-- TODO : Build Registries

EnemyService.enemiesOnSpawn = {
	dummyOnSpawn,
	robotOnSpawn,
}

EnemyService.enemiesOnDeath = {
	dummyOnDeath,
	robotOnDeath,
}

EnemyService.enemiesOnEnabled = {
	dummyOnEnabled,
	robotOnEnabled,
}

EnemyService.enemiesOnDisabled = {
	dummyOnDisabled,
	defaultOnDisabled,
}

-- #endregion

-- #region SPAWN ENEMY

-- Custom Spawn Enemy
--- Spawn New Model + Create Enemy
function EnemyService.SpawnEnemy(enemyId, position)
	-- Spawn Model
	local character = EnemiesPrefabs[enemyId]:Clone()
	character:PivotTo(CFrame.new(position))
	character.Name = "Dummy3"

	EnemyService.CreateEnemy(character, enemyId)
end

--- Create Enemy for already spawned Model
function EnemyService.CreateEnemy(character, enemyId)
	local entityId = EcsService.CreateEntity()

	-- warn("Create enemy : " .. character.Name .. ", TypeId = " .. enemyId .. ", EntityId = " .. entityId)

	character.Parent = CONSTANTS.WEAPON_HIT_FOLDER
	local enemyDefinition = EnemiesStats[enemyId]

	-- Add Components : Gameobject, Unit
	-- TODO : Fuse with Archetype Setup
	local GameObjectStorage = EcsState.storages[CONSTANTS.EcsStorages.gameObject]
	local unitStorage = EcsState.storages[CONSTANTS.EcsStorages.unit]

	GameObjectStorage.AddComponentToEntity(entityId, character)
	unitStorage.AddComponentToEntity(entityId, enemyId, enemyDefinition.MaxLife)

	-- Per Enemy type setup
	EnemyService.enemiesOnSpawn[enemyId](character, entityId)
end

--- Spawn an enemy using Its OnSpawn
function EnemyService.CEnemy(enemyId, position)
	local entityId = EcsService.CreateEntity()

	-- warn("Create enemy : " .. character.Name .. ", TypeId = " .. enemyId .. ", EntityId = " .. entityId)

	-- Per Enemy type setup
	local OnSpawnFunctions = EnemyService.enemiesOnSpawn[enemyId]

	for i = 1, #OnSpawnFunctions do
		OnSpawnFunctions[i](entityId, enemyId)
	end

	-- Move GameObject
	local GameObjectStorage = EcsState.storages[CONSTANTS.EcsStorages.gameObject]
	local char = GameObjectStorage.GetGameObject(entityId)
	char:PivotTo(CFrame.new(position))

	return entityId
end

-- #endregion

-- #region POOLS
-- TODO : PoolService

export type Pool = {
	name: string,
	definitionId: number,
	size: number,
	startIndex: number,
	endIndex: number,
	activeCount: number,
}

--- Register and Create a Pool of Enemy
function EnemyService.CreatePool(enemyId)
	local pool = EnemyDefinitions.EnemiesPool[enemyId]

	-- TODO : Prevent Creating the same Pool

	local startIndex = #EnemyServiceState.entitiesPool
	local endIndex = startIndex + pool.size

	-- Update Pool
	pool.startIndex = startIndex
	pool.endIndex = endIndex

	-- Register Pool
	table.insert(EnemyServiceState.pools, pool)
	EnemyServiceState.poolsLookups[enemyId] = #EnemyServiceState.pools

	-- Create Entities
	warn("Create Pool : " .. pool.name .. ", StartIndex = " .. startIndex .. ", EndIndex = " .. endIndex)
	local GameObjectStorage = EcsService.GetStorage(CONSTANTS.EcsStorages.gameObject)

	for _ = 1, pool.size do
		local entityId = EnemyService.CEnemy(pool.definitionId, Vector3.zero)
		table.insert(EnemyServiceState.entitiesPool, entityId)

		-- Disable
		GameObjectStorage.OnDisable(entityId)
	end
end

--- return the pool of an Entity
function EnemyService.GetPool(entityId)
	-- warn("Get Pool of EntityId = " .. entityId)

	local pools = EnemyServiceState.pools

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

function EnemyService.EnableNextInPool(enemyId, position)
	-- Validation
	local poolIndex = EnemyServiceState.poolsLookups[enemyId]
	local pool = EnemyServiceState.pools[poolIndex]

	local hasReachedMax = pool.activeCount >= pool.size - 1

	if hasReachedMax then
		warn(pool.name .. " Reached Limit of : " .. pool.size)
		return
	end

	pool.activeCount += 1

	-- Get State
	local index = pool.startIndex + pool.activeCount
	local entityId = EnemyServiceState.entitiesPool[index]

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

--- Disable a GameObject in Pool
function EnemyService.DisableEntity(entityId)
	if not EcsService.HasComponent(entityId, 1) then
		warn(entityId .. " Doesn't have Gameobject Component")
		return
	end

	local pool = EnemyService.GetPool(entityId)

	if not pool then
		return
	end

	-- warn("Disable .. " .. pool.name)

	local lastIndex = pool.startIndex + pool.activeCount
	local lastEntityId = EnemyServiceState.entitiesPool[lastIndex]

	-- Update Pool
	pool.activeCount -= 1

	-- Update Components
	-- TODO : Per Archetype's Component

	local GameObjectStorage = EcsService.GetStorage(CONSTANTS.EcsStorages.gameObject)
	GameObjectStorage.OnDisable(entityId)

	-- If entityId not last Entity : Swap Last
	if entityId == lastEntityId then
		return
	end

	-- Swap Entities
	local index = table.find(EnemyServiceState.entitiesPool, entityId) -- TODO : replace with : entityId index array

	if not index then
		warn("EntityId = " .. entityId .. " Not Found in entitiesPool")
		return
	end

	EnemyServiceState.entitiesPool[index] = lastEntityId
	EnemyServiceState.entitiesPool[lastIndex] = entityId
end

--- Disable every GameObjects in a Pool
function EnemyService.ClearPool(pool)
	for i = 1, pool.activeCount do
		local index = pool.startIndex + i
		local entityId = EnemyServiceState.entitiesPool[index]
		EnemyService.DisableEntity(entityId)
	end
end

--- Disable every GameObjects in Pools
function EnemyService.ClearEnemies()
	for i = 1, #EnemyServiceState.pools do
		local pool = EnemyServiceState.pools[i]
		EnemyService.ClearPool(pool)
	end
end

-- TODO : DefinitionId param
--- Call when a GameObject got OOB and Destroyed by Roblox
function EnemyService.ResetGameObject(entityId, character)
	-- Replace GameObject
	character:Destroy()

	-- Create new model
	local enemy = EnemiesPrefabs[Enemies.Robot]:Clone() -- TODO : Per DefinitionId
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

-- #region UTILS

--- Keep the Input Position in the Level Range (Prevent OOB)
function EnemyService.GetSpawnPosition(position)
	local radius = Gears.RandomRange(EnemyConst.SPAWN_RADIUS, EnemyConst.SPAWN_RADIUS_RANGE)
	local progress = math.random(0, CONSTANTS.MAX_RADIANT)
	local circlePos = Gears.CirclePos(radius, progress)

	local pos = position + Vector3.new(circlePos.X, 0, circlePos.Y) -- Circle around Pos
	local usePos = LevelService.KeepPointInLimits(pos)

	return usePos
end

--- return player
function EnemyService.GetNearestPlayer(state, enemy)
	local minDistance = math.huge
	local p = nil

	for _, player in pairs(Players:GetPlayers()) do
		-- Avoid non ready player
		local playerState = Selectors.PlayerState(state, player.UserId)
		local isPlayerReady = playerState and playerState.state == CONSTANTS.PLAYER_STATES.playing

		if not isPlayerReady then
			continue
		end

		local distance = PlayerServiceState.playersDetections[player.UserId][enemy]
		-- warn(enemy.Name .. " Distance With " .. player.Name .. " = " .. distance)
		local isCloser = distance and distance < minDistance

		if isCloser then
			minDistance = distance
			p = player
		end
	end

	return p, minDistance
end

function EnemyService.TryToFindLifeBar(character)
	local lBar = character:FindFirstChild("LifeBar")
	local lifeBar = nil

	if lBar then
		lifeBar = lBar.LifeBar
	end

	return lifeBar
end

-- #endregion

-- #region DAMAGE + DEATH
-- TODO : Move to RpgService

function EnemyService.DamageEnemy(player, entityId, humanoid, damage)
	-- Get State
	local unitStorage = EcsState.storages[CONSTANTS.EcsStorages.unit]
	local unitStorageState = unitStorage.GetState()
	local unitId = unitStorage.GetComponentId(unitStorageState, entityId)

	-- warn("Damage Enemy : Entity ID = " .. entityId .. ", Unit ID = " .. unitId)

	local currentLife = unitStorageState.life[unitId]
	if currentLife <= 0 or damage <= 0 then
		return
	end

	-- Damage Unit
	unitStorageState.life[unitId] -= damage
	local damagedLife = unitStorageState.life[unitId]
	-- print(" Dealt " .. damage .. " damage to " .. humanoid.Parent.Name .. " New life : " .. life)

	-- Trigger Life Changed Event
	local definitionId = unitStorageState.definitionId[unitId]
	local definition = EnemiesStats[definitionId]

	local percent = damagedLife / definition.MaxLife
	unitStorageState.lifeChanged[unitId]:Fire(percent)

	-- Handle Death
	if damagedLife <= 0 then
		local overKillDamage = math.abs(damagedLife)
		EnemyService.KillEnemy(player, entityId, humanoid, overKillDamage)
	end
end

function EnemyService.KillEnemy(player, entityId, humanoid, overKillDamage)
	EnemyServiceState.enemiesDeathCount += 1

	-- TODO : Check if userId is nil -> attribute the kill to nearest Player
	-- Rewards
	ItemService.GenerateLoot(player, humanoid)

	-- UnitState
	local unitStorage = EcsState.storages[CONSTANTS.EcsStorages.unit]
	local unitStorageState = unitStorage.GetState()

	local unitId = unitStorage.GetComponentId(unitStorageState, entityId)
	local deathEvent = unitStorageState.deathEvent[unitId]

	-- Trigger Death Event
	if deathEvent then
		-- warn("Trigger Death Event : EntityID = " .. entityId .. " UnitID = " .. unitId)
		deathEvent:Fire(entityId, humanoid.Parent, player) -- overKillDamage
	end
end

-- TODO : AttackValidation + AttackCtx

--- Unit + MobBehavior System
function EnemyService.EnemyAttack(entityId, enemy, player)
	local isValid = player.Character.Humanoid.Health > 0

	if not isValid then
		return
	end

	-- Stop
	enemy.Humanoid:MoveTo(enemy.HumanoidRootPart.Position)

	-- Check CD
	local robotStats = EnemiesStats[Enemies.Robot]

	local UnitStorage = EcsState.storages[CONSTANTS.EcsStorages.unit]
	local UnitStorageState = UnitStorage.GetState()
	local unitId = UnitStorage.GetComponentId(UnitStorageState, entityId)

	local isReady = UnitStorageState.attackCd[unitId] >= robotStats.AttackSpeed

	if not isReady then
		return
	end

	-- warn(entityId .. " Robot Attack")
	UnitStorageState.attackCd[unitId] = 0
	RpgService.DamagePlayer(player, robotStats.Damage)
end

-- #endregion

-- #region SCALING

--- Increment Enemies Stats
function EnemyService.LevelUpEnemies()
	local state = Store:getState()
	local globalEnemyLvl = state.gameState.globalEnemyLvl + 1

	-- Increment Global Stats
	local currentRobotStats = EnemyServiceState.currentRobotStats

	-- Offense
	currentRobotStats.Damage *= EnemyDefinitions.DAMAGE_MULTIPLIER

	-- Defense
	currentRobotStats.MaxLife *= EnemyDefinitions.LIFE_MULTIPLIER

	-- Utils
	local movementSpeed = currentRobotStats.MovementSpeed
	local newMs = movementSpeed + EnemyDefinitions.MOVEMENT_SPEED_INCREMENT
	currentRobotStats.MovementSpeed = math.clamp(newMs, 0, EnemyDefinitions.MAX_MOVEMENT_SPEED)

	-- warn("Enemy Lvl+ : Damage = " .. currentRobotStats.Damage .. " MaxLife = " .. currentRobotStats.MaxLife)

	-- MAYBE : Mutate Existing Entities

	-- Level Breakpoints (Every X Levels)
	local isBreakPointReached = globalEnemyLvl % EnemyConst.STREAM_SPAWN_LVL_BREAKPOINT == 0

	if isBreakPointReached then
		EnemyService.IncrementStreamSpawn()
	end

	-- Update State
	local patch = { globalEnemyLvl = globalEnemyLvl }
	Store:dispatch(StoreActions.PatchGameState(patch))

	PlayerService.Client.PatchGameState:FireAll(patch)
end

function EnemyService.IncrementStreamSpawn()
	EnemyServiceState.streamSpawnNbr += EnemyConst.STREAM_SPAWN_INCREMENT
	EnemyServiceState.streamSpawnNbrRange += 1

	local newCd = EnemyServiceState.streamSpawnDeltaTime - 0.1
	EnemyServiceState.streamSpawnDeltaTime = math.max(newCd, EnemyConst.STREAM_SPAWN_MIN_CD)

	local newCdRange = EnemyServiceState.streamSpawnDeltaTimeRange - 0.1
	EnemyServiceState.streamSpawnDeltaTimeRange = math.max(newCdRange, EnemyConst.STREAM_SPAWN_MIN_CD)
end

-- #endregion

-- #region UPDATE

-- TODO : Component Param
--- Unit Update System
function EnemyService.UnitUpdate(dt)
	local UnitStorageState = EcsState.UnitStorageState

	for i = 1, #UnitStorageState.entities do
		local entityId = UnitStorageState.entities[i]

		-- Attack CD
		-- TODO : Attack Speed = Attack / sec
		local isReady = UnitStorageState.attackCd[i] >= EnemiesStats[Enemies.Robot].AttackSpeed

		if not isReady then
			UnitStorageState.attackCd[i] += dt
		end

		-- Dispawn CD
		if UnitStorageState.dispawnCd[i] <= 0 then
			continue
		end

		UnitStorageState.dispawnCd[i] -= dt

		if UnitStorageState.dispawnCd[i] <= 0 then
			-- warn("EntityId = " .. entityId .. " -> Dispawn Event")
			UnitStorageState.onDispawn[i]:Fire(entityId)
		end
	end
end

function EnemyService.StartUnitUpdate()
	PlayerService.StateUpdate:Connect(function(state, dt)
		EnemyService.UnitUpdate(dt)
	end)
end

--- MobBehavior System : Seek & Attack Players
--- Using Components : MobBehavior, GameObject, Unit
function EnemyService.MobBehavior(state, entityId, character, robotStats)
	-- Get Nearest Player
	local targetPlayer, distance = EnemyService.GetNearestPlayer(state, character)
	local humanoid = character.Humanoid

	-- Check GameObject
	local root = character:FindFirstChild("HumanoidRootPart")

	if not root then
		-- warn("Entity " .. entityId .. " " .. character.Name .. " No HumanoidRootPart")
		EnemyService.ResetGameObject(entityId, character)
		return
	end

	-- Stop if no target found
	if not targetPlayer then
		-- TODO : Respawn to Random Player
		humanoid:MoveTo(character.HumanoidRootPart.Position)
		return
	end

	-- Target found
	local isWithinRange = distance <= robotStats.Range

	-- Attack
	if isWithinRange then
		EnemyService.EnemyAttack(entityId, character, targetPlayer)
		return
	end

	-- Move to player
	local playerPos = targetPlayer.character:GetPivot().Position
	humanoid:MoveTo(playerPos)
end

--- Start MobBehavior in Throttled update
function EnemyService.StartMobBehavior()
	PlayerService.StateUpdate:Connect(function(state, dt)
		-- Mob Movements
		EcsState.MobBehaviorStorageState.timer += dt

		local isDeltaReached = EcsState.MobBehaviorStorageState.timer >= EcsState.MobBehaviorStorageState.timerDelta

		if not isDeltaReached then
			return
		end

		-- Reset Timer
		EcsState.MobBehaviorStorageState.timer = 0

		local GameObjectStorage = EcsState.storages[CONSTANTS.EcsStorages.gameObject]
		-- TODO : UnitStorage get DefinitionId
		local robotStats = EnemiesStats[Enemies.Robot]

		-- TODO : Archetype loops
		for _, entityId in pairs(EcsState.MobBehaviorStorageState.entities) do
			local enemyCharacter = GameObjectStorage.GetGameObject(entityId)
			local isDisabled = enemyCharacter.Parent == CONSTANTS.DISABLED_ENTITIES_FOLDER

			if isDisabled then
				continue
			end

			EnemyService.MobBehavior(state, entityId, enemyCharacter, robotStats)
		end
	end)
end

--- Spawn Mob Enemies around player
function EnemyService.StreamSpawn(state, player)
	-- Check if Player is Valid
	local playerState = Selectors.PlayerState(state, player.UserId)
	-- MAYBE : isPickingAugment

	local isValid = playerState and not playerState.isDead and player.Character

	if not isValid then
		return
	end

	local playerPos = player.Character:GetPivot().Position
	local enemyNbr = Gears.RandomRange(EnemyServiceState.streamSpawnNbr, EnemyServiceState.streamSpawnNbrRange)

	-- Spawn X Mobs
	for _ = 1, enemyNbr do
		local spawnPos = EnemyService.GetSpawnPosition(playerPos)
		EnemyService.EnableNextInPool(Enemies.Robot, spawnPos)
	end
end

--- Set a Random CD on StreamSpawn
function EnemyService.RollStreamSpawnDelta()
	local minTime = EnemyServiceState.streamSpawnDeltaTime
	local maxTime = minTime + EnemyServiceState.streamSpawnDeltaTimeRange

	local spawnDelta = math.random(minTime, maxTime)

	EnemyServiceState.streamSpawnDelta = spawnDelta
end

function EnemyService.StartStreamSpawn()
	task.wait(EnemyConst.STREAM_SPAWN_INITIAL_TIME)
	EnemyService.RollStreamSpawnDelta()

	PlayerService.StateUpdate:Connect(function(state, dt)
		EnemyServiceState.streamSpawnTimer += dt

		-- Spawn
		local isDeltaTimeReached = EnemyServiceState.streamSpawnTimer >= EnemyServiceState.streamSpawnDelta

		if isDeltaTimeReached then
			-- Reset Timers
			EnemyServiceState.streamSpawnTimer = 0
			EnemyService.RollStreamSpawnDelta()

			for _, player in ipairs(Players:GetPlayers()) do
				EnemyService.StreamSpawn(state, player)
			end
		end
	end)
end

--- Spawn Big waves of Enemies on Each Player
function EnemyService.SwarmSpawn()
	for _, player in ipairs(Players:GetPlayers()) do
		local enemyNbr = Gears.RandomRange(EnemyConst.SWARM_NBR, EnemyConst.SWARM_NBR_RANGE)

		local playerPos = player.Character:GetPivot().Position
		local spawnPos = EnemyService.GetSpawnPosition(playerPos)

		for _ = 1, enemyNbr, 1 do
			EnemyService.EnableNextInPool(Enemies.Robot, spawnPos)
		end
	end
end

function EnemyService.StartSwarmSpawn()
	local swarmWaves = EnemyServiceState.swarmWaves
	swarmWaves = EnemyConst.SWARM_WAVES

	local handle
	handle = PlayerService.StateUpdate:Connect(function(state, dt)
		EnemyServiceState.swarmSpawnTimer += dt

		-- Spawn
		if EnemyServiceState.swarmSpawnTimer >= 1 then
			-- Reset Timers
			EnemyServiceState.swarmSpawnTimer = 0
			EnemyService.RollStreamSpawnDelta()

			swarmWaves -= 1
			EnemyService.SwarmSpawn()

			-- Stop Swarm
			if swarmWaves <= 0 then
				handle:Disconnect()
			end
		end
	end)
end

-- #endregion

-- SERVICE

function EnemyService:KnitInit()
	print("EnemyService Init")
end

function EnemyService:KnitStart()
	PlayerService = Knit.GetService("PlayerService")
	LevelService = Knit.GetService("LevelService")
	RpgService = Knit.GetService("RpgService")
	EcsService = Knit.GetService("EcsService")
	ItemService = Knit.GetService("ItemService")
end

return EnemyService
