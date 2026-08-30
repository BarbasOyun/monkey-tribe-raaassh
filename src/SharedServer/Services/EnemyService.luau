-- Enemy System :
-- 2 Types :
-- ModelEnemy = Model made of Parts + Humanoid
-- MeshEnemy = Single Mesh

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Gears = require(ReplicatedStorage.Shared.Gears)

-- Get Constants
local CONSTANTS = require(ServerScriptService.SharedServer.Constants)
local EnemyConst = CONSTANTS.EnemyConst
local Enemies = EnemyConst.Enemies
local EnemiesStats = EnemyConst.EnemiesStats

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

-- Knit
local Knit = require(ReplicatedStorage.Packages.Knit)
-- local Signal = require(ReplicatedStorage.Packages._Index["sleitnick_signal@1.5.0"].signal)

local PoolService, PlayerService, LevelService, RpgService, EcsService, ItemService

local EnemyService = Knit.CreateService({
	Name = "EnemyService",
	-- Client = {},
})

function EnemyService:KnitInit()
	print("EnemyService Init")
end

function EnemyService:KnitStart()
	PoolService = Knit.GetService("PoolService")
	PlayerService = Knit.GetService("PlayerService")
	LevelService = Knit.GetService("LevelService")
	RpgService = Knit.GetService("RpgService")
	EcsService = Knit.GetService("EcsService")
	ItemService = Knit.GetService("ItemService")
end

--- Update that should always be on
function EnemyService.StartEnemyUpdate()
	PlayerService.StateUpdate:Connect(function(state, dt)
		EnemyService.UnitUpdate(dt)
	end)

	PlayerService.SecondPassed:Connect(function(state)
		EnemyService.SwarmUpdate(state)
	end)
end

-- TODO : Rename EnemyCtx
type SpawnCtx = {
	entityId: number,
	definitionId: number,
	model: Model,
	-- Pos?
}

-- #region COMPONENTS SYSTEMS
-- Component systems called on Unit lifetime Events : Spawn, Enable, Death, Disable

-- GameObject
function EnemyService.OnAddGameObject(spawnCtx)
	local entityId = spawnCtx.entityId
	local character = spawnCtx.model

	local GameObjectStorage = EcsState.storages[CONSTANTS.EcsStorages.gameObject]
	GameObjectStorage.AddComponentToEntity(entityId, character)
end

function EnemyService.EnableGameObject(spawnCtx)
	local character = spawnCtx.model

	PlayerService.DetectEnemy(character)

	-- character:SetAttribute("Version", entityVersion)
	character.HumanoidRootPart.Anchored = false
end

-- Unit
function EnemyService.OnAddUnit(spawnCtx)
	local entityId = spawnCtx.entityId
	local definitionId = spawnCtx.definitionId
	local enemyDefinition = EnemiesStats[definitionId]

	-- Add Unit Component
	local UnitStorage = EcsState.storages[CONSTANTS.EcsStorages.unit]
	local UnitStorageState = UnitStorage.GetState()

	local unitId = UnitStorage.AddComponentToEntity(entityId, Enemies.Dummy, enemyDefinition.MaxLife)

	-- Setup OnDeath
	local onDeath = EnemyService.enemiesOnDeath[definitionId]
	UnitStorageState.deathEvent[unitId]:Connect(onDeath)

	-- Setup OnDisabled
	local onDisabled = EnemyService.enemiesOnDisabled[definitionId]
	UnitStorageState.onDispawn[unitId]:Connect(onDisabled)
end

