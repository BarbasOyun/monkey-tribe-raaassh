local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Gears = require(ReplicatedStorage.Shared.Gears)
local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages._Index["sleitnick_signal@1.5.0"].signal)

-- Get Rodux Store
local RoduxStore = require(ReplicatedStorage.Shared.RoduxStore)
local store = RoduxStore.Store
local storeActions = RoduxStore.Actions

-- Get Stats Authoring Data
local statsData = require(ReplicatedStorage.Shared.AuthoringData.StatsDefinitions)
local STATS_STORE = statsData.STATS_STORE
local STATS_DISPLAY = statsData.STATS_DISPLAY
local META_UPRGADES = statsData.META_UPRGADES
local AUGMENTS = statsData.AUGMENTS

local PlayerService = Knit.CreateService({
	Name = "PlayerService",
	StatsStore = STATS_STORE,
	PlayerAdded = Signal.new(),
	PlayerRemoved = Signal.new(),
	Client = {
		ReplicateStore = Knit.CreateSignal(),
		PlayerAdded = Knit.CreateSignal(),
		PlayerRemoved = Knit.CreateSignal(),
		MusicChanged = Knit.CreateSignal(),
		EnteringGame = Knit.CreateSignal(),
		BananasChanged = Knit.CreateSignal(),
		AskForUpgrade = Knit.CreateSignal(),
	},
})

local ItemService = nil

-- PickupRange Parameters
local autoPickupParam = OverlapParams.new()
autoPickupParam.FilterType = Enum.RaycastFilterType.Include
autoPickupParam.FilterDescendantsInstances = { workspace.AutoPickup }
autoPickupParam.MaxParts = 50

local AUTO_PICKUP_FRAME = 5 -- AutoPickup every X Frame
local frameCount = 0

-- TP to main Game instance
local GAME_PLACE_ID = 109804031798809

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

-- PLAYERS

-- Replicate State when Player Join
local function gameState()
	local state = store:getState()
	local players = {}

	-- TODO : use player struct
	for userId, player in pairs(state.players) do
		players[userId] = {
			username = player.username,
			isMusicEnabled = player.isMusicEnabled,
			bananas = player.bananas,
			sticks = player.sticks,
			stones = player.stones,
			stats = player.stats,
			metaUpgrades = player.metaUpgrades,
		}
	end

	local gameState = {
		players = players,
		-- other game data
	}

	return gameState
end

function PlayerService:AddPlayer(player, username)
	local userId = player.UserId

	store:dispatch(storeActions.AddPlayer(userId, username))

	-- Events
	self.PlayerAdded:Fire(userId)
	self.Client.PlayerAdded:FireAll(userId, username)

	-- Send the full store to the new player
	local gameState = gameState()
	self.Client.ReplicateStore:Fire(player, gameState)
end

function PlayerService:RemovePlayer(userId)
	-- Save Bananas + Meta Upgrades to DB

	store:dispatch(storeActions.RemovePlayer(userId))

	-- Events
	self.PlayerRemoved:Fire(userId)
	self.Client.PlayerRemoved:FireAll(userId)
end

function PlayerService.Client:ToggleMusic(player, enabled)
	store:dispatch(storeActions.ToggleMusic(player.UserId, enabled))
	self.MusicChanged:Fire(player, enabled)
end

-- TP

local function createGameInstance(players)
	Gears.joinTable(playersLoadingTp, players)

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

local function updatePlatformLabel(platformId)
	platformsLabels[platformId].Text = "Raaassh ("
		.. #platformsPlayers[platformId]
		.. "/"
		.. platformsMaxPlayers[platformId]
		.. ")"
end

local function setupPlatforms()
	for i, platform in ipairs(platforms) do
		platform.Touched:Connect(function(hit)
			local player = game.Players:GetPlayerFromCharacter(hit.Parent)

			if not player or table.find(playersLoadingTp, player) or table.find(platformsPlayers[i], player) then
				return
			end

			table.insert(platformsPlayers[i], player)
			updatePlatformLabel(i)

			-- if there is enough players on the Platform -> Launch Game
			if #platformsPlayers[i] >= platformsMaxPlayers[i] then
				createGameInstance(platformsPlayers[i])

				table.clear(platformsPlayers[i])
				updatePlatformLabel(i)
			end
		end)

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

