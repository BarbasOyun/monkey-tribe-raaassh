local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local TeleportService = game:GetService("TeleportService")

local Gears = require(ReplicatedStorage.Shared.Gears)

local Knit = require(ReplicatedStorage.Packages.Knit)
Knit.OnStart():await()

-- Get Constants
local CONSTANTS = require(ServerScriptService.SharedServer.Constants)
local enemyDef = require(ReplicatedStorage.Shared.AuthoringData.EnemyDefinitions)
local Enemies = enemyDef.Enemies

-- Get Services
local PlayerService = Knit.GetService("PlayerService")
local RpgService = Knit.GetService("RpgService")
local AugmentsService = Knit.GetService("AugmentsService")
local EnemyService = Knit.GetService("EnemyService")
local EcsService = Knit.GetService("EcsService")
-- local ItemService = Knit.GetService("ItemService")

-- Platforms tp
local GAME_PLACE_ID = 109804031798809

-- TODO : HubState
-- Db
local isPlayerChanged = {}

local gamePlatforms = workspace.GamePlatforms

local platforms = {
	gamePlatforms.GamePlatform1.PlayerDetection,
	gamePlatforms.GamePlatform2.PlayerDetection,
	gamePlatforms.GamePlatform3.PlayerDetection,
	gamePlatforms.GamePlatform4.PlayerDetection,
}

local platformsLabels = {
	gamePlatforms.GamePlatform1.SurfacePart.SurfaceGui.TextLabel,
	gamePlatforms.GamePlatform2.SurfacePart.SurfaceGui.TextLabel,
	gamePlatforms.GamePlatform3.SurfacePart.SurfaceGui.TextLabel,
	gamePlatforms.GamePlatform4.SurfacePart.SurfaceGui.TextLabel,
}

local platformsMaxPlayers = {
	1,
	2,
	3,
	4,
}

local platformsPlayers = {
	{},
	{},
	{},
	{},
}

local playersLoadingTp = {}

-- Store
local HUNDRED_DONATION_ID = 3607471778
local THOUSAND_DONATION_ID = 3607471867

-- Weapon Spawner
-- local spawnWeaponButton = workspace.Wiki.RandomWeaponSpawner.Surface.SurfaceGui.TextButton
-- local weaponSpawnPos = workspace.Wiki.RandomWeaponSpawner.WeaponSpawnPos

-- #region PLATFORMS

local function updatePlatformLabel(platformId)
	platformsLabels[platformId].Text = "Raaassh ("
		.. #platformsPlayers[platformId]
		.. "/"
		.. platformsMaxPlayers[platformId]
		.. ")"
end

local function createGameInstance(players)
	for _, player in ipairs(players) do
		PlayerService.Client.EnteringGame:Fire(player) -- Feedback
	end

	-- Create Instance
	print("Creating new Game Instance for players :")
	print(players)

	local newCode = TeleportService:ReserveServerAsync(GAME_PLACE_ID)
	print("Reserved new server with code: " .. newCode)

	-- Join Instance
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = newCode

	task.spawn(function()
		task.wait(TeleportService:TeleportAsync(GAME_PLACE_ID, players, options))
		Gears.SplitTable(playersLoadingTp, players)
	end)
end

local function setupPlatforms()
	for i, platform in ipairs(platforms) do
		-- Player Enter Platform
		platform.Touched:Connect(function(hit)
			local player = game.Players:GetPlayerFromCharacter(hit.Parent)

			if not player or table.find(playersLoadingTp, player) or table.find(platformsPlayers[i], player) then
				return
			end

			table.insert(platformsPlayers[i], player)
			updatePlatformLabel(i)

			-- if there is enough players on the Platform -> Launch Game
			if #platformsPlayers[i] >= platformsMaxPlayers[i] then
				Gears.JoinTable(playersLoadingTp, platformsPlayers[i])
				createGameInstance(platformsPlayers[i])

				table.clear(platformsPlayers[i])
				updatePlatformLabel(i)
			end
		end)

		-- Player Leave Platform
		platform.TouchEnded:Connect(function(hit)
			local player = game.Players:GetPlayerFromCharacter(hit.Parent)

			if not player or table.find(playersLoadingTp, player) then
				return
			end

			local id = table.find(platformsPlayers[i], player)
			table.remove(platformsPlayers[i], id)
			updatePlatformLabel(i)
		end)
	end
