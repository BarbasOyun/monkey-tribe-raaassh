local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
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
-- DataStores
local PlayersDb = DataStoreService:GetDataStore("PlayersDb")

-- TP to main Game instance
local HUB_PLACE_ID = 95975992291805
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
local MAX_BANANAS = 10_000
local MAX_DISTANCE = 250

local deadPlayers = {}

local totalXp = 0 -- Add to joining players

-- Picking Augments
local currentAugments = {}
local positionStart = {} -- Reset Player's Pos after picking augment

-- PickupRange Parameters
local autoPickupParam = OverlapParams.new()
autoPickupParam.FilterType = Enum.RaycastFilterType.Include
autoPickupParam.FilterDescendantsInstances = { workspace.AutoPickup }
autoPickupParam.MaxParts = 50

local AUTO_PICKUP_FRAME = 5 -- AutoPickup every X Frame
local frameCount = 0

-- Dynamic Stats
local playersLife = {}
local lifeRegenUpdates = {}

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

-- TODO : AddHubPlayer
function PlayerService:AddPlayer(player, username)
	local userId = player.UserId

	-- TODO : Create Player Data Struct
	store:dispatch(storeActions.AddPlayer(userId, username))

	-- Events
	self.PlayerAdded:Fire(userId)
	self.Client.PlayerAdded:FireAll(userId, username)

	local state = store:getState()

	-- Send the full store to the new player
	-- local gameState = playerGameState(player)
	self.Client.ReplicateStore:Fire(player, state)

	-- Stats
	self:GetBananasDb(player.UserId)
	self:GetMetaUpgrades(player.UserId)

	-- Set Current Life
	local newState = store:getState()
	local playerData = newState.players[userId]
	playersLife[userId] = playerData.stats.maxLife

	-- On Player Death
	-- player:LoadCharacterAsync()
	local character = player.Character
	character.Humanoid.Died:Connect(function()
		self:OnPlayerDeath(player)
	end)
end

function PlayerService:RemovePlayer(player)
	local userId = player.UserId

	store:dispatch(storeActions.RemovePlayer(userId))

	-- Events
	self.PlayerRemoved:Fire(userId)
	self.Client.PlayerRemoved:FireAll(userId)
end

-- Save Score & Meta Upgrades to Db
function PlayerService:SaveToDb(userId)
	local state = store:getState()
	local playerData = state.players[userId]

	print(playerData.username .. " Saving Meta Upgrades and Score to DB")

	-- Bananas
	local bananaCount = playerData.bananas
	pcall(function()
		PlayersDb:SetAsync(userId .. "_bananas", bananaCount)
	end)

	-- Meta Upgrades
	for upgradeType, value in pairs(playerData.metaUpgradesLevel) do
		pcall(function()
			PlayersDb:SetAsync(userId .. "_" .. upgradeType, value)
		end)
	end
end

function PlayerService:IncrementDbBananas(userId, value)
	if value <= 0 then
		return
	end

	local success, newValue = pcall(function()
		return PlayersDb:UpdateAsync(userId, function(oldValue)
			local current = oldValue or 0
			local nextValue = current + value
			return math.clamp(nextValue, 0, MAX_BANANAS)
		end)
	end)
end

function PlayerService:GetBananasDb(userId)
	local bananaCount = 0

	local success, bananas = pcall(function()
		return PlayersDb:GetAsync(userId .. "_bananas")
	end)

	if success and bananas then
		bananaCount = bananas
	end

	store:dispatch(storeActions.PatchPlayer(userId, { bananas = bananaCount }))
	-- TODO : Replicate to Client
end

-- Debug func -> Delete Player's DB
local function ResetPlayer(player)
	local state = store:getState()
	local userId = player.UserId
	local playerData = state.players[userId]

	-- Meta Upgrades
	for upgradeType, value in pairs(playerData.metaUpgradesLevel) do
		pcall(function()
			PlayersDb:SetAsync(userId .. "_" .. upgradeType, 0)
		end)
	end

	-- Bananas
	pcall(function()
		PlayersDb:SetAsync(userId .. "_" .. "bananas", 0)
	end)
end

function PlayerService.Client:ToggleMusic(player, isEnabled)
	store:dispatch(storeActions.PatchPlayer(player.UserId, { isMusicEnabled = isEnabled }))
end

-- HUB

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

-- GAME