-- CURRENCIES

function PlayerService:GetBananas(userId)
	local bananas = store:getState().players[userId].bananas
	return if bananas ~= nil then bananas else 0
end

function PlayerService:AddBananas(userId, value)
	if value <= 0 then
		return
	end

	local bananas = self:GetBananas(userId)
	local newValue = bananas + value
	store:dispatch(storeActions.SetScore(userId, newValue))

	-- Replicate to Clients
	self.Client.BananasChanged:FireAll(userId, newValue)
end

-- STATS

-- Most Stats work like this : baseX * increasedX = x
-- some baseX (eg baseAttackSpeed) come from weaponData
-- every used / final x stats is stored in the playerStats (weaponData never mutate)

-- upgradeType = from STATS_STORE
local function incrementMetaUpgrade(userId, upgradeType)
	local newStat = store:getState().players[userId].metaUpgrades[upgradeType] + 1
	store:dispatch(storeActions.SetMetaUpgrade(userId, upgradeType, newStat))
end

function PlayerService.Client:BuyMetaUpgrade(player, upgradeType)
	local userId = player.UserId
	local playerData = store:getState().players[userId]
	local playerBananas = playerData.bananas

	-- Price Check
	local upgradeLevel = playerData.metaUpgrades[upgradeType]
	local upgradeData = META_UPRGADES[upgradeType]
	local upgradeCost = upgradeData.baseCost + upgradeData.baseCost * upgradeLevel * upgradeData.costMultiplier

	print(
		playerData.username
			.. " Try to buy "
			.. upgradeType
			.. " at "
			.. upgradeCost
			.. " with "
			.. playerBananas
			.. " Bananas"
	)

	if playerBananas < upgradeCost then
		print(playerData.username .. " Not Enough Bananas to buy Upgrade")
		return
	end

	-- Buy = Subtract Cost + Grant Upgrade
	local newBananas = playerBananas - upgradeCost
	store:dispatch(storeActions.SetBananas(userId, newBananas))
	incrementMetaUpgrade(userId, upgradeType)
end

function PlayerService:GetStats(userId)
	local storeState = store:getState()

	local playerStats = storeState.players[userId].stats
	local metaUpgrade = storeState.players[userId].metaUpgrades
	local weaponData = storeState.players[userId].weaponData

	return playerStats, metaUpgrade, weaponData
end

-- Every function to calculate a player stats
local statsCalcFunctions = {
	calculateAttackDamage = function(userId)
		local playerStats, metaUpgrade, weaponData = PlayerService:GetStats(userId)

		if not playerStats or not weaponData then
			return
		end

		local metaUpgradeIncrease = metaUpgrade.increasedAttackDamage
			* META_UPRGADES[STATS_STORE.increasedAttackDamage].incrementValue
		local totalIncrease = playerStats.increasedAttackDamage + metaUpgradeIncrease

		-- use weapon as Base Damage
		local attackDamage = weaponData.damage * Gears.increaseToMultiplier(totalIncrease)

		store:dispatch(storeActions.SetAttackDamage(userId, attackDamage))

		-- print("Attack Damage = " .. attackDamage)
	end,

	calculateAttackSpeed = function(userId)
		local playerStats, metaUpgrade, weaponData = PlayerService:GetStats(userId)

		if not playerStats or not weaponData then
			return
		end

		local attackSpeed = weaponData.attackSpeed * Gears.increaseToMultiplier(playerStats.increasedAttackSpeed)
		local animationTime = 1 / attackSpeed

		store:dispatch(storeActions.SetAttackSpeed(userId, attackSpeed, animationTime))

		-- print("Attack Speed = " .. attackSpeed)
		-- print("Animation Time = " .. animationTime)
	end,

	calculateAoe = function(userId)
		local playerStats, metaUpgrade, weaponData = PlayerService:GetStats(userId)

		if not playerStats or not weaponData then
			return
		end

		local aoe = weaponData.aoe * Gears.increaseToMultiplier(playerStats.increasedAoe)

		-- disspatch
		store:dispatch(storeActions.SetAoe(userId, aoe))

		-- print("AOE = " .. aoe)
	end,

	-- DR
	-- PickupRange
}

