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

function EnemyService.Dismember(character)
	local snap = character.Torso:FindFirstChild("Snap")
	if snap then
		snap.Enabled = false
	end
end

local dummyOnDeath = function(character, player)
	EnemyService.Dismember(character)

	task.wait(1)
	EnemyService.SpawnDummy(character:GetPivot().Position)
	EnemyService.ResetCharacter(character)
	task.wait()
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

--- Setup Enemy after Spawn
function EnemyService.EnemySetup(character, definitionId, entityId)
	-- warn("Enemy Setup : " .. character.Name .. " EntityID = " .. entityId)

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

	-- Spawn Dissabled Enemy
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

function EnemyService.SpawnDummy(position)
	local entityId, entityVersion = EcsService.EnableArchetypeEntity(Enemies.Dummy)

	-- Setup Gameobject Component
	local GameObjectStorage = EcsService.GetStorage(CONSTANTS.EcsStorages.gameObject)
	local dummy = GameObjectStorage.GetGameObject(entityId)

	dummy:PivotTo(CFrame.new(position))
	dummy.Parent = CONSTANTS.WEAPON_HIT_FOLDER

	-- Un Anchor parts
	for _, child in pairs(dummy:GetChildren()) do
		if child:IsA("Part") then
			child.Anchored = false
		end
	end

	-- TODO : Move to Component Storages
	dummy:SetAttribute("Version", entityVersion)

	-- Setup Unit Component
	EnemyService.EnemySetup(dummy, Enemies.Dummy, entityId)
end

-- #region UTILS

--- Reset a Character so that it can be enabled again (Object Pooling)
function EnemyService.ResetCharacter(character)
	local torso = character.Torso

	-- World Pos
	-- torso.CFrame = CFrame.new(Vector3.new(-3.15, 5, 70))
	-- character.Head.CFrame = CFrame.new(Vector3.new(3.15, 6.5, 70))
	-- character:FindFirstChild("Right Leg").CFrame = CFrame.new(Vector3.new(-2.65, 3, 70))
	-- character:FindFirstChild("Left Leg").CFrame = CFrame.new(Vector3.new(-3.65, 3, 70))
	-- character:FindFirstChild("Right Arm").CFrame = CFrame.new(Vector3.new(-1.65, 5, 70))
	-- character:FindFirstChild("Left Arm").CFrame = CFrame.new(Vector3.new(-4.65, 5, 70))

	-- Local Pos
	local characterPivot = character:GetPivot()

	torso.CFrame = characterPivot * CFrame.new(0, 0.5, 0)
	character.Head.CFrame = characterPivot * CFrame.new(0, 2, 0)
	character:FindFirstChild("Right Leg").CFrame = characterPivot * CFrame.new(0.5, -1.5, 0)
	character:FindFirstChild("Left Leg").CFrame = characterPivot * CFrame.new(-0.5, -1.5, 0)
	character:FindFirstChild("Right Arm").CFrame = characterPivot * CFrame.new(1.5, 0.5, 0)
	character:FindFirstChild("Left Arm").CFrame = characterPivot * CFrame.new(-1.5, 0.5, 0)

	local snap = torso:FindFirstChild("Snap")

	if snap then
		snap.Enabled = true
	end
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

	-- Spawn Archetypes
	EnemyService.AddArchetype(Enemies.Dummy)
	-- EnemyService.AddArchetype(Enemies.Robot)

	EcsService.CreatePools()

	-- Enable Default Dummies -> Hub Only
	local pos1 = Vector3.new(-3.15, 4.5, 70)
	local pos2 = Vector3.new(5.85, 4.5, 70)

	EnemyService.SpawnDummy(pos1)
	-- EnemyService.SpawnDummy(pos2)
end

return EnemyService