function EnemyService.EnableUnit(spawnCtx)
	local entityId = spawnCtx.entityId
	-- local character = spawnCtx.model

	local UnitStorage = EcsState.storages[CONSTANTS.EcsStorages.unit]
	local UnitStorageState = UnitStorage.GetState()
	local unitID = UnitStorage.GetComponentId(UnitStorageState, entityId)

	-- Life
	local maxLife = EnemyServiceState.currentRobotStats.MaxLife
	UnitStorageState.life[unitID] = maxLife

	-- TODO : Move to other component
	-- Movement Speed
	-- local movementSpeed = EnemyServiceState.currentRobotStats.MovementSpeed
	-- local humanoid = character.Humanoid :: Humanoid
	-- humanoid.WalkSpeed = movementSpeed
end

function EnemyService.UnitDeath(spawnCtx)
	local entityId = spawnCtx.entityId

	-- Setup Dispawn
	local UnitStorage = EcsState.storages[CONSTANTS.EcsStorages.unit]
	local UnitStorageState = EcsState.UnitStorageState
	local unitId = UnitStorage.GetComponentId(UnitStorageState, entityId)

	UnitStorageState.dispawnCd[unitId] = 1
end

-- LifeBar
function EnemyService.OnAddLifeBar(spawnCtx)
	local entityId = spawnCtx.entityId

	local LifeBarStorage = EcsState.storages[CONSTANTS.EcsStorages.lifeBar]
	LifeBarStorage.AddComponentToEntity(entityId, EcsService)
end

function EnemyService.EnableLifeBar(spawnCtx)
	local character = spawnCtx.model

	local lifeBar = EnemyService.TryToFindLifeBar(character)
	local billboardGui = lifeBar.Parent

	Gears.UpdateBar(lifeBar, 1)

	-- Force Re render of lifebar
	billboardGui.Enabled = true
end

function EnemyService.DisableLifeBar(spawnCtx)
	local character = spawnCtx.model

	local lifeBar = EnemyService.TryToFindLifeBar(character)
	local billboardGui = lifeBar.Parent

	-- Force Re render of lifebar
	billboardGui.Enabled = false
end

-- MobBehavior
function EnemyService.OnAddMobBehavior(spawnCtx)
	local entityId = spawnCtx.entityId

	local MobBehaviorStorage = EcsState.storages[CONSTANTS.EcsStorages.mobBehavior]
	MobBehaviorStorage.AddComponentToEntity(entityId)
end

-- Respawn
function EnemyService.OnAddRespawn(spawnCtx)
	local entityId = spawnCtx.entityId

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
	-- 	-- Get Back respawnPos
	-- 	local respawnPos = CustomStorage.GetCustomProperties(id).respawnPos

	-- 	EnemyService.SpawnArchetypeEnemy(Enemies.Dummy, respawnPos) -- Respawn
	-- end)
end

function EnemyService.EnableRespawn(spawnCtx, position)
	local entityId = spawnCtx.entityId

	local CustomStorage = EcsState.storages[CONSTANTS.EcsStorages.custom]
	CustomStorage.GetCustomProperties(entityId).respawnPos = position
end

function EnemyService.DisableRespawn(spawnCtx)
	local entityId = spawnCtx.entityId

	-- Get Back respawnPos
	local CustomStorage = EcsState.storages[CONSTANTS.EcsStorages.custom]
	local respawnPos = CustomStorage.GetCustomProperties(entityId).respawnPos

	-- Respawn
	EnemyService.EnableEnemy(Enemies.Dummy, respawnPos)
end

-- #endregion

-- #region ENEMIES LOGIC
-- Move to other File? -> Dependency Injection

local defaultOnDisabled = function(spawnCtx)
	local character = spawnCtx.model

	-- warn("Default On Dispawn")
	Gears.ResetCharacter(character)
	character.HumanoidRootPart.Anchored = true
end

