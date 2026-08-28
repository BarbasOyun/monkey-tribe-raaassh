local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Gears = require(ReplicatedStorage.Shared.Gears)

-- Get Constants
local CONSTANTS = require(ServerScriptService.SharedServer.Constants)
local RpgConst = CONSTANTS.RpgConst
local TO_STAT_OBJECT = RpgConst.TO_STAT_OBJECT
local MOD_STATS_INDEX = RpgConst.MOD_STATS_INDEX
local AUGMENTS = RpgConst.AUGMENTS

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
-- local Signal = require(ReplicatedStorage.Packages._Index["sleitnick_signal@1.5.0"].signal)

local RpgService, PlayerService

local AugmentsService = Knit.CreateService({
	Name = "AugmentsService",
	Client = {
		NewAugments = Knit.CreateSignal(),
		FinishPickingAugments = Knit.CreateSignal(),
	},
})

function AugmentsService:KnitInit()
	print("AugmentsService Initialized")
end

function AugmentsService:KnitStart()
	RpgService = Knit.GetService("RpgService")
	PlayerService = Knit.GetService("PlayerService")
end

-- #region UTILS

--- Generate a patch of the specified augment
function AugmentsService.AugmentPatch(state, userId, modStat, value)
	local playerState = state.players[userId]

	-- Get stat
	local stat = playerState.augments[modStat]
	local newStat = stat + value

	local patch = { [modStat] = newStat }
	return patch
end

--- Debug func : Add a Specific Stat
function AugmentsService.AddAugmentStat(userId, modStat, value)
	local state = Store:getState()

	local patch = AugmentsService.AugmentPatch(state, userId, modStat, value)
	Store:dispatch(StoreActions.PatchAugment(userId, patch))
end

-- #endregion

-- #region AUGMENTS GENERATION

--- Generate Weight for each Rarity based on Luck Value
function AugmentsService.GetWeights(luck)
	-- local weights = AUGMENTS.weights -- TODO : Per Augment type weight
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

--- Get a Rarity based on Weights
function AugmentsService.RollRarity(weights, totalWeight)
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

--- Get a random valid augment of a Rarity
function AugmentsService.GetAugment(rarity, banList)
	-- Build Possible List
	local optionList = Gears.DeepCopy(MOD_STATS_INDEX)

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

	local optionCount = Gears.TableSize(optionList)

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

--- Make the next set of Augments available
function AugmentsService.GenerateAugments(player)
	-- Get State
	local userId = player.UserId
	local state = Store:getState()
	local playerState = Selectors.PlayerState(state, userId)

	local weights = AugmentsService.GetWeights(playerState.stats.luck)
	local totalWeight = Gears.SumTable(weights)

	-- Generate 3 Augments + Build Ban List
	local banList = {} -- Avoid Generating the Same Augment Type

	local rarity1 = AugmentsService.RollRarity(weights, totalWeight)
	local augment1 = AugmentsService.GetAugment(rarity1)
	table.insert(banList, augment1.modStat)

	local rarity2 = AugmentsService.RollRarity(weights, totalWeight)
	local augment2 = AugmentsService.GetAugment(rarity2, banList)
	table.insert(banList, augment2.modStat)

	local rarity3 = AugmentsService.RollRarity(weights, totalWeight)
	local augment3 = AugmentsService.GetAugment(rarity3, banList)

	local augmentChoices = {
		augment1,
		augment2,
		augment3,
	}

	-- TODO : Find Rarest
	-- local rarest = "Common"

	-- for _, augment in pairs(augmentChoices) do
	-- 	if table.find(AUGMENTS.rarity, augment.rarity) > table.find(AUGMENTS.rarity, rarest) then
	-- 		rarest = augment.rarity
	-- 	end
	-- end

	-- local rarestColor = AUGMENTS.colors[rarest]

	local patch = { currentAugments = augmentChoices }
	Store:dispatch(StoreActions.PatchPlayer(userId, patch))
	-- TODO : Augment Generated Event(rarestColor)
end

-- #endregion

-- #region AUGMENT PICK STATE

