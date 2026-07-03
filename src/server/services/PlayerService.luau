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
-- stores
local STATS_STORE = statsData.STATS_STORE
local MOD_STATS_STORE = statsData.MOD_STATS_STORE
local TO_STAT_OBJECT = statsData.TO_STAT_OBJECT
-- authoring data
local DEFAULT_STATS = statsData.DEFAULT_STATS
local META_UPRGADES = statsData.META_UPRGADES

local PlayerService = Knit.CreateService({
	Name = "PlayerService",
	StatsStore = MOD_STATS_STORE,
	PlayerAdded = Signal.new(),
	PlayerRemoved = Signal.new(),
	Client = {
		ReplicateStore = Knit.CreateSignal(),
		PlayerAdded = Knit.CreateSignal(),
		PlayerRemoved = Knit.CreateSignal(),
		BananasChanged = Knit.CreateSignal(),
		-- Hub
		EnteringGame = Knit.CreateSignal(),
		-- Game
		LevelUp = Knit.CreateSignal(),
		RerollAugment = Knit.CreateSignal(), -- Func
		PickAugment = Knit.CreateSignal(), -- Func
	},
})

local ItemService

-- Hub
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

-- Game
-- PickupRange Parameters
local autoPickupParam = OverlapParams.new()
autoPickupParam.FilterType = Enum.RaycastFilterType.Include
autoPickupParam.FilterDescendantsInstances = { workspace.AutoPickup }
autoPickupParam.MaxParts = 50

local AUTO_PICKUP_FRAME = 5 -- AutoPickup every X Frame
local frameCount = 0

local totalXp = 0 -- Add to joining players

local currentAugments = {}
local positionStart = {} -- Reset Player's Pos after picking augment

-- PLAYERS

-- Per Player Custom GameState -> Remove useless Data
local function playerGameState(player)
	local state = store:getState()
	local players = {}

	for userId, player in pairs(state.players) do
		if userId == player.UserId then
			-- Self Data
			players[userId] = {
				username = player.username,
				isMusicEnabled = player.isMusicEnabled,
				-- Score
				kills = player.kills,
				-- Currencies
				bananas = player.bananas,
				sticks = player.sticks,
				stones = player.stones,
				stats = player.stats,
				metaUpgrades = player.metaUpgrades,
			}
		else
			-- Others Data
			players[userId] = {
				username = player.username,
				kills = player.kills,
			}
		end
	end

	local gameState = {
		players = players,
		-- other game data
	}

	-- return gameState
	return gameState
end

function PlayerService:AddPlayer(player, username)
	local userId = player.UserId

	store:dispatch(storeActions.AddPlayer(userId, username))

	self:GetMetaUpgrades(player.UserId)

	-- Events
	self.PlayerAdded:Fire(userId)
	self.Client.PlayerAdded:FireAll(userId, username)

	-- Send the full store to the new player
	-- local gameState = playerGameState(player)
	local state = store:getState()
	self.Client.ReplicateStore:Fire(player, state)
end

function PlayerService:RemovePlayer(userId)
	-- Save Bananas + Meta Upgrades to DB

	store:dispatch(storeActions.RemovePlayer(userId))

	-- Events
	self.PlayerRemoved:Fire(userId)
	self.Client.PlayerRemoved:FireAll(userId)
end

function PlayerService.Client:ToggleMusic(player, isEnabled)
	store:dispatch(storeActions.PatchPlayer(player.UserId, { isMusicEnabled = isEnabled }))
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
	local state = store:getState()
	local bananas = state.players[userId].bananas
	return if bananas ~= nil then bananas else 0
end

function PlayerService:AddBananas(userId, value)
	if value <= 0 then
		return
	end

	local bananas = self:GetBananas(userId)
	local newValue = bananas + value
	store:dispatch(storeActions.PatchPlayer(userId, { bananas = newValue }))

	-- Replicate to Clients
	self.Client.BananasChanged:FireAll(userId, newValue)
end

-- LEVELS