local dummyLogic = {
	onSpawn = function(spawnCtx)
		EnemyService.OnAddUnit(spawnCtx)
		EnemyService.OnAddLifeBar(spawnCtx)
		EnemyService.OnAddRespawn(spawnCtx)
	end,

	onEnabled = function(spawnCtx)
		EnemyService.EnableGameObject(spawnCtx)
		EnemyService.EnableUnit(spawnCtx)
		EnemyService.EnableLifeBar(spawnCtx)
		EnemyService.EnableRespawn(spawnCtx)
	end,

	onDeath = function(spawnCtx, player)
		local character = spawnCtx.model

		EnemyService.UnitDeath(spawnCtx)
		Gears.Dismember(character)
	end,

	onDisabled = function(spawnCtx)
		EnemyService.DisableRespawn(spawnCtx)
		defaultOnDisabled(spawnCtx)
	end,
}

local robotLogic = {
	onSpawn = function(spawnCtx)
		EnemyService.OnAddUnit(spawnCtx)
		EnemyService.OnAddLifeBar(spawnCtx)
		EnemyService.OnAddMobBehavior(spawnCtx)
	end,

	onEnabled = function(spawnCtx)
		local character = spawnCtx.model

		-- EnemyService.EnableGameObject(spawnCtx)
		PlayerService.DetectEnemy(character)
		character.Anchored = false
		character.AlignOrientation.Enabled = true

		EnemyService.EnableUnit(spawnCtx)
		EnemyService.EnableLifeBar(spawnCtx)
	end,

	onDeath = function(spawnCtx, player)
		local character = spawnCtx.model

		character.AlignOrientation.Enabled = false
		EnemyService.UnitDeath(spawnCtx)
		EnemyService.DisableLifeBar(spawnCtx)
	end,

	onDisabled = function(spawnCtx)
		local character = spawnCtx.model

		character.Anchored = true
	end,
	-- onDisabled = function(spawnCtx)
	-- 	defaultOnDisabled(spawnCtx)
	-- end,
}

-- #endregion

-- #region ENEMIES REGISTRIES
-- TODO : Build Registries -> avoid maintenance

EnemyService.enemiesOnSpawn = {
	dummyLogic.onSpawn,
	robotLogic.onSpawn,
}

EnemyService.enemiesOnDeath = {
	dummyLogic.onDeath,
	robotLogic.onDeath,
}

EnemyService.enemiesOnEnabled = {
	dummyLogic.onEnabled,
	robotLogic.onEnabled,
}

EnemyService.enemiesOnDisabled = {
	dummyLogic.onDisabled,
	robotLogic.onDisabled,
}

-- #endregion

-- #region SPAWN ENEMY

--- Spawn New Model + Create Enemy
function EnemyService.SpawnEnemy(enemyId, position)
	-- Spawn Model
	local character = EnemyConst.EnemiesPrefabs[enemyId]:Clone()
	character:PivotTo(CFrame.new(position))

	EnemyService.CreateEnemy(character, enemyId)
end

--- Create Enemy for already spawned Model
function EnemyService.CreateEnemy(character, enemyId)
	local entityId = EcsService.CreateEntity()

	-- warn("Create enemy : " .. character.Name .. ", TypeId = " .. enemyId .. ", EntityId = " .. entityId)

	character.Parent = CONSTANTS.WEAPON_HIT_FOLDER
	local enemyDefinition = EnemiesStats[enemyId]

	-- Add Components : Gameobject, Unit
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
	local enemy = EnemyConst.EnemiesPrefabs[enemyId]:Clone()

	-- warn("Create enemy : " .. character.Name .. ", TypeId = " .. enemyId .. ", EntityId = " .. entityId)

	-- Setup GameObject
	-- enemy.Name = enemy.Name .. entityId

	local spawnCtx = {
		entityId = entityId,
		definitionId = enemyId,
		model = enemy,
	}

	EnemyService.AddGameObject(spawnCtx)

	-- Per Enemy type OnSpawn
	local OnSpawn = EnemyService.enemiesOnSpawn[enemyId]
	OnSpawn(spawnCtx)

	-- Move GameObject
	enemy:PivotTo(CFrame.new(position))
	enemy.Parent = CONSTANTS.WEAPON_HIT_FOLDER

	return entityId
