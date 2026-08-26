-- RpgService = Calculate + Manage Unit Stats

-- StatsSystem :
-- Power Systems = ModStats -> Mutated by other Systems
-- TotalStats = Calc Power Systems

-- ModStats :
-- 1] FlatStat eg maxLife, crit
-- 2] IncreaseStat

-- TotalStats :
-- 1] SumStat eg maxLife, crit
-- 2] MultStat eg attackDamage

-- MultStat :
-- baseX * increasedX = x
-- some baseX come from weaponData eg baseAttackSpeed

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Gears = require(ReplicatedStorage.Shared.Gears)

-- Get Constants
local CONSTANTS = require(ServerScriptService.SharedServer.Constants)
local RpgConst = CONSTANTS.RpgConst

local STATS_STORE = RpgConst.STATS_STORE
local MOD_STATS_STORE = RpgConst.MOD_STATS_STORE
local TO_STAT_OBJECT = RpgConst.TO_STAT_OBJECT
local DEFAULT_STATS = RpgConst.DEFAULT_STATS
local META_UPRGADES = RpgConst.META_UPRGADES

-- Get Rodux Store
local RoduxStore = require(ReplicatedStorage.Shared.RoduxStore)
local Store = RoduxStore.Store
local Selectors = RoduxStore.Selectors
local StoreActions = RoduxStore.Actions

-- Get Mutable State
local MutState = require(ServerScriptService.SharedServer.MutableState)
local RpgState = MutState.RpgState

-- Knit
local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages._Index["sleitnick_signal@1.5.0"].signal)
local PlayerService

local RpgService = Knit.CreateService({
	Name = "RpgService",
	MetaUpgradesChanged = Signal.new(),
	XpGained = Signal.new(),
	Client = {
		PatchStats = Knit.CreateSignal(),
		MetaUpgradesChanged = Knit.CreateSignal(),
		LevelUp = Knit.CreateSignal(),
		LifeUpdate = Knit.CreateSignal(),
		PlayerDamaged = Knit.CreateSignal(),
	},
})

-- #region START

function RpgService:KnitInit()
	print("RpgService Initialized")
end

function RpgService:KnitStart()
	PlayerService = Knit.GetService("PlayerService")

	RpgService.SetupPlayerService()
end

function RpgService.SetupPlayerService()
	PlayerService.ThrottledUpdate:Connect(function(state)
		-- LifeRegen Update -> UI
		for _, player in pairs(Players:GetPlayers()) do
			local playerLife = RpgState.playersLife[player.UserId]

			if playerLife then
				RpgService.Client.LifeUpdate:Fire(player, playerLife)
			end
		end
	end)

	PlayerService.PlayerAdded:Connect(function(player)
		local userId = player.UserId

		-- Reset Player on Respawn
		player.CharacterAdded:Connect(function(character)
			-- Get Max Life
			local state = Store:getState()
			local playerState = Selectors.PlayerState(state, userId)
			local maxLife = playerState.stats.maxLife

			RpgState.playersLife[userId] = maxLife
		end)
	end)

	PlayerService.PlayerRemoved:Connect(function(player)
		local userId = player.UserId
		RpgService.StopLifeRegen(userId)
	end)
end

-- #endregion

-- #region UPDATE

function RpgService.StartLifeRegen(userId, lifeRegen)
	-- Validation
	local state = Store:getState()
	local playerState = Selectors.PlayerState(state, userId)
	local playersLife = RpgState.playersLife

	local isValid = lifeRegen > 0
		and playerState.state == CONSTANTS.PLAYER_STATES.playing
		and RpgState.lifeRegenUpdates[userId] == nil
		and playersLife[userId]

	if not isValid then
		-- warn(playerState.username .. " Not Valid for Life Regen")
		return
	end

	-- warn("Start Life Regen")

	local lifeRegenUpdate = PlayerService.StateUpdate:Connect(function(state, dt)
		local playerState = Selectors.PlayerState(state, userId)

		if not playerState then
			RpgService.StopLifeRegen(userId)
		end

		local maxLife = playerState.stats.maxLife
		local lifeDelta = lifeRegen * dt -- lifeRegen / 60 -- 60 FPS
		local lifeUpdate = playersLife[userId] + lifeDelta

		playersLife[userId] = math.min(lifeUpdate, maxLife)
	end)

	RpgState.lifeRegenUpdates[userId] = lifeRegenUpdate
end

function RpgService.StopLifeRegen(userId)
	if RpgState.lifeRegenUpdates[userId] then
		RpgState.lifeRegenUpdates[userId]:Disconnect()
		RpgState.lifeRegenUpdates[userId] = nil
	end
end

-- #endregion

-- #region LIFE
-- TODO = Fuse RpgService + Enemy takeDamage function