function PlayerService:AddXpToAllPlayers(xp)
	if not xp or xp <= 0 then
		return
	end

	local state = store:getState()

	totalXp += xp

	for _, player in pairs(Players:GetPlayers()) do
		self:AddXpToLvl(state, player, xp)
	end
end

function PlayerService:AddXpToPlayer(state, player, xp)
	print(player.Name .. " Get : " .. xp .. " XP")

	if not xp or xp <= 0 then
		return
	end

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

-- STATS

-- Add Stat
function PlayerService:AddAugment(userId, modStat, value)
	local state = store:getState()

	-- Get stat
	local stat = state.players[userId].augments[modStat]
	local newStat = stat + value

	store:dispatch(storeActions.PatchAugment(userId, { [modStat] = newStat }))
end

local function updateMetaUpgrade(newLevel, upgradeType)
	-- Calculate Cost & Stat after cahnging level
	local upgradeData = META_UPRGADES[upgradeType]

	local cost = upgradeData.baseCost + upgradeData.baseCost * newLevel * upgradeData.costMultiplier
	local stat = newLevel * upgradeData.incrementValue

	return cost, stat
end

-- upgradeType = from MOD_STATS_STORE
local function incrementMetaUpgrade(state, userId, upgradeType)
	local playerData = state.players[userId]

	-- Increment Update Level
	local newLevel = playerData.metaUpgradesLevel[upgradeType] + 1

	-- Calculate new Stats & Cost
	local cost, stat = updateMetaUpgrade(newLevel, upgradeType)

	local newUpgrade = {
		level = newLevel,
		cost = cost,
		stat = stat,
	}

	-- Dispatch
	store:dispatch(storeActions.SetMetaUpgrade(userId, upgradeType, newUpgrade))

	-- Update Stat
	local newState = store:getState()
	local statType = TO_STAT_OBJECT[upgradeType]
	PlayerService:CalculateStat(newState, userId, statType)
end

function PlayerService.Client:BuyMetaUpgrade(player, upgradeType)
	local state = store:getState()
	local userId = player.UserId

	local playerData = state.players[userId]
	local playerBananas = playerData.bananas

	-- Price Check
	local upgradeCost = playerData.metaUpgradesCost[upgradeType]

	print(
		playerData.username
			.. " Try to buy "
			.. upgradeType
			.. " at Cost = "
			.. upgradeCost
			.. " with "
			.. playerBananas
			.. " Bananas"
	)

	if playerBananas < upgradeCost then
		print(playerData.username .. " Not Enough Bananas to buy Upgrade")
		return
	end

	-- Buy
	-- Grant Upgrade
	incrementMetaUpgrade(state, userId, upgradeType)

	-- Subtract Cost from Bananas
	local newBananas = playerBananas - upgradeCost
	-- store:dispatch(storeActions.SetBananas(userId, newBananas))
	store:dispatch(storeActions.PatchPlayer(userId, { bananas = newBananas }))
end

function PlayerService:GetMetaUpgrades(userId)
	-- Get Levels from DB or 0
	local levels = {}
	local costs = {}
	local stats = {}

	-- Calculate Cost & Stat
	for upgradeType, level in pairs(levels) do
		local cost, stat = updateMetaUpgrade(level, upgradeType)
		costs[upgradeType] = cost
		stats[upgradeType] = stat
	end

	store:dispatch(
		storeActions.PatchPlayer(userId, { metaUpgradesLevel = levels, metaUpgradesCost = costs, metaUpgrades = stats })
	)
end

-- Stat Calc
local function calcModStat(state, userId, statType)
	local playerData = state.players[userId]

	-- Get Stat from each Power System
	local metaUpgradeStat = playerData.metaUpgrades[statType]
	local augmentStat = playerData.augments[statType]

	local modStat = DEFAULT_STATS[statType] + metaUpgradeStat + augmentStat

	return modStat
end

local function calcSumStat(state, userId, modStat)
	local totalModStat = calcModStat(state, userId, modStat)

	store:dispatch(storeActions.PatchStat(userId, { [modStat] = totalModStat }))
end

