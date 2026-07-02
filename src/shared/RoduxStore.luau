local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Gears = require(ReplicatedStorage.Shared.Gears)
local Rodux = require(ReplicatedStorage.Shared.Rodux)

MAX_BANANAS = 10_000

-- DATA STRUCTS

-- Rodux hold a table of players
-- key = player.UserId
local PLAYER_STRUCT = {
	username = "",
	isMusicEnabled = true,
	-- Currencies
	bananas = 0,
	sticks = 0,
	stones = 0,
	-- Level
	level = 1,
	currentXp = 0,
	xpRequired = 10,
	-- Stats
	stats = nil,
	metaUpgradesLevel = nil,
	metaUpgradesCost = nil,
	metaUpgradesStat = nil,
	augmentsStat = nil,
	weaponData = nil,
	-- gearData
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
	life = 100,
	lifeRegen = 1,
	damageReduction = 0,
	-- Utility
	mobility = 10,
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

	ToggleMusic = function(userId, enabled)
		return {
			type = "ToggleMusic",
			userId = userId,
			enabled = enabled,
		}
	end,

	-- Currencies
	-- TODO : SetCurrency
	SetBananas = function(userId, bananas)
		return {
			type = "SetBananas",
			userId = userId,
			bananas = bananas,
		}
	end,

	-- Stats
	SetTotalStat = function(userId, statType, value)
		return {
			type = "SetModStat",
			userId = userId,
			statType = statType,
			value = value,
		}
	end,

	-- Meta Upgrades
	SetMetaUpgrades = function(userId, property, metaUpgrades)
		return {
			type = "SetMetaUpgrades",
			userId = userId,
			metaUpgrades = metaUpgrades,
		}
	end,

	SetMetaUpgrade = function(userId, upgradeType, metaUpgrade)
		return {
			type = "SetMetaUpgrade",
			userId = userId,
			upgradeType = upgradeType,
			metaUpgrade = metaUpgrade,
		}
	end,

	SetAugment = function(userId, augmentType, value)
		return {
			type = "SetAugment",
			userId = userId,
			augmentType = augmentType,
			value = value,
		}
	end,

	-- Gear
	SetWeaponData = function(userId, weaponData)
		return {
			type = "SetWeaponData",
			userId = userId,
			weaponData = weaponData,
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
		players[userId].metaUpgrades = Gears.deepCopy(MOD_STATS)
		players[userId].augmentsStats = Gears.deepCopy(MOD_STATS)

		return players
	end,

	RemovePlayer = function(state, action)
		local players = table.clone(state) or {}
		players[action.userId] = nil
		return players
	end,

	ToggleMusic = function(state, action)
		local players = table.clone(state) or {}
		local userId = action.userId
		local enabled = action.enabled

		players[userId].isMusicEnabled = enabled
		return players
	end,

	-- Currencies
	SetBananas = function(state, action)
		local players = table.clone(state) or {}
		players[action.userId].bananas = action.bananas

		return players
	end,

	-- Stats
	SetTotalStat = function(state, action)
		local players = table.clone(state) or {}
		local userId = action.userId
		local statType = action.statType
		local value = action.value

		players[userId].stats[statType] = value
		return players
	end,

	SetMetaUpgrades = function(state, action)
		local players = table.clone(state) or {}
		local metaUpgrades = action.metaUpgrades

		players[action.userId].metaUpgrades = metaUpgrades
		return players
	end,

	SetMetaUpgrade = function(state, action)
		local players = table.clone(state) or {}
		local upgradeType = action.upgradeType
		local metaUpgrade = action.metaUpgrade

		players[action.userId].metaUpgradesLevel[upgradeType] = metaUpgrade.level
		players[action.userId].metaUpgradesCost[upgradeType] = metaUpgrade.cost
		players[action.userId].metaUpgradesStat[upgradeType] = metaUpgrade.stat
		return players
	end,

	SetAugment = function(state, action)
		local players = table.clone(state) or {}
		local augmentType = action.augmentType
		local value = action.value

		players[action.userId].augmentType[augmentType] = value
		return players
	end,

	SetWeaponData = function(state, action)
		local players = table.clone(state) or {}
		players[action.userId].weaponData = action.weaponData
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
