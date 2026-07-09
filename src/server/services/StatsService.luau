local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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
local AUGMENTS = statsData.AUGMENTS

-- StatsSystem :
-- INPUT = Take ModStats of each Power Systems (Mutated by other Systems)
-- Calculate & Create TotalStats & Make them effective
-- OUTPUT = TotalStats -> Display

-- ModStats :
-- (Stats Mutated by other Systems)
-- 1] FlatStat eg maxLife, crit
-- 2] IncreaseStat

-- TotalStats :
-- (Effective Stats) -> Calculated from powerSystems eg metaUpgrades, augments
-- Stored in the playerStats -> weaponData never mutate
-- 1] SumStat eg maxLife, crit
-- 2] MultStat eg attackDamage

-- MultStat
-- baseX * increasedX = x
-- some baseX come from weaponData eg baseAttackSpeed

-- Stats of Power Systems : MetaUpgrades + Augments -> Input
local MOD_STATS = {
	-- Offense
	increasedAttackDamage = 0,
	increasedAttackSpeed = 0,
	critChance = 0,
	critMultiplier = 0,
	increasedAoe = 0,
	-- Defense
	maxLife = 0,
	lifeRegen = 0,
	damageReduction = 0,
	-- Utility
	mobility = 0,
	luck = 0,
	increasedXp = 0,
	increasedPickupRange = 0,
}

-- Total Stats -> Output
local STATS_STRUCT = {
	-- Offensive
	increasedAttackDamage = 0,
	-- moreAttackDamageLayers = {}
	attackDamage = 0,
	increasedAttackSpeed = 0,
	attackSpeed = 0, -- Attacks / Second
	animationTime = 1, -- Get lower as attackSpeed get higher
	critChance = 5,
	critMultiplier = 50,
	increasedAoe = 0,
	aoe = 0,
	-- Defensive
	-- baseLife = 100,
	-- increasedLife = 0,
	maxLife = 100,
	lifeRegen = 1,
	damageReduction = 0,
	-- Utility
	mobility = 15,
	luck = 0,
	increasedXp = 0,
	basePickupRange = 10,
	increasedPickupRange = 0,
	pickupRange = 10,
}

AUGMENT = {
	modStat = "",
	rarity = "",
	value = 0,
}

local StatService = Knit.CreateService({
	Name = "StatService",
	MOD_STATS_STORE = MOD_STATS_STORE,
	MOD_STATS = MOD_STATS,
	STATS_STRUCT = STATS_STRUCT,
	MetaUpgradesChanged = Signal.new(),
	Client = {
		MetaUpgradesChanged = Knit.CreateSignal(),
		LevelUp = Knit.CreateSignal(),
		NewAugments = Knit.CreateSignal(),
		FinishPickingAugments = Knit.CreateSignal(),
	},
})

local PlayerService

local totalXp = 0 -- Add to joining players

-- Picking Augments
local positionStart = {} -- Reset Player's Pos after picking augment

-- Dynamic Stats
local playersLife = {}
local lifeRegenUpdates = {}

function StatService:RegisterLife(userId)
	local state = store:getState()
	local playerData = state.players[userId]
	playersLife[userId] = playerData.stats.maxLife

	self:CalculateStat(MOD_STATS_STORE.lifeRegen)
end

-- LEVELS

local function levelUp(state, player, currentXp)
	print(player.Name .. " Level Up")

	local userId = player.UserId
	local playerData = state.players[userId]

	-- Compute XP
	local overXp = currentXp

	local newWaitingLevel = playerData.waitingLevel
	local newXpRequired = playerData.xpRequired

	-- Manage Additional LevelUps + Validate
	while overXp >= newXpRequired do
		overXp = overXp - newXpRequired
		newWaitingLevel += 1
		newXpRequired *= 1.1
	end

	-- Patch
	local patch = { waitingLevel = newWaitingLevel, currentXp = overXp, xpRequired = newXpRequired }
	store:dispatch(storeActions.PatchPlayer(userId, patch))

	StatService.Client.LevelUp:Fire(player, patch)