local function calcMultStat(state, userId, modStat, calcStat, baseValue)
	local totalModStat = calcModStat(state, userId, modStat)
	local totalStat = baseValue * Gears.increaseToMultiplier(totalModStat)

	store:dispatch(storeActions.PatchStat(userId, { [modStat] = totalModStat, [calcStat] = totalStat }))
end

-- Every functions to calculate player stats
local statsCalculation = {
	-- Offense
	attackDamage = function(state, userId)
		local weaponData = state.players[userId].weaponData

		if not weaponData then
			return
		end

		local modStat = MOD_STATS_STORE.increasedAttackDamage
		local calcStat = STATS_STORE.attackDamage

		calcMultStat(state, userId, modStat, calcStat, weaponData.damage)
	end,

	critChance = function(state, userId)
		calcSumStat(state, userId, MOD_STATS_STORE.critChance)
	end,

	critMultiplier = function(state, userId)
		calcSumStat(state, userId, MOD_STATS_STORE.critMultiplier)
	end,

	attackSpeed = function(state, userId)
		local weaponData = state.players[userId].weaponData

		if not weaponData then
			return
		end

		local modStat = MOD_STATS_STORE.increasedAttackSpeed
		local calcStat = STATS_STORE.attackSpeed

		local totalModStat = calcModStat(state, userId, modStat)
		local attackSpeed = weaponData.attackSpeed * Gears.increaseToMultiplier(totalModStat)
		local animationTime = 1 / attackSpeed

		store:dispatch(
			storeActions.PatchStat(
				userId,
				{ [modStat] = totalModStat, [calcStat] = attackSpeed, animationTime = animationTime }
			)
		)
	end,

	aoe = function(state, userId)
		local weaponData = state.players[userId].weaponData

		if not weaponData then
			return
		end

		local modStat = MOD_STATS_STORE.increasedAoe
		local calcStat = STATS_STORE.aoe

		calcMultStat(state, userId, modStat, calcStat, weaponData.aoe)
	end,

	-- Defense
	life = function(state, userId)
		calcSumStat(state, userId, MOD_STATS_STORE.maxLife)
	end,

	lifeRegen = function(state, userId)
		calcSumStat(state, userId, MOD_STATS_STORE.lifeRegen)
	end,

	damageReduction = function(state, userId)
		calcSumStat(state, userId, MOD_STATS_STORE.damageReduction)
	end,

	-- Utility
	mobility = function(state, userId)
		calcSumStat(state, userId, MOD_STATS_STORE.mobility)
	end,

	luck = function(state, userId)
		calcSumStat(state, userId, MOD_STATS_STORE.luck)
	end,

	xp = function(state, userId)
		calcSumStat(state, userId, MOD_STATS_STORE.increasedXp)
	end,

	pickupRange = function(state, userId)
		local modStat = MOD_STATS_STORE.increasedPickupRange
		local calcStat = STATS_STORE.pickupRange

		local basePickupRange = DEFAULT_STATS[MOD_STATS_STORE.basePickupRange]

		calcMultStat(state, userId, modStat, calcStat, basePickupRange)
	end,
}

-- statType = from STATS_STORE
function PlayerService:CalculateStat(state, userId, statType)
	statsCalculation[statType](state, userId)
end

function PlayerService:CalculateAllStats(userId)
	local state = store:getState()

	for _, calculateStat in pairs(statsCalculation) do
		calculateStat(state, userId)
	end

	-- TODO : Replicate to Client -> Display on Client side character stats sheet
end

-- EFFECTIVE STATS

function PlayerService:ApplyStats(userId)
	-- Make the current stats effective
	-- eg restart lifeRegen thread

	self:CalculateAllStats(userId) -- Use correct stats values

	-- life regen
	-- weapon:ScaleTo(weaponInfo.weaponSize * Gears.IncreaseToMultiplier(playerStat.aoe))
	-- MS
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

	local state = store:getState()

	for _, player in ipairs(Players:GetPlayers()) do
		local playerData = state.players[player.userId]

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
end

function PlayerService:KnitStart()
	ItemService = Knit.GetService("ItemService")

	RunService.Heartbeat:Connect(autoPickupRange)
end

return PlayerService
