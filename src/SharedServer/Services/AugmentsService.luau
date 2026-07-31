local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Gears = require(ReplicatedStorage.Shared.Gears)
local Knit = require(ReplicatedStorage.Packages.Knit)
-- local Signal = require(ReplicatedStorage.Packages._Index["sleitnick_signal@1.5.0"].signal)

-- Get Constants
local CONSTANTS = require(ServerScriptService.SharedServer.Constants)

local statsDefinition = require(ReplicatedStorage.Shared.AuthoringData.StatsDefinitions)
local MOD_STATS_INDEX = statsDefinition.MOD_STATS_INDEX
local AUGMENTS = statsDefinition.AUGMENTS

-- Get Rodux Store
local RoduxStore = require(ReplicatedStorage.Shared.RoduxStore)
local Store = RoduxStore.Store
local Selectors = RoduxStore.Selectors
local StoreActions = RoduxStore.Actions

-- Get Mutable State
local MutState = require(ServerScriptService.SharedServer.MutableState)
local StatState = MutState.StatState

-- Get Services
local RpgService
local PlayerService

local AugmentsService = Knit.CreateService({
	Name = "AugmentsService",
	Client = {
		NewAugments = Knit.CreateSignal(),
		FinishPickingAugments = Knit.CreateSignal(),
	},
})

-- Generate a patch of the specified augment
local function augmentPatch(state, userId, modStat, value)
	local playerData = state.players[userId]

	-- Get stat
	local stat = playerData.augments[modStat]
	local newStat = stat + value

	local patch = { [modStat] = newStat }
	return patch
end

-- Debug func : Add a Specific Stat
function AugmentsService.AddAugmentStat(userId, modStat, value)
	local state = Store:getState()

	local patch = augmentPatch(state, userId, modStat, value)
	Store:dispatch(StoreActions.PatchAugment(userId, patch))
end

-- #region AUGMENTS GENERATION

-- Generate Weight for each Rarity based on Luck Value
local function getWeights(luck)
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

-- Get a Rarity based on Weights
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

-- Get a random valid augment of a Rarity
local function getAugment(rarity, banList)
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

-- Make the next set of Augments available
function AugmentsService.GenerateAugments(player)
	local userId = player.UserId
	local state = Store:getState()
	local playerData = state.players[userId]

	local weights = getWeights(playerData.stats.luck)
	local totalWeight = Gears.SumTable(weights)

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
local function sendAugments(player)
	local state = Store:getState()
	local userId = player.UserId

	local augmentChoices = state.players[userId].currentAugments

	AugmentsService.Client.NewAugments:Fire(player, augmentChoices)
end

local function finishAugmentPick(player)
	local userId = player.UserId

	local state = Store:getState()
	local playerState = Selectors.PlayerState(state, userId)

	-- Reset Player State
	player.Character:MoveTo(StatState.positionStart[userId])
	StatState.positionStart[userId] = nil

	RpgService.StartLifeRegen(userId, playerState.stats.lifeRegen)

	local patch = { state = CONSTANTS.PLAYER_STATES.playing }

	Store:dispatch(StoreActions.PatchPlayer(userId, patch))
	AugmentsService.Client.FinishPickingAugments:Fire(player)
end

-- Player start choosing Augment
function AugmentsService.Client:StartAugmentPick(player)
	local userId = player.UserId
	local state = Store:getState()
	local playerState = Selectors.PlayerState(state, userId)

	-- Validations
	assert(playerState.currentAugments, player.Name .. " No Augments ready")

	local waitingLevel = playerState.waitingLevel
	assert(waitingLevel > 0, player.Name .. " No waiting Level")

	-- Picking Augment State
	-- print(player.Name .. " Is Picking Augment...")
	StatState.positionStart[userId] = player.Character.HumanoidRootPart.CFrame.Position -- Movements are disabled client side

	RpgService.StopLifeRegen(userId)

	local patch = { state = CONSTANTS.PLAYER_STATES.pickingAugment }
	Store:dispatch(StoreActions.PatchPlayer(userId, patch))

	sendAugments(player)
end

function AugmentsService.Client:RerollAugment(player)
	local state = Store:getState()
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
	AugmentsService.SendAugment(player)

	PlayerService:SubtractCurrency(player, PlayerService.CURRENCIES.sticks, 10)
end

function AugmentsService.Client:PickAugment(player, index)
	local userId = player.UserId
	local state = Store:getState()
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
	Store:dispatch(StoreActions.PatchAugment(userId, augmentPatch))
	-- Replicate to Client -> Display Augment stats client side

	-- Update Player Level
	local patch = { level = level, waitingLevel = waitingLevel, currentAugments = nil }
	Store:dispatch(StoreActions.PatchPlayer(userId, patch))
	PlayerService.Client.PatchPlayer:Fire(player, patch)

	-- Generate augments for next Level
	AugmentsService.GenerateAugments(player)

	-- Additional Levels
	if waitingLevel > 0 then
		sendAugments(player)
		return
	end

	finishAugmentPick(player)
end

-- #endregion

-- Start Service
function AugmentsService:KnitInit()
	print("AugmentsService Initialized")
end

function AugmentsService:KnitStart()
	RpgService = Knit.GetService("RpgService")
	PlayerService = Knit.GetService("PlayerService")
end

return AugmentsService
