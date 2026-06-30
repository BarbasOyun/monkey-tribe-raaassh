local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Gears = require(ReplicatedStorage.Shared.Gears)
local Rodux = require(ReplicatedStorage.Shared.Rodux)

MAX_BANANAS = 10_000

-- Rodux store hold a table of players
-- key = player.UserId
local PLAYER_STRUCT = {
	username = "",
	isMusicEnabled = true,
	bananas = 0,
	sticks = 0,
	stones = 0,
	stats = nil,
	metaUpgrades = nil,
	weaponData = nil,
	-- gearData
}

-- PlayerStats struct & Authoring Data
-- Default Stats
local PLAYER_STATS_STRUCT = {
	-- Level
	level = 1,
	currentXp = 0,
	increasedXp = 0,
	levelUpXp = 10,
	-- Offensive
	increasedAttackDamage = 0,
	attackDamage = 0,
	critChance = 5,
	critMultiplier = 50,
	increasedAttackSpeed = 0,
	attackSpeed = 0, -- Attacks / Second
	animationTime = 1, -- Get lower as attackSpeed get higher
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
	movementSpeed = 15,
	luck = 0,
	basePickupRange = 10,
	increasedPickupRange = 0,
	pickupRange = 10,
}

-- Load from DB and Store in Server for Mutations
-- When player leave HUB -> Send to DB
local META_UPGRADES = {
	-- Offense
	increasedAttackDamage = 0,
	critChance = 0,
	critMultiplier = 0,
	increasedAttackSpeed = 0,
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

	-- Bananas
	SetBananas = function(userId, bananas)
		return {
			type = "SetBananas",
			userId = userId,
			bananas = bananas,
		}
	end,

	-- Stats
	SetIncreasedStat = function(userId, statType, increasedValue)
		return {
			type = "SetIncreasedStat",
			userId = userId,
			statType = statType,
			increasedValue = increasedValue,
		}
	end,

	SetAttackDamage = function(userId, attackDamage)
		return {
			type = "SetAttackDamage",
			userId = userId,
			attackDamage = attackDamage,
		}
	end,

	SetAttackSpeed = function(userId, attackSpeed, animationTime)
		return {
			type = "SetAttackSpeed",
			userId = userId,
			attackSpeed = attackSpeed,
			animationTime = animationTime,
		}
	end,

	SetAoe = function(userId, aoe)
		return {
			type = "SetAoe",
			userId = userId,
			aoe = aoe,
		}
	end,

	-- Meta Upgrades
	SetMetaUpgrades = function(userId, metaUpgrades)
		return {
			type = "SetMetaUpgrades",
			userId = userId,
			metaUpgrades = metaUpgrades,
		}
	end,

	SetMetaUpgrade = function(userId, upgradeType, value)
		return {
			type = "SetMetaUpgrade",
			userId = userId,
			upgradeType = upgradeType,
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
		players[action.userId] = Gears.deepCopy(PLAYER_STRUCT) -- Deep copy the default Player Data
		players[action.userId].username = action.username
		players[action.userId].stats = Gears.deepCopy(PLAYER_STATS_STRUCT)
		players[action.userId].metaUpgrades = Gears.deepCopy(META_UPGRADES)

		return players
	end,

	RemovePlayer = function(state, action)
		local players = table.clone(state) or {}
		players[action.userId] = nil
		return players
	end,

	-- Bananas
	SetBananas = function(state, action)
		local players = table.clone(state) or {}
		players[action.userId].bananas = action.bananas

		return players
	end,

	-- Stats
	SetIncreasedStat = function(state, action)
		local players = table.clone(state) or {}
		local userId = action.userId
		local statType = action.statType
		local increasedValue = action.increasedValue

		players[userId].stats[statType] = increasedValue
		return players
	end,

	SetAttackDamage = function(state, action)
		local players = table.clone(state) or {}
		players[action.userId].stats.attackDamage = action.attackDamage
		return players
	end,

	SetAttackSpeed = function(state, action)
		local players = table.clone(state) or {}
		players[action.userId].stats.attackSpeed = action.attackSpeed
		players[action.userId].stats.animationTime = action.animationTime
		return players
	end,

	SetAoe = function(state, action)
		local players = table.clone(state) or {}
		players[action.userId].stats.aoe = action.aoe
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
		local value = action.value

		players[action.userId].metaUpgrades[upgradeType] = value
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
