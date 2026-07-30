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
local ecsState = MutState.ecsState

-- Get Services
local EcsService
local ItemService

local EnemyService = Knit.CreateService({
	Name = "EnemyService",
	-- Client = {},
})

-- Archetype less dummy setup
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
	local gameObjectStorage = ecsState.storages[CONSTANTS.STORAGE_STORE.gameObject]

	local unitStorage = ecsState.storages[CONSTANTS.STORAGE_STORE.unit]
	local unitStorageState = unitStorage.GetState()
	local unitId = unitStorage.GetComponentId(unitStorageState, entityId)

	-- Setup LifeBar
	local dummy = gameObjectStorage.GetGameObject(entityId)
	local lifeBar = EnemyService.TryToFindLifeBar(dummy)
	unitStorageState.lifeBar[unitId] = lifeBar

	-- Setup OnDeath
	unitStorageState.deathEvent[unitId]:Connect(onDeath)
end
]]

-- Archetype Dummy Setup
local dummySetup = function(character, entityId)
	-- warn("Dummy Setup : " .. character.Name .. " EntityID = " .. entityId)

	local function onDeath(player)
		-- Feedback
		-- print(character.Name .. " Died")

		-- dismember(dummy)
		local snap = character.Torso:FindFirstChild("Snap")
		if snap then
			snap:Destroy()
		end

		task.wait(1)
		EnemyService.SpawnDummy(character:GetPivot().Position)
		EcsService.DisableEntity(character:GetAttribute("EntityId"))
	end

	local unitStorage = ecsState.storages[CONSTANTS.STORAGE_STORE.unit]
	local unitStorageState = unitStorage.GetState()

	-- Setup Life + LifeBar
	unitStorageState.life[entityId] = EnemiesDefinitions[Enemies.Dummy].MaxLife

	local lifeBar = EnemyService.TryToFindLifeBar(character)
	local billboardGui = lifeBar.Parent

	EnemyService.UpdateLifeBar(lifeBar, 1)

	-- Force Re render of lifebar
	billboardGui.Enabled = false
	task.spawn(function()
		task.wait(0.1)
		billboardGui.Enabled = true
	end)

	-- Setup OnDeath
	local deathEvent = unitStorageState.deathEvent[entityId]
	deathEvent:DisconnectAll()
	deathEvent:Connect(onDeath)
end

-- TODO : robotSetup

-- Per enemyType Spawn setup
local enemySetup = {
	dummySetup,
	-- robotSetup
}

local dummySetupGameObject = function(entityId)
	-- warn("Dummy Archetype Setup : Game Object")

	-- Spawn Disabled Model
	local dummy = EnemiesPrefabs[Enemies.Dummy]:Clone()
	dummy.Name = "Dummy3"
	dummy.Parent = CONSTANTS.DISABLED_ENTITIES_FOLDER

	local gameObjectStorage = ecsState.storages[CONSTANTS.STORAGE_STORE.gameObject]
	gameObjectStorage.AddComponentToEntity(ecsState, entityId, dummy)
end

local dummySetupUnit = function(entityId)
	local dummyDefinition = EnemiesDefinitions[Enemies.Dummy]
	local unitStorage = ecsState.storages[CONSTANTS.STORAGE_STORE.unit]

	-- Get GameObject
	local gameObjectStorage = ecsState.storages[CONSTANTS.STORAGE_STORE.gameObject]
	local gameObjectStorageState = gameObjectStorage.GetState()
	local gameObjectId = gameObjectStorage.GetComponentId(gameObjectStorageState, entityId)

	local dummy = ecsState.gameObjectStorageState.gameObjects[gameObjectId]

	local lifeBar = EnemyService.TryToFindLifeBar(dummy)

	unitStorage.AddComponentToEntity(ecsState, entityId, Enemies.Dummy, dummyDefinition.MaxLife, lifeBar)
end

local dummyArchetypeSetup = {
	dummySetupGameObject,
	dummySetupUnit,
}

local enemiesArchetypeSetup = {
	dummyArchetypeSetup,
}

-- #region SPAWN ENEMY