end

function StatService:AddXpToAllPlayers(xp)
	if not xp or xp <= 0 then
		return
	end

	local state = store:getState()

	totalXp += xp

	for _, player in pairs(Players:GetPlayers()) do
		self:AddXpToPlayer(state, player, xp)
	end
end

function StatService:AddXpToPlayer(state, player, xp)
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
		local patch = { currentXp = newXp }

		store:dispatch(storeActions.PatchPlayer(userId, patch))
		PlayerService.Client.PatchPlayer:Fire(player, patch)
	end
end

-- META UPGRADES

function StatService:UpdateMetaUpgrade(newLevel, upgradeType)
	-- Calculate Cost & Stat at a Level
	local upgradeData = META_UPRGADES[upgradeType]

	local totalMultiplier = math.pow(upgradeData.costMultiplier, newLevel)
	local cost = math.floor(upgradeData.baseCost * totalMultiplier)

	local stat = newLevel * upgradeData.incrementValue

	return cost, stat
end

-- upgradeType = from MOD_STATS_STORE
local function incrementMetaUpgrade(state, player, upgradeType)
	local userId = player.UserId
	local playerData = state.players[userId]

	-- Increment Update Level
	local newLevel = playerData.metaUpgradesLevel[upgradeType] + 1

	-- Calculate new Stats & Cost
	local cost, stat = StatService:UpdateMetaUpgrade(newLevel, upgradeType)

	local newUpgrade = {
		level = newLevel,
		cost = cost,
		stat = stat,
	}

	-- Dispatch
	store:dispatch(storeActions.SetMetaUpgrade(userId, upgradeType, newUpgrade))

	-- Events
	StatService.MetaUpgradesChanged:Fire(player, upgradeType, newUpgrade)
	StatService.Client.MetaUpgradesChanged:Fire(player, upgradeType, newUpgrade)

	-- Update Stat
	local newState = store:getState()
	local statType = TO_STAT_OBJECT[upgradeType]
	StatService:CalculateStat(newState, userId, statType)
end

function StatService.Client:BuyMetaUpgrade(player, upgradeType)
	local state = store:getState()
	local userId = player.UserId

	local playerData = state.players[userId]

	if playerData.metaUpgradesLevel[upgradeType] >= META_UPRGADES[upgradeType].maxLevel then
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

	-- Handle Fail
	if playerBananas < upgradeCost then
		print(playerData.username .. " Not Enough Bananas to buy Upgrade")
		return
	end

	-- Transaction
	-- Grant Upgrade
	incrementMetaUpgrade(state, player, upgradeType)

	-- Subtract Cost from Bananas
	PlayerService:SubtractBananas(player, upgradeCost)
end

-- AUGMENTS

-- Generate a patch of the specified augment
local function augmentPatch(state, userId, modStat, value)
	local playerData = state.players[userId]

	-- Get stat
	local stat = playerData.augments[modStat]
	local newStat = stat + value

	local patch = { [modStat] = newStat }
	return patch
end

-- Debug func
function StatService:AddAugmentStat(userId, modStat, value)
	local state = store:getState()

	local patch = augmentPatch(state, userId, modStat, value)
	store:dispatch(storeActions.PatchAugment(userId, patch))
end

function StatService.Client:RerollAugment(player)
	local state = store:getState()
	local playerData = state.players[player.UserId]

	if not playerData.currentAugments then
		print(player.Name .. " No Augments ready")
		return
	end

	if playerData.sticks.Value < 10 then
		print(player.Name .. " Not enough Sticks")
		return
	end

	-- Transaction
	StatService:SendAugment(player)

	PlayerService:SubtractCurrency(player, PlayerService.CURRENCIES.sticks, 10)
end