end

-- #endregion

-- #region POOLS

function EnemyService.CreatePool(definitionID, size)
	local prefab = EnemyConst.EnemiesPrefabs[definitionID]

	-- Setup OnSpawn functions table
	-- local onSpawn = table.clone(EnemyService.enemiesOnSpawn[definitionID])
	-- local onDisabled = EnemyService.enemiesOnDisabled[definitionID]
	-- Gears.JoinTable(onSpawn, onDisabled)

	local onSpawn = EnemyService.enemiesOnSpawn[definitionID]
	local onDisabled = EnemyService.enemiesOnDisabled[definitionID]

	local useOnSpawn = function(spawnCtx)
		onSpawn(spawnCtx)
		onDisabled(spawnCtx)
	end

	-- Create + Register Pool
	local _pool, poolIndex = PoolService.CreatePool("Robot", Enemies.Robot, prefab, useOnSpawn, size)

	EnemyServiceState.poolIDs[definitionID] = poolIndex
end

--- Use PoolService to Enable an Enemy
function EnemyService.EnableEnemy(definitionID, position)
	local poolID = EnemyServiceState.poolIDs[definitionID]
	local parent = CONSTANTS.WEAPON_HIT_FOLDER
	local entityId, model = PoolService.EnableNextInPool(poolID, parent, position)

	-- warn("Enable Enemy : " .. model.Name .. " EntityID = " .. entityId)

	-- If Pool limit is reached
	if not model then
		return
	end

	-- Per Enemy Type OnEnabled
	local spawnCtx = {
		entityId = entityId,
		definitionId = definitionID,
		model = model,
	}

	-- Per Type OnEnabled
	local onEnabled = EnemyService.enemiesOnEnabled[definitionID]
	onEnabled(spawnCtx)
end

-- #endregion

-- #region ADVANCED SPAWN

--- Respawn an Enemy around a Random player
function EnemyService.RespawnEnemy(character)
	local randomPlayer = PlayerService.GetRandomPlayer()

	if not randomPlayer then
		return
	end

	-- warn("Respawn Mob : " .. character.Name)

	local playerPos = randomPlayer.character:GetPivot()
	local respawnPos = EnemyService.GetSpawnPosition(playerPos)

	-- character:PivotTo(CFrame.new(respawnPos))
	character.CFrame = CFrame.new(respawnPos)

	-- Avoid instant respawn
	PlayerService.DetectEnemy(character)
end

--- Spawn Mob Enemies around player
function EnemyService.SpawnMobOnPlayer(state, player, enemyNbr)
	-- Validation
	local playerState = Selectors.PlayerState(state, player.UserId)
	local isValid = playerState and not playerState.isDead and player.Character

	if not isValid then
		return
	end

	local playerPos = player.Character:GetPivot().Position

	-- Spawn X Mobs
	for _ = 1, enemyNbr do
		local spawnPos = EnemyService.GetSpawnPosition(playerPos)
		EnemyService.EnableEnemy(Enemies.Robot, spawnPos)
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

			local enemyNbr = Gears.RandomRange(EnemyServiceState.streamSpawnNbr, EnemyServiceState.streamSpawnNbrRange)

			for _, player in ipairs(Players:GetPlayers()) do
				EnemyService.SpawnMobOnPlayer(state, player, enemyNbr)
			end
		end
	end)
end

