local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Gears = require(ReplicatedStorage.Shared.Gears)
local Rodux = require(ReplicatedStorage.Shared.Rodux)

MAX_BANANAS = 10_000

-- Rodux store hold a table of players
-- key = player.UserId
local PLAYER_STRUCT = {
	username = "",
	bananas = 0,
	sticks = 0,
	stones = 0,
	stats = nil,
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
	SetWeaponData = function(userId, weaponData)
		return {
			type = "SetWeaponData",
			userId = userId,
			weaponData = weaponData,
		}
	end,

	SetIncreasedAttackSpeed = function(userId, increasedAttackSpeed)
		return {
			type = "SetIncreasedAttackSpeed",
			userId = userId,
			-- statType = statType,
			increasedAttackSpeed = increasedAttackSpeed,
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
}

-- RODUX REDUCERS

local playerReducer = Rodux.createReducer({}, {
	AddPlayer = function(state, action)
		local players = table.clone(state) or {} -- Shallow copy the players table
		players[action.userId] = Gears.deepCopy(PLAYER_STRUCT) -- Deep copy the default Player Data
		players[action.userId].username = action.username
		players[action.userId].stats = Gears.deepCopy(PLAYER_STATS_STRUCT)

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
	SetWeaponData = function(state, action)
		local players = table.clone(state) or {}
		players[action.userId].weaponData = action.weaponData
		return players
	end,

	SetIncreasedAttackSpeed = function(state, action)
		local players = table.clone(state) or {}
		players[action.userId].stats.increasedAttackSpeed = action.increasedAttackSpeed
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