local function finishAugmentPick(player)
	local userId = player.UserId

	-- Reset Player State
	player.Character:MoveTo(positionStart[userId])
	positionStart[userId] = nil

	lifeRegenUpdates[userId]:Connect()

	local patch = { state = PlayerService.PLAYER_STATE.playing }

	store:dispatch(storeActions.PatchPlayer(userId, patch))
	StatService.Client.FinishPickingAugment:Fire(player, patch)
end

-- Send Augments to Client -> Display
local function sendAugments(state, player)
	local userId = player.UserId

	local augmentChoices = state.players[userId].currentAugments

	local patch = { currentAugments = augmentChoices }
	StatService.Client.NewAugments:Fire(player, patch)
end

function StatService.Client:PickAugment(player, index)
	local userId = player.UserId
	local state = store:getState()
	local playerData = state.players[userId]

	-- Validation
	local augment = playerData.currentAugments[index]
	assert(augment, player.Name .. " Augment not ready")

	local waitingLevel = playerData.waitingLevel
	assert(waitingLevel > 0, player.Name .. " No waiting Level")

	print(player.Name .. " Choosed : " .. index)

	-- Level
	local level = playerData.level
	level += 1
	waitingLevel -= 1

	--Add Augment Stats
	local augmentPatch = augmentPatch(state, userId, augment.modStat, augment.value)
	store:dispatch(storeActions.PatchAugment(userId, augmentPatch))
	-- Replicate to Client -> Display Augment stats client side

	local patch = { level = level, waitingLevel = waitingLevel, currentAugments = nil }

	store:dispatch(storeActions.PatchPlayer(userId, patch))
	PlayerService.Client.PatchPlayer:Fire(player, patch)

	local newState = store:getState() -- needed?

	-- Generate augments for next Level
	StatService:GenerateAugments(newState, player)

	local newState2 = store:getState() -- needed?

	-- Additional Levels
	if waitingLevel > 0 then
		sendAugments(newState2, player)
		return
	end

	finishAugmentPick(player)
end

-- Player start choosing Augment
function StatService.Client:StartAugmentPick(player)
	local userId = player.UserId
	local state = store:getState()
	local playerData = state.players[userId]

	-- Validations
	assert(playerData.currentAugments, player.Name .. " No Augments ready")

	local waitingLevel = playerData.waitingLevel
	assert(waitingLevel > 0, player.Name .. " No waiting Level")

	-- print(player.Name .. " Is Picking Augment...")
	-- Picking Augment State
	positionStart[userId] = player.Character.HumanoidRootPart.CFrame.Position -- Movements are disabled client side

	lifeRegenUpdates[userId]:Disconnect()

	local patch = { state = PlayerService.PLAYER_STATE.pickingAugment }
	store:dispatch(storeActions.PatchPlayer(userId, patch))

	local newState = store:getState()

	sendAugments(newState, player)
end

local function getWeights(luck)
	-- local weights = Augments.weights
	local baseLuckValue = AUGMENTS.baseLuckValue
	local luckPoints = AUGMENTS.luckPoints

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

local function rollRarity(weights, totalWeight)
	local roll = math.random(0, totalWeight)
	local count = 1
	local currentCheck = weights[1]

	while roll > currentCheck do
		count += 1
		currentCheck += weights[count]
	end

	return AUGMENTS.rarity[count]
end