function EnemyService.IncrementStreamSpawn()
	-- Mob Amount
	local newAmount = EnemyServiceState.streamSpawnNbr + EnemyConst.STREAM_SPAWN_INCREMENT
	EnemyServiceState.streamSpawnNbr = math.min(EnemyConst.STREAM_SPAWN_AMOUNT_CAP, newAmount)

	-- Amount Range
	local newRange = EnemyServiceState.streamSpawnNbrRange + EnemyConst.STREAM_SPAWN_RANGE_INCREMENT
	EnemyServiceState.streamSpawnNbrRange = math.min(EnemyConst.STREAM_SPAWN_AMOUNT_CAP, newRange)

	-- CD
	local cdReduction = EnemyConst.STREAM_SPAWN_CD_REDUCTION

	local newCd = EnemyServiceState.streamSpawnDeltaTime - cdReduction
	EnemyServiceState.streamSpawnDeltaTime = math.max(newCd, EnemyConst.STREAM_SPAWN_MIN_CD)

	local newCdRange = EnemyServiceState.streamSpawnDeltaTimeRange - cdReduction
	EnemyServiceState.streamSpawnDeltaTimeRange = math.max(newCdRange, EnemyConst.STREAM_SPAWN_MIN_CD)
end

--- Start Spawning Swarm Waves
function EnemyService.StartSwarmSpawn()
	EnemyServiceState.swarmWaves = EnemyConst.SWARM_WAVES
end

--- Called every second
function EnemyService.SwarmUpdate(state)
	local swarmWaves = EnemyServiceState.swarmWaves

	if swarmWaves <= 0 then -- Connect / Disconnect?
		return
	end

	-- Trigger Swarm Wave
	EnemyServiceState.swarmWaves -= 1
	local enemyNbr = Gears.RandomRange(EnemyServiceState.swarmAmount, EnemyServiceState.swarmAmountRange)

	for _, player in ipairs(Players:GetPlayers()) do
		EnemyService.SpawnMobOnPlayer(state, player, enemyNbr)
	end
end

function EnemyService.IncrementSwarmSpawn()
	EnemyServiceState.swarmAmount = EnemyConst.SWARM_INCREMENT
end

-- #endregion

-- #region UTILS

--- Get a Random Position in a Circle around input Pos
--- Keep the Input Position in the Level Range (Prevent OOB)
function EnemyService.GetSpawnPosition(position)
	-- Get Random Circle Pos
	local radius = Gears.RandomRange(EnemyConst.SPAWN_RADIUS, EnemyConst.SPAWN_RADIUS_RANGE)
	local progress = math.random(0, CONSTANTS.MAX_RADIANT)
	local circlePos = Gears.CirclePos(radius, progress)
	local pos = position + Vector3.new(circlePos.X, 0, circlePos.Y) -- Circle around Pos

	local usePos = LevelService.KeepPointInLimits(pos)

	return usePos
end

--- return Player
function EnemyService.GetNearestPlayer(state, enemy)
	local minDistance = math.huge
	local nearestPlayer = nil
	local logicState = nil

	for _, player in pairs(Players:GetPlayers()) do
		-- Avoid non ready player
		local playerState = Selectors.PlayerState(state, player.UserId)
		local isPlayerReady = playerState and playerState.state == CONSTANTS.PLAYER_STATES.playing

		if playerState then
			logicState = playerState.state
		end

		if not isPlayerReady then
			continue
		end

		local distance = PlayerServiceState.playersDetections[player.UserId][enemy]
		-- warn(enemy.Name .. " Distance With " .. player.Name .. " = " .. distance)
		local isCloser = distance and distance < minDistance

		if isCloser then
			minDistance = distance
			nearestPlayer = player
		end
	end

	return nearestPlayer, minDistance, logicState
end

function EnemyService.TryToFindLifeBar(character)
	local lBar = character:FindFirstChild("LifeBar")
	local lifeBar = nil

	if lBar then
		lifeBar = lBar.LifeBar
	end

	return lifeBar
end

