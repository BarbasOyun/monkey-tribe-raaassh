local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Gears = require(ReplicatedStorage.Shared.Gears)
local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages._Index["sleitnick_signal@1.5.0"].signal)

-- Get Rodux Store
local RoduxStore = require(ReplicatedStorage.Shared.RoduxStore)
local store = RoduxStore.Store
local storeActions = RoduxStore.Actions

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
	currentAugments = {}, -- 3+ choice cards
	weaponData = nil,
	-- gearData
}

local PLAYER_STATE = {
	playing = "Playing",
	pickingAugment = "PickingAugment",
	-- menuing
}

local CURRENCIES = {
	bananas = "bananas",
	sticks = "sticks",
	stones = "stones",
}

local MAX_CURRENCIES = {
	bananas = 100_000,
	sticks = 10_000,
	stones = 10_000,
}

local StatService
local ItemService

-- DataStore
local PlayersDb = DataStoreService:GetDataStore("PlayersDb")

-- TP to main Game instance
local HUB_PLACE_ID = 95975992291805

-- GlobalUpdate
local THROTTLED_UPDATE_FRAMES = 5
local frameCount = 0

-- PickupRange Parameters
local autoPickupParam = OverlapParams.new()
autoPickupParam.FilterType = Enum.RaycastFilterType.Include
autoPickupParam.FilterDescendantsInstances = { workspace.AutoPickup }
autoPickupParam.MaxParts = 50

-- Enemies Detection
local detectionParam = OverlapParams.new()
detectionParam.FilterType = Enum.RaycastFilterType.Include
detectionParam.FilterDescendantsInstances = { workspace.WeaponHit }
detectionParam.MaxParts = 50

-- List with key = userId of tables : key = enemy, Value = squared distance
-- TODO : Flatten -> playersDetectionCount
local playersDetections = {}

-- Game
-- TODO : Move to GameManager
local MAX_DISTANCE = 250
local deadPlayers = {}

local PlayerService = Knit.CreateService({
	Name = "PlayerService",
	PlayerAdded = Signal.new(),
	PlayerRemoved = Signal.new(),
	BananasChanged = Signal.new(),
	PLAYER_STATE = PLAYER_STATE,
	CURRENCIES = CURRENCIES,
	PlayersDetections = playersDetections,
	StateUpdate = Signal.new(),
	ThrottledUpdate = Signal.new(),
	Client = {
		ReplicateStore = Knit.CreateSignal(),
		PlayerAdded = Knit.CreateSignal(),
		PlayerRemoved = Knit.CreateSignal(),
		PatchPlayer = Knit.CreateSignal(),
		-- Hub
		EnteringGame = Knit.CreateSignal(),
	},
})

-- PLAYERS

-- Per Player Custom GameState -> Remove useless Data
local function playerGameState(player)
	local state = store:getState()
	local players = {}

	for userId, player in pairs(state.players) do
		if userId == player.UserId then
			-- Self Data
			players[userId] = {
				username = player.username,
				isMusicEnabled = player.isMusicEnabled,
				-- Score
				kills = player.kills,
				-- Currencies
				bananas = player.bananas,
				sticks = player.sticks,
				stones = player.stones,
				stats = player.stats,
				metaUpgrades = player.metaUpgrades,
			}
		else
			-- Others Data
			players[userId] = {
				username = player.username,
				kills = player.kills,
			}
		end
	end

	local gameState = {
		players = players,
		-- other game data
	}

	-- return gameState
	return gameState
end

local function createPlayerData(player)
	local playerData = Gears.deepCopy(PLAYER_STRUCT)

	playerData.username = player.Name

	local statsStruct = StatService.STATS_STRUCT
	local modStatsStruct = StatService.MOD_STATS

	-- Stats
	playerData.stats = Gears.deepCopy(statsStruct)
	playerData.metaUpgradesLevel = Gears.deepCopy(modStatsStruct)
	playerData.metaUpgradesCost = Gears.deepCopy(modStatsStruct)
	playerData.metaUpgrades = Gears.deepCopy(modStatsStruct)
	playerData.augments = Gears.deepCopy(modStatsStruct)

	return playerData
end

-- TODO : AddHubPlayer
function PlayerService:AddPlayer(player, username)
	local userId = player.UserId

	-- Create Player
	local playerData = createPlayerData(player)
	store:dispatch(storeActions.AddPlayer(userId, playerData))

	-- TODO : Move to GameManager
	-- On Player Death
	-- player:LoadCharacterAsync()
	-- local character = player.Character
	-- character.Humanoid.Died:Connect(function()
	-- 	self:OnPlayerDeath(player)
	-- end)

	-- Stats
	self:GetMetaUpgrades(userId)

	-- Send the full store to the new player
	local state = store:getState()
	self.Client.ReplicateStore:Fire(player, state)

	-- Events
	self.PlayerAdded:Fire(userId)
	self.Client.PlayerAdded:FireAll(userId, username)