-- TODO : Ban list
local function getAugment(rarity, banList)
	-- Build Possible List
	local possibleList = {}

	for _, modStat in MOD_STATS do
		if not table.find(banList, modStat) and AUGMENTS[modStat][rarity] then
			table.insert(possibleList, modStat)
		end
	end

	-- FindAugment
	local augmentRoll = math.random(1, #possibleList)
	local augmentType = possibleList[augmentRoll]
	local augmentValue = AUGMENTS[augmentType][rarity]

	local augment = Gears.deepCopy(AUGMENT)
	augment.modStat = augmentType
	augment.rarity = rarity
	augment.value = augmentValue

	return augment
end

-- Make the next set of Augments available
function StatService:GenerateAugments(state, player)
	local userId = player.UserId
	local playerData = state.players[userId]

	local weights = getWeights(playerData.stats.luck)
	local totalWeight = Gears.sumTable(weights)

	local banList = {} -- Avoid Generating the Same Augment Type

	local augment1 = getAugment(rollRarity(weights, totalWeight))
	table.insert(banList, augment1.modStat)

	local augment2 = getAugment(rollRarity(weights, totalWeight), banList)
	table.insert(banList, augment2.modStat)

	local augment3 = getAugment(rollRarity(weights, totalWeight), banList)

	local augmentChoices = {
		augment1,
		augment2,
		augment3,
	}

	local patch = { currentAugments = augmentChoices }
	store:dispatch(storeActions.PatchPlayer(userId, patch))
	-- TODO : Augment Generated Event(maxRarityColor)
end

-- ARTIFACTS
-- ...

-- CALCULATIONS

-- Sum modStats from each Power Systems
local function calcModStat(state, userId, statType)
	local playerData = state.players[userId]

	local metaUpgradeStat = playerData.metaUpgrades[statType]
	local augmentStat = playerData.augments[statType]

	local modStat = DEFAULT_STATS[statType] + metaUpgradeStat + augmentStat

	return modStat
end

-- base * increase
local function calcMultStat(state, userId, modStat, calcStat, baseValue)
	local totalModStat = calcModStat(state, userId, modStat)
	local totalStat = baseValue * Gears.increaseToMultiplier(totalModStat)

	local patch = { [modStat] = totalModStat, [calcStat] = totalStat }

	return patch
end

-- Every functions to calculate player stats
local statsCalculation = {
	-- Offense
	attackDamage = function(state, userId)
		local modStat = MOD_STATS_STORE.increasedAttackDamage
		local calcStat = STATS_STORE.attackDamage

		local weaponData = state.players[userId].weaponData
		local weaponDamage = weaponData and weaponData.damage or 0

		local patch = calcMultStat(state, userId, modStat, calcStat, weaponDamage)

		return patch
	end,

	critChance = function(state, userId)
		local modStat = MOD_STATS_STORE.critChance
		local patch = { [modStat] = calcModStat(state, userId, modStat) }

		return patch
	end,

	critMultiplier = function(state, userId)
		local modStat = MOD_STATS_STORE.critMultiplier
		local patch = { [modStat] = calcModStat(state, userId, modStat) }

		return patch
	end,

	attackSpeed = function(state, userId)
		-- Get Values
		local modStat = MOD_STATS_STORE.increasedAttackSpeed
		local calcStat = STATS_STORE.attackSpeed

		local weaponData = state.players[userId].weaponData
		local weaponAttackSpeed = weaponData and weaponData.attackSpeed or 1

		local totalModStat = calcModStat(state, userId, modStat)

		-- Calc
		local attackSpeed = weaponAttackSpeed * Gears.increaseToMultiplier(totalModStat)
		local animationTime = 1 / attackSpeed

		local patch = { [modStat] = totalModStat, [calcStat] = attackSpeed, animationTime = animationTime }

		return patch
	end,

	aoe = function(state, userId)
		-- Get Values
		local modStat = MOD_STATS_STORE.increasedAoe
		local calcStat = STATS_STORE.aoe

		local weaponData = state.players[userId].weaponData
		local weaponAoe = weaponData and weaponData.aoe or 0

		local totalIncreasedAoe = calcModStat(state, userId, modStat)

		-- Calc
		local aoeMultiplier = Gears.increaseToMultiplier(totalIncreasedAoe)
		local totalAoe = weaponAoe * aoeMultiplier

		local patch = { [modStat] = totalIncreasedAoe, [calcStat] = totalAoe }

		if not weaponData then
			return patch
		end

		-- Adjust Weapon Size
		local player = Players:GetPlayerByUserId(userId)
		local character = player.Character or player.CharacterAdded:Wait()
		local weaponModel = character:FindFirstChildOfClass("Tool")
		weaponModel:ScaleTo(weaponData.weaponSize * aoeMultiplier)

		-- Attack VFX
		local baseSize = 0.5
		local size = baseSize * totalIncreasedAoe
		local keypoints = {
			NumberSequenceKeypoint.new(0, size),
			NumberSequenceKeypoint.new(1, size),
		}
		weaponData.attackVFX.Size = NumberSequence.new(keypoints)

		return patch
	end,

	-- Defense
	life = function(state, userId)
		local playerData = state.players[userId]
		local modStat = MOD_STATS_STORE.maxLife

		local maxLife = calcModStat(state, userId, modStat)

		-- MaxLife also Give life
		local maxLifeDelta = math.max(maxLife - playerData.stats.maxLife, 0)

		local playerLife = playersLife[userId]

		if playerLife then
			playerLife += maxLifeDelta
		end

		local patch = { [modStat] = maxLife }

		return patch
	end,

	lifeRegen = function(state, userId)
		local modStat = MOD_STATS_STORE.lifeRegen

		local lifeRegen = calcModStat(state, userId, modStat)

		-- Reset lifeRegen Update
		if lifeRegenUpdates[userId] then
			lifeRegenUpdates[userId]:Disconnect()
			lifeRegenUpdates[userId] = nil
		end

		if lifeRegen > 0 and playersLife[userId] then
			lifeRegenUpdates[userId] = RunService.Heartbeat:Connect(function() -- Put in PlayerServiceUpdate?
				playersLife[userId] += lifeRegen / 60 -- 60 FPS
			end)
		end

		local patch = { [modStat] = lifeRegen }

		return patch
	end,

	damageReduction = function(state, userId)
		local modStat = MOD_STATS_STORE.damageReduction

		local totalDr = math.min(calcModStat(state, userId, modStat), 90) -- Hard Cap at 90% DR
		local patch = { [modStat] = totalDr }

		return patch
	end,

	-- Utility
	mobility = function(state, userId)
		local modStat = MOD_STATS_STORE.mobility

		local totalMobility = calcModStat(state, userId, modStat)

		-- Adjust Humanoid
		local player = Players:GetPlayerByUserId(userId)
		local character = player.Character or player.CharacterAdded:Wait()
		local humanoid = character.Humanoid

		humanoid.WalkSpeed = totalMobility
		humanoid.JumpPower = 40 + totalMobility / 2

		local patch = { [modStat] = totalMobility }

		return patch
	end,

	luck = function(state, userId)
		local modStat = MOD_STATS_STORE.luck
		local patch = { [modStat] = calcModStat(state, userId, modStat) }

		return patch
	end,

	xp = function(state, userId)
		local modStat = MOD_STATS_STORE.increasedXp
		local patch = { [modStat] = calcModStat(state, userId, modStat) }

		return patch
	end,

	pickupRange = function(state, userId)
		local modStat = MOD_STATS_STORE.increasedPickupRange
		local calcStat = STATS_STORE.pickupRange

		local basePickupRange = DEFAULT_STATS[MOD_STATS_STORE.basePickupRange]

		local patch = calcMultStat(state, userId, modStat, calcStat, basePickupRange)

		return patch
	end,
}

-- statType = from STATS_STORE
function StatService:CalculateStat(state, userId, statType)
	local patch = statsCalculation[statType](state, userId)

	store:dispatch(storeActions.PatchStat(userId, patch))
end

function StatService:CalculateAllStats(userId)
	local state = store:getState()

	local patches = {}

	for _, calculateStat in pairs(statsCalculation) do
		local patch = calculateStat(state, userId)
		Gears.fuseTable(patches, patch)
	end

	store:dispatch(storeActions.PatchStat(userId, patches))

	-- Replicate to Client -> Display on Client side character stats sheet
end

-- Start Service
function StatService:KnitInit()
	print("StatService Initialized")
end

function StatService:KnitStart()
	PlayerService = Knit.GetService("PlayerService")
end

return StatService
