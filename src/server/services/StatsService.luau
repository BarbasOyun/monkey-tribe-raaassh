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

local StatService = Knit.CreateService({
	Name = "StatService",
	ModStatsStore = MOD_STATS_STORE,
	ModStats = MOD_STATS,
	StatsStruct = STATS_STRUCT,
	MetaUpgradesChanged = Signal.new(),
	Client = {
		MetaUpgradesChanged = Knit.CreateSignal(),
		LevelUp = Knit.CreateSignal(),
	},
})

local PlayerService

local totalXp = 0 -- Add to joining players

-- Picking Augments
local currentAugments = {}
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

	-- StatService:GenerateAugments(player) -- > Generate augments for next Level

	local patch = { currentXp = overXp, xpRequired = newXpRequired, waitingLevel = newWaitingLevel }
	store.dispatch(storeActions.PatchPlayer(userId, patch))

	StatService.Client.LevelUp:Fire(player)
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
		store:dispatch(storeActions.PatchPlayer(userId, { currentXp = newXp }))
	end
end

-- AUGMENTS

function StatService.Client:RerollAugment()
	-- TODO
end

function StatService.Client:PickAugment(index)
	-- TODO
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

-- Augments
function StatService:AddAugment(userId, modStat, value)
	local state = store:getState()

	-- Get stat
	local stat = state.players[userId].augments[modStat]
	local newStat = stat + value

	store:dispatch(storeActions.PatchAugment(userId, { [modStat] = newStat }))
end

--[[
function StatService.Client:RollAugments(luck)
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
			lifeRegenUpdates[userId] = RunService.Heartbeat:Connect(function()
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