function RpgService.RegisterLife(player)
	local userId = player.UserId
	local state = Store:getState()

	local playerData = state.players[userId]
	RpgState.playersLife[userId] = playerData.stats.maxLife

	RpgService.CalculateStat(state, player, MOD_STATS_STORE.lifeRegen)
end

function RpgService.DamagePlayer(player, damage)
	assert(damage > 0, "Damage needs to be greater than 0")

	local userId = player.UserId

	-- Take Damage
	local life = RpgState.playersLife[userId] - damage
	RpgState.playersLife[userId] = math.max(life, 0)

	RpgService.Client.PlayerDamaged:Fire(player)

	-- Check Death
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

	RpgState.totalXp += xp

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

--- Sum modStats from each Power Systems -> Generate Patch
function RpgService.CalcModStat(metaUpgrades, augments, modStat)
	local metaUpgradeStat = metaUpgrades[modStat]
	local augmentStat = augments[modStat]

	local totalModStat = DEFAULT_STATS[modStat] + metaUpgradeStat + augmentStat

	return totalModStat
end

--- base * increase -> Generate Patch
function RpgService.CalcMultStat(metaUpgrades, augments, modStat, calcStat, baseValue)
	local totalModStat = RpgService.CalcModStat(metaUpgrades, augments, modStat)
	local totalStat = baseValue * Gears.IncreaseToMultiplier(totalModStat)

	local patch = { [modStat] = totalModStat, [calcStat] = totalStat }

	return patch
end

--- Calculate a Final Stat using Power Systems -> Make Stat Effective,
--- modStat = from STATS_STORE
function RpgService.CalculateStat(state, player, stat)
	local userId = player.UserId

	local playerState = Selectors.PlayerState(state, userId)

	local patch = RpgService.statsCalculation[stat](playerState)

	-- Dispatch Server + Client
	Store:dispatch(StoreActions.PatchStat(userId, patch))
	RpgService.Client.PatchStats:Fire(player, patch)
end

function RpgService.CalculateAllStats(player)
	local userId = player.UserId
	local state = Store:getState()

	-- Stich patches together
	local patches = {}

	for _, calculateStat in pairs(RpgService.statsCalculation) do
		local playerState = Selectors.PlayerState(state, userId)

		local patch = calculateStat(playerState)
		Gears.FuseTable(patches, patch)
	end

	-- Dispatch Server + Client
	Store:dispatch(StoreActions.PatchStat(userId, patches))
	RpgService.Client.PatchStats:Fire(player, patches)
end

