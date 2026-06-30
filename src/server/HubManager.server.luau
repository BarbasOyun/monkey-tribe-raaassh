local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
Knit.OnStart():await()

local PlayerService = Knit.GetService("PlayerService")
-- local ItemService = Knit.GetService("ItemService")

-- Enemies to load for this place
-- local enemyList = {
-- 	"Dummy",
-- }

-- local spawnWeaponButton = workspace.Wiki.RandomWeaponSpawner.Surface.SurfaceGui.TextButton
-- local weaponSpawnPos = workspace.Wiki.RandomWeaponSpawner.WeaponSpawnPos

Players.PlayerAdded:Connect(function(player)
	PlayerService:AddPlayer(player, player.Name)

	-- Manual Tests
	local userId = player.UserId
	PlayerService:AddIncreasedStat(userId, PlayerService.StatsStore.increasedAttackSpeed, 100)
end)

Players.PlayerRemoving:Connect(function(player)
	local userId = player.UserId

	PlayerService:RemovePlayer(userId)
end)

-- IN WORLD UI

--[[
-- Weapon Spawner
spawnWeaponButton.MouseButton1Click:Connect(function()
	local randomId = math.random(6, 8) -- TODO : Split per type item definitions
	ItemService:SpawnItem(randomId, weaponSpawnPos.CFrame.Position)
end)
]]
