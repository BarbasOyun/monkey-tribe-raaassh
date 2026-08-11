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

-- #region ENEMIES LOGIC

local defaultOnDeath = function(character, player)
	Gears.Dismember(character)
	task.wait(1)
	EcsService.DisableEntity(character:GetAttribute("EntityId"))
end

-- Global OnSpawn Logic
-- Add Components :

local gameObjectSetup = function(entityId, definitionId)
	-- Spawn Disabled Enemy
	local enemy = EnemiesPrefabs[definitionId]:Clone()
	enemy.Parent = CONSTANTS.WEAPON_HIT_FOLDER

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
		-- respawnPrefab
	}

	CustomStorage.AddComponentToEntity(entityId, customProperties)

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

-- #region DUMMY

local dummyOnDeath = function(character, player)
	defaultOnDeath(character, player)

	-- Get Back respawnPos
	local CustomStorage = EcsState.storages[CONSTANTS.EcsStorages.custom]
	local id = character:GetAttribute("EntityId")
	local respawnPos = CustomStorage.GetCustomProperties(id).respawnPos

	EnemyService.SpawnArchetypeEnemy(Enemies.Dummy, respawnPos) -- Respawn
end

local dummyOnSpawn = {
	gameObjectSetup,
	unitSetup,
	lifeBarSetup,
	respawnSetup,
}

local dummyOnEnabled = function(character, entityId)
	-- Set Respawn Pos
	local CustomStorage = EcsState.storages[CONSTANTS.EcsStorages.custom]
	CustomStorage.GetCustomProperties(entityId).respawnPos = character:GetPivot().Position
end

-- #endregion

-- #region ROBOT

-- local robotOnDeath = defaultOnDeath

local robotOnDeath = function(character, player)
	defaultOnDeath(character, player)

	-- Get Back respawnPos
	local CustomStorage = EcsState.storages[CONSTANTS.EcsStorages.custom]
	local id = character:GetAttribute("EntityId")
	local respawnPos = CustomStorage.GetCustomProperties(id).respawnPos

	EnemyService.SpawnArchetypeEnemy(Enemies.Robot, respawnPos) -- Respawn
end

local robotOnEnabled = function(character, entityId)
	-- Set Respawn Pos
	local CustomStorage = EcsState.storages[CONSTANTS.EcsStorages.custom]
	CustomStorage.GetCustomProperties(entityId).respawnPos = character:GetPivot().Position
end

local robotOnSpawn = {
	gameObjectSetup,
	unitSetup,
	lifeBarSetup,
	mobBehaviorSetup,
	respawnSetup,
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
	EnemyService.enemiesOnSpawn[enemyId](entityId, enemyId)

	-- Move GameObject
	local GameObjectStorage = EcsState.storages[CONSTANTS.EcsStorages.gameObject]
	local char = GameObjectStorage.GetGameObject(entityId)
	char:PivotTo(CFrame.new(position))
end

-- #endregion

-- #region POOLS

-- TODO : rename RegisterPool
--- Use ECS to Spawn Archetypes (Object Pooling)
---@param enemyId number
function EnemyService.AddArchetype(enemyId)
	local archetype = EnemyDefinitions.Archetypes[enemyId]
	archetype.setup = EnemyService.enemiesOnSpawn[enemyId]

	EcsService.AddArchetype(archetype)
end

--- Spawn an Enemy from a Pool
function EnemyService.SpawnArchetypeEnemy(enemyId, position)
	local entityId, entityVersion = EcsService.EnableArchetypeEntity(enemyId)

	local GameObjectStorage = EcsService.GetStorage(CONSTANTS.EcsStorages.gameObject)
	local GameObjectStorageState = GameObjectStorage.GetState()
	local character = GameObjectStorageState.gameObjects[entityId]

	-- Move GameObject
	character:PivotTo(CFrame.new(position))
	character.Parent = CONSTANTS.WEAPON_HIT_FOLDER

	-- Components OnEnabled
	EnemyService.OnEnabled(character, entityVersion, entityId)

	-- Per Type OnEnabled
	local enemyOnEnabled = EnemyService.enemiesOnEnabled[enemyId]
	if enemyOnEnabled then
		enemyOnEnabled(character, entityId)
	end
end

-- TODO : Move to Component Storages
--- Components OnEnabled
function EnemyService.OnEnabled(character, entityVersion, entityId)
	-- warn("Enemy Setup : " .. character.Name .. " EntityID = " .. entityId)

	-- 1] GameObject -> Reset
	-- character.Name = "character" .. entityId
	character:SetAttribute("Version", entityVersion)
	Gears.ResetCharacter(character)
	Gears.AnchorModel(character, false)

	-- 2] Unit
	local UnitStorage = EcsState.storages[CONSTANTS.EcsStorages.unit]
	local UnitStorageState = UnitStorage.GetState()

	-- Movement Speed
	local movementSpeed = EnemyServiceState.currentRobotStats.MovementSpeed
	local humanoid = character.Humanoid :: Humanoid
	humanoid.WalkSpeed = movementSpeed

	-- Life
	local maxLife = EnemiesStats[Enemies.Robot].MaxLife
	UnitStorageState.life[entityId] = maxLife

	-- 3] LifeBar
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
		if not playerState or playerState.state ~= CONSTANTS.PLAYER_STATES.playing then
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

	if damage <= 0 then
		return
	end

	unitStorageState.life[unitId] -= damage
	local life = unitStorageState.life[unitId]
	-- print(" Dealt " .. damage .. " damage to " .. humanoid.Parent.Name .. " New life : " .. life)

	-- Trigger Life Changed Event
	local definitionId = unitStorageState.definitionId[unitId]
	local definition = EnemiesStats[definitionId]

	local percent = life / definition.MaxLife
	unitStorageState.lifeChanged[unitId]:Fire(percent)

	-- Handle Death
	if life <= 0 then
		local overKillDamage = math.abs(life)
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
	-- warn("Up Global Enemy Lvl")

	local state = Store:getState()
	local globalEnemyLvl = state.gameState.globalEnemyLvl + 1

	-- Increment Global Stats
	local currentRobotStats = EnemyServiceState.currentRobotStats

	-- Offense
	currentRobotStats.Damage += EnemyDefinitions.DAMAGE_INCREMENT

	-- Defense
	currentRobotStats.MaxLife += EnemyDefinitions.LIFE_INCREMENT

	-- Utils
	local movementSpeed = EnemyServiceState.currentRobotStats.MovementSpeed
	local newMs = movementSpeed + EnemyDefinitions.MOVEMENT_SPEED_INCREMENT
	movementSpeed = math.clamp(newMs, 0, EnemyDefinitions.MAX_MOVEMENT_SPEED)

	-- MAYBE : Mutate Existing Entities

	-- Level Breakpoints (Every X Levels)
	local isBreakPointReached = globalEnemyLvl % EnemyConst.STREAM_SPAWN_LVL_BREAKPOINT == 0

	if isBreakPointReached then
		EnemyServiceState.streamSpawnNbr += 1
	end

	-- Update State
	local patch = { globalEnemyLvl = globalEnemyLvl }
	Store:dispatch(StoreActions.PatchGameState(patch))

	PlayerService.Client.PatchGameState:FireAll(patch)
