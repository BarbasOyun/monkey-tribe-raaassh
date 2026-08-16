local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local DataStoreService = game:GetService("DataStoreService")

local CombatService = require(script.Parent.CombatService)
local Gears = require(ReplicatedStorage.Shared.Gears)

-- Get Constants
local CONSTANTS = require(ServerScriptService.SharedServer.Constants)

-- Get State
local RoduxStore = require(ReplicatedStorage.Shared.RoduxStore)
local Store = RoduxStore.Store
local StoreActions = RoduxStore.Actions
-- local Selectors = RoduxStore.Selectors

-- Get Mutable State
local MutState = require(ServerScriptService.SharedServer.MutableState)
local PlayerServiceState = MutState.PlayerServiceState

-- Get DataStore
local PlayersDb = DataStoreService:GetDataStore("PlayersDb")

-- Get Knit
local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages._Index["sleitnick_signal@1.5.0"].signal)

local RpgService
local ItemService

local PlayerService = Knit.CreateService({
	Name = "PlayerService",
	PlayerAdded = Signal.new(),
	PlayerRemoved = Signal.new(),
	PlayerDied = Signal.new(),
	BananasChanged = Signal.new(),
	StateUpdate = Signal.new(),
	ThrottledUpdate = Signal.new(),
	Client = {
		ReplicateStore = Knit.CreateSignal(),
		PlayerAdded = Knit.CreateSignal(),
		PlayerRemoved = Knit.CreateSignal(),
		PatchPlayer = Knit.CreateSignal(),
		PatchGameState = Knit.CreateSignal(),
		-- Hub
		EnteringGame = Knit.CreateSignal(),
	},
})

-- #region PLAYERS

--- Generate Custom Game State for Clients -> Remove Useless Data
local function playerGameState(player)
	local state = Store:getState()
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

function PlayerService.AddPlayer(player)
	local userId = player.UserId
	local username = player.Name

	-- Create Player
	Store:dispatch(StoreActions.AddPlayer(userId, username))

	-- Send the full store to the new player
	local state = Store:getState()
	PlayerService.Client.ReplicateStore:Fire(player, state)

	-- Set Detection to empty
	PlayerServiceState.playersDetections[userId] = {}
	PlayerServiceState.buildingsDetections[userId] = {}

	-- Events
	PlayerService.PlayerAdded:Fire(player)
	PlayerService.Client.PlayerAdded:FireAll(player)

	player.CharacterAdded:Connect(function(character)
		PlayerService.OnCharacterAdded(player, character)
	end)
end

function PlayerService.OnCharacterAdded(player, character)
	-- warn(player.Name .. " Character Added")
	local userId = player.UserId

	PlayerService.AddSounds(player)

	-- Un-kill on character on spawn
	local patch = { isDead = false }
	Store:dispatch(StoreActions.PatchPlayer(userId, patch))
end

function PlayerService.RemovePlayer(player)
	local userId = player.UserId

	Store:dispatch(StoreActions.RemovePlayer(userId))

	-- Events
	PlayerService.PlayerRemoved:Fire(player)
	PlayerService.Client.PlayerRemoved:FireAll(player)
end

--- Add the Default sounds to a player
function PlayerService.AddSounds(player)
	local playerGui = player:WaitForChild("PlayerGui")
	local soundFolder = playerGui.ClientSounds -- or Instance("Folder")

	local mainSounds = MutState.mainSounds:clone()
	mainSounds.Parent = soundFolder
end

function PlayerService.Client:ToggleMusic(player, isEnabled)
	local patch = { isMusicEnabled = isEnabled }
	Store:dispatch(StoreActions.PatchPlayer(player.UserId, patch))
end

-- #endregion

-- #region DB

--- Save a Player Score & Meta Upgrades to Db
function PlayerService.SaveToDb(userId)
	local state = Store:getState()
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

function PlayerService.IncrementDbBananas(userId, value)
	if value <= 0 then
		return
	end

	local success, newValue = pcall(function()
		return PlayersDb:UpdateAsync(userId, function(oldValue)
			local current = oldValue or 0
			local nextValue = current + value
			return math.clamp(nextValue, 0, CONSTANTS.MAX_CURRENCIES[CONSTANTS.CURRENCIES.bananas])
		end)
	end)
end

function PlayerService.GetBananasDb(player)
	local userId = player.UserId
	local bananaCount = 0

	local success, bananas = pcall(function()
		return PlayersDb:GetAsync(userId .. "_bananas")
	end)

	if success and bananas then
		bananaCount = bananas
	end

	local patch = { bananas = bananaCount }

	Store:dispatch(StoreActions.PatchPlayer(userId, patch))
	PlayerService.Client.PatchPlayer:Fire(player, patch)
end

