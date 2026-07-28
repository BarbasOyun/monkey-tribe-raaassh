local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local EnemyDefinitions = require(ReplicatedStorage.Shared.AuthoringData.EnemyDefinitions)
-- local Signal = require(ReplicatedStorage.Packages._Index["sleitnick_signal@1.5.0"].signal)

-- Get Services
local EcsService
local ItemService

-- Get Constants
local CONSTANTS = require(ServerScriptService.SharedServer.Constants)

local enemyDef = require(ReplicatedStorage.Shared.AuthoringData.EnemyDefinitions)
local Enemies = enemyDef.Enemies
local EnemiesDefinitions = enemyDef.EnemiesDefinitions
local EnemiesPrefabs = enemyDef.EnemiesPrefabs

-- Get Mutable State
local MutState = require(ServerScriptService.SharedServer.MutableState)
local ecsState = MutState.ecsState

local EnemyService = Knit.CreateService({
	Name = "EnemyService",
	-- Client = {},
})

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
		-- TODO : DisableEntity
	end

	local unitStorage = ecsState.storages[CONSTANTS.STORAGE_STORE.unit]
	local unitStorageState = unitStorage.getState()

	local unitId = unitStorage.getComponentId(unitStorageState, entityId)
	unitStorageState.deathEvent[unitId]:Connect(onDeath)
end

-- TODO : robotSetup

-- Per enemyType Spawn setup
local enemySetup = {
	dummySetup,
	-- robotSetup
}

-- #region SPAWN ENEMY

-- Create Enemy for already spawned Model
function EnemyService.CreateEnemy(character, enemyId)
	local entityId = EcsService.CreateEntity()

	-- warn("Create enemy : " .. character.Name .. ", TypeId = " .. enemyId .. ", EntityId = " .. entityId)

	local enemyDefinition = EnemiesDefinitions[enemyId]
	character.Parent = CONSTANTS.WEAPON_HIT_FOLDER

	-- Try to find lifeBar
	local lBar = character:FindFirstChild("LifeBar")
	local lifeBar

	if lBar then
		lifeBar = lBar.LifeBar
	end

	-- Add Components : Gameobject, Unit
	local gameObjectStorage = ecsState.storages[CONSTANTS.STORAGE_STORE.gameObject]
	local unitStorage = ecsState.storages[CONSTANTS.STORAGE_STORE.unit]

	gameObjectStorage.addComponentToEntity(ecsState, entityId, character)
	unitStorage.addComponentToEntity(ecsState, entityId, enemyId, enemyDefinition.MaxLife, lifeBar)

	-- Per Enemy type setup
	enemySetup[enemyId](character, entityId)
end

-- Spawn Model + Create Enemy
function EnemyService.SpawnEnemy(enemyId, position)
	-- Spawn Model
	local character = EnemiesPrefabs[enemyId]:Clone() -- TODO : Object Pooling
	character:PivotTo(CFrame.new(position))
	character.Name = "Dummy3"

	EnemyService.CreateEnemy(character, enemyId)
end

-- #endregion

-- #region DAMAGE + DEATH

local function updateLifeBar(lifeBar, lifePercent)
	local usePercent = math.max(0, lifePercent)
	-- warn("Update Life Bar = " .. lifeBar.Name .. ", Percent = " .. usePercent)

	lifeBar.Size = UDim2.fromScale(usePercent, 1)
end

function EnemyService.DamageEnemy(player, entityId, humanoid, damage)
	local unitStorage = ecsState.storages[CONSTANTS.STORAGE_STORE.unit]
	local unitStorageState = unitStorage.getState()
	local unitId = unitStorage.getComponentId(unitStorageState, entityId)

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
		updateLifeBar(lifeBar, lifePercent)
	end

	if life <= 0 then
		local overKillDamage = math.abs(life)
		EnemyService.KillEnemy(player, entityId, humanoid, overKillDamage)
	end
end

function EnemyService.KillEnemy(player, entityId, humanoid, overKillDamage)
	-- TODO : Check if userId is nil -> attribute the kill to nearest Player
	-- Rewards
	ItemService:GenerateLoot(player, humanoid)

	-- UnitData
	local unitStorage = ecsState.storages[CONSTANTS.STORAGE_STORE.unit]
	local unitStorageState = unitStorage.getState()

	local unitId = unitStorage.getComponentId(unitStorageState, entityId)
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

-- TODO : Setup Enemy / Type
-- enemyId
local function setupAllDummies()
	-- Setup Existing Dummies
	for _, dummy in pairs(CollectionService:GetTagged("Dummy")) do
		-- Skip Prefabs
		if not dummy:IsDescendantOf(workspace) then
			continue
		end

		EnemyService.CreateEnemy(dummy, Enemies.Dummy)
	end
end

-- #endregion

-- SERVICE

function EnemyService:KnitInit()
	print("EnemyService Init")
end

function EnemyService:KnitStart()
	EcsService = Knit.GetService("EcsService")
	ItemService = Knit.GetService("ItemService")

	setupAllDummies()

	-- TOOD : Add Archetypes
	EcsService.AddArchetype(EnemyDefinitions.Archetypes[Enemies.Dummy])
	EcsService.CreatePools()
end

return EnemyService
