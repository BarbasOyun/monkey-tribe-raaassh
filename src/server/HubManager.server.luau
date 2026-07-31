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
-- local ItemService = Knit.GetService("ItemService")

-- Enemies to load for this place
-- local enemyList = {
-- 	"Dummy",
-- }

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
local hundredDonationId = 3607471778
local thousandDonationId = 3607471867

local productFunctions = {}

-- World Enemies
-- local dummy1 = workspace.WeaponHit.Dummy1
-- local dummy2 = workspace.WeaponHit.Dummy2

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
		Gears.splitTable(playersLoadingTp, players)
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
				Gears.joinTable(playersLoadingTp, platformsPlayers[i])
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

productFunctions[hundredDonationId] = function(receipt, player)
	return true
end

productFunctions[thousandDonationId] = function(receipt, player)
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

-- DO

Players.PlayerAdded:Connect(function(player)
	PlayerService.AddPlayer(player)

	PlayerService.GetBananasDb(player)

	-- Manual Tests
	-- local userId = player.UserId
	-- AugmentsService.AddAugment(userId, PlayerService.ModStatsStore.increasedAttackSpeed, 100)
	-- PlayerService.AddBananas(100)
	AugmentsService.GenerateAugments(player)
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

setupPlayerService()
setupRpgService()
setupPlatforms()

-- Setup Enemies
-- warn("Setup Dummies")
-- EnemyService.CreateEnemy(dummy1, Enemies.Dummy)
-- EnemyService.CreateEnemy(dummy2, Enemies.Dummy)

-- In World Shared Ui
--[[
-- Weapon Spawner
spawnWeaponButton.MouseButton1Click:Connect(function()
	local randomId = math.random(6, 8) -- TODO : Split per type item definitions
	ItemService:SpawnItem(randomId, weaponSpawnPos.CFrame.Position)
end)
]]
