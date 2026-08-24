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

-- TODO : Rename EnemyCtx
type SpawnCtx = {
	entityId: number,
	definitionId: number,
	model: Model,
	-- Pos?
}

-- #region ON SPAWN SYSTEMS

-- local gameObjectSetup = function(onSpawnCtx)
-- 	local entityId = onSpawnCtx.entityId
-- 	local character = onSpawnCtx.model

-- 	local GameObjectStorage = EcsState.storages[CONSTANTS.EcsStorages.gameObject]
-- 	GameObjectStorage.AddComponentToEntity(entityId, character)
-- end

local unitSetup = function(spawnCtx)
	local entityId = spawnCtx.entityId
	local definitionId = spawnCtx.definitionId

	-- Add Unit Component
	local enemyDefinition = EnemiesStats[definitionId]
	local UnitStorage = EcsState.storages[CONSTANTS.EcsStorages.unit]

	local unitId = UnitStorage.AddComponentToEntity(entityId, Enemies.Dummy, enemyDefinition.MaxLife)

	local UnitStorageState = UnitStorage.GetState()

	-- Setup OnDeath
	local onDeath = EnemyService.enemiesOnDeath[definitionId]
	UnitStorageState.deathEvent[unitId]:Connect(onDeath)

	-- Setup OnDispawn
	local onDisabled = EnemyService.enemiesOnDisabled[definitionId]
	UnitStorageState.onDispawn[unitId]:Connect(function(spawnCtx)
		onDisabled(spawnCtx)
	end)
end

local lifeBarSetup = function(spawnCtx)
	local entityId = spawnCtx.entityId

	local LifeBarStorage = EcsState.storages[CONSTANTS.EcsStorages.lifeBar]
	LifeBarStorage.AddComponentToEntity(entityId, EcsService)
end

local mobBehaviorSetup = function(spawnCtx)
	local entityId = spawnCtx.entityId

	local MobBehaviorStorage = EcsState.storages[CONSTANTS.EcsStorages.mobBehavior]
	MobBehaviorStorage.AddComponentToEntity(entityId)
end

local respawnSetup = function(spawnCtx)
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

-- #endregion

-- #region ON ENABLED SYSTEMS

local gameObjectOnEnabled = function(spawnCtx, position)
	local character = spawnCtx.model

	-- character:SetAttribute("Version", entityVersion)
	character.HumanoidRootPart.Anchored = false
end

local unitOnEnabled = function(spawnCtx)
	local entityId = spawnCtx.entityId
	local character = spawnCtx.model

	local UnitStorage = EcsState.storages[CONSTANTS.EcsStorages.unit]
	local UnitStorageState = UnitStorage.GetState()
	local unitID = UnitStorage.GetComponentId(UnitStorageState, entityId)

	-- Movement Speed
	local movementSpeed = EnemyServiceState.currentRobotStats.MovementSpeed
	local humanoid = character.Humanoid :: Humanoid
	humanoid.WalkSpeed = movementSpeed

	-- Life
	local maxLife = EnemiesStats[Enemies.Robot].MaxLife
	UnitStorageState.life[unitID] = maxLife
end

local lifeBarOnEnabled = function(spawnCtx)
	local character = spawnCtx.model

	local lifeBar = EnemyService.TryToFindLifeBar(character)
	local billboardGui = lifeBar.Parent

	Gears.UpdateBar(lifeBar, 1)

	-- Force Re render of lifebar
	billboardGui.Enabled = true
end

local respawnOnEnabled = function(spawnCtx, position)
	local entityId = spawnCtx.entityId

	local CustomStorage = EcsState.storages[CONSTANTS.EcsStorages.custom]
	CustomStorage.GetCustomProperties(entityId).respawnPos = position
end

-- #endregion

-- #region ENEMIES LOGIC
-- Move to other File? -> Dependency Injection

local defaultOnDeath = function(entityId, character, player)
	-- warn("Default OnDeath")

	Gears.Dismember(character)

	-- Setup Dispawn
	local UnitStorage = EcsState.storages[CONSTANTS.EcsStorages.unit]
	local UnitStorageState = EcsState.UnitStorageState
	local unitId = UnitStorage.GetComponentId(UnitStorageState, entityId)

	UnitStorageState.dispawnCd[unitId] = 1
end

local defaultOnDisabled = function(spawnCtx)
	local character = spawnCtx.model

	-- warn("Default On Dispawn")
	Gears.ResetCharacter(character)
	character.HumanoidRootPart.Anchored = true
end

local dummyLogic = {
	onSpawn = {
		-- gameObjectSetup,
		unitSetup,
		lifeBarSetup,
		respawnSetup,
	},
	onEnabled = {
		gameObjectOnEnabled,
		unitOnEnabled,
		lifeBarOnEnabled,
		respawnOnEnabled,
	},
	onDeath = defaultOnDeath,

	onDisabled = function(entityId)
		-- Get Back respawnPos
		local CustomStorage = EcsState.storages[CONSTANTS.EcsStorages.custom]
		local respawnPos = CustomStorage.GetCustomProperties(entityId).respawnPos

		-- Respawn
		EnemyService.EnableEnemy(Enemies.Dummy, respawnPos)

		defaultOnDisabled(entityId)
	end,
}