function PlayerService:GameOver()
	print("Game Over -> Saving Bananas & Going back to Hub")
	local players = Players:GetPlayers()

	-- TODO
	for _, player in pairs(players) do
		self:IncrementDbBananas(player.UserId, 0)
	end

	pcall(function()
		return TeleportService:TeleportAsync(HUB_PLACE_ID, players)
	end)
end

function PlayerService:OnPlayerDeath(player)
	print(player.Name .. " died -> Waiting Next Stage to respawn...")
	table.insert(deadPlayers, player)
	-- Events.PlayerDied:FireClient(player) -- TODO

	if #deadPlayers >= #Players:GetPlayers() then
		self:GameOver()
	end
end

-- Prevent Players from groing OOB
function PlayerService:LimitInBound(limit)
	RunService.Heartbeat:Connect(function()
		for _, player in pairs(Players:GetPlayers()) do
			local character = player.Character or player.CharacterAdded:Wait()
			local root = character.Humanoid.HumanoidRootPart

			local pos = root.Position
			local flatPos = Vector2.new(pos.X, pos.Z) -- Check 2D distance

			if flatPos.Magnitude > MAX_DISTANCE then -- TODO : Squared Magnitude
				character:PivotTo(CFrame.new(Vector3.zero))
				root.AssemblyLinearVelocity = Vector3.zero -- Reset momentum
			end
		end
	end)
end

-- CURRENCIES

function PlayerService:GetBananas(state, userId)
	local playerData = state.players[userId]
	local bananas = playerData.bananas
	return if bananas ~= nil then bananas else 0
end

-- Add To all Players
function PlayerService:AddBananas(value)
	if value <= 0 then
		return
	end

	local state = store:getState()

	for _, player in Players:GetPlayers() do
		local userId = player.UserId

		local bananas = self:GetBananas(state, userId)
		local newValue = math.min(bananas + value, MAX_BANANAS)
		store:dispatch(storeActions.PatchPlayer(userId, { bananas = newValue }))

		-- Replicate to Clients
		self.Client.BananasChanged:FireAll(userId, newValue)
	end
end

-- LEVELS

local function levelUp(state, player, currentXp)
	print(player.Name .. " Leveling Up")

	local userId = player.UserId
	local playerData = state.players[userId]

	-- Compute XP
	local overXp = currentXp

	local newXpRequired = playerData.xpRequired
	local newWaitingLevel = playerData.waitingLevel

	-- Manage Next LevelUps + Validate
	while overXp >= newXpRequired do
		overXp = overXp - newXpRequired
		newXpRequired *= 1.1
		newWaitingLevel += 1
	end

	-- PlayerService:GenerateAugments(player) -- > Generate augments for next Level

	store.dispatch(
		storeActions.PatchPlayer(
			userId,
			{ currentXp = overXp, xpRequired = newXpRequired, waitingLevel = newWaitingLevel }
		)
	)
	PlayerService.Client.LevelUp:Fire(player)
end

function PlayerService:AddXpToAllPlayers(xp)
	if not xp or xp <= 0 then
		return
	end

	local state = store:getState()

	totalXp += xp

	for _, player in pairs(Players:GetPlayers()) do
		self:AddXpToPlayer(state, player, xp)
	end
end

function PlayerService:AddXpToPlayer(state, player, xp)
	print(player.Name .. " Get : " .. xp .. " XP")

	if not xp or xp <= 0 then
		return
	end

	-- Calculate new xp
	local userId = player.UserId
	local playerData = state.players[userId]

	local totalXp = xp * Gears.increaseToMultiplier(playerData.stats.increasedXp)
	local newXp = state.players[userId].currentXp + totalXp

	-- Check Level up
	if newXp >= playerData.xpRequired then
		levelUp(state, player, newXp)
	else
		store:dispatch(storeActions.PatchPlayer(userId, { currentXp = newXp }))
	end
end

-- STATS

-- Meta Upgrades
local function updateMetaUpgrade(newLevel, upgradeType)
	-- Calculate Cost & Stat after cahnging level
	local upgradeData = META_UPRGADES[upgradeType]

	local totalMultiplier = math.pow(upgradeData.costMultiplier, newLevel)
	local cost = math.floor(upgradeData.baseCost + upgradeData.baseCost * totalMultiplier)

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

	if playerData.metaUpgradesLevel >= META_UPRGADES[upgradeType].maxLevel then
		print(playerData.username .. " " .. upgradeType .. " Upgrade Max Level")
	end

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
	local newBananas = math.max(0, playerBananas - upgradeCost)
	store:dispatch(storeActions.PatchPlayer(userId, { bananas = newBananas }))