--- Increment Enemies Stats
function EnemyService.LevelUpEnemies()
	local state = Store:getState()
	local globalEnemyLvl = state.gameState.globalEnemyLvl + 1

	-- Increment Global Stats
	local currentRobotStats = EnemyServiceState.currentRobotStats

	-- Offense
	currentRobotStats.Damage += EnemyConst.DAMAGE_INCREMENT
	currentRobotStats.Damage *= EnemyConst.DAMAGE_MULTIPLIER

	-- Defense
	currentRobotStats.MaxLife += EnemyConst.LIFE_INCREMENT
	currentRobotStats.MaxLife *= EnemyConst.LIFE_MULTIPLIER

	-- Utils
	local movementSpeed = currentRobotStats.MovementSpeed
	local newMs = movementSpeed + EnemyConst.MOVEMENT_SPEED_INCREMENT
	currentRobotStats.MovementSpeed = math.clamp(newMs, 0, EnemyConst.MAX_MOVEMENT_SPEED)

	-- warn("ENEMY LVL+ : ")
	-- warn(" Damage = " .. currentRobotStats.Damage)
	-- warn(" MaxLife = " .. currentRobotStats.MaxLife)
	-- warn(" Movement Speed = " .. currentRobotStats.MovementSpeed)

	-- MAYBE : Mutate Existing Entities

	-- Level Breakpoints (Every X Levels)
	local isBreakPointReached = globalEnemyLvl % EnemyConst.STREAM_SPAWN_LVL_BREAKPOINT == 0

	if isBreakPointReached then
		EnemyService.IncrementStreamSpawn()
		EnemyService.IncrementSwarmSpawn()
	end

	-- Update State
	local patch = { globalEnemyLvl = globalEnemyLvl }
	Store:dispatch(StoreActions.PatchGameState(patch))

	PlayerService.Client.PatchGameState:FireAll(patch)
end

--- Catchup the Global Enemy Level to a Stage
function EnemyService.CatchupLvl(state, stageLevel)
	local minEnemyLvl = stageLevel * 10 - 10
	local enemyLvlDelta = minEnemyLvl - state.gameState.globalEnemyLvl

	local isUnderLevel = enemyLvlDelta > 0

	if not isUnderLevel then
		return
	end

	for i = 1, enemyLvlDelta do
		EnemyService.LevelUpEnemies()
	end
end

-- #endregion

-- #region DAMAGE + DEATH
-- TODO : Move to RpgService

function EnemyService.DamageEnemy(player, entityId, character, damage)
	-- Get State
	local UnitStorage = EcsState.storages[CONSTANTS.EcsStorages.unit]
	local UnitStorageState = UnitStorage.GetState()
	local unitId = UnitStorage.GetComponentId(UnitStorageState, entityId)

	-- Validation
	local currentLife = UnitStorageState.life[unitId]
	local isValid = currentLife > 0 and damage > 0

	if not isValid then
		-- warn("Damage Enemy Not Valid : Current Life = " .. currentLife)
		return
	end

	-- warn("Damage Enemy : Entity ID = " .. entityId .. ", Unit ID = " .. unitId)

	-- Damage Unit
	UnitStorageState.life[unitId] -= damage
	local damagedLife = UnitStorageState.life[unitId]

	-- Trigger Life Changed Event
	-- local definitionId = UnitStorageState.definitionId[unitId]
	-- local definition = EnemiesStats[definitionId]

	local percent = math.max(0, damagedLife / EnemyServiceState.currentRobotStats.MaxLife) -- TODO : Per Type MaxLife
	UnitStorageState.lifeChanged[unitId]:Fire(percent)

	-- Handle Death
	if damagedLife <= 0 then
		local overKillDamage = math.abs(damagedLife)
		EnemyService.KillEnemy(player, entityId, character, overKillDamage)
	end
end