end

function PlayerService:RemovePlayer(player)
	local userId = player.UserId

	store:dispatch(storeActions.RemovePlayer(userId))

	-- Events
	self.PlayerRemoved:Fire(userId)
	self.Client.PlayerRemoved:FireAll(userId)
end

function PlayerService.Client:ToggleMusic(player, isEnabled)
	store:dispatch(storeActions.PatchPlayer(player.UserId, { isMusicEnabled = isEnabled }))
end

-- Prevent Players from groing OOB
function PlayerService:LimitInBound(limit)
	RunService.Heartbeat:Connect(function()
		for _, player in pairs(Players:GetPlayers()) do
			local character = player.Character or player.CharacterAdded:Wait()
			local root = character.Humanoid.HumanoidRootPart

			local pos = root.Position
			local flatPos = Vector2.new(pos.X, pos.Z) -- Check 2D distance

			if flatPos.Magnitude > MAX_DISTANCE then -- TODO : Squared Magnitude
				character:PivotTo(CFrame.new(Vector3.zero))
				root.AssemblyLinearVelocity = Vector3.zero -- Reset momentum
			end
		end
	end)
end

-- DB

-- Save Score & Meta Upgrades to Db
function PlayerService:SaveToDb(userId)
	local state = store:getState()
	local playerData = state.players[userId]

	warn(playerData.username .. " Saving Meta Upgrades and Score to DB")

	-- Bananas
	local bananaCount = playerData.bananas
	-- warn("Bananas = " .. bananaCount)
	pcall(function()
		PlayersDb:SetAsync(userId .. "_bananas", bananaCount)
	end)

	-- Meta Upgrades
	for upgradeType, level in pairs(playerData.metaUpgradesLevel) do
		-- warn(upgradeType .. " Saving Level to DB : " .. level)
		pcall(function()
			PlayersDb:SetAsync(userId .. "_" .. upgradeType, level)
		end)
	end
end

function PlayerService:IncrementDbBananas(userId, value)
	if value <= 0 then
		return
	end

	local success, newValue = pcall(function()
		return PlayersDb:UpdateAsync(userId, function(oldValue)
			local current = oldValue or 0
			local nextValue = current + value
			return math.clamp(nextValue, 0, MAX_CURRENCIES[CURRENCIES.bananas])
		end)
	end)
end

-- Get
function PlayerService:GetBananasDb(player)
	local userId = player.UserId
	local bananaCount = 0

	local success, bananas = pcall(function()
		return PlayersDb:GetAsync(userId .. "_bananas")
	end)

	if success and bananas then
		bananaCount = bananas
	end

	local patch = { bananas = bananaCount }

	store:dispatch(storeActions.PatchPlayer(userId, patch))
	self.Client.PatchPlayer:Fire(player, patch)
end

function PlayerService:GetMetaUpgrades(userId)
	-- Get Levels from DB or 0
	local levels = {}
	local costs = {}
	local metaUpgrades = {}

	local state = store:getState()
	local playerData = state.players[userId]

	for upgradeType, _ in pairs(playerData.metaUpgrades) do
		local level = 0

		local success, dbLevel = pcall(function()
			return PlayersDb:GetAsync(userId .. "_" .. upgradeType)
		end)

		if success and dbLevel then
			-- warn(upgradeType .. " Level from DB = " .. dbLevel)
			level = dbLevel
		end

		local cost, stat = StatService:UpdateMetaUpgrade(level, upgradeType)

		levels[upgradeType] = level
		costs[upgradeType] = cost
		metaUpgrades[upgradeType] = stat
	end

	local patch = { metaUpgradesLevel = levels, metaUpgradesCost = costs, metaUpgrades = metaUpgrades }
	store:dispatch(storeActions.PatchPlayer(userId, patch))

	StatService:CalculateAllStats(userId)
end

-- Debug func -> Delete Player's DB
local function ResetPlayer(player)
	local state = store:getState()
	local userId = player.UserId
	local playerData = state.players[userId]

	-- Bananas
	pcall(function()
		PlayersDb:SetAsync(userId .. "_" .. "bananas", 0)
	end)

	-- Meta Upgrades
	for upgradeType, value in pairs(playerData.metaUpgradesLevel) do
		pcall(function()
			PlayersDb:SetAsync(userId .. "_" .. upgradeType, 0)
		end)
	end
end

-- GAME
-- TODO : Move to GameManager

function PlayerService:GameOver()
	print("Game Over -> Saving Bananas & Going back to Hub")
	local players = Players:GetPlayers()

	-- TODO : Get Bananas Delta
	for _, player in pairs(players) do
		local bananasDelta = 0
		PlayerService:IncrementDbBananas(player.UserId, bananasDelta)
	end

	pcall(function()
		return TeleportService:TeleportAsync(HUB_PLACE_ID, players)
	end)
