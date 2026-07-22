local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Gears = require(ReplicatedStorage.Shared.Gears)
local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages._Index["sleitnick_signal@1.5.0"].signal)

-- Get Rodux Store
local RoduxStore = require(ReplicatedStorage.Shared.RoduxStore)
local store = RoduxStore.Store
local selectors = RoduxStore.Selectors
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

local MOD_STATS_INDEX = {
	-- Offense
	"increasedAttackDamage",
	"increasedAttackSpeed",
	"critChance",
	"critMultiplier",
	"increasedAoe",
	-- Defense
	"maxLife",
	"lifeRegen",
	"damageReduction",
	-- Utility
	"mobility",
	"luck",
	"increasedXp",
	"increasedPickupRange",
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

local StatService = Knit.CreateService({
	Name = "StatService",
	MOD_STATS_STORE = MOD_STATS_STORE,
	MOD_STATS = MOD_STATS,
	STATS_STRUCT = STATS_STRUCT,
	MetaUpgradesChanged = Signal.new(),
	XpGained = Signal.new(),
	Client = {
		MetaUpgradesChanged = Knit.CreateSignal(),
		LevelUp = Knit.CreateSignal(),
		NewAugments = Knit.CreateSignal(),
		FinishPickingAugments = Knit.CreateSignal(),
		LifeUpdate = Knit.CreateSignal(),
	},
})

local PlayerService

local totalXp = 0 -- Add to joining players

-- Picking Augments
local positionStart = {} -- Reset Player's Pos after picking augment

-- Dynamic Stats
local playersLife = {}
local lifeRegenUpdates = {}

-- LIFE
-- TODO = Fuse StatService + Enemy takeDamage function

function StatService:RegisterLife(player)
	local userId = player.UserId
	local state = store:getState()

	local playerData = state.players[userId]
	playersLife[userId] = playerData.stats.maxLife

	self:CalculateStat(state, userId, MOD_STATS_STORE.lifeRegen)
end

function StatService:DamagePlayer(player, damage)
	local userId = player.UserId

	playersLife[userId] -= damage
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
		newXpRequired = math.floor(newXpRequired + 3 * 1.1)
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

-- #region CALCULATIONS

local function stopLifeRegen(userId)
	if lifeRegenUpdates[userId] then
		lifeRegenUpdates[userId]:Disconnect()
		lifeRegenUpdates[userId] = nil
	end
end

local function startLifeRegen(userId, lifeRegen)
	if lifeRegen > 0 and playersLife[userId] then
		lifeRegenUpdates[userId] = PlayerService.StateUpdate:Connect(function(state)
			local playerData = selectors.PlayerData(state, userId)

			if not playerData then
				stopLifeRegen(userId)
			end

			local maxLife = playerData.stats.maxLife
			local lifeUpdate = playersLife[userId] + lifeRegen / 60 -- 60 FPS

			playersLife[userId] = math.min(lifeUpdate, maxLife)
		end)
	end
end

-- Sum modStats from each Power Systems
local function calcModStat(metaUpgrades, augments, modStat)
	local metaUpgradeStat = metaUpgrades[modStat]
	local augmentStat = augments[modStat]

	local totalModStat = DEFAULT_STATS[modStat] + metaUpgradeStat + augmentStat

	return totalModStat
end

-- base * increase
local function calcMultStat(metaUpgrades, augments, modStat, calcStat, baseValue)
	local totalModStat = calcModStat(metaUpgrades, augments, modStat)
	local totalStat = baseValue * Gears.increaseToMultiplier(totalModStat)

	local patch = { [modStat] = totalModStat, [calcStat] = totalStat }

	return patch
end

-- Every functions to calculate player stats
local statsCalculation = {
	-- Offense
	attackDamage = function(statCtx)
		local modStat = MOD_STATS_STORE.increasedAttackDamage
		local calcStat = STATS_STORE.attackDamage

		local weaponData = statCtx.weaponData
		local augments = statCtx.augments
		local metaUpgrades = statCtx.metaUpgrades

		local weaponDamage = weaponData and weaponData.damage or 0

		local patch = calcMultStat(metaUpgrades, augments, modStat, calcStat, weaponDamage)

		return patch
	end,

	attackSpeed = function(statCtx)
		-- Get Values
		local modStat = MOD_STATS_STORE.increasedAttackSpeed
		local calcStat = STATS_STORE.attackSpeed

		local augments = statCtx.augments
		local metaUpgrades = statCtx.metaUpgrades
		local weaponData = statCtx.weaponData

		local weaponAttackSpeed = weaponData and weaponData.attackSpeed or 1

		local totalModStat = calcModStat(metaUpgrades, augments, modStat)

		-- Calc
		local attackSpeed = weaponAttackSpeed * Gears.increaseToMultiplier(totalModStat)
		local animationTime = 1 / attackSpeed

		local patch = { [modStat] = totalModStat, [calcStat] = attackSpeed, animationTime = animationTime }

		return patch
	end,

	critChance = function(statCtx)
		local modStat = MOD_STATS_STORE.critChance

		local augments = statCtx.augments
		local metaUpgrades = statCtx.metaUpgrades

		local totalModStat = calcModStat(metaUpgrades, augments, modStat)
		local patch = { [modStat] = totalModStat }

		return patch
	end,

	critMultiplier = function(statCtx)
		local modStat = MOD_STATS_STORE.critMultiplier

		local augments = statCtx.augments
		local metaUpgrades = statCtx.metaUpgrades

		local totalModStat = calcModStat(metaUpgrades, augments, modStat)
		local patch = { [modStat] = totalModStat }

		return patch
	end,

	aoe = function(statCtx)
		-- Get Values
		local modStat = MOD_STATS_STORE.increasedAoe
		local calcStat = STATS_STORE.aoe

		local userId = statCtx.userId
		local augments = statCtx.augments
		local metaUpgrades = statCtx.metaUpgrades
		local weaponData = statCtx.weaponData

		local totalIncreasedAoe = calcModStat(metaUpgrades, augments, modStat)
		local useAoe = weaponData and weaponData.aoe or 0

		-- Calc
		local aoeMultiplier = Gears.increaseToMultiplier(totalIncreasedAoe)
		local totalAoe = useAoe * aoeMultiplier

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
	life = function(statCtx)
		local modStat = MOD_STATS_STORE.maxLife

		local userId = statCtx.userId
		local augments = statCtx.augments
		local metaUpgrades = statCtx.metaUpgrades

		local maxLife = calcModStat(metaUpgrades, augments, modStat)

		-- MaxLife also Give life
		local playerLife = playersLife[userId]

		if playerLife then
			playerLife += maxLife
		end

		local patch = { [modStat] = maxLife }

		return patch
	end,

	lifeRegen = function(statCtx)
		local modStat = MOD_STATS_STORE.lifeRegen

		local userId = statCtx.userId
		local augments = statCtx.augments
		local metaUpgrades = statCtx.metaUpgrades

		local totalLifeRegen = calcModStat(metaUpgrades, augments, modStat)

		stopLifeRegen(userId)
		startLifeRegen(userId, totalLifeRegen)

		local patch = { [modStat] = totalLifeRegen }

		return patch
	end,

	damageReduction = function(statCtx)
		local modStat = MOD_STATS_STORE.damageReduction

		local augments = statCtx.augments
		local metaUpgrades = statCtx.metaUpgrades

		local totalDr = math.min(calcModStat(metaUpgrades, augments, modStat), 90) -- Hard Cap at 90% DR
		local patch = { [modStat] = totalDr }

		return patch
	end,

	-- Utility
	mobility = function(statCtx)
		local modStat = MOD_STATS_STORE.mobility

		local userId = statCtx.userId
		local augments = statCtx.augments
		local metaUpgrades = statCtx.metaUpgrades

		local totalMobility = calcModStat(metaUpgrades, augments, modStat)

		-- Adjust Humanoid
		local player = Players:GetPlayerByUserId(userId)
		local character = player.Character or player.CharacterAdded:Wait()
		local humanoid = character.Humanoid

		humanoid.WalkSpeed = totalMobility
		humanoid.JumpPower = 40 + totalMobility / 2

		local patch = { [modStat] = totalMobility }

		return patch
	end,

	luck = function(statCtx)
		local modStat = MOD_STATS_STORE.luck

		local augments = statCtx.augments
		local metaUpgrades = statCtx.metaUpgrades

		local totalLuck = calcModStat(metaUpgrades, augments, modStat)
		local patch = { [modStat] = totalLuck }

		return patch
	end,

	xp = function(statCtx)
		local modStat = MOD_STATS_STORE.increasedXp

		local augments = statCtx.augments
		local metaUpgrades = statCtx.metaUpgrades

		local totalIncreasedXp = calcModStat(metaUpgrades, augments, modStat)
		local patch = { [modStat] = totalIncreasedXp }

		return patch
	end,

	pickupRange = function(statCtx)
		local modStat = MOD_STATS_STORE.increasedPickupRange
		local calcStat = STATS_STORE.pickupRange

		local augments = statCtx.augments
		local metaUpgrades = statCtx.metaUpgrades

		local basePickupRange = DEFAULT_STATS[MOD_STATS_STORE.basePickupRange]

		local patch = calcMultStat(metaUpgrades, augments, modStat, calcStat, basePickupRange)

		return patch
	end,
}

local function statContext(state, userId)
	local playerData = state.players[userId]
	local augments, metaUpgrades = selectors.PlayerPowerSystems(playerData)

	local statCtx = {
		userId = userId,
		augments = augments,
		metaUpgrades = metaUpgrades,
		weaponData = playerData.weaponData,
	}

	return statCtx
end

-- statType = from STATS_STORE
function StatService:CalculateStat(state, userId, modStat)
	local statCtx = statContext(state, userId)

	local patch = statsCalculation[modStat](statCtx)
	store:dispatch(storeActions.PatchStat(userId, patch))
end

function StatService:CalculateAllStats(userId)
	local state = store:getState()

	local patches = {}

	for _, calculateStat in pairs(statsCalculation) do
		local statCtx = statContext(state, userId)

		local patch = calculateStat(statCtx)
		Gears.fuseTable(patches, patch)
	end

	store:dispatch(storeActions.PatchStat(userId, patches))
	-- Replicate to Client -> Display on Client side character stats sheet
end

-- #endregion

-- #region META UPGRADES

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

	local isUpgradeMaxLevel = playerData.metaUpgradesLevel[upgradeType] >= META_UPRGADES[upgradeType].maxLevel

	if isUpgradeMaxLevel then
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
	PlayerService:SubtractCurrency(player, PlayerService.CURRENCIES.bananas, upgradeCost)
end

-- #endregion

-- #region AUGMENTS

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

-- 1] Augments Generation
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

	-- Check if roll is within a rarity range
	while roll > currentCheck do
		count += 1
		currentCheck += weights[count]
	end

	return AUGMENTS.rarity[count]
