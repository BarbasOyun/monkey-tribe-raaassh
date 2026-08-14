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

local defaultOnDeath = function(character, player)
	Gears.Dismember(character)
	task.wait(1)
	local entityId = character:GetAttribute("EntityId")
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

	-- Connect OnDeath Event
	local UnitStorageState = UnitStorage.GetState()
	local onDeath = EnemyService.enemiesOnDeath[definitionId]
	UnitStorageState.deathEvent[unitId]:Connect(onDeath)
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
	billboardGui.Enabled = false
	task.spawn(function()
		task.wait()
		billboardGui.Enabled = true
	end)
end

local respawnOnEnabled = function(entityId, character, position)
	local CustomStorage = EcsState.storages[CONSTANTS.EcsStorages.custom]
	CustomStorage.GetCustomProperties(entityId).respawnPos = position
end

-- #endregion

-- #region DUMMY

local dummyOnDeath = function(character, player)
	defaultOnDeath(character, player)
	local entityId = character:GetAttribute("EntityId")

	-- Get Back respawnPos
	local CustomStorage = EcsState.storages[CONSTANTS.EcsStorages.custom]
	local respawnPos = CustomStorage.GetCustomProperties(entityId).respawnPos

	-- Respawn
	EnemyService.EnableNextInPool(Enemies.Dummy, respawnPos)
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

EnemyService.enemiesOnDeath = {
	dummyOnDeath,
	robotOnDeath,
}

EnemyService.enemiesOnEnabled = {
	dummyOnEnabled,
	robotOnEnabled,
}

EnemyService.enemiesOnSpawn = {
	dummyOnSpawn,
	robotOnSpawn,
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

--- Register and Create a Pool of Enemy
function EnemyService.CreatePool(enemyId)
	local pool = EnemyDefinitions.EnemiesPool[enemyId]

	-- TODO : Prevent Creating the same Pool

	-- Update Pool
	local startIndex = #EnemyServiceState.entitiesPool + 1
	local endIndex = startIndex + pool.size
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
		local threshold = pool.endIndex

		if entityId <= threshold then
			return pool
		end
	end

	return nil
end

function EnemyService.EnableNextInPool(enemyId, position)
	-- Validation
	local poolIndex = EnemyServiceState.poolsLookups[enemyId]
	local pool = EnemyServiceState.pools[poolIndex]

	local hasReachedMax = pool.activeCount >= pool.size

	if hasReachedMax then
		warn(pool.name .. " Reached Limit of : " .. pool.count)
		return
	end

	-- Get State
	pool.activeCount += 1

	local index = pool.startIndex + pool.activeCount
	local entityId = EnemyServiceState.entitiesPool[index]

	local GameObjectStorage = EcsService.GetStorage(CONSTANTS.EcsStorages.gameObject)
	local GameObjectStorageState = GameObjectStorage.GetState()
	local character = GameObjectStorageState.gameObjects[entityId]

	-- warn("Enable Object in Pool = " .. pool.name .. ", Entity ID = " .. entityId)

	-- Per Type OnEnabled
	local componentsOnEnabled = EnemyService.enemiesOnEnabled[enemyId]
	for i = 1, #componentsOnEnabled do
		local onEnabled = componentsOnEnabled[i]

		if onEnabled then
			onEnabled(entityId, character, position)
		end
	end

	return entityId
end

--- Disable an Object
function EnemyService.DisableEntity(entityId)
	if not EcsService.HasComponent(entityId, 1) then
		warn(entityId .. " Doesn't have Gameobject Component")
		return
	end

	local pool = EnemyService.GetPool(entityId)

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

	EnemyServiceState.entitiesPool[index] = lastEntityId
	EnemyServiceState.entitiesPool[lastIndex] = entityId
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

		local distance = MutState.playersDetections[player.UserId][enemy]
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
	local unitStorage = EcsState.storages[CONSTANTS.EcsStorages.unit]
	local unitStorageState = unitStorage.GetState()
	local unitId = unitStorage.GetComponentId(unitStorageState, entityId)

	-- warn("Damage Enemy : Entity ID = " .. entityId .. ", Unit ID = " .. unitId)

	local currentLife = unitStorageState.life[unitId]
	if currentLife <= 0 or damage <= 0 then
		return
	end

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
		-- warn("Death Event : EntityID  = " .. entityId .. " UnitID = " .. unitId)
		deathEvent:Fire(humanoid.Parent, player) -- overKillDamage
	end
end

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

-- TODO : AttackValidation + AttackCtx

--- Unit + MobBehavior System
function EnemyService.EnemyAttack(entityId, enemy, player)
	local robotStats = EnemiesStats[Enemies.Robot]

	enemy.Humanoid:MoveTo(enemy.HumanoidRootPart.Position) -- Stop

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

-- #region UPDATE

--- MobBehavior System : Seek & Attack Players
function EnemyService.MobBehavior(state, entityId, character, robotStats)
	-- Get Nearest Player
	local targetPlayer, distance = EnemyService.GetNearestPlayer(state, character)
	local humanoid = character.Humanoid

	-- Stop if no target found
	if not targetPlayer then
		local t = character:FindFirstChild("HumanoidRootPart")

		if not t then
			warn("Entity " .. entityId .. " " .. character.Name .. " No HumanoidRootPart")
		end

		humanoid:MoveTo(character.HumanoidRootPart.Position)
		return
	end

	-- Target found : Attack or Move to
	local isWithinRange = distance <= robotStats.Range

	if isWithinRange then
		EnemyService.EnemyAttack(entityId, character, targetPlayer)
		return
	end

	humanoid:MoveTo(targetPlayer.character:GetPivot().Position)
end

--- Start MobBehavior in Throttled update
function EnemyService.StartMobBehavior()
	PlayerService.StateUpdate:Connect(function(state, dt)
		-- Mob Movements
		EcsState.MobBehaviorStorageState.timer += dt

		local isDeltaReached = EcsState.MobBehaviorStorageState.timer >= EcsState.MobBehaviorStorageState.timerDelta

		if isDeltaReached then
			-- Reset Timer
			EcsState.MobBehaviorStorageState.timer = 0

			local GameObjectStorage = EcsState.storages[CONSTANTS.EcsStorages.gameObject]
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
		end

		-- Mob Attack CD
		-- TODO : Attack Speed = Attack / sec
		for i = 1, #EcsState.UnitStorageState.attackCd, 1 do
			local isReady = EcsState.UnitStorageState.attackCd[i] >= EnemiesStats[Enemies.Robot].AttackSpeed

			if not isReady then
				EcsState.UnitStorageState.attackCd[i] += dt
			end
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