end

function PlayerService:OnPlayerDeath(player)
	print(player.Name .. " died -> Waiting Next Stage to respawn...")
	table.insert(deadPlayers, player)
	-- Events.PlayerDied:FireClient(player) -- TODO : Event

	if #deadPlayers >= #Players:GetPlayers() then
		self:GameOver()
	end
end

-- CURRENCIES

-- currencyType = from CURRENCIES
function PlayerService:GetCurrency(state, userId, currencyType)
	local playerData = state.players[userId]
	local currency = playerData[currencyType]
	return if currency ~= nil then currency else 0
end

local function updateCurrency(state, player, currencyType, value)
	local userId = player.UserId

	local currency = PlayerService:GetCurrency(state, userId, currencyType)
	local newValue = math.clamp(currency + value, 0, MAX_CURRENCIES[currencyType])

	local patch = { [currencyType] = newValue }
	store:dispatch(storeActions.PatchPlayer(userId, patch))

	-- Replicate to Clients
	PlayerService.Client.PatchPlayer:Fire(player, patch)

	-- For Managers
	PlayerService.BananasChanged:Fire(player, value)
end

local function updateCurrencyToAllPlayers(currencyType, value)
	assert(value ~= 0, "value must be not zero")

	local state = store:getState()

	for _, player in Players:GetPlayers() do
		updateCurrency(state, player, currencyType, value)
	end
end

-- Add To all Players
function PlayerService:AddCurrencyToAllPlayers(currencyType, value)
	assert(value > 0, "value must be positive")
	updateCurrencyToAllPlayers(currencyType, value)
end

function PlayerService:SubtractCurrency(player, currencyType, value)
	assert(value > 0, "value must be positive")

	local state = store:getState()

	updateCurrency(state, player, currencyType, -value)
end

-- UPDATES

-- Enemies Detection
local function enemiesDetection(state)
	for _, player in pairs(Players:GetPlayers()) do
		local userId = player.UserId

		playersDetections[userId] = {}

		local playerData = state.players[player.userId]

		if not playerData then
			continue
		end

		local character = player.Character or player.CharacterAdded:Wait()
		local playerPos = character.HumanoidRootPart.CFrame.Position

		-- DEBUG
		-- Gears.DisplayHitBox(position, 10, 0.1)

		-- Get the Squared Distance Player -> Enemy
		local detectedEnemies = workspace:GetPartBoundsInRadius(playerPos, 15, detectionParam)

		for _, enemy in pairs(detectedEnemies) do
			local playerToEnemyDirection = enemy.CFrame.Position - playerPos
			local playerToEnemyDistanceSquared = Gears.squaredMagnitude(playerToEnemyDirection)
			playersDetections[userId][enemy] = playerToEnemyDistanceSquared
		end
	end
end
-- Auto Pickup
local function autoPickup(player, itemModel)
	if not itemModel.Parent or itemModel.Parent ~= workspace.AutoPickup then
		return
	end

	itemModel.Parent = game.Workspace
	itemModel.CanCollide = false

	-- Lerp itemModel
	local startPos = itemModel.CFrame

	local steps = 20
	local progress = 0
	local speed = 1 / steps / 4
	local acceleration = (1 / steps - speed) / (steps / 2)

	for _ = 1, steps do
		progress += speed
		speed += acceleration
		itemModel.CFrame = startPos:Lerp(player.character:GetPivot(), progress)
		RunService.Heartbeat:Wait()
	end

	ItemService:PickupItem(player, itemModel)
end

local function autoPickupRange(state)
	for _, player in ipairs(Players:GetPlayers()) do
		local playerData = state.players[player.userId]

		if not playerData then
			continue
		end

		local character = player.Character or player.CharacterAdded:Wait()
		local playerPos = character.HumanoidRootPart.CFrame.Position
		local pickupRange = playerData.stats.pickupRange

		-- DEBUG
		-- Gears.DisplayHitBox(position, pickupRange, 0.1)

		local autoPickupItems = workspace:GetPartBoundsInRadius(playerPos, pickupRange, autoPickupParam)

		for _, itemModel in ipairs(autoPickupItems) do
			autoPickup(player, itemModel)
		end
	end
end

local function stateUpdate()
	frameCount += 1

	local state = store:getState() -- Get state once every frame

	PlayerService.StateUpdate:Fire(state)

	-- Throttled Update
	if frameCount > THROTTLED_UPDATE_FRAMES then
		PlayerService.ThrottledUpdate:Fire(state)

		autoPickupRange(state)
		enemiesDetection(state)

		frameCount = 0
	end
end

-- Start Service
function PlayerService:KnitInit()
	print("PlayerService Initialized")
end

function PlayerService:KnitStart()
	StatService = Knit.GetService("StatService")
	ItemService = Knit.GetService("ItemService")

	RunService.Heartbeat:Connect(stateUpdate)
end

return PlayerService