function EnemyService.KillEnemy(player, entityId, character, overKillDamage)
	-- Increment DeathCount
	local state = Store:getState()
	local newDeathCount = state.gameState.enemiesDeathCount + 1
	local patch = { enemiesDeathCount = newDeathCount }
	Store:dispatch(StoreActions.PatchGameState(patch))
	PlayerService.Client.PatchGameState:FireAll(patch)

	-- TODO : Check if userId is nil -> attribute the kill to nearest Player
	-- Rewards
	ItemService.GenerateLoot(player, character)

	-- UnitState
	local UnitStorage = EcsState.storages[CONSTANTS.EcsStorages.unit]
	local UnitStorageState = UnitStorage.GetState()
	local unitId = UnitStorage.GetComponentId(UnitStorageState, entityId)

	local spawnCtx = {
		entityId = entityId,
		definitionId = nil, -- Get from UnitStorageState
		model = character,
	}

	-- Trigger Death Event
	local deathEvent = UnitStorageState.deathEvent[unitId]

	if deathEvent then
		-- warn("Trigger Death Event : EntityID = " .. entityId .. " UnitID = " .. unitId)
		deathEvent:Fire(spawnCtx, player) -- overKillDamage
	end
end

-- TODO : AttackValidation + AttackCtx

--- Unit + MobBehavior System
function EnemyService.EnemyAttack(entityId, enemy, player)
	local isPlayerDead = player.Character.Humanoid.Health > 0

	if not isPlayerDead then
		return
	end

	-- Validation : CD
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

	local damage = EnemyServiceState.currentRobotStats.Damage
	RpgService.DamagePlayer(player, damage)
end

-- #endregion

-- #region ENEMIES UPDATE LOGIC

-- TODO : Component Param
--- Unit Update System : Attack CD + Dispawn CD
function EnemyService.UnitUpdate(dt)
	local UnitStorageState = EcsState.UnitStorageState
	local GameObjectStorage = EcsState.storages[CONSTANTS.EcsStorages.gameObject]

	for i = 1, #UnitStorageState.entities do
		EnemyService.UnitSystem(i, UnitStorageState, GameObjectStorage, dt)
	end
end

-- TODO : UnitComponent Param
function EnemyService.UnitSystem(index, UnitStorageState, GameObjectStorage, dt)
	local entityId = UnitStorageState.entities[index]
	local character = GameObjectStorage.GetGameObject(entityId)

	local isDisabled = character.Parent == CONSTANTS.DISABLED_ENTITIES_FOLDER

	if isDisabled then
		return
	end

	-- Attack CD
	-- TODO : Attack Speed = Attack / sec
	local isReady = UnitStorageState.attackCd[index] >= EnemiesStats[Enemies.Robot].AttackSpeed

	if not isReady then
		UnitStorageState.attackCd[index] += dt
	end

	-- Dispawn CD
	if UnitStorageState.dispawnCd[index] <= 0 then
		return
	end

	UnitStorageState.dispawnCd[index] -= dt

	-- Dispawn
	if UnitStorageState.dispawnCd[index] <= 0 then
		local spawnCtx = {
			entityId = entityId,
			definitionId = UnitStorageState.definitionId[index],
			model = character,
		}

		-- warn("EntityId = " .. entityId .. " -> Dispawn Event")
		UnitStorageState.onDispawn[index]:Fire(spawnCtx)
		PoolService.DisableEntity(entityId)
	end
end

function EnemyService.StartMobBehavior()
	PlayerService.StateUpdate:Connect(function(state, dt)
		EnemyService.MobBehaviorUpdate(state, dt)
	end)

	-- PlayerService.ThrottledUpdate:Connect(function(state, dt)
	-- 	EnemyService.MobBehaviorUpdate(state, dt)
	-- end)
end

