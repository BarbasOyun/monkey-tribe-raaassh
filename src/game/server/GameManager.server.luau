local Players = game:GetService("Players")
-- local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

-- local Gears = require(ReplicatedStorage.Shared.Gears)

-- Get Constants
-- local CONSTANTS = require(ServerScriptService.SharedServer.Constants)
local enemyDef = require(ReplicatedStorage.Shared.AuthoringData.EnemyDefinitions)
local Enemies = enemyDef.Enemies

-- Get Services
local Knit = require(ReplicatedStorage.Packages.Knit)
Knit.OnStart():await()

local PlayerService = Knit.GetService("PlayerService")
local LevelService = Knit.GetService("LevelService")

local RpgService = Knit.GetService("RpgService")
local AugmentsService = Knit.GetService("AugmentsService")

local EcsService = Knit.GetService("EcsService")
local EnemyService = Knit.GetService("EnemyService")
-- local ItemService = Knit.GetService("ItemService")

-- TODO : PlayerService:AddPlayer
-- On Player Death
-- player:LoadCharacterAsync()
-- local character = player.Character
-- character.Humanoid.Died:Connect(function()
-- 	self:OnPlayerDeath(player)
-- end)

local function setupPlayers()
	Players.PlayerAdded:Connect(function(player)
		PlayerService.SetupGameOver(player)

		PlayerService.AddPlayer(player)
		PlayerService.GetMetaUpgrades(player)
		AugmentsService.GenerateAugments(player)

		RpgService.RegisterLife(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		PlayerService.RemovePlayer(player)
	end)
end

local function setupLevel()
	LevelService.LoadLevelDefinitions()

	-- Set Map Limits
	local minLimitPart = workspace.Map.Limits.MinLimit
	local maxLimitPart = workspace.Map.Limits.MaxLimit

	local minLimit = LevelService.ToFlatVector(minLimitPart.CFrame.Position)
	local maxLimit = LevelService.ToFlatVector(maxLimitPart.CFrame.Position)

	LevelService.SetLimits(minLimit, maxLimit)
end

local function setupEnemies()
	-- Load Enemies
	EnemyService.AddArchetype(Enemies.Robot)
	EcsService.CreatePools()

	-- Start Spawning Mobs
	EnemyService.StartStreamSpawn()
	-- EnemyService.StartMobBehavior()
	-- LevelService.StartGameTimer()

	-- Start Stage
	LevelService.StartStage()
end

-- #region START

setupPlayers()
setupLevel()
setupEnemies()

-- #endregion
