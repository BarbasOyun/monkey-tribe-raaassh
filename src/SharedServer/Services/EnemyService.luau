local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
-- local Signal = require(ReplicatedStorage.Packages._Index["sleitnick_signal@1.5.0"].signal)

local enemyParent = workspace.WeaponHit

local EcsService
local ItemService

-- ENEMY AUTHORING DATA
local enemyDef = require(ReplicatedStorage.Shared.AuthoringData.EnemyDefinitions)
local enemyStore = enemyDef.enemyStore
local enemyDefinitions = enemyDef.enemyDefinitions
local enemyPrefabs = enemyDef.enemyPrefabs

local EnemyService = Knit.CreateService({
	Name = "EnemyService",
	-- Client = {},
})

local dummySetup = function(character, entityId)
	local function onDeath(player)
		-- Feedback
		-- print(character.Name .. " Died")

		-- dismember(dummy)
		local snap = character.Torso:FindFirstChild("Snap")

		if snap then
			snap:Destroy()
		end

		task.wait(1)
		EnemyService:SpawnEnemy(enemyStore.Dummy, character:GetPivot().Position) -- Re spawn Dummy
		EcsService:RemoveEntity(entityId)
		-- TODO : DisableEntity
	end

	local unitId = EcsService.UnitSystem:getComponentId(entityId)
	EcsService.UnitSystem.deathEvent[unitId]:Connect(onDeath)
end

-- TODO : robotSetup

-- Per enemyType Spawn setup
local enemySetup = {
	dummySetup,
	-- robotSetup
}

-- #region ADD ENEMY

-- Create Enemy for already spawned Model
function EnemyService:CreateEnemy(character, enemyId)
	local entityId = EcsService:CreateEntity()

	-- warn("Create enemy : " .. character.Name .. ", TypeId = " .. enemyId .. ", EntityId = " .. entityId)

	local enemyDefinition = enemyDefinitions[enemyId]
	character.Parent = enemyParent

	-- Try to find lifeBar
	local lBar = character:FindFirstChild("LifeBar")
	local lifeBar

	if lBar then
		lifeBar = lBar.LifeBar
	end

	-- Add Components : Gameobject, Unit
	EcsService.GameobjectSystem:addComponentToEntity(entityId, character)
	EcsService.UnitSystem:addComponentToEntity(entityId, enemyId, enemyDefinition.MaxLife, lifeBar)

	-- Per Enemy type setup
	enemySetup[enemyId](character, entityId)
end

-- Spawn Model + Create Enemy
function EnemyService:SpawnEnemy(enemyId, position)
	-- Spawn Model
	local character = enemyPrefabs[enemyId]:Clone() -- TODO : Object Pooling
	character:PivotTo(CFrame.new(position))

	self:CreateEnemy(character, enemyId)
end

-- #endregion

-- #region DAMAGE + REMOVE

local function updateLifeBar(lifeBar, lifePercent)
	local usePercent = math.max(0, lifePercent)
	-- warn("Update Life Bar = " .. lifeBar.Name .. ", Percent = " .. usePercent)

	lifeBar.Size = UDim2.fromScale(usePercent, 1)
end

function EnemyService:DamageEnemy(player, entityId, humanoid, damage)
	local unitSystem = EcsService.UnitSystem
	local unitId = unitSystem:getComponentId(entityId)

	if damage <= 0 then
		return
	end

	unitSystem.life[unitId] -= damage
	local life = unitSystem.life[unitId]
	-- print(" Dealt " .. damage .. " damage to " .. humanoid.Parent.Name .. " New life : " .. life)

	-- Update Lifebar
	local definitionId = unitSystem.definitionId[unitId]
	local definition = enemyDefinitions[definitionId]
	local lifeBar = unitSystem.lifeBar[unitId]

	if lifeBar then
		local lifePercent = life / definition.MaxLife
		updateLifeBar(lifeBar, lifePercent)
	end

	if life <= 0 then
		local overKillDamage = math.abs(life)
		self:KillEnemy(player, entityId, humanoid, overKillDamage)
	end
end

function EnemyService:KillEnemy(player, entityId, humanoid, overKillDamage)
	-- TODO : Check if userId is nil -> attribute the kill to nearest Player
	-- Rewards
	ItemService:GenerateLoot(player, humanoid)

	-- UnitData
	local unitSystem = EcsService.UnitSystem
	local unitId = unitSystem:getComponentId(entityId)
	local deathEvent = unitSystem.deathEvent[unitId]

	-- Trigger Death Event
	if deathEvent then
		deathEvent:Fire(player) -- overKillDamage
	end
end

-- #endregion

-- #region ENEMY TYPE SETUP

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

		-- EnemyService:CreateEnemy(dummy, enemyStore.Dummy)
		EnemyService:CreateEnemy(dummy, 1)
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
end

return EnemyService