end

local function getAugment(rarity, banList)
	-- Build Possible List
	local optionList = Gears.deepCopy(MOD_STATS_INDEX)

	-- Remove Augments :
	-- Already Generated
	-- Don't have Rarity Value
	if banList then
		for index = #MOD_STATS_INDEX, 1, -1 do
			local modStat = MOD_STATS_INDEX[index]

			if table.find(banList, modStat) or not AUGMENTS[modStat][rarity] then
				table.remove(optionList, index)
			end
		end
	else
		for index = #MOD_STATS_INDEX, 1, -1 do
			local modStat = MOD_STATS_INDEX[index]

			if not AUGMENTS[modStat][rarity] then
				table.remove(optionList, index)
			end
		end
	end

	local optionCount = Gears.tableSize(optionList)

	if optionCount <= 0 then
		warn("No Options Left")
		return nil
	end

	-- FindAugment
	local augmentRoll = 1

	if optionCount > 1 then
		augmentRoll = math.random(1, optionCount)
	end

	local augmentType = optionList[augmentRoll]
	local augmentValue = AUGMENTS[augmentType][rarity]

	local augment = {
		modStat = augmentType,
		rarity = rarity,
		value = augmentValue,
	}

	return augment
end

-- Make the next set of Augments available
function StatService:GenerateAugments(player)
	local userId = player.UserId
	local state = store:getState()
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

	-- local rarest = "Common"

	-- for _, augment in pairs(augmentChoices) do
	-- 	if table.find(AUGMENTS.rarity, augment.rarity) > table.find(AUGMENTS.rarity, rarest) then
	-- 		rarest = augment.rarity
	-- 	end
	-- end

	-- local rarestColor = AUGMENTS.colors[rarest]

	local patch = { currentAugments = augmentChoices }
	store:dispatch(storeActions.PatchPlayer(userId, patch))
	-- TODO : Augment Generated Event(rarestColor)