--- Final Stats Calcs using Power Systems
RpgService.statsCalculation = {
	-- Offense
	attackDamage = function(playerState)
		local modStat = MOD_STATS_STORE.increasedAttackDamage
		local calcStat = STATS_STORE.attackDamage

		local weaponData = playerState.weaponData
		local augments = playerState.augments
		local metaUpgrades = playerState.metaUpgrades

		local weaponDamage = weaponData and weaponData.damage or 0

		local patch = RpgService.CalcMultStat(metaUpgrades, augments, modStat, calcStat, weaponDamage)

		return patch
	end,

	attackSpeed = function(playerState)
		-- Get Values
		local modStat = MOD_STATS_STORE.increasedAttackSpeed
		local calcStat = STATS_STORE.attackSpeed

		local augments = playerState.augments
		local metaUpgrades = playerState.metaUpgrades
		local weaponData = playerState.weaponData

		local weaponAttackSpeed = weaponData and weaponData.attackSpeed or 1

		local totalModStat = RpgService.CalcModStat(metaUpgrades, augments, modStat)

		-- Calc
		local attackSpeed = weaponAttackSpeed * Gears.IncreaseToMultiplier(totalModStat)
		local animationTime = 1 / attackSpeed

		local patch = { [modStat] = totalModStat, [calcStat] = attackSpeed, animationTime = animationTime }

		return patch
	end,

	critChance = function(playerState)
		local modStat = MOD_STATS_STORE.critChance

		local augments = playerState.augments
		local metaUpgrades = playerState.metaUpgrades

		local totalModStat = RpgService.CalcModStat(metaUpgrades, augments, modStat)
		local patch = { [modStat] = totalModStat }

		return patch
	end,

	critMultiplier = function(playerState)
		local modStat = MOD_STATS_STORE.critMultiplier

		local augments = playerState.augments
		local metaUpgrades = playerState.metaUpgrades

		local totalModStat = RpgService.CalcModStat(metaUpgrades, augments, modStat)
		local patch = { [modStat] = totalModStat }

		return patch
	end,

	aoe = function(playerState)
		-- Get Values
		local modStat = MOD_STATS_STORE.increasedAoe
		local calcStat = STATS_STORE.aoe

		local userId = playerState.userId
		local augments = playerState.augments
		local metaUpgrades = playerState.metaUpgrades
		local weaponState = playerState.weaponData

		local totalIncreasedAoe = RpgService.CalcModStat(metaUpgrades, augments, modStat)
		local useAoe = weaponState and weaponState.aoe or 0

		-- Calc
		local aoeMultiplier = Gears.IncreaseToMultiplier(totalIncreasedAoe)
		local totalAoe = useAoe * aoeMultiplier

		local patch = { [modStat] = totalIncreasedAoe, [calcStat] = totalAoe }

		if Gears.IsEmpty(weaponState) then
			return patch
		end

		-- Adjust Weapon Size
		local player = Players:GetPlayerByUserId(userId)
		local character = player.Character or player.CharacterAdded:Wait()
		local weaponModel = character:FindFirstChildOfClass("Tool")
		weaponModel:ScaleTo(weaponState.weaponSize * aoeMultiplier)

		-- Attack VFX
		local baseSize = 1.5
		local sizeIncrease = totalIncreasedAoe * 0.05
		local size = baseSize + baseSize * sizeIncrease
		local keypoints = {
			NumberSequenceKeypoint.new(0, size),
			NumberSequenceKeypoint.new(1, size),
		}
		weaponState.attackVFX.Size = NumberSequence.new(keypoints)

		return patch
	end,

	-- Defense
	maxLife = function(playerState)
		local modStat = MOD_STATS_STORE.maxLife

		local userId = playerState.userId
		local augments = playerState.augments
		local metaUpgrades = playerState.metaUpgrades

		local maxLife = RpgService.CalcModStat(metaUpgrades, augments, modStat)

		-- Gain current Life
		local lifeDelta = math.max(0, maxLife - playerState.stats.maxLife)

		if RpgState.playersLife[userId] then
			RpgState.playersLife[userId] += lifeDelta
		end

		local patch = { [modStat] = maxLife }

		return patch
	end,

	lifeRegen = function(playerState)
		local modStat = MOD_STATS_STORE.lifeRegen

		local userId = playerState.userId
		local augments = playerState.augments
		local metaUpgrades = playerState.metaUpgrades

		local totalLifeRegen = RpgService.CalcModStat(metaUpgrades, augments, modStat)

		RpgService.StopLifeRegen(userId)
		RpgService.StartLifeRegen(userId, totalLifeRegen)

		local patch = { [modStat] = totalLifeRegen }

		return patch
	end,

	damageReduction = function(playerState)
		local modStat = MOD_STATS_STORE.damageReduction

		local augments = playerState.augments
		local metaUpgrades = playerState.metaUpgrades

		local totalDr = math.min(RpgService.CalcModStat(metaUpgrades, augments, modStat), 90) -- Hard Cap at 90% DR
		local patch = { [modStat] = totalDr }

		return patch
	end,

	-- Utility
	mobility = function(playerState)
		local modStat = MOD_STATS_STORE.mobility

		local userId = playerState.userId
		local augments = playerState.augments
		local metaUpgrades = playerState.metaUpgrades

		local totalMobility = RpgService.CalcModStat(metaUpgrades, augments, modStat)

		-- Adjust Humanoid
		local player = Players:GetPlayerByUserId(userId)
		local character = player.Character or player.CharacterAdded:Wait()
		local humanoid = character.Humanoid

		humanoid.WalkSpeed = totalMobility
		humanoid.JumpPower = 40 + totalMobility / 2

		local patch = { [modStat] = totalMobility }

		return patch
	end,

	luck = function(playerState)
		local modStat = MOD_STATS_STORE.luck

		local augments = playerState.augments
		local metaUpgrades = playerState.metaUpgrades

		local totalLuck = RpgService.CalcModStat(metaUpgrades, augments, modStat)
		local patch = { [modStat] = totalLuck }

		return patch
	end,

	xp = function(playerState)
		local modStat = MOD_STATS_STORE.increasedXp

		local augments = playerState.augments
		local metaUpgrades = playerState.metaUpgrades

		local totalIncreasedXp = RpgService.CalcModStat(metaUpgrades, augments, modStat)
		local patch = { [modStat] = totalIncreasedXp }

		return patch
	end,

	pickupRange = function(playerState)
		local modStat = MOD_STATS_STORE.increasedPickupRange
		local calcStat = STATS_STORE.pickupRange

		local augments = playerState.augments
		local metaUpgrades = playerState.metaUpgrades

		local basePickupRange = DEFAULT_STATS[MOD_STATS_STORE.basePickupRange]

		local patch = RpgService.CalcMultStat(metaUpgrades, augments, modStat, calcStat, basePickupRange)

		return patch
	end,
}

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
	RpgService.CalculateStat(newState, player, statType)
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

return RpgService