local robotLogic = {
	onSpawn = {
		-- gameObjectSetup,
		unitSetup,
		lifeBarSetup,
		mobBehaviorSetup,
	},
	onEnabled = {
		gameObjectOnEnabled,
		unitOnEnabled,
		lifeBarOnEnabled,
	},
	onDeath = defaultOnDeath,
	onDisabled = defaultOnDisabled,
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

	-- Add GameObject Comp
	local GameObjectStorage = EcsState.storages[CONSTANTS.EcsStorages.gameObject]
	GameObjectStorage.AddComponentToEntity(entityId, enemy)

	-- Setup GameObject
	enemy.Parent = CONSTANTS.WEAPON_HIT_FOLDER
	enemy.Name = enemy.Name .. entityId

	-- Per Enemy type OnSpawn
	local OnSpawnFunctions = EnemyService.enemiesOnSpawn[enemyId]
	local spawnCtx = {
		entityId = entityId,
		definitionId = enemyId,
		model = enemy,
	}

	for i = 1, #OnSpawnFunctions do
		OnSpawnFunctions[i](spawnCtx)
	end

	-- Move GameObject
	enemy:PivotTo(CFrame.new(position))

	return entityId
end

-- #endregion

-- #region POOLS

function EnemyService.CreatePool(definitionID, size)
	local prefab = EnemyConst.EnemiesPrefabs[definitionID]
	local onSpawn = table.clone(EnemyService.enemiesOnSpawn[definitionID])

	local onDisabled = EnemyService.enemiesOnDisabled[definitionID]

	table.insert(onSpawn, onDisabled)

	PoolService.CreatePool("Robot", CONSTANTS.DefinedTypes.Unit, Enemies.Robot, prefab, onSpawn, size)
end

--- Use PoolService to Enable an Enemy
function EnemyService.EnableEnemy(definitionID, position)
	local parent = CONSTANTS.WEAPON_HIT_FOLDER
	local entityId, model = PoolService.EnableNextInPool(CONSTANTS.DefinedTypes.Unit, definitionID, parent, position)

	-- If Pool limit is reached
	if not model then
		return
	end

	-- Per Type OnEnabled
	local onEnabled = EnemyService.enemiesOnEnabled[definitionID]

	-- Per Enemy Type OnEnabled
	local spawnCtx = {
		entityId = entityId,
		definitionId = definitionID,
		model = model,
	}

	for i = 1, #onEnabled do
		onEnabled[i](spawnCtx, position)
	end
end

-- #endregion

-- #region ADVANCED SPAWN

--- Respawn an Enemy around a Random player
function EnemyService.RespawnEnemy(character)
	local randomPlayer = PlayerService.GetRandomPlayer()

	if not randomPlayer then
		return
	end

	local playerpos = randomPlayer.character:GetPivot()
	local respawnPos = EnemyService.GetSpawnPosition(playerpos)

	character:PivotTo(CFrame.new(respawnPos))
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

-- #endregion

-- #region DAMAGE + DEATH
-- TODO : Move to RpgService

function EnemyService.DamageEnemy(player, entityId, humanoid, damage)
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
	local definitionId = UnitStorageState.definitionId[unitId]
	local definition = EnemiesStats[definitionId]

	local percent = math.max(0, damagedLife / definition.MaxLife)
	UnitStorageState.lifeChanged[unitId]:Fire(percent)

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
	local UnitStorage = EcsState.storages[CONSTANTS.EcsStorages.unit]
	local UnitStorageState = UnitStorage.GetState()

	local unitId = UnitStorage.GetComponentId(UnitStorageState, entityId)
	local deathEvent = UnitStorageState.deathEvent[unitId]

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
	currentRobotStats.Damage *= EnemyConst.DAMAGE_MULTIPLIER

	-- Defense
	currentRobotStats.MaxLife *= EnemyConst.LIFE_MULTIPLIER

	-- Utils
	local movementSpeed = currentRobotStats.MovementSpeed
	local newMs = movementSpeed + EnemyConst.MOVEMENT_SPEED_INCREMENT
	currentRobotStats.MovementSpeed = math.clamp(newMs, 0, EnemyConst.MAX_MOVEMENT_SPEED)

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

		-- Dispawn
		if UnitStorageState.dispawnCd[i] <= 0 then
			local GameObjectStorage = EcsState.storages[CONSTANTS.EcsStorages.gameObject]
			local character = GameObjectStorage.GetGameObject(entityId)

			local spawnCtx = {
				entityId = entityId,
				definitionId = UnitStorageState.definitionId[i],
				model = character,
			}

			-- warn("EntityId = " .. entityId .. " -> Dispawn Event")
			UnitStorageState.onDispawn[i]:Fire(spawnCtx)
			PoolService.DisableEntity(entityId)
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
	local targetPlayer, distance, playerState = EnemyService.GetNearestPlayer(state, character)
	local humanoid = character.Humanoid

	-- Check GameObject
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
			EnemyService.EnableEnemy(Enemies.Robot, spawnPos)
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

return EnemyService
