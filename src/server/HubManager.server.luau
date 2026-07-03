local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MarketplaceService = game:GetService("MarketplaceService")

local Knit = require(ReplicatedStorage.Packages.Knit)
Knit.OnStart():await()

local PlayerService = Knit.GetService("PlayerService")
-- local ItemService = Knit.GetService("ItemService")

-- Enemies to load for this place
-- local enemyList = {
-- 	"Dummy",
-- }

-- Weapon Spawner
-- local spawnWeaponButton = workspace.Wiki.RandomWeaponSpawner.Surface.SurfaceGui.TextButton
-- local weaponSpawnPos = workspace.Wiki.RandomWeaponSpawner.WeaponSpawnPos

-- Store
local hundredDonationId = 3607471778
local thousandDonationId = 3607471867

-- Authoring Logic
local productFunctions = {}

-- STORE

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

Players.PlayerAdded:Connect(function(player)
	PlayerService:AddPlayer(player, player.Name)

	-- Manual Tests
	local userId = player.UserId
	PlayerService:AddAugment(userId, PlayerService.StatsStore.increasedAttackSpeed, 100)
	PlayerService:AddBananas(userId, 100)
end)

Players.PlayerRemoving:Connect(function(player)
	local userId = player.UserId

	PlayerService:RemovePlayer(userId)
end)

-- IN WORLD SHARED UI

--[[
-- Weapon Spawner
spawnWeaponButton.MouseButton1Click:Connect(function()
	local randomId = math.random(6, 8) -- TODO : Split per type item definitions
	ItemService:SpawnItem(randomId, weaponSpawnPos.CFrame.Position)
end)
]]
