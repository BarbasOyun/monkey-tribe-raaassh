local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Knit = require(ReplicatedStorage.Packages.Knit)
-- local Signal = require(ReplicatedStorage.Packages._Index["sleitnick_signal@1.5.0"].signal)
local Gears = require(ReplicatedStorage.Shared.Gears)

-- Get Constants
local CONSTANTS = require(ServerScriptService.SharedServer.Constants)

local EnemyDefinitions = require(ReplicatedStorage.Shared.AuthoringData.EnemyDefinitions)
local Enemies = EnemyDefinitions.Enemies
local EnemiesDefinitions = EnemyDefinitions.EnemiesDefinitions
local EnemiesPrefabs = EnemyDefinitions.EnemiesPrefabs

-- Get State
local RoduxStore = require(ReplicatedStorage.Shared.RoduxStore)
local Store = RoduxStore.Store
-- local StoreActions = RoduxStore.Actions
local Selectors = RoduxStore.Selectors

-- Get Mutable State
local MutState = require(ServerScriptService.SharedServer.MutableState)
local EcsState = MutState.EcsState

-- Get Services
local EcsService
local ItemService

local EnemyService = Knit.CreateService({
	Name = "EnemyService",
	-- Client = {},
})

-- #region ENEMIES ON SPAWN

--- Archetype less dummy setup
--[[
local dummySetup = function(character, entityId)
	warn("Dummy Setup : " .. character.Name .. " EntityID = " .. entityId)

	local function onDeath(player)
		-- Feedback
		-- print(character.Name .. " Died")

		-- dismember(dummy)
		local snap = character.Torso:FindFirstChild("Snap")
		if snap then
			snap:Destroy()
		end

		task.wait(1)
		EnemyService.SpawnEnemy(Enemies.Dummy, character:GetPivot().Position) -- Re spawn Dummy
		EcsService.RemoveEntity(character:GetAttribute("EntityId"))
		-- TODO :
		-- Enable Entity
		-- Disable Entity at id
	end

	-- Get GameObject
	local GameObjectStorage = EcsState.storages[CONSTANTS.EcsStorages.gameObject]

	local unitStorage = EcsState.storages[CONSTANTS.EcsStorages.unit]
	local unitStorageState = unitStorage.GetState()
	local unitId = unitStorage.GetComponentId(unitStorageState, entityId)

	-- Setup LifeBar
	local dummy = GameObjectStorage.GetGameObject(entityId)
	local lifeBar = EnemyService.TryToFindLifeBar(dummy)
	unitStorageState.lifeBar[unitId] = lifeBar

	-- Setup OnDeath
	unitStorageState.deathEvent[unitId]:Connect(onDeath)
end
]]

local defaultOnDeath = function(character, player)
	EnemyService.Dismember(character)
	task.wait(1)
	EcsService.DisableEntity(character:GetAttribute("EntityId"))
end

local dummyOnDeath = defaultOnDeath

local robotOnDeath = defaultOnDeath

local enemiesOnDeath = {
	dummyOnDeath,
	robotOnDeath,
}

-- TODO : Move Global to Respective Storage

--- Global GameObject Archetype Setup
local gameObjectSetup = function(entityId, definitionId)
	-- warn("Archetype Setup : Game Object")

	-- Spawn Disabled Enemy
	local enemy = EnemiesPrefabs[definitionId]:Clone()

	local GameObjectStorage = EcsState.storages[CONSTANTS.EcsStorages.gameObject]
	GameObjectStorage.AddComponentToEntity(EcsState, entityId, enemy)
	GameObjectStorage.DisableEntity(entityId)
end

--- Global Unit Archetype Setup
local unitSetup = function(entityId, definitionId)
	-- Add Unit Component
	local enemyDefinition = EnemiesDefinitions[definitionId]
	local UnitStorage = EcsState.storages[CONSTANTS.EcsStorages.unit]

	local unitId = UnitStorage.AddComponentToEntity(EcsState, entityId, Enemies.Dummy, enemyDefinition.MaxLife)

	-- Connect OnDeath Event
	local UnitStorageState = UnitStorage.GetState()
	local onDeath = enemiesOnDeath[definitionId]
	UnitStorageState.deathEvent[unitId]:Connect(onDeath)