-- Send Augments to Client -> Display
function AugmentsService.SendAugments(player)
	local state = Store:getState()
	local userId = player.UserId

	local augmentChoices = state.players[userId].currentAugments

	AugmentsService.Client.NewAugments:Fire(player, augmentChoices)
end

function AugmentsService.FinishAugmentPick(player)
	local userId = player.UserId

	local state = Store:getState()
	local playerState = Selectors.PlayerState(state, userId)

	-- Reset Player State
	player.Character:MoveTo(RpgState.positionStart[userId])
	RpgState.positionStart[userId] = nil

	-- Update PlayerState
	local patch = { state = CONSTANTS.PLAYER_STATES.playing }
	Store:dispatch(StoreActions.PatchPlayer(userId, patch))
	AugmentsService.Client.FinishPickingAugments:Fire(player)

	RpgService.StartLifeRegen(userId, playerState.stats.lifeRegen)
end

-- Player start choosing Augment
function AugmentsService.Client:StartAugmentPick(player)
	-- Get State
	local userId = player.UserId
	local state = Store:getState()
	local playerState = Selectors.PlayerState(state, userId)

	local waitingLevel = playerState.waitingLevel

	-- Validations
	local isValid = waitingLevel > 0 and playerState.currentAugments
	if not isValid then
		warn("No Waiting Levels or Augments = " .. playerState.currentAugments)
		return
	end

	-- Picking Augment State
	-- print(player.Name .. " Is Picking Augment...")
	RpgState.positionStart[userId] = player.Character.HumanoidRootPart.CFrame.Position -- Movements are disabled client side

	RpgService.StopLifeRegen(userId)

	local patch = { state = CONSTANTS.PLAYER_STATES.pickingAugment }
	Store:dispatch(StoreActions.PatchPlayer(userId, patch))

	AugmentsService.SendAugments(player)
end

function AugmentsService.Client:RerollAugment(player)
	local state = Store:getState()
	local playerState = Selectors.PlayerState(state, player.UserId)

	-- Validation
	local rerollCost = 10 -- TODO : Per Player

	if not playerState.currentAugments then
		print(player.Name .. " No Augments ready")
		return
	end

	if playerState.sticks < rerollCost then
		print(player.Name .. " Not enough Sticks")
		return
	end

	-- Transaction
	AugmentsService.GenerateAugments(player)
	AugmentsService.SendAugments(player)
	PlayerService.SubtractCurrency(player, CONSTANTS.CURRENCIES.sticks, rerollCost)
end

--- Player Choose Augment -> Get Stats
function AugmentsService.Client:PickAugment(player, index)
	local userId = player.UserId
	local state = Store:getState()
	local playerState = Selectors.PlayerState(state, userId)

	-- Validation
	local augment = playerState.currentAugments[index]
	assert(augment, player.Name .. " Augment not ready")

	local waitingLevel = playerState.waitingLevel
	assert(waitingLevel > 0, player.Name .. " No waiting Level")

	print(player.Name .. " Choosed : " .. index)

	-- Update State : Level
	local level = playerState.level
	level += 1
	waitingLevel -= 1

	local patch = { level = level, waitingLevel = waitingLevel, currentAugments = nil }
	Store:dispatch(StoreActions.PatchPlayer(userId, patch))
	PlayerService.Client.PatchPlayer:Fire(player, patch)

	-- Update State : Augment
	local augmentPatch = AugmentsService.AugmentPatch(state, userId, augment.modStat, augment.value)
	Store:dispatch(StoreActions.PatchAugment(userId, augmentPatch))
	-- Replicate to Client -> Display Augment stats client side

	-- Make Stat Effective
	local stat = TO_STAT_OBJECT[augment.modStat]
	RpgService.CalculateStat(state, player, stat)

	-- Generate augments for next Level
	AugmentsService.GenerateAugments(player)

	-- Additional Levels
	if waitingLevel > 0 then
		AugmentsService.SendAugments(player)
		return
	end

	AugmentsService.FinishAugmentPick(player)
end

-- #endregion

return AugmentsService
