local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages._Index["sleitnick_signal@1.5.0"].signal)

local enemyParent = workspace.WeaponHit

local EcsService
local ItemService

-- ENEMY AUTHORING DATA
local enemyDef = require(ReplicatedStorage.Shared.AuthoringData.EnemyDefinitions)
local enemyStore = enemyDef.enemyStore
local enemyDefinitions = enemyDef.enemyDefinitions
local enemyPrefabs = enemyDef.enemyPrefabs

-- Per enemy property
-- local life = {}
-- local lifeBar = {}
-- local deathEvent = {}

local EnemyService = Knit.CreateService({
	Name = "EnemyService",
	-- Client = {},
})

local dummySetup = function(character, entityId)
	local function onDeath(player)
		-- Feedback
		-- print(character.Name .. " Died")

		-- dismember(dummy)
		local snap = character.Torso.Snap

		if snap then
			snap:Destroy()
		end

		task.wait(1)
		EnemyService:SpawnEnemy(enemyStore.Dummy, character:GetPivot().Position) -- Re spawn Dummy
		character:Destroy()
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

-- ADD ENEMY

-- Create Enemy for already spawned Model
function EnemyService:CreateEnemy(character, enemyId)
	local entityId = EcsService:CreateEntity()

	local enemyDefinition = enemyDefinitions[enemyId]
	-- local humanoid = character:FindFirstChildOfClass("Humanoid")

	character.Parent = enemyParent

	-- life[humanoid] = enemyDefinition.MaxLife
	-- deathEvent[humanoid] = Signal.new()

	-- Try to find lifeBar
	local lBar = character:FindFirstChild("LifeBar")
	-- if lBar then
	-- 	lifeBar[humanoid] = lBar.LifeBar
	-- end

	-- Add GameObject Component
	EcsService.GameobjectSystem:addComponentToEntity(entityId, character)

	-- Add Unit Component
	EcsService.UnitSystem:addComponentToEntity(entityId, enemyDefinition.MaxLife, lBar, Signal.new())

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

-- #region DAMAGE + REMOVE

-- function EnemyService:DamageEnemy(player, humanoid, damage)
-- 	if not life[humanoid] or damage <= 0 then
-- 		return
-- 	end

-- 	local enemyId = humanoid.Parent:GetAttribute("DefinitionID")
-- 	local definition = enemyDefinitions[enemyId]

-- 	life[humanoid] -= damage

-- 	local life = life[humanoid]

-- 	-- print(" Dealt " .. damage .. " damage to " .. humanoid.Parent.Name .. " New life : " .. life)

-- 	if lifeBar[humanoid] then
-- 		local lifePercent = life / definition.MaxLife
-- 		lifeBar[humanoid].Size = UDim2.fromScale(lifePercent, 1)
-- 	end

-- 	if life <= 0 then
-- 		local overKillDamage = math.abs(life)
-- 		self:KillEnemy(player, humanoid, overKillDamage)
-- 	end
-- end

local function updateLifeBar(lifeBar, lifePercent)
	lifeBar.Size = UDim2.fromScale(lifePercent, 1)
end

function EnemyService:DamageEnemy(player, entityId, damage)
	local unitSystem = EcsService.UnitSystem
	local unitId = unitSystem:getComponentId(entityId)

	local life = unitSystem.life[unitId]

	if not life or damage <= 0 then
		return
	end

	local definition = enemyDefinitions[unitSystem.definitionId[unitId]]
	local lifeBar = unitSystem.lifeBar[unitId]

	life -= damage

	-- print(" Dealt " .. damage .. " damage to " .. humanoid.Parent.Name .. " New life : " .. life)

	if lifeBar then
		local lifePercent = life / definition.MaxLife
		updateLifeBar(lifePercent)
	end

	if life <= 0 then
		local overKillDamage = math.abs(life)
		self:KillEnemy(player, unitId, overKillDamage)
	end
end

-- function EnemyService:KillEnemy(player, humanoid, overKillDamage)
-- 	-- TODO : Check if userId is nil -> attribute the kill to nearest Player
-- 	-- Rewards
-- 	ItemService:GenerateLoot(player, humanoid)

-- 	life[humanoid] = nil

-- 	if lifeBar[humanoid] then
-- 		lifeBar[humanoid] = nil
-- 	end

-- 	if deathEvent[humanoid] then
-- 		deathEvent[humanoid]:Fire(player) -- overKillDamage
-- 	end

-- 	deathEvent[humanoid] = nil
-- end

function EnemyService:KillEnemy(player, entityId, overKillDamage)
	-- TODO : Check if userId is nil -> attribute the kill to nearest Player
	-- Rewards
	ItemService:GenerateLoot(player, entityId)

	-- UnitData
	local unitSystem = EcsService.UnitSystem
	local unitId = unitSystem:getComponentId(entityId)
	local deathEvent = unitSystem.deathEvent[unitId]

	-- Trigger Death Event
	if deathEvent[unitId] then
		deathEvent[unitId]:Fire(player) -- overKillDamage
	end

	EcsService:DisableEntity(entityId)
end

-- #endregion

-- ENEMY TYPE SETUP

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

		warn("Setup Dummy : " .. dummy.Name)

		-- EnemyService:CreateEnemy(dummy, enemyStore.Dummy)
		EnemyService:CreateEnemy(dummy, 1)
	end
end

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