end

--- Global LifeBar Archetype Setup
local lifeBarSetup = function(entityId, definitionId)
	local LifeBarStorage = EcsState.storages[CONSTANTS.EcsStorages.lifeBar]
	LifeBarStorage.AddComponentToEntity(EcsState, entityId, EcsService)
end

local defaultSetup = {
	gameObjectSetup,
	unitSetup,
	lifeBarSetup,
}

-- Dummy Setup
local respawnSetup = function(entityId, definitionId)
	-- Add Custom Component (Storing respawnPos)
	local CustomStorage = EcsState.storages[CONSTANTS.EcsStorages.custom]
	local customProperties = {
		respawnPos = Vector3.zero,
	}

	CustomStorage.AddComponentToEntity(EcsState, entityId, customProperties)

	-- Connect to Unit OnDeath
	local UnitStorage = EcsState.storages[CONSTANTS.EcsStorages.unit]
	local UnitStorageState = UnitStorage.GetState()
	local unitId = UnitStorage.GetComponentId(UnitStorageState, entityId)

	UnitStorageState.deathEvent[unitId]:Connect(function(character, _player)
		task.wait(1)
		-- Get respawnPos Back
		local id = character:GetAttribute("EntityId")
		local respawnPos = CustomStorage.GetCustomProperties(id).respawnPos

		EnemyService.SpawnArchetypeEnemy(Enemies.Dummy, respawnPos) -- Respawn
	end)
end

local dummyArchetypeSetup = {
	gameObjectSetup,
	unitSetup,
	lifeBarSetup,
	respawnSetup,
}

local robotArchetypeSetup = defaultSetup

local enemiesArchetypeSetup = {
	dummyArchetypeSetup,
	robotArchetypeSetup,
}

-- #endregion

-- #region ENEMIES ON ENABLED (OBJECT POOLING)

local dummySetup = function(character, entityId)
	local CustomStorage = EcsState.storages[CONSTANTS.EcsStorages.custom]
	CustomStorage.GetCustomProperties(entityId).respawnPos = character:GetPivot().Position
end

local robotSetup = function(character, entityId) end

-- Per enemyType Spawn setup
local enemiesSetup = {
	dummySetup,
	robotSetup,
}

--- Setup Enemy OnSpawn
function EnemyService.EnemySetup(character, definitionId, entityId)
	-- warn("Enemy Setup : " .. character.Name .. " EntityID = " .. entityId)

	EnemyService.ResetCharacter(character)

	-- Components Setup
	-- TODO : Move to each Components

	-- Unit
	local UnitStorage = EcsState.storages[CONSTANTS.EcsStorages.unit]
	local UnitStorageState = UnitStorage.GetState()

	-- Life
	local maxLife = EnemiesDefinitions[Enemies.Robot].MaxLife
	UnitStorageState.life[entityId] = maxLife

	-- Connect OnDeath
	-- local deathEvent = UnitStorageState.deathEvent[entityId]
	-- deathEvent:DisconnectAll()

	-- Connect OnDeath Per Type
	-- local enemyOnDeathEvent = enemiesOnDeath[definitionId]
	-- if enemyOnDeathEvent then
	-- 	deathEvent:Connect(enemyOnDeathEvent)
	-- end

	-- Reset LifeBar
	local lifeBar = EnemyService.TryToFindLifeBar(character)
	local billboardGui = lifeBar.Parent

	Gears.UpdateBar(lifeBar, 1)

	-- Force Re render of lifebar
	billboardGui.Enabled = false
	task.spawn(function()
		task.wait()
		billboardGui.Enabled = true
	end)

	-- Per Type Setup
	local enemySetup = enemiesSetup[definitionId]
	if enemiesSetup then
		enemySetup(character, entityId)
	end
end

-- #endregion