--- Get Meta Upgrades Levels from DB or 0
function PlayerService.GetMetaUpgrades(player)
	local userId = player.UserId

	local levels = {}
	local costs = {}
	local metaUpgrades = {}

	local state = Store:getState()
	local playerState = state.players[userId]

	for upgradeType, _ in pairs(playerState.metaUpgrades) do
		local level = 0

		local success, dbLevel = pcall(function()
			return PlayersDb:GetAsync(userId .. "_" .. upgradeType)
		end)

		if success and dbLevel then
			-- warn(upgradeType .. " Level from DB = " .. dbLevel)
			level = dbLevel
		end

		local cost, stat = RpgService.UpdateMetaUpgrade(level, upgradeType)

		levels[upgradeType] = level
		costs[upgradeType] = cost
		metaUpgrades[upgradeType] = stat
	end

	local patch = { metaUpgradesLevel = levels, metaUpgradesCost = costs, metaUpgrades = metaUpgrades }
	Store:dispatch(StoreActions.PatchPlayer(userId, patch))

	RpgService.CalculateAllStats(player)
end

--- Debug func -> Delete Player's DB
local function ResetPlayer(player)
	local state = Store:getState()
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

-- #endregion

-- #region GAME
-- TODO GameService + Per Place Services loading

function PlayerService.GameOver()
	print("Game Over -> Saving Bananas & Going back to Hub")
	local players = Players:GetPlayers()

	PlayerService.SaveAllBananasDelta()

	pcall(function()
		return TeleportService:TeleportAsync(CONSTANTS.HUB_PLACE_ID, players)
	end)
end

--- Calculate Bananas Delta for a player and Increment the DB Value by it
function PlayerService.SaveBananasDelta(player)
	-- TODO
	local bananasDelta = 0
	PlayerService.IncrementDbBananas(player.UserId, bananasDelta)
end

function PlayerService.SaveAllBananasDelta()
	for _, player in pairs(Players:GetPlayers()) do
		PlayerService.SaveBananasDelta(player)
	end
end

--- CheckGameOver on player Death
function PlayerService.SetupGameOver(player)
	Players.CharacterAutoLoads = false

	local function onCharacterAdded(character)
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.Died:Connect(PlayerService.CheckGameOver)
	end

	player.CharacterAdded:Connect(onCharacterAdded)
end

function PlayerService.CheckGameOver()
	local state = Store:getState()
	local players = state.players

	local deadPlayersCount = 0

	-- Count using custom isDead
	-- for i = 1, #players, 1 do
	-- 	if players[i].isDead then
	-- 		deadPlayersCount += 1
	-- 	end
	-- end

	-- Count using Roblox Humanoid
	for _, player in pairs(Players:GetPlayers()) do
		if player.character.Humanoid.Health <= 0 then
			deadPlayersCount += 1
		end
	end

	if deadPlayersCount >= #players then
		PlayerService.GameOver()
	end
end

--- Resurrect every Dead players
function PlayerService.ResurrectAll()
	for _, player in pairs(Players:GetPlayers()) do
		if player.character.Humanoid.Health <= 0 then
			player:LoadCharacterAsync()
		end
	end
end

function PlayerService.KillPlayer(player)
	print(player.Name .. " died -> Waiting Next Stage to respawn...")
	local userId = player.UserId

	local patch = { isDead = true }
	Store:dispatch(StoreActions.PatchPlayer(userId, patch))

	PlayerService.PlayerDied:Fire()
	-- Events.PlayerDied:FireClient(player) -- TODO : Client Event

	player.character.Humanoid.Health = 0
	PlayerService.CheckGameOver()
end

-- #endregion

-- #region CURRENCIES

-- currencyId = from CONSTANTS.CURRENCIES
function PlayerService.GetCurrency(state, userId, currencyId)
	local playerData = state.players[userId]
	local currency = playerData[CONSTANTS.CURRENCIES_NAMES[currencyId]]
	return if currency ~= nil then currency else 0
end

local function updateCurrency(state, player, currencyId, value)
	local userId = player.UserId

	local currency = PlayerService:GetCurrency(state, userId, currencyId)
	local newValue = math.clamp(currency + value, 0, CONSTANTS.MAX_CURRENCIES[currencyId])

	local patch = { [CONSTANTS.CURRENCIES_NAMES[currencyId]] = newValue }
	Store:dispatch(StoreActions.PatchPlayer(userId, patch))

	-- Replicate to Clients
	PlayerService.Client.PatchPlayer:Fire(player, patch)

	-- For Managers
	PlayerService.BananasChanged:Fire(player, value)
end

local function updateCurrencyToAllPlayers(currencyId, value)
	assert(value ~= 0, "value must be not zero")

	local state = Store:getState()

	for _, player in Players:GetPlayers() do
		updateCurrency(state, player, currencyId, value)
	end
end

function PlayerService.AddCurrencyToAllPlayers(currencyId, value)
	assert(value > 0, "value must be positive")
	updateCurrencyToAllPlayers(currencyId, value)