end

-- #endregion

-- #region STORE

local productFunctions = {}

productFunctions[HUNDRED_DONATION_ID] = function(receipt, player)
	return true
end

productFunctions[THOUSAND_DONATION_ID] = function(receipt, player)
	return true
end

local function processReceipt(receiptInfo)
	local userId = receiptInfo.PlayerId
	local productId = receiptInfo.ProductId
	local player = Players:GetPlayerByUserId(userId)

	if player then
		local handler = productFunctions[productId]

		local success, result = pcall(handler, receiptInfo, player)
		if success then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		else
			error(receiptInfo)
		end
	end

	return Enum.ProductPurchaseDecision.NotProcessedYet
end

MarketplaceService.ProcessReceipt = processReceipt

-- #endregion

-- #region PLAYERS

local function safeInsert(t, element)
	if not table.find(t, element) then
		table.insert(t, element)
	end
end

local function setupPlayerService()
	PlayerService.BananasChanged:Connect(function(player, value)
		safeInsert(isPlayerChanged, player)
	end)
end

local function setupRpgService()
	RpgService.MetaUpgradesChanged:Connect(function(player, upgradeType, newUpgrade)
		safeInsert(isPlayerChanged, player)
	end)
end

-- #endregion

-- #region START

local function setupInWorldUi()
	-- In World Shared Ui
	--[[
-- Weapon Spawner
spawnWeaponButton.MouseButton1Click:Connect(function()
	local randomId = math.random(6, 8) -- TODO : Split per type item definitions
	ItemService:SpawnItem(randomId, weaponSpawnPos.CFrame.Position)
end)
]]
end

local function setupEnemies()
	-- Load Enemies
	EnemyService.AddArchetype(Enemies.Dummy)
	EnemyService.AddArchetype(Enemies.Robot)
	EcsService.CreatePools()

	-- Spawn Default Dummies
	local pos1 = Vector3.new(-3.15, 4.5, 70)
	local pos2 = Vector3.new(5.85, 4.5, 70)

	EnemyService.SpawnArchetypeEnemy(Enemies.Dummy, pos1)
	EnemyService.SpawnArchetypeEnemy(Enemies.Dummy, pos2)

	-- Spawn Test Robots
	local pos3 = Vector3.new(-3.15, 4.5, 50)
	local pos4 = Vector3.new(5.85, 4.5, 50)

	EnemyService.SpawnArchetypeEnemy(Enemies.Robot, pos3)
	EnemyService.SpawnArchetypeEnemy(Enemies.Robot, pos4)
end

Players.PlayerAdded:Connect(function(player)
	PlayerService.AddPlayer(player)

	PlayerService.GetBananasDb(player)

	-- Manual Tests
	-- local userId = player.UserId
	-- AugmentsService.AddAugment(userId, PlayerService.ModStatsStore.increasedAttackSpeed, 100)
	-- PlayerService.AddBananas(100)
	AugmentsService.GenerateAugments(player) -- FIXME : Augment service connected to player service
	RpgService.AddXpToAllPlayers(225)
	RpgService.RegisterLife(player)
	RpgService.DamagePlayer(player, 50)
end)

Players.PlayerRemoving:Connect(function(player)
	-- SaveToDb Only if Player is Changed
	local i = table.find(isPlayerChanged, player)

	if i then
		PlayerService.SaveToDb(player.UserId)
		table.remove(isPlayerChanged, i)
	end

	PlayerService.RemovePlayer(player)
end)

-- Setup Services
setupPlayerService()
setupRpgService()

-- Hub Setup
setupPlatforms()
setupEnemies()

-- #endregion