-- #region SPAWN ENEMY

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

	local enemyDefinition = EnemiesDefinitions[enemyId]
	character.Parent = CONSTANTS.WEAPON_HIT_FOLDER

	-- Add Components : Gameobject, Unit
	-- TODO : Fuse with Archetype Setup
	local GameObjectStorage = EcsState.storages[CONSTANTS.EcsStorages.gameObject]
	local unitStorage = EcsState.storages[CONSTANTS.EcsStorages.unit]

	GameObjectStorage.AddComponentToEntity(EcsState, entityId, character)
	unitStorage.AddComponentToEntity(EcsState, entityId, enemyId, enemyDefinition.MaxLife)

	-- Per Enemy type setup
	enemiesSetup[enemyId](character, entityId)
end

-- #endregion

-- #region ARCHETYPE

--- Use ECS to Spawn Archetypes (Object Pooling)
---@param enemyId number
function EnemyService.AddArchetype(enemyId)
	local archetype = EnemyDefinitions.Archetypes[enemyId]
	archetype.setup = enemiesArchetypeSetup[enemyId]

	EcsService.AddArchetype(archetype)
end

--- Spawn an Enemy of an Archetype by Enabling a ECS Entity
function EnemyService.SpawnArchetypeEnemy(enemyId, position)
	local entityId, entityVersion = EcsService.EnableArchetypeEntity(enemyId)

	-- Setup Gameobject Component
	local GameObjectStorage = EcsService.GetStorage(CONSTANTS.EcsStorages.gameObject)
	local GameObjectStorageState = GameObjectStorage.GetState()
	local character = GameObjectStorageState.gameObjects[entityId]

	-- character.Name = "character" .. entityId

	character:PivotTo(CFrame.new(position))
	character.Parent = CONSTANTS.WEAPON_HIT_FOLDER

	-- TODO : Move to Component Storages
	character:SetAttribute("Version", entityVersion)

	-- Setup Unit Component
	EnemyService.EnemySetup(character, enemyId, entityId)

	-- Un Anchor parts
	EnemyService.AnchorModel(character, false)
end

-- #endregion

-- #region UTILS

--- Keep the Input Position in the Level Range (Prevent OOB)
function EnemyService.GetSpawnPosition(position)
	-- TODO
end

--- Anchor Every Part in a Model
function EnemyService.AnchorModel(character, isAnchored)
	for _, child in pairs(character:GetChildren()) do
		if child:IsA("Part") then
			child.Anchored = isAnchored
		end
	end
end

--- Get the Body Parts of a R6 Model
function EnemyService.GetBodyParts(character)
	local torso = character.Torso
	local head = character.Head
	local leftArm = character:FindFirstChild("Left Arm")
	local leftLeg = character:FindFirstChild("Left Leg")
	local rightArm = character:FindFirstChild("Right Arm")
	local rightLeg = character:FindFirstChild("Right Leg")

	assert(torso, character.Name .. " Missing Body Part")
	assert(head, character.Name .. " Missing Body Part")
	assert(leftArm, character.Name .. " Missing Body Part")
	assert(leftLeg, character.Name .. " Missing Body Part")
	assert(rightArm, character.Name .. " Missing Body Part")
	assert(rightLeg, character.Name .. " Missing Body Part")

	return torso, head, leftArm, leftLeg, rightArm, rightLeg
end

--- Get the Limbs Joints of a R6 Model
function EnemyService.GetJoints(character)
	local torso = character.Torso

	assert(torso, character.Name .. " Missing Torso")

	local rootJoint
	local neck = torso:FindFirstChild("Neck") :: Motor6D
	local leftShoulder = torso:FindFirstChild("Left Shoulder") :: Motor6D
	local leftHip = torso:FindFirstChild("Left Hip") :: Motor6D
	local rightShoulder = torso:FindFirstChild("Right Shoulder") :: Motor6D
	local rightHip = torso:FindFirstChild("Right Hip") :: Motor6D

	assert(neck, character.Name .. " Missing Joint")
	assert(leftShoulder, character.Name .. " Missing Joint")
	assert(leftHip, character.Name .. " Missing Joint")
	assert(rightShoulder, character.Name .. " Missing Joint")
	assert(rightHip, character.Name .. " Missing Joint")

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")

	if humanoidRootPart then
		rootJoint = humanoidRootPart:FindFirstChild("RootJoint")
	end

	return rootJoint, neck, leftShoulder, leftHip, rightShoulder, rightHip
end