end

function PlayerService.AddCurrencyToPlayer(player, currencyId, value)
	assert(value > 0, "value must be positive")

	local state = Store:getState()

	updateCurrency(state, player, currencyId, value)
end

function PlayerService.SubtractCurrency(player, currencyId, value)
	assert(value > 0, "value must be positive")

	local state = Store:getState()

	updateCurrency(state, player, currencyId, -value)
end

-- #endregion

-- #region UPDATES

--- Detect Enemies around player -> Calculate Distance + Normals
local function enemiesDetection(state, player)
	local userId = player.UserId
	local playerState = state.players[userId]

	PlayerServiceState.playersDetections[userId] = {}

	if not playerState then
		return
	end

	local character = player.Character or player.CharacterAdded:Wait()
	local torso = character.UpperTorso or character.Torso
	local playerPos = torso.CFrame.Position

	-- DEBUG
	-- Gears.DisplayHitBox(position, 10, 0.1)

	-- Calc Distance Player -> Enemy
	local hits = workspace:GetPartBoundsInRadius(
		playerPos,
		CONSTANTS.ENEMIES_DETECTION_RADIUS,
		PlayerServiceState.enemiesDetectionParam
	)

	-- Detect Enemy Humanoids
	local detectedEnemies = Gears.FindUniqueHumanoids(hits)

	-- Calculate Distance Player to Enemy
	for _, humanoid in pairs(detectedEnemies) do
		local enemy = humanoid.Parent :: Model
		local enemyPos = enemy.Torso.CFrame.Position

		local playerToEnemyDirection = enemyPos - playerPos

		local playerToEnemyDistance = vector.magnitude(playerToEnemyDirection) :: number
		PlayerServiceState.playersDetections[userId][enemy] = playerToEnemyDistance

		-- TODO : Calculate Normals
	end
end

--- Detect Buildings around player -> Calculate Distance + Normals
function PlayerService.BuildingsDetection(state, player)
	local userId = player.UserId
	local playerState = state.players[userId]

	PlayerServiceState.buildingsDetections[userId] = {}

	if not playerState then
		return
	end

	local character = player.Character or player.CharacterAdded:Wait()
	local torso = character.UpperTorso or character.Torso
	local playerPos = torso.CFrame.Position

	-- Detection
	local hits = workspace:GetPartBoundsInRadius(
		playerPos,
		CombatService.PlayerRange(playerState.stats),
		MutState.LevelState.buildingsDetectionParam
	)

	-- Calculate Distance Player to Building
	for _, part in pairs(hits) do
		local buildingPos = part.CFrame.Position

		local playerToBuilding = buildingPos - playerPos

		local playerToBuildingDistance = vector.magnitude(playerToBuilding) :: number
		PlayerServiceState.buildingsDetections[userId][part] = playerToBuildingDistance

		-- TODO : Calculate Normals
	end
end

--- Lerp Item Pos to Player
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
		local character = player.character

		if not character then
			return
		end

		itemModel.CFrame = startPos:Lerp(character:GetPivot(), progress)
		RunService.Heartbeat:Wait()
	end

	ItemService.PickupItem(player, itemModel)
end

--- Player Autopickup Ground Items
local function autoPickupRange(state, player)
	local userId = player.UserId
	local playerState = state.players[userId]

	if not playerState then
		return
	end

	local character = player.Character or player.CharacterAdded:Wait()
	local playerPos = character.HumanoidRootPart.CFrame.Position
	local pickupRange = playerState.stats.pickupRange

	-- DEBUG
	-- Gears.DisplayHitBox(position, pickupRange, 0.1)

	local autoPickupItems = workspace:GetPartBoundsInRadius(playerPos, pickupRange, PlayerServiceState.autoPickupParam)

	for _, itemModel in ipairs(autoPickupItems) do
		autoPickup(player, itemModel)
	end
end

local function stateUpdate(dt: number)
	local state = Store:getState() -- Get state once every frame

	PlayerService.StateUpdate:Fire(state, dt)

	-- Throttled Update
	MutState.frameCount += 1

	if MutState.frameCount > CONSTANTS.THROTTLED_UPDATE_FRAMES then
		PlayerService.ThrottledUpdate:Fire(state, dt)

		for _, player in pairs(Players:GetPlayers()) do
			autoPickupRange(state, player)
			enemiesDetection(state, player)
		end

		MutState.frameCount = 0
	end
end

-- #endregion

-- Start Service
function PlayerService:KnitInit()
	print("PlayerService Initialized")
end

function PlayerService:KnitStart()
	RpgService = Knit.GetService("RpgService")
	ItemService = Knit.GetService("ItemService")

	RunService.Heartbeat:Connect(function(dt: number)
		stateUpdate(dt)
	end)
end

return PlayerService
