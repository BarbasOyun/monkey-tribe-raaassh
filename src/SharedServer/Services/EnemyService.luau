local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local EnemyDefinitions = require(ReplicatedStorage.Shared.AuthoringData.EnemyDefinitions)
-- local Signal = require(ReplicatedStorage.Packages._Index["sleitnick_signal@1.5.0"].signal)

-- Get Constants
local CONSTANTS = require(ServerScriptService.SharedServer.Constants)

local enemyDef = require(ReplicatedStorage.Shared.AuthoringData.EnemyDefinitions)
local Enemies = enemyDef.Enemies
local EnemiesDefinitions = enemyDef.EnemiesDefinitions
local EnemiesPrefabs = enemyDef.EnemiesPrefabs

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

-- #region ENEMY TYPES SETUP

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

local dummyOnDeath = function(character, player)
	EnemyService.Dismember(character)

	task.wait(1)
	EnemyService.SpawnDummy(character:GetPivot().Position)
	EcsService.DisableEntity(character:GetAttribute("EntityId"))
end

local robotOnDeath = EnemyService.Dismember

local enemiesOnDeath = {
	dummyOnDeath,
	robotOnDeath,
}

--- Archetype Dummy Setup
local dummySetup = function(character, entityId)
	-- warn("Dummy Setup : " .. character.Name .. " EntityID = " .. entityId)

	-- LifeBar
	local lifeBar = EnemyService.TryToFindLifeBar(character)
	local billboardGui = lifeBar.Parent

	EnemyService.UpdateLifeBar(lifeBar, 1)

	-- Force Re render of lifebar
	billboardGui.Enabled = false
	task.spawn(function()
		task.wait()
		billboardGui.Enabled = true
	end)
end

local robotSetup = nil

-- Per enemyType Spawn setup
local enemiesSetup = {
	dummySetup,
	robotSetup,
}

--- Setup Enemy OnSpawn
function EnemyService.EnemySetup(character, definitionId, entityId)
	-- warn("Enemy Setup : " .. character.Name .. " EntityID = " .. entityId)

	EnemyService.ResetCharacter(character)

	local UnitStorage = EcsState.storages[CONSTANTS.EcsStorages.unit]
	local UnitStorageState = UnitStorage.GetState()

	-- Life
	local maxLife = EnemiesDefinitions[Enemies.Robot].MaxLife
	UnitStorageState.life[entityId] = maxLife

	-- OnDeath
	local deathEvent = UnitStorageState.deathEvent[entityId]
	deathEvent:DisconnectAll()

	-- Per Enemy Type on Death
	local enemyOnDeathEvent = enemiesOnDeath[definitionId]

	if enemyOnDeathEvent then
		deathEvent:Connect(enemyOnDeathEvent)
	end

	enemiesSetup[definitionId](character, entityId)
end

-- Archetypes Setup

--- GameObject Component Archetype Setup for every Enemy
local gameObjectSetup = function(entityId, definitionId)
	-- warn("Archetype Setup : Game Object")

	-- Spawn Disabled Enemy
	local enemy = EnemiesPrefabs[definitionId]:Clone()

	local GameObjectStorage = EcsState.storages[CONSTANTS.EcsStorages.gameObject]
	GameObjectStorage.AddComponentToEntity(EcsState, entityId, enemy)
	GameObjectStorage.DisableEntity(entityId)
end

--- Unit Component Archetype Setup for every Enemy
local unitSetup = function(entityId, definitionId)
	local enemyDefinition = EnemiesDefinitions[definitionId]
	local unitStorage = EcsState.storages[CONSTANTS.EcsStorages.unit]

	unitStorage.AddComponentToEntity(EcsState, entityId, Enemies.Dummy, enemyDefinition.MaxLife)
end

--- Additional Unit Setup for Dummies (LifeBar)
local dummySetupUnit = function(entityId)
	unitSetup(entityId, Enemies.Dummy)

	local unitStorage = EcsState.storages[CONSTANTS.EcsStorages.unit]
	local unitStorageState = unitStorage.GetState()

	-- Get GameObject
	local GameObjectStorage = EcsState.storages[CONSTANTS.EcsStorages.gameObject]
	local dummy = GameObjectStorage.GetGameObject(entityId)

	local lifeBar = EnemyService.TryToFindLifeBar(dummy)

	unitStorageState.lifeBar[entityId] = lifeBar
end

local dummyArchetypeSetup = {
	gameObjectSetup,
	dummySetupUnit,
}

local robotArchetypeSetup = {
	gameObjectSetup,
	unitSetup,
}

local enemiesArchetypeSetup = {
	dummyArchetypeSetup,
	robotArchetypeSetup,
}

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
---@param definitionId any = EnemyID
function EnemyService.AddArchetype(definitionId)
	-- Dummy
	local archetype = EnemyDefinitions.Archetypes[definitionId]
	archetype.setup = enemiesArchetypeSetup[definitionId]

	EcsService.AddArchetype(archetype)
end

--- Spawn Dummy by Enabling an Entity in Dummy ECS Archetype
function EnemyService.SpawnDummy(position)
	local entityId, entityVersion = EcsService.EnableArchetypeEntity(Enemies.Dummy)

	-- Setup Gameobject Component
	local GameObjectStorage = EcsService.GetStorage(CONSTANTS.EcsStorages.gameObject)
	local GameObjectStorageState = GameObjectStorage.GetState()
	local dummy = GameObjectStorageState.gameObjects[entityId]

	dummy.Name = "Dummy" .. entityId

	dummy:PivotTo(CFrame.new(position))
	dummy.Parent = CONSTANTS.WEAPON_HIT_FOLDER

	-- TODO : Move to Component Storages
	dummy:SetAttribute("Version", entityVersion)

	-- Setup Unit Component
	EnemyService.EnemySetup(dummy, Enemies.Dummy, entityId)

	-- Un Anchor parts
	EnemyService.AnchorModel(dummy, false)
end

-- #endregion

-- #region UTILS

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
	local lifeBar

	if lBar then
		lifeBar = lBar.LifeBar
	end

	return lifeBar
end

-- #endregion

-- #region DAMAGE + DEATH

function EnemyService.UpdateLifeBar(lifeBar, lifePercent)
	local usePercent = math.max(0, lifePercent)
	-- warn("Update Life Bar = " .. lifeBar.Name .. ", Percent = " .. usePercent)

	lifeBar.Size = UDim2.fromScale(usePercent, 1)
end

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

	-- Update Lifebar
	local definitionId = unitStorageState.definitionId[unitId]
	local definition = EnemiesDefinitions[definitionId]
	local lifeBar = unitStorageState.lifeBar[unitId]

	if lifeBar then
		local lifePercent = life / definition.MaxLife
		EnemyService.UpdateLifeBar(lifeBar, lifePercent)
	end

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
