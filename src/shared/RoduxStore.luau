local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- local ServerScriptService = game:GetService("ServerScriptService")

local Gears = require(script.Parent.Gears)
local Rodux = require(ReplicatedStorage.Shared.Rodux)

-- local CONSTANTS = require(ServerScriptService.SharedServer.Constants)
local statsDefinition = require(ReplicatedStorage.Shared.AuthoringData.StatsDefinitions)

-- Immutable Default Game State
local defaultGameState = {
	enemiesDeathCount = 0,
	globalEnemyLvl = 1,
	minLimit = Vector2.new(-100, -100),
	maxLimit = Vector2.new(100, 100),
	currentStage = 1,
	currentEvents = {},
}

-- #region SELECTORS

local Selectors = {
	PlayerState = function(state, userId)
		assert(state, "State is nil")
		assert(userId, "userId is nil")
		return state.players[userId]
	end,

	PlayerStats = function(playerState)
		assert(playerState, "playerState is Nil")

		local playerStats = playerState.stats
		local weaponData = playerState.weaponData

		return playerStats, weaponData
	end,

	PlayerPowerSystems = function(playerState)
		assert(playerState, "playerState is Nil")

		local augments = playerState.augments
		local metaUpgrades = playerState.metaUpgrades
		-- Gear

		return augments, metaUpgrades
	end,
}

-- #endregion

-- #region RODUX ACTIONS

local Actions = {
	SetWorldState = function(userId, worldState)
		return {
			type = "SetWorldState",
			userId = userId,
			worldState = worldState,
		}
	end,

	PatchGameState = function(patch)
		return {
			type = "PatchGameState",
			patch = patch,
		}
	end,

	-- Players
	AddPlayer = function(player, highestKills)
		return {
			type = "AddPlayer",
			player = player,
			highestKills = highestKills,
		}
	end,

	RemovePlayer = function(userId)
		return {
			type = "RemovePlayer",
			userId = userId,
		}
	end,

	-- Music, Currencies, Score, Level, Gear
	PatchPlayer = function(userId, patch)
		return {
			type = "PatchPlayer",
			userId = userId,
			patch = patch,
		}
	end,

	-- Stats
	PatchStat = function(userId, patch)
		return {
			type = "PatchStat",
			userId = userId,
			patch = patch,
		}
	end,

	-- Meta Upgrades
	SetMetaUpgrade = function(userId, upgradeType, metaUpgrade)
		return {
			type = "SetMetaUpgrade",
			userId = userId,
			upgradeType = upgradeType,
			metaUpgrade = metaUpgrade,
		}
	end,

	-- Augments
	PatchAugment = function(userId, patch)
		return {
			type = "PatchAugment",
			userId = userId,
			patch = patch,
		}
	end,
}

-- #endregion

-- #region RODUX REDUCERS

local playerReducer = Rodux.createReducer({}, {
	AddPlayer = function(state, action)
		local players = table.clone(state) or {}

		local player = action.player
		local userId = player.UserId
		local username = player.Name
		local highestKills = action.highestKills

		players[userId] = Gears.DeepCopy(statsDefinition.DEFAULT_PLAYER)
		players[userId].userId = userId
		players[userId].username = username
		players[userId].highestKills = highestKills

		return players
	end,

	RemovePlayer = function(state, action)
		local players = table.clone(state) or {}
		players[action.userId] = nil
		return players
	end,

	PatchPlayer = function(state, action)
		local players = table.clone(state) or {}

		local userId = action.userId
		local patch = action.patch

		local playerState = players[userId]

		for key, value in pairs(patch) do
			local property = playerState[key]

			if property == nil then
				warn("Key : " .. key .. " Doesn't exist in Player")
			end

			playerState[key] = value
		end

		return players
	end,

	-- Stats
	PatchStat = function(state, action)
		local players = table.clone(state) or {}

		local userId = action.userId
		local patch = action.patch

		for key, value in pairs(patch) do
			local property = players[userId].stats[key]

			if property == nil then
				warn("Key : " .. key .. " Doesn't exist in Stats")
				continue
			end

			players[userId].stats[key] = value
		end

		return players
	end,

	SetMetaUpgrade = function(state, action)
		local players = table.clone(state) or {}

		local userId = action.userId
		local upgradeType = action.upgradeType
		local metaUpgrade = action.metaUpgrade

		players[userId].metaUpgradesLevel[upgradeType] = metaUpgrade.level
		players[userId].metaUpgradesCost[upgradeType] = metaUpgrade.cost
		players[userId].metaUpgrades[upgradeType] = metaUpgrade.stat
		return players
	end,

	PatchAugment = function(state, action)
		local players = table.clone(state) or {}

		local userId = action.userId
		local patch = action.patch

		for key, value in pairs(patch) do
			local property = players[userId].augments[key]

			if not property then
				warn("Key : " .. key .. " Doesn't exist in Augments")
				continue
			end

			players[userId].augments[key] = value
		end

		return players
	end,
})

local gameStateReducer = Rodux.createReducer({}, {
	PatchGameState = function(state, action)
		local gameState = table.clone(state)

		if Gears.IsEmpty(gameState) then
			gameState = defaultGameState
		end

		local patch = action.patch

		for key, value in pairs(patch) do
			local property = gameState[key]

			if property == nil then
				warn("Key : " .. key .. " Doesn't exist in GameState")
				return
			end

			gameState[key] = value
		end

		return gameState
	end,
})

-- #endregion

-- #region STORE / STATE

local rootReducer = Rodux.combineReducers({
	players = playerReducer,
	gameState = gameStateReducer,
	-- ... Others game data
})

local function masterReducer(state, action)
	if action.type == "SetWorldState" then
		local worldState = action.worldState

		return worldState
	end

	return rootReducer(state, action)
end

local store = Rodux.Store.new(masterReducer, nil, {
	Rodux.loggerMiddleware,
})

-- #endregion

return {
	Store = store,
	Actions = Actions,
	Selectors = Selectors,
}