function PlayerService:CalculateAllStats(userId)
	for _, calculateStat in pairs(statsCalcFunctions) do
		calculateStat(userId)
	end

	-- TODO : Send to Client -> Display on Client side character stats sheet
end

function PlayerService:ApplyStats(userId)
	-- Make the current stats effective
	-- eg restart lifeRegen thread

	self:CalculateAllStats(userId)
	-- life regen
	-- weapon:ScaleTo(weaponInfo.weaponSize * Gears.IncreaseToMultiplier(playerStat.aoe))
	-- MS
end

-- statType = string from the STATS_STORE
function PlayerService:AddIncreasedStat(userId, statType, value)
	-- Get stat
	local newStat = store:getState().players[userId].stats[statType] + value
	store:dispatch(storeActions.SetIncreasedStat(userId, statType, newStat))
end

function PlayerService:AddXpToPlayer(player, xp)
	-- print(player.Name .. " Gained : " .. xp .. " XP")
	-- local playerStat = playersStats[player.UserId]
	-- playerStat.currentXp.Value += xp * Gears.increaseToMultiplier(playerStat.increasedXp)

	-- if playerStat.currentXp.Value >= playerStat.levelUpXp.Value then
	-- 	playersStats.LevelUp(player, playerStat)
	-- end

	-- Dispatch xp
end

function PlayerService:LevelUp(player, playerStat)
	-- Compute XP
	-- local overXp = playerStat.currentXp.Value - playerStat.levelUpXp.Value
	-- playerStat.waitingLevel += 1
	-- playerStat.currentXp.Value = 0
	-- playerStat.levelUpXp.Value *= 1.1
	-- print(player.Name .. " Leveled Up")

	-- playersStats.SendAugment(player, playerStat)
	-- levelUpEvent:FireClient(player, playerStat.level, playerStat.waitingLevel)

	-- playersStats.AddXpToLvl(player, overXp)

	-- Dispatch Lvl
end

-- Auto Pickup
local function autoPickup(player, itemModel)
	if not itemModel.Parent or itemModel.Parent ~= workspace.AutoPickup then
		return
	end

	itemModel.Parent = game.Workspace
	itemModel.CanCollide = false

	-- Lerp itemModel
	local startPos = itemModel.CFrame

	local steps = 20
	local progress = 0
	local speed = 1 / steps / 4
	local acceleration = (1 / steps - speed) / (steps / 2)

	for _ = 1, steps do
		progress += speed
		speed += acceleration
		itemModel.CFrame = startPos:Lerp(player.character:GetPivot(), progress)
		RunService.Heartbeat:Wait()
	end

	ItemService:PickupItem(player, itemModel)
end

local function autoPickupRange()
	if frameCount < AUTO_PICKUP_FRAME then
		frameCount += 1
		return
	end

	frameCount = 0

	local storeState = store:getState()

	for _, player in ipairs(Players:GetPlayers()) do
		local playerData = storeState.players[player.userId]

		if not playerData then
			continue
		end

		local playerStats = playerData.stats
		local character = player.Character or player.CharacterAdded:Wait()

		local playerPos = character.HumanoidRootPart.CFrame.Position
		local pickupRange = playerStats.pickupRange

		-- DEBUG
		-- Gears.DisplayHitBox(position, pickupRange, 0.1)

		local autoPickupItems = workspace:GetPartBoundsInRadius(playerPos, pickupRange, autoPickupParam)

		for _, itemModel in ipairs(autoPickupItems) do
			autoPickup(player, itemModel)
		end
	end
end

-- Start Service
function PlayerService:KnitInit()
	print("PlayerService Initialized")

	setupPlatforms()

	self.Client.AskForUpgrade:Connect(function(player)
		-- Check Bananas
	end)
end

function PlayerService:KnitStart()
	-- print("PlayerService Start")

	ItemService = Knit.GetService("ItemService")

	RunService.Heartbeat:Connect(autoPickupRange)
end

return PlayerService
