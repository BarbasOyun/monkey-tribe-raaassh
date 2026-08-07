local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Gears = require(ReplicatedStorage.Shared.Gears)
local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages._Index["sleitnick_signal@1.5.0"].signal)

-- Get Rodux Store
local RoduxStore = require(ReplicatedStorage.Shared.RoduxStore)
local Store = RoduxStore.Store
local Selectors = RoduxStore.Selectors
local StoreActions = RoduxStore.Actions

-- Get Constants
local CONSTANTS = require(ServerScriptService.SharedServer.Constants)
local RpgConst = CONSTANTS.RpgConst

local statsDefinition = require(ReplicatedStorage.Shared.AuthoringData.StatsDefinitions)

local STATS_STORE = statsDefinition.STATS_STORE
local MOD_STATS_STORE = statsDefinition.MOD_STATS_STORE
local TO_STAT_OBJECT = statsDefinition.TO_STAT_OBJECT
local MOD_STATS_INDEX = statsDefinition.MOD_STATS_INDEX
local DEFAULT_STATS = statsDefinition.DEFAULT_STATS
-- local STATS_DISPLAY = statsDefinition.STATS_DISPLAY
local META_UPRGADES = statsDefinition.META_UPRGADES
local AUGMENTS = statsDefinition.AUGMENTS

-- Get Mutable State
local MutState = require(ServerScriptService.SharedServer.MutableState)
local StatState = MutState.StatState

-- Get Services
local PlayerService

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

local RpgService = Knit.CreateService({
	Name = "RpgService",
	MetaUpgradesChanged = Signal.new(),
	XpGained = Signal.new(),
	Client = {
		MetaUpgradesChanged = Knit.CreateSignal(),
		LevelUp = Knit.CreateSignal(),
		LifeUpdate = Knit.CreateSignal(),
	},
})

-- #region LIFE
-- TODO = Fuse RpgService + Enemy takeDamage function

function RpgService.RegisterLife(player)
	local userId = player.UserId
	local state = Store:getState()

	local playerData = state.players[userId]
	StatState.playersLife[userId] = playerData.stats.maxLife

	RpgService.CalculateStat(state, userId, MOD_STATS_STORE.lifeRegen)
end

function RpgService.DamagePlayer(player, damage)
	assert(damage > 0, "Damage needs to be greater than 0")

	local userId = player.UserId

	local life = StatState.playersLife[userId] - damage
	StatState.playersLife[userId] = math.max(life, 0)

	if life <= 0 then
		PlayerService.KillPlayer(player)
	end
end

-- #endregion

-- #region LEVELS

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

		-- New XP Formula
		newXpRequired = math.floor(newXpRequired + RpgConst.ADDITIONAL_XP * RpgConst.MULTIPLIER_XP)
	end

	-- Patch
	local patch = { waitingLevel = newWaitingLevel, currentXp = overXp, xpRequired = newXpRequired }
	Store:dispatch(StoreActions.PatchPlayer(userId, patch))

	RpgService.Client.LevelUp:Fire(player, patch)
end

function RpgService.AddXpToAllPlayers(xp)
	if not xp or xp <= 0 then
		return
	end

	local state = Store:getState()

	StatState.totalXp += xp

	for _, player in pairs(Players:GetPlayers()) do
		RpgService.AddXpToPlayer(state, player, xp)
	end
end

function RpgService.AddXpToPlayer(state, player, xp)
	print(player.Name .. " Get : " .. xp .. " XP")

	if not xp or xp <= 0 then
		return
	end

	-- Calculate new xp
	local userId = player.UserId
	local playerData = state.players[userId]

	local totalXp = xp * Gears.IncreaseToMultiplier(playerData.stats.increasedXp)
	local newXp = state.players[userId].currentXp + totalXp

	-- Check Level up
	if newXp >= playerData.xpRequired then
		levelUp(state, player, newXp)
	else
		local patch = { currentXp = newXp }

		Store:dispatch(StoreActions.PatchPlayer(userId, patch))
		PlayerService.Client.PatchPlayer:Fire(player, patch)
	end
end

-- #endregion

-- #region CALCULATIONS

function RpgService.StopLifeRegen(userId)
	local lifeRegenUpdates = StatState.lifeRegenUpdates

	if lifeRegenUpdates[userId] then
		lifeRegenUpdates[userId]:Disconnect()
		lifeRegenUpdates[userId] = nil
	end
end