---@param character Model
function EnemyService.Dismember(character)
	-- Get Body Parts
	local torso, head, leftArm, leftLeg, rightArm, rightLeg = EnemyService.GetBodyParts(character)

	-- Get Joints
	local rootJoint, neck, leftShoulder, leftHip, rightShoulder, rightHip = EnemyService.GetJoints(character)

	-- Disable Joints
	rootJoint.Enabled = false
	neck.Enabled = false
	leftShoulder.Enabled = false
	leftHip.Enabled = false
	rightShoulder.Enabled = false
	rightHip.Enabled = false

	-- Enable Collisions
	leftArm.CanCollide = true
	leftLeg.CanCollide = true
	rightArm.CanCollide = true
	rightLeg.CanCollide = true
end

--- Reset a Character so that it can be enabled again (Object Pooling)
---@param character Model
function EnemyService.ResetCharacter(character)
	-- Get Body Parts
	local torso, head, leftArm, leftLeg, rightArm, rightLeg = EnemyService.GetBodyParts(character)

	-- Get Joints
	local rootJoint, neck, leftShoulder, leftHip, rightShoulder, rightHip = EnemyService.GetJoints(character)

	-- Enable Joints
	rootJoint.Enabled = true
	neck.Enabled = true
	leftShoulder.Enabled = true
	leftHip.Enabled = true
	rightShoulder.Enabled = true
	rightHip.Enabled = true

	-- Disable Collisions
	leftArm.CanCollide = false
	-- leftLeg.CanCollide = false
	rightArm.CanCollide = false
	-- rightLeg.CanCollide = false
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
	local definition = EnemiesDefinitions[definitionId]

	local percent = life / definition.MaxLife
	unitStorageState.lifeChanged[unitId]:Fire(percent)

	-- Handle Death
	if life <= 0 then
		local overKillDamage = math.abs(life)
		EnemyService.KillEnemy(player, entityId, humanoid, overKillDamage)
	end
end

function EnemyService.KillEnemy(player, entityId, humanoid, overKillDamage)
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

-- #endregion

-- #region UPDATE

--- Start Spawning Mob Enemies every X Sec
function EnemyService.StreamSpawn()
	local minTime = CONSTANTS.STREAM_SPAWN_DELTA_TIME
	local maxTime = CONSTANTS.STREAM_SPAWN_DELTA_TIME + CONSTANTS.STREAM_SPAWN_DELTA_TIME_RANGE

	local spawnDelta = math.random(minTime, maxTime)
	task.wait(spawnDelta)

	-- Spawn Mobs around each player
	-- warn("STREAM SPAWN MOBS")

	for _, player in ipairs(Players:GetPlayers()) do
		local state = Store:getState()
		local playerState = Selectors.PlayerState(state, player.UserId)
		local isPickingAugment = playerState.state == CONSTANTS.PLAYER_STATES.pickingAugment

		local isTargetable = not isPickingAugment and not playerState.isDead and player.Character

		if not isTargetable then
			continue
		end

		local playerPos = player.Character:GetPivot().Position
		local enemyNbr = Gears.RandomRange(CONSTANTS.STREAM_SPAWN_NBR, CONSTANTS.STREAM_SPAWN_NBR_RANGE)

		-- Spawn X Mobs
		for _ = 1, enemyNbr, 1 do
			local radius = Gears.RandomRange(CONSTANTS.SPAWN_RADIUS, CONSTANTS.SPAWN_RADIUS_RANGE)
			local progress = math.random(0, CONSTANTS.MAX_RADIANT)

			local pos = Gears.CirclePos(radius, progress)
			local pos3 = Vector3.new(playerPos.X + pos.X, playerPos.Y, playerPos.Z + pos.Y) -- Take a Circle Around each Player
			-- local spawnPos = EnemyService.GetSpawnPosition(pos3)

			EnemyService.SpawnArchetypeEnemy(Enemies.Robot, pos3)
		end
	end

	EnemyService.StreamSpawn()
end

-- #endregion

-- SERVICE

function EnemyService:KnitInit()
	print("EnemyService Init")
end

function EnemyService:KnitStart()
	EcsService = Knit.GetService("EcsService")
	ItemService = Knit.GetService("ItemService")
end

return EnemyService