end

-- TODO : AttackValidation + AttackCtx

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

-- TODO : Archetype loops
--- MobBehavior Component Logic
function EnemyService.MobBehavior(state)
	local robotStats = EnemiesStats[Enemies.Robot]

	for _, entityId in pairs(EcsState.MobBehaviorStorageState.entities) do
		-- Get Enemy GameObject
		local GameObjectStorage = EcsState.storages[CONSTANTS.EcsStorages.gameObject]
		local enemy = GameObjectStorage.GetGameObject(entityId)

		-- Get Nearest Player
		local targetPlayer, distance = EnemyService.GetNearestPlayer(state, enemy)
		local humanoid = enemy.Humanoid

		if not targetPlayer then
			-- Stop if no target found
			humanoid:MoveTo(enemy.HumanoidRootPart.Position)
			continue
		end

		-- Target found : Attack or Move to
		local isWithinRange = distance <= robotStats.Range

		if isWithinRange then
			-- EnemyService.EnemyAttack(entityId, enemy, targetPlayer)
			continue
		end

		humanoid:MoveTo(targetPlayer.character:GetPivot().Position)
	end
end

--- Start MobBehavior in Throttled update
function EnemyService.StartMobBehavior()
	PlayerService.StateUpdate:Connect(function(state, dt)
		-- Movements
		EcsState.MobBehaviorStorageState.timer += dt

		local isDeltaReached = EcsState.MobBehaviorStorageState.timer >= EcsState.MobBehaviorStorageState.timerDelta

		if isDeltaReached then
			-- Reset Timer
			EcsState.MobBehaviorStorageState.timer = 0

			EnemyService.MobBehavior(state)
		end

		-- Attack CD
		-- TODO : Attack Speed = Attack / sec
		for i = 1, #EcsState.UnitStorageState.attackCd, 1 do
			local isReady = EcsState.UnitStorageState.attackCd[i] >= EnemiesStats[Enemies.Robot].AttackSpeed

			if not isReady then
				EcsState.UnitStorageState.attackCd[i] += dt
			end
		end
	end)
end

--- Spawn Mob Enemies
function EnemyService.StreamSpawn()
	-- Spawn Mobs around each player
	local state = Store:getState()

	for _, player in ipairs(Players:GetPlayers()) do
		-- Check if Player is Valid
		local playerState = Selectors.PlayerState(state, player.UserId)
		-- MAYBE : isPickingAugment

		local isValid = playerState and not playerState.isDead and player.Character

		if not isValid then
			continue
		end

		local playerPos = player.Character:GetPivot().Position
		local enemyNbr = Gears.RandomRange(EnemyServiceState.streamSpawnNbr, EnemyConst.STREAM_SPAWN_NBR_RANGE)

		-- Spawn X Mobs
		for _ = 1, enemyNbr, 1 do
			local spawnPos = EnemyService.GetSpawnPosition(playerPos)
			EnemyService.SpawnArchetypeEnemy(Enemies.Robot, spawnPos)
		end
	end
end

function EnemyService.RollStreamSpawnDelta()
	local minTime = EnemyConst.STREAM_SPAWN_DELTA_TIME
	local maxTime = EnemyConst.STREAM_SPAWN_DELTA_TIME + EnemyConst.STREAM_SPAWN_DELTA_TIME_RANGE

	local spawnDelta = math.random(minTime, maxTime)

	EnemyServiceState.streamSpawnDelta = spawnDelta
end

function EnemyService.StartStreamSpawn()
	task.wait(EnemyConst.STREAM_SPAWN_INITIAL_CD)
	EnemyService.RollStreamSpawnDelta()
	EnemyService.StartMobBehavior()
	LevelService.StartGameTimer()

	PlayerService.StateUpdate:Connect(function(state, dt)
		EnemyServiceState.streamSpawnTimer += dt

		-- Spawn
		local isDeltaTimeReached = EnemyServiceState.streamSpawnTimer >= EnemyServiceState.streamSpawnDelta

		if isDeltaTimeReached then
			-- Reset Timers
			EnemyServiceState.streamSpawnTimer = 0
			EnemyService.RollStreamSpawnDelta()

			EnemyService.StreamSpawn()
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
			EnemyService.SpawnArchetypeEnemy(Enemies.Robot, spawnPos)
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
