local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rodux = require(ReplicatedStorage.Shared.Rodux)

-- RODUX ACTIONS

local Actions = {
	SetGameState = function(gameState, userId)
		return {
			type = "SetGameState",
			gameState = gameState,
			userId = userId,
		}
	end,

	-- Players
	AddPlayer = function(userId, playerData)
		return {
			type = "AddPlayer",
			userId = userId,
			playerData = playerData,
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

-- RODUX REDUCERS

local playerReducer = Rodux.createReducer({}, {
	AddPlayer = function(state, action)
		local players = table.clone(state) or {}

		local userId = action.userId
		local playerData = action.playerData

		players[userId] = playerData

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

		for key, value in pairs(patch) do
			local property = players[userId][key]

			if not property then
				warn("Key : " .. key .. " Doesn't exist in Player")
				-- continue
			end

			players[userId][key] = value
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

			if not property then
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

-- STORE

local rootReducer = Rodux.combineReducers({
	players = playerReducer,
	-- Other game data
})

local function masterReducer(state, action)
	if action.type == "SetGameState" then
		local players = table.clone(state.players) or {}
		local gamePlayers = action.gameState.players -- playerList from the server

		for userId, player in pairs(gamePlayers) do
			players[userId] = player
		end

		return {
			players = players,
			-- Other game data
		}
	end

	return rootReducer(state, action)
end

local store = Rodux.Store.new(masterReducer, nil, {
	Rodux.loggerMiddleware,
})

return {
	Store = store,
	Actions = Actions,
}