-- Spawn New Model + Create Enemy
function EnemyService.SpawnEnemy(enemyId, position)
	-- Spawn Model
	local character = EnemiesPrefabs[enemyId]:Clone()
	character:PivotTo(CFrame.new(position))
	character.Name = "Dummy3"

	EnemyService.CreateEnemy(character, enemyId)
end

-- Create Enemy for already spawned Model
function EnemyService.CreateEnemy(character, enemyId)
	local entityId = EcsService.CreateEntity()

	-- warn("Create enemy : " .. character.Name .. ", TypeId = " .. enemyId .. ", EntityId = " .. entityId)

	local enemyDefinition = EnemiesDefinitions[enemyId]
	character.Parent = CONSTANTS.WEAPON_HIT_FOLDER

	-- Add Components : Gameobject, Unit
	local gameObjectStorage = ecsState.storages[CONSTANTS.STORAGE_STORE.gameObject]
	local unitStorage = ecsState.storages[CONSTANTS.STORAGE_STORE.unit]

	gameObjectStorage.AddComponentToEntity(ecsState, entityId, character)
	unitStorage.AddComponentToEntity(ecsState, entityId, enemyId, enemyDefinition.MaxLife)

	-- Per Enemy type setup
	enemySetup[enemyId](character, entityId)
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
	local unitStorage = ecsState.storages[CONSTANTS.STORAGE_STORE.unit]
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
	local unitStorage = ecsState.storages[CONSTANTS.STORAGE_STORE.unit]
	local unitStorageState = unitStorage.GetState()

	local unitId = unitStorage.GetComponentId(unitStorageState, entityId)
	local deathEvent = unitStorageState.deathEvent[unitId]

	-- Trigger Death Event
	if deathEvent then
		-- warn("Death Event : EntityID  = " .. entityId .. " UnitID = " .. unitId)
		deathEvent:Fire(player) -- overKillDamage
	end
end

-- #endregion

-- #region ENEMY SETUP

-- TODO : Move
local function dismember(character)
	print("Dismember : " .. character.Name)
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("Motor6D") then
			print("Delete Motor6D")
			descendant:Destroy()
		end
	end
end

-- Use ECS to Spawn an Archetype (Object Pooling)
function EnemyService.SpawnArchetype(enemyId)
	local archetype = EnemyDefinitions.Archetypes[enemyId]
	archetype.setup = enemiesArchetypeSetup[enemyId]

	EcsService.AddArchetype(archetype)
	EcsService.CreatePools()
end

function EnemyService.SpawnDummy(position)
	local entityId, entityVersion = EcsService.EnableArchetypeEntity(Enemies.Dummy)

	-- Setup Gameobject Component
	local gameObjectStorage = EcsService.GetStorage(CONSTANTS.STORAGE_STORE.gameObject)
	local dummy = gameObjectStorage.GetGameObject(entityId)

	dummy:PivotTo(CFrame.new(position))
	dummy.Parent = CONSTANTS.WEAPON_HIT_FOLDER

	-- TODO : Move to GameobjectStorage
	-- dummy:SetAttribute("EntityId", entityId)
	dummy:SetAttribute("Version", entityVersion)

	-- Setup Unit Component
	-- local untitStorage = EcsService.GetStorage(CONSTANTS.STORAGE_STORE.unit)
	-- local unitId = untitStorage.GetComponentId(untitStorage.GetState(), entityId)
	dummySetup(dummy, entityId)
end

-- #endregion

-- SERVICE

function EnemyService:KnitInit()
	print("EnemyService Init")
end

function EnemyService:KnitStart()
	EcsService = Knit.GetService("EcsService")
	ItemService = Knit.GetService("ItemService")

	-- Spawn Archetypes
	EnemyService.SpawnArchetype(Enemies.Dummy)

	-- Enable Default Dummies -> Hub Only
	-- local pos = Vector3.new(0, 4.5, 0)
	local pos1 = Vector3.new(-3.15, 4.5, 70)
	local pos2 = Vector3.new(5.85, 4.5, 70)

	EnemyService.SpawnDummy(pos1)
	EnemyService.SpawnDummy(pos2)
end

return EnemyService
