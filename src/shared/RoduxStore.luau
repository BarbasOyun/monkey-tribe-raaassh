local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Gears = require(ReplicatedStorage.Shared.Gears)
local Rodux = require(ReplicatedStorage.Shared.Rodux)

-- DATA STRUCTS

-- Rodux hold a table of players
-- key = player.UserId
local PLAYER_STRUCT = {
	username = "",
	state = "Playing",
	isMusicEnabled = true,
	-- Currencies
	bananas = 0,
	sticks = 0,
	stones = 0,
	-- Score
	kills = 0,
	destruction = 0,
	-- Level
	level = 1,
	waitingLevel = 0,
	currentXp = 0,
	xpRequired = 10,
	-- Stats
	stats = nil,
	metaUpgradesLevel = nil,
	metaUpgradesCost = nil,
	metaUpgrades = nil,
	augments = nil,
	weaponData = "",
	-- gearData
}

-- TODO : Move
local PLAYER_STATE = {
	playing = "Playing",
	pickingAugment = "PickingAugment",
	-- menuing
}

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
	AddPlayer = function(userId, username)
		return {
			type = "AddPlayer",
			userId = userId,
			username = username,
		}
	end,

	RemovePlayer = function(userId)
		return {
			type = "RemovePlayer",
			userId = userId,
		}
	end,

	-- Manage : Music, Currencies, Score, Level, Gear
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
		local players = table.clone(state) or {} -- Shallow copy the players table
		local userId = action.userId

		players[userId] = Gears.deepCopy(PLAYER_STRUCT) -- Deep copy the default Player Data
		players[userId].username = action.username

		-- Stats
		players[userId].stats = Gears.deepCopy(STATS_STRUCT)
		players[userId].metaUpgradesLevel = Gears.deepCopy(MOD_STATS)
		players[userId].metaUpgradesCost = Gears.deepCopy(MOD_STATS)
		players[userId].metaUpgrades = Gears.deepCopy(MOD_STATS)
		players[userId].augments = Gears.deepCopy(MOD_STATS)

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
				continue
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
		local upgradeType = action.upgradeType
		local metaUpgrade = action.metaUpgrade

		players[action.userId].metaUpgradesLevel[upgradeType] = metaUpgrade.level
		players[action.userId].metaUpgradesCost[upgradeType] = metaUpgrade.cost
		players[action.userId].metaUpgrades[upgradeType] = metaUpgrade.stat
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