end

-- 2] Augment Pick State
-- Send Augments to Client -> Display
local function sendAugments(player)
	local state = store:getState()
	local userId = player.UserId

	local augmentChoices = state.players[userId].currentAugments

	StatService.Client.NewAugments:Fire(player, augmentChoices)
end

local function finishAugmentPick(player)
	local userId = player.UserId

	local state = store:getState()
	local playerData = selectors.PlayerData(state, userId)

	-- Reset Player State
	player.Character:MoveTo(positionStart[userId])
	positionStart[userId] = nil

	startLifeRegen(userId, playerData.stats.lifeRegen)

	local patch = { state = PlayerService.PLAYER_STATE.playing }

	store:dispatch(storeActions.PatchPlayer(userId, patch))
	StatService.Client.FinishPickingAugments:Fire(player)
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

	-- Picking Augment State
	-- print(player.Name .. " Is Picking Augment...")
	positionStart[userId] = player.Character.HumanoidRootPart.CFrame.Position -- Movements are disabled client side

	stopLifeRegen(userId)

	local patch = { state = PlayerService.PLAYER_STATE.pickingAugment }
	store:dispatch(storeActions.PatchPlayer(userId, patch))

	sendAugments(player)
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

	-- Update Player Level
	local patch = { level = level, waitingLevel = waitingLevel, currentAugments = nil }
	store:dispatch(storeActions.PatchPlayer(userId, patch))
	PlayerService.Client.PatchPlayer:Fire(player, patch)

	-- Generate augments for next Level
	StatService:GenerateAugments(player)

	-- Additional Levels
	if waitingLevel > 0 then
		sendAugments(player)
		return
	end

	finishAugmentPick(player)
end

-- #endregion

-- ARTIFACTS
-- ...

-- Start Service
function StatService:KnitInit()
	print("StatService Initialized")
end

function StatService:KnitStart()
	PlayerService = Knit.GetService("PlayerService")

	PlayerService.ThrottledUpdate:Connect(function(state)
		for _, player in pairs(Players:GetPlayers()) do
			local playerLife = playersLife[player.UserId]

			if playerLife then
				self.Client.LifeUpdate:Fire(player, playerLife)
			end
		end
	end)
end

return StatService