end

function PlayerService:GetMetaUpgrades(userId)
	-- Get Levels from DB or 0
	local levels = {}
	local costs = {}
	local metaUpgrades = {}

	local state = store:getState()
	local playerData = state.players[userId]

	for upgradeType, _ in pairs(playerData.metaUpgrades) do
		local level = 0

		local success, lvl = pcall(function()
			return PlayersDb:GetAsync(userId .. "_" .. upgradeType)
		end)

		if success and lvl then
			level = lvl
		end

		local cost, stat = updateMetaUpgrade(level, upgradeType)

		levels[upgradeType] = level
		costs[upgradeType] = cost
		metaUpgrades[upgradeType] = stat
	end

	store:dispatch(
		storeActions.PatchPlayer(
			userId,
			{ metaUpgradesLevel = levels, metaUpgradesCost = costs, metaUpgrades = metaUpgrades }
		)
	)
	-- TODO : Replicate to Client
end

-- Augments
function PlayerService:AddAugment(userId, modStat, value)
	local state = store:getState()

	-- Get stat
	local stat = state.players[userId].augments[modStat]
	local newStat = stat + value

	store:dispatch(storeActions.PatchAugment(userId, { [modStat] = newStat }))
end

--[[
function PlayerService.Client:RollAugments(luck)
	local function GetWeights()
		-- local weights = Augments.weights
		local baseLuckValue = Augments.baseLuckValue
		local luckPoints = Augments.luckPoints
		local luckDistance = {
			math.abs(luckPoints[1] - luck), -- Deal with Negative Luck
			math.abs(luckPoints[2] - luck),
			math.abs(luckPoints[3] - luck),
			math.abs(luckPoints[4] - luck),
			math.abs(luckPoints[5] - luck),
		}
		local weights = {
			baseLuckValue - luckDistance[1],
			baseLuckValue - luckDistance[2],
			baseLuckValue - luckDistance[3],
			baseLuckValue - luckDistance[4],
			baseLuckValue - luckDistance[5],
		}

		return weights
	end

	-- print("Rolling Augments with : " .. luck .. " Luck")

	local weights = GetWeights()

	local function GetAugment()
		local function FindRarity()
			local totalWeight = Gears.SumTable(weights)
			local roll = math.random(0, totalWeight)
			local count = 1
			local currentCheck = weights[1]
			while roll > currentCheck do
				count += 1
				currentCheck += weights[count]
			end

			return Augments.rarity[count]
		end

		local rarity = FindRarity()

		local function FindAugment()
			local augmentRoll = math.random(1, #Augments.augmentType)
			local augmentType = Augments.augmentType[augmentRoll]
			local augmentValue = Augments[augmentType][rarity]

			-- TODO Find List of Possible Augments
			if not augmentValue then
				-- print(augmentType .. " Doesn't have : " .. rarity .. " Version")
				return FindAugment()
			end

			return { augmentType, rarity, augmentValue }
		end

		return FindAugment()
	end

	-- TODO : Luck Protection
	local augmentChoices = { GetAugment(), GetAugment(), GetAugment() }

	return augmentChoices
end

function playersStats.SendAugment(player, playerStat)
	local augments = playersStats.RollAugments(playerStat.luck)
	currentAugments[player.UserId] = augments
	rerollEvent:FireClient(player, augments)
end

local function StartAugmentPick(player)
	if not currentAugments[player.UserId] then
		print("No Augments ready for : " .. player.Name)
		return
	end

	-- print(player.Name .. "Is Picking Augment")
	local playerStats = playersStats[player.UserId]
	playerStats.lifeRegenUpdate:Disconnect()
	playerStats.pickingAugment = true

	positionStart[player.UserId] = player.Character.HumanoidRootPart.CFrame.Position
end

local function AugmentPick(player, choiceNbr)
	if not currentAugments[player.UserId] then
		print("No Augments ready for : " .. player.Name)
		return
	end

	-- Update Level
	-- print(player.Name .. " Choosed : " .. choiceNbr)
	local playerStat = playersStats[player.UserId]
	playerStat.level += 1
	playerStat.waitingLevel -= 1
	augmentPick:FireClient(player, playerStat.level, playerStat.waitingLevel)

	--Add Augment Stats
	local augment = currentAugments[player.UserId][choiceNbr]
	-- Check Augment Or Artifact -> #augment

	playersStats.AddStat(player, playerStat, augment[1], augment[3]) -- Augment Type & Value
	currentAugments[player.UserId] = nil

	-- Additional Levels
	if playerStat.waitingLevel > 0 then
		playersStats.SendAugment(player, playerStat)
		playerStat.lifeRegenUpdate:Disconnect() -- TODO : Refactor
		return
	end

	player.Character:MoveTo(positionStart[player.UserId])
	positionStart[player.UserId] = nil
	playersStats[player.UserId].pickingAugment = false
end

local function RerollAugment(player)
	if not currentAugments[player.UserId] then
		print("No Augments ready for : " .. player.Name)
		return
	end

	if playersStats[player.UserId].sticks.Value < 10 then
		return
	end

	playersStats[player.UserId].sticks.Value -= 10
	playersStats.SendAugment(player, playersStats[player.UserId])
end
]]

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

		local totalIncreasedAoe = calcModStat(state, userId, modStat)
		local aoeMultiplier = Gears.increaseToMultiplier(totalIncreasedAoe)
		local totalAoe = weaponData.aoe * aoeMultiplier

		-- Adjust Weapon Size
		local player = Players:GetPlayerByUserId(userId)
		local character = player.Character or player.CharacterAdded:Wait()
		local weaponModel = character:FindFirstChildOfClass("Tool")
		weaponModel:ScaleTo(weaponData.weaponSize * aoeMultiplier)

		-- Attack VFX
		local size = 2 * totalIncreasedAoe -- 2 = Base VFX Size
		local keypoints = {
			NumberSequenceKeypoint.new(0, size),
			NumberSequenceKeypoint.new(1, size),
		}
		weaponData.attackVFX.Size = NumberSequence.new(keypoints)

		store:dispatch(storeActions.PatchStat(userId, { [modStat] = totalIncreasedAoe, [calcStat] = totalAoe }))
	end,

	-- Defense
	life = function(state, userId)
		local playerData = state.players[userId]
		local modStat = MOD_STATS_STORE.maxLife

		local maxLife = calcModStat(state, userId, modStat)

		-- MaxLife also Give life
		local maxLifeDelta = math.max(maxLife - playerData.stats.maxLife, 0)
		playersLife[userId] += maxLifeDelta

		store:dispatch(storeActions.PatchStat(userId, { [modStat] = maxLife }))
	end,

	lifeRegen = function(state, userId)
		local modStat = MOD_STATS_STORE.lifeRegen

		local lifeRegen = calcModStat(state, userId, modStat)

		-- Start lifeRegen Update
		if lifeRegenUpdates[userId] then
			lifeRegenUpdates[userId]:Disconnect()
			lifeRegenUpdates[userId] = nil
		end

		if lifeRegen > 0 then
			lifeRegenUpdates[userId] = RunService.Heartbeat:Connect(function()
				playersLife[userId] += lifeRegen / 60 -- 60 FPS
			end)
		end

		store:dispatch(storeActions.PatchStat(userId, { [modStat] = lifeRegen }))
	end,

	damageReduction = function(state, userId)
		calcSumStat(state, userId, MOD_STATS_STORE.damageReduction)

		local modStat = MOD_STATS_STORE.damageReduction
		local totalDr = math.min(calcModStat(state, userId, modStat), 90) -- Hard Cap at 90% DR

		store:dispatch(storeActions.PatchStat(userId, { [modStat] = totalDr }))
	end,

	-- Utility
	mobility = function(state, userId)
		-- calcSumStat(state, userId, MOD_STATS_STORE.mobility)

		local modStat = MOD_STATS_STORE.mobility

		local totalMobility = calcModStat(state, userId, modStat)

		-- Adjust Humanoid
		local player = Players:GetPlayerByUserId(userId)
		local character = player.Character or player.CharacterAdded:Wait()
		local humanoid = character.Humanoid

		humanoid.WalkSpeed = totalMobility
		humanoid.JumpPower = 40 + totalMobility / 2

		store:dispatch(storeActions.PatchStat(userId, { [modStat] = totalMobility }))
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
