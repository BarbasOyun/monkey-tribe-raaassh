local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- local Gears = require(ReplicatedStorage.Shared.Gears)

-- Get Constants
local CONSTANTS = require(ServerScriptService.SharedServer.Constants)
local EnemyConst = CONSTANTS.EnemyConst
local Enemies = EnemyConst.Enemies

local CategoryStore = CONSTANTS.CategoryStore
local CategoryRegistries = CONSTANTS.CategoryRegistries

-- Get Services
local Knit = require(ReplicatedStorage.Packages.Knit)
Knit.OnStart():await()

local PlayerService = Knit.GetService("PlayerService")
local LevelService = Knit.GetService("LevelService")

local RpgService = Knit.GetService("RpgService")
local AugmentsService = Knit.GetService("AugmentsService")

local EnemyService = Knit.GetService("EnemyService")
local ItemService = Knit.GetService("ItemService")

local function createPools()
	-- Create ItemsPools : SmallXpOrb + Banana
	ItemService.CreatePool(CategoryRegistries[CategoryStore.Usable].SmallXpOrb, 300)
	ItemService.CreatePool(CategoryRegistries[CategoryStore.Usable].Banana, 300)
	ItemService.CreatePool(CategoryRegistries[CategoryStore.Usable].Stick, 50)

	-- Load Enemies
	EnemyService.CreatePool(Enemies.Robot, 100)
end

local function onCharacterAdded(player, character)
	-- Set Player Dead when Humanoid Die
	local humanoid = character:WaitForChild("Humanoid")

	humanoid.Died:Connect(function()
		PlayerService.SetPlayerDead(player)
	end)
end

local function setupPlayers()
	Players.PlayerAdded:Connect(function(player)
		PlayerService.AddPlayer(player)

		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)

		player:LoadCharacterAsync()

		PlayerService.GetMetaUpgrades(player)
		AugmentsService.GenerateAugments(player)

		RpgService.RegisterLife(player)
		PlayerService.SetupGameOver(player)
	end)

	Players.PlayerRemoving:Connect(PlayerService.RemovePlayer)
end

local function setupLevel()
	-- Set Map Limits
	local minLimitPart = workspace.Map.Limits.MinLimit
	local maxLimitPart = workspace.Map.Limits.MaxLimit

	local minLimit = LevelService.ToFlatVector(minLimitPart.CFrame.Position)
	local maxLimit = LevelService.ToFlatVector(maxLimitPart.CFrame.Position)

	LevelService.SetLimits(minLimit, maxLimit)
end

local function startStage()
	-- LevelService.StartStage(1, 10)
	LevelService.StartRandomStage()
end

local function setupEnemies()
	EnemyService.StartEnemyUpdate()

	-- Start Spawning Mobs
	EnemyService.StartStreamSpawn()
	EnemyService.StartMobBehavior()
end

-- #region START

Players.CharacterAutoLoads = false
LevelService.LoadLevelDefinitions()

setupPlayers()
setupLevel()
createPools()
setupEnemies()

LevelService.StartGameTimer()
startStage()

-- #endregion