function RpgService.StartLifeRegen(userId, lifeRegen)
	local playersLife = StatState.playersLife
	local lifeRegenUpdates = StatState.lifeRegenUpdates

	if lifeRegen > 0 and StatState.playersLife[userId] then
		lifeRegenUpdates[userId] = PlayerService.StateUpdate:Connect(function(state)
			local playerState = Selectors.PlayerState(state, userId)

			if not playerState then
				RpgService.StopLifeRegen(userId)
			end

			local maxLife = playerState.stats.maxLife
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
	local totalStat = baseValue * Gears.IncreaseToMultiplier(totalModStat)

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
		local attackSpeed = weaponAttackSpeed * Gears.IncreaseToMultiplier(totalModStat)
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
		local weaponState = statCtx.weaponData

		local totalIncreasedAoe = calcModStat(metaUpgrades, augments, modStat)
		local useAoe = weaponState and weaponState.aoe or 0

		-- Calc
		local aoeMultiplier = Gears.IncreaseToMultiplier(totalIncreasedAoe)
		local totalAoe = useAoe * aoeMultiplier

		local patch = { [modStat] = totalIncreasedAoe, [calcStat] = totalAoe }

		if #weaponState == 0 then
			return patch
		end

		-- Adjust Weapon Size
		local player = Players:GetPlayerByUserId(userId)
		local character = player.Character or player.CharacterAdded:Wait()
		local weaponModel = character:FindFirstChildOfClass("Tool")
		weaponModel:ScaleTo(weaponState.weaponSize * aoeMultiplier)

		-- Attack VFX
		local baseSize = 0.5
		local size = baseSize * totalIncreasedAoe
		local keypoints = {
			NumberSequenceKeypoint.new(0, size),
			NumberSequenceKeypoint.new(1, size),
		}
		weaponState.attackVFX.Size = NumberSequence.new(keypoints)

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
		local playerLife = StatState.playersLife[userId]

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

		RpgService.StopLifeRegen(userId)
		RpgService.StartLifeRegen(userId, totalLifeRegen)

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
	local playerState = state.players[userId]
	local augments, metaUpgrades = Selectors.PlayerPowerSystems(playerState)

	local statCtx = {
		userId = userId,
		augments = augments,
		metaUpgrades = metaUpgrades,
		weaponData = playerState.weaponData,
	}

	return statCtx
end

-- modStat = from STATS_STORE
function RpgService.CalculateStat(state, userId, modStat)
	local statCtx = statContext(state, userId)

	local patch = statsCalculation[modStat](statCtx)
	Store:dispatch(StoreActions.PatchStat(userId, patch))
end

function RpgService.CalculateAllStats(userId)
	local state = Store:getState()

	local patches = {}

	for _, calculateStat in pairs(statsCalculation) do
		local statCtx = statContext(state, userId)

		local patch = calculateStat(statCtx)
		Gears.FuseTable(patches, patch)
	end

	Store:dispatch(StoreActions.PatchStat(userId, patches))
	-- Replicate to Client -> Display on Client side character stats sheet
end

-- #endregion

-- #region META UPGRADES

function RpgService.UpdateMetaUpgrade(newLevel, upgradeType)
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
	local cost, stat = RpgService.UpdateMetaUpgrade(newLevel, upgradeType)

	local newUpgrade = {
		level = newLevel,
		cost = cost,
		stat = stat,
	}

	-- Dispatch
	Store:dispatch(StoreActions.SetMetaUpgrade(userId, upgradeType, newUpgrade))

	-- Events
	RpgService.MetaUpgradesChanged:Fire(player, upgradeType, newUpgrade)
	RpgService.Client.MetaUpgradesChanged:Fire(player, upgradeType, newUpgrade)

	-- Update Stat
	local newState = Store:getState()
	local statType = TO_STAT_OBJECT[upgradeType]
	RpgService.CalculateStat(newState, userId, statType)
end

function RpgService.Client.BuyMetaUpgrade(player, upgradeType)
	local state = Store:getState()
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

-- ARTIFACTS
-- ...

-- Start Service
function RpgService:KnitInit()
	print("RpgService Initialized")
end

function RpgService:KnitStart()
	PlayerService = Knit.GetService("PlayerService")

	-- LifeRegen Update -> UI
	PlayerService.ThrottledUpdate:Connect(function(state)
		for _, player in pairs(Players:GetPlayers()) do
			local playerLife = StatState.playersLife[player.UserId]

			if playerLife then
				self.Client.LifeUpdate:Fire(player, playerLife)
			end
		end
	end)

	PlayerService.PlayerRemoved:Connect(function(userId)
		RpgService.StopLifeRegen(userId)
	end)
end

return RpgService
