local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages._Index["sleitnick_signal@1.5.0"].signal)

local EnemyService = Knit.CreateService({
	Name = "EnemyService",
	-- Client = {},
})

local enemyParent = workspace.WeaponHit

local ItemService = nil

-- ENEMY AUTHORING DATA
local enemyDef = require(ReplicatedStorage.Shared.AuthoringData.EnemyDefinitions)
local enemyStore = enemyDef.enemyStore
local enemyDefinitions = enemyDef.enemyDefinitions
local enemyPrefabs = enemyDef.enemyPrefabs

-- ECS
-- TODO : Implement ECS
-- Instead of using Rodux store
-- TODO : Use smart ID instead of Humanoid as key

-- Per enemy property
-- local ids = {}
-- local versions = {}
local life = {}
local lifeBar = {}
local deathEvent = {}

-- Per enemyType Spawn setup
local enemySetup = {
	-- 1 = Dummy
	function(character, humanoid)
		local function onDeath(player)
			-- Feedback
			print(character.Name .. " Died")

			-- dismember(dummy)
			local snap = character.Torso.Snap

			if snap then
				snap:Destroy()
			end

			task.wait(1)
			EnemyService:SpawnEnemy(enemyStore.Dummy, character:GetPivot().Position) -- Re spawn Dummy
			character:Destroy()
		end

		deathEvent[humanoid]:Connect(onDeath)
	end,
	-- 2 = Robot
}

-- ADD ENEMY

-- Create Enemy for already spawned Model
function EnemyService:CreateEnemy(character, enemyId)
	local enemyDefinition = enemyDefinitions[enemyId]
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	character.Parent = enemyParent

	life[humanoid] = enemyDefinition.MaxLife
	deathEvent[humanoid] = Signal.new()

	-- Try to find lifeBar
	local lBar = character:FindFirstChild("LifeBar")
	if lBar then
		lifeBar[humanoid] = lBar.LifeBar
	end

	-- Per Enemy type setup
	enemySetup[enemyId](character, humanoid)
end

-- Spawn Model + Create Enemy
function EnemyService:SpawnEnemy(enemyId, position)
	local character = enemyPrefabs[enemyId]:Clone() -- TODO : Object Pooling
	character:PivotTo(CFrame.new(position))
	self:CreateEnemy(character, enemyId)
end

-- DAMAGE + REMOVE

function EnemyService:DamageEnemy(player, humanoid, damage)
	if not life[humanoid] or damage <= 0 then
		return
	end

	local enemyId = humanoid.Parent:GetAttribute("DefinitionID")
	local definition = enemyDefinitions[enemyId]

	life[humanoid] -= damage

	local life = life[humanoid]

	-- print(" Dealt " .. damage .. " damage to " .. humanoid.Parent.Name .. " New life : " .. life)

	if lifeBar[humanoid] then
		local lifePercent = life / definition.MaxLife
		lifeBar[humanoid].Size = UDim2.fromScale(lifePercent, 1)
	end

	if life <= 0 then
		local overKillDamage = math.abs(life)
		self:KillEnemy(player, humanoid, overKillDamage)
	end
end

function EnemyService:KillEnemy(player, humanoid, overKillDamage)
	-- TODO : Check if userId is nil -> attribute the kill to nearest Player
	-- Rewards
	ItemService:GenerateLoot(player, humanoid)

	life[humanoid] = nil

	if lifeBar[humanoid] then
		lifeBar[humanoid] = nil
	end

	deathEvent[humanoid]:Fire(player) -- overKillDamage

	deathEvent[humanoid] = nil
end

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
		-- Avoid setuping Prefabs
		if not dummy:IsDescendantOf(workspace) then
			continue
		end

		EnemyService:CreateEnemy(dummy, enemyStore.Dummy)
	end
end

-- SERVICE

function EnemyService:KnitInit()
	print("EnemyService Init")
end

function EnemyService:KnitStart()
	ItemService = Knit.GetService("ItemService")

	setupAllDummies()
end

return EnemyService