--- MobBehavior in Throttled update
function EnemyService.MobBehaviorUpdate(state, dt)
	-- Mob Movements
	local MobBehaviorStorageState = EcsState.MobBehaviorStorageState

	local GameObjectStorage = EcsState.storages[CONSTANTS.EcsStorages.gameObject]
	local UnitStorage = EcsState.storages[CONSTANTS.EcsStorages.unit]
	local UnitStorageState = UnitStorage.GetState()

	local robotStats = EnemiesStats[Enemies.Robot] -- TODO : UnitStorage get DefinitionIdStorage per Entity

	-- TODO : Archetype loops
	for i = 1, #MobBehaviorStorageState.entities do
		local entityId = MobBehaviorStorageState.entities[i]
		local character = GameObjectStorage.GetGameObject(entityId)

		local isDisabled = character.Parent == CONSTANTS.DISABLED_ENTITIES_FOLDER
		if isDisabled then
			continue
		end

		local unitID = UnitStorage.GetComponentId(UnitStorageState, entityId)

		-- EnemyService.MobBehavior(state, entityId, character, robotStats)
		EnemyService.CustomMobBehavior(state, UnitStorageState, entityId, character, unitID, robotStats)
	end
end

--- MobBehavior System : Seek & Attack Players
--- Using Components : MobBehavior, GameObject, Unit
function EnemyService.MobBehavior(state, entityId, character, robotStats)
	-- Get Nearest Player
	local targetPlayer, distance, playerState = EnemyService.GetNearestPlayer(state, character)
	-- TODO : GetValidNearestPlayer()
	local humanoid = character.Humanoid

	-- Replace Missing GameObject
	local root = character:FindFirstChild("HumanoidRootPart")

	if not root then
		-- warn("Entity " .. entityId .. " " .. character.Name .. " No HumanoidRootPart")
		PoolService.ResetGameObject(entityId, character)
		return
	end

	-- No Target = Stop + Respawn
	if not targetPlayer then
		humanoid:MoveTo(character.HumanoidRootPart.Position)

		local isPickingAugments = playerState == CONSTANTS.PLAYER_STATES.pickingAugment
		if not isPickingAugments then
			EnemyService.RespawnEnemy(character)
		end
		return
	end

	-- Target found
	local isWithinRange = distance <= robotStats.Range

	-- Attack
	if isWithinRange then
		-- Stop
		humanoid:MoveTo(character.HumanoidRootPart.Position)
		EnemyService.EnemyAttack(entityId, character, targetPlayer)
		return
	end

	-- Move to player
	local playerPos = targetPlayer.character:GetPivot().Position
	humanoid:MoveTo(playerPos)
end

--- Replace Roblox Humanoid -> Performance
function EnemyService.CustomMobBehavior(state, UnitStorageState, entityId, character, unitID, robotStats)
	-- Replace Missing GameObject
	if not character then
		warn("Entity " .. entityId .. " Replace GameObject")
		PoolService.ResetGameObject(entityId, character)
		return
	end

	-- Dead Unit = No behavior
	local life = UnitStorageState.life[unitID]
	local isDead = life <= 0

	if isDead then
		return
	end

	local targetPlayer, distance, playerState = EnemyService.GetNearestPlayer(state, character)

	-- No Target = Respawn
	if not targetPlayer then
		local isPickingAugments = playerState == CONSTANTS.PLAYER_STATES.pickingAugment
		if not isPickingAugments then
			EnemyService.RespawnEnemy(character)
		end
		return
	end

	-- Target found
	local isWithinRange = distance <= robotStats.Range

	-- Attack
	if isWithinRange then
		EnemyService.EnemyAttack(entityId, character, targetPlayer)
		return
	end

	-- Move to Player
	local playerPos = targetPlayer.character:GetPivot().Position
	local targetPos = Vector3.new(playerPos.X, character.Position.Y, playerPos.Z) -- Vector3.new(playerPos.X, 4.5, playerPos.Z)

	-- FIXME : Perf
	local enemyToPlayer = targetPos - character.CFrame.Position
	local normal = enemyToPlayer.Unit
	local nextPos = character.CFrame.Position + normal * EnemyServiceState.currentRobotStats.MovementSpeed * 0.025
	character.CFrame = CFrame.new(nextPos)

	-- Rotate -> Face Player
	-- Client Side?
	character.CFrame = CFrame.lookAt(character.Position, targetPos)
end

-- #endregion

return EnemyService
