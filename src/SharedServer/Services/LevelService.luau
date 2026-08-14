local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Gears = require(ReplicatedStorage.Shared.Gears)

-- Get Constants
local CONSTANTS = require(ServerScriptService.SharedServer.Constants)

local LevelDefinitions
local Events, EventsSounds, Maps, MapsMusics, MapsBuildings

-- Get State
local RoduxStore = require(ReplicatedStorage.Shared.RoduxStore)
local Store = RoduxStore.Store
local StoreActions = RoduxStore.Actions
-- local Selectors = RoduxStore.Selectors

-- Get Mutable State
local MutState = require(ServerScriptService.SharedServer.MutableState)
local LevelState = MutState.LevelState

-- Get Knit
local Knit = require(ReplicatedStorage.Packages.Knit)
-- local Signal = require(ReplicatedStorage.Packages._Index["sleitnick_signal@1.5.0"].signal)

local PlayerService
local EnemyService
local ItemService

local LevelService = Knit.CreateService({
	Name = "LevelService",
	Client = {
		GameTimerUpdate = Knit.CreateSignal(),
		ProgressUpdate = Knit.CreateSignal(),
	},
})

-- #region Bounds

--- Set Quadrilateral limits of the Level
function LevelService.SetLimits(minLimit: Vector2, maxLimit: Vector2)
	local patch = { minLimit = minLimit, maxLimit = maxLimit }
	Store:dispatch(StoreActions.PatchGameState(patch))

	LevelService.LimitInBound()
end

function LevelService.ToFlatVector(v: Vector3)
	return Vector2.new(v.X, v.Z)
end

-- TODO : Set Circular Limits

function LevelService.IsOob(state, point: Vector3)
	local minLimit = state.gameState.minLimit
	local maxLimit = state.gameState.maxLimit

	local horizontal = point.X < minLimit.X or point.X > maxLimit.X
	local vertical = point.Z < minLimit.Y or point.Y > maxLimit.Y

	local isOob = horizontal or vertical

	return isOob
end

--- Take a FlatPoint and return The point within the Limits of the Map
function LevelService.KeepPointInLimits(point: Vector3)
	local state = Store:getState()
	local usePoint = point

	local minLimit = state.gameState.minLimit
	local maxLimit = state.gameState.maxLimit

	local xValue = math.clamp(usePoint.X, minLimit.X, maxLimit.X)
	local zValue = math.clamp(usePoint.Z, minLimit.Y, maxLimit.Y)

	usePoint = Vector3.new(xValue, point.Y, zValue)

	return usePoint
end

--- Prevent Players from going OOB
function LevelService.LimitInBound()
	PlayerService.StateUpdate:Connect(function(state, dt)
		for _, player in pairs(Players:GetPlayers()) do
			local character = player.Character or player.CharacterAdded:Wait()

			local pos = character:GetPivot()
			local isOob = LevelService.IsOob(state, pos)

			if isOob then
				warn(player.Name .. " Is OOB")
				LevelService.ResetPlayerPos(character)
			end
		end
	end)
end

--- Reset Player Position + Momentum
function LevelService.ResetPlayerPos(character)
	local root = character.HumanoidRootPart

	local respawnPos = workspace.Main.SpawnLocation.CFrame.Position + Vector3.new(0, 5, 0)
	character:PivotTo(CFrame.new(respawnPos))
	-- local respawn = workspace.Main.SpawnLocation.CFrame
	-- character:PivotTo(respawn)
	root.AssemblyLinearVelocity = Vector3.zero
end

-- #endregion

-- #region STAGE

function LevelService.LoadLevelDefinitions()
	LevelDefinitions = require(ReplicatedStorage.Shared.AuthoringData.LevelDefinitions)

	Maps = LevelDefinitions.Maps
	MapsMusics = LevelDefinitions.MapsMusics
	MapsBuildings = LevelDefinitions.MapsBuildings

	Events = LevelDefinitions.Events
	EventsSounds = LevelDefinitions.EventsSounds
end

--- Start a New Stage
function LevelService.StartStage()
	-- Generate Map
	LevelState.stageProgress = 0
	LevelState.currentMapId = math.random(1, #MapsBuildings)
	local buildingsAmount = LevelState.buildingAmount
	-- LevelService.GenerateMap(LevelState.currentMapId, LevelState.stageRadius, buildingsAmount)

	warn("Start Stage MapID = " .. LevelState.currentMapId)

	-- Additional Setup
	LevelService.SetMusic(LevelState.currentMapId)
	LevelService.GenerateWeapons()
	LevelService.GenerateEvents()
end

-- Set the Music for a Player
function LevelService.SetPlayerMusic(state, player, mapId)
	warn("Set Player Music : " .. player.Name .. " Map Id = " .. mapId)
	local ClientSounds = player.PlayerGui:WaitForChild("ClientSounds")
	local music = ClientSounds:FindFirstChild("Music")

	-- Destroy old music
	if music then
		music:Destroy()
	end

	-- Add new music
	local mapMusic = MapsMusics[mapId]:clone()
	mapMusic.Parent = ClientSounds
	mapMusic.Name = "Music"

	-- Play Music
	local playerState = state.players[player.UserId]

	if playerState and playerState.isMusicEnabled then
		mapMusic:Play()
	end
end

--- Set music OnCharacterAdded
function LevelService.SetPlayerMusicChar(player, mapId)
	local userId = player.UserId

	-- Add music OnCharacterAdded
	local musicHandle = LevelState.addMusicHandles[userId]

	if musicHandle then
		musicHandle:Disconnect()
	end

	local addMusicHandle = player.CharacterAdded:Connect(function(character)
		-- warn("Set Music for : " .. character.Name)
		local state = Store:getState()
		LevelService.SetPlayerMusic(state, player, mapId)
	end)

	LevelState.addMusicHandles[userId] = addMusicHandle
end

--- Set the Music for every Players
function LevelService.SetMusic(mapId)
	-- Set Music for Current Players
	local state = Store:getState()

	for _, player in pairs(Players:GetPlayers()) do
		LevelService.SetPlayerMusic(state, mapId, player)
		LevelService.SetPlayerMusicChar(player, mapId)
	end

	-- Set Music for Joining Players
	if LevelState.addMusicHandle then
		LevelState.addMusicHandle:Disconnect()
	end

	local addMusicHandle = PlayerService.PlayerAdded:Connect(function(player)
		LevelService.SetPlayerMusicChar(player, mapId)
	end)

	LevelState.addMusicHandle = addMusicHandle
end

function LevelService.ResetLevel()
	LevelService.ClearBuildings()

	ItemService.ClearGroundItems()

	-- Reset every players Pos
	for _, player in pairs(Players:GetPlayers()) do
		LevelService.ResetPlayerPos(player.character)
	end
end

--- Called on destroying Building
function LevelService.ProgressStage()
	if LevelState.isWaitingForNextStage then
		return
	end

	LevelState.partsCount += 1
	local stageProgress = LevelState.partsCount / LevelState.totalParts

	LevelService.CheckEvents(stageProgress)

	-- Is Stage Finished
	if stageProgress >= 1 then
		LevelService.FinishStage()
	end

	LevelService.Client.ProgressUpdate:FireAll(stageProgress)
end

function LevelService.FinishStage()
	-- TODO :
	-- Start Countdown
	task.wait() -- Countdown

	-- Map Increments
	local newBuildingAmount = LevelState.buildingAmount + LevelDefinitions.BUILDINGS_INCREMENT
	LevelState.buildingAmount = math.min(newBuildingAmount, LevelDefinitions.BUILDING_LIMIT)

	local state = Store:getState()
	local currentStage = state.gameState.currentStage + 1

	local patch = { currentStage = currentStage }
	Store:dispatch(StoreActions.PatchGameState(patch))

	PlayerService.PatchGameState:FireAll(patch)

	LevelService.ResetLevel()
	LevelService.StartStage()
end

function LevelService.GameTimer(dt)
	MutState.gameTimerCount += dt

	if MutState.gameTimerCount >= 1 then
		MutState.gameTimerCount -= 1
		MutState.gameTimer += 1

		LevelService.Client.GameTimerUpdate:FireAll(MutState.gameTimer)

		local isLvlBreakpointReached = (MutState.gameTimer % CONSTANTS.EnemyConst.ENEMY_LVL_UP_BREAKPOINT) == 0
		if isLvlBreakpointReached then
			EnemyService.LevelUpEnemies()
		end
	end
end

function LevelService.StartGameTimer()
	warn("Start Game Timer")
	PlayerService.StateUpdate:Connect(function(state, dt)
		LevelService.GameTimer(dt)
	end)
end

-- #endregion

-- #region EVENTS

local EventsLogic = {
	-- Swarm
	function()
		EnemyService.StartSwarmSpawn()
	end,
}

function LevelService.GenerateEvents()
	LevelState.maxEvents = math.random(3, 4)
	-- print("Generating " .. maxEvents .. " Events")

	local currentEvents = {}

	for i = 1, LevelState.maxEvents do
		-- print("Stage Event " .. i .. " : " .. eventsEnum.SWARM)
		table.insert(currentEvents, Events.Swarm)
	end

	-- patch
	local patch = { currentEvents = currentEvents }
	Store:dispatch(StoreActions.PatchGameState(patch))

	PlayerService.Client.PatchGameState:FireAll(patch)
end

function LevelService.CheckEvents(stageProgress)
	local nextEventProgress = LevelState.currentEventIndex / (LevelState.maxEvents + 1)
	local isEventReached = nextEventProgress < 1 and stageProgress >= nextEventProgress

	-- Trigger Event
	if isEventReached then
		local state = Store:getState()
		local currentEventId = state.gameState.currentEvents[LevelState.currentEventIndex]
		warn("Trigger Event ID = " .. currentEventId)

		EventsSounds[currentEventId]:Play()
		EventsLogic[currentEventId]()

		LevelState.currentEventIndex += 1
	end
end

-- #endregion

-- #region MAP GENERATION

--- Generate Random Buildings
function LevelService.GenerateMap(mapId, stageRadiusSize, buildingsAmount)
	local buildings = MapsBuildings[mapId]

	-- DEBUG : Draw Stage Radius + Minimum Radius
	PlayerService.StateUpdate:Connect(function(state, dt)
		-- Outer Radius
		local outerRadiusPoints = Gears.CirclePoints(stageRadiusSize, 20)
		Gears.DrawCircle(Vector3.new(0, 3, 0), outerRadiusPoints)

		-- Inner Radius
		local pos = Vector3.new(LevelDefinitions.SPAWN_POS.X, 3, LevelDefinitions.SPAWN_POS.Y)
		local innerRadiusPoints = Gears.CirclePoints(LevelDefinitions.MINIMUM_RADIUS, 20)
		Gears.DrawCircle(pos, innerRadiusPoints)
	end)

	-- 1] Create Nodes at random Positions
	local buildingAmount = Gears.RandomRange(LevelState.buildingAmount, LevelDefinitions.BUILDINGS_RANGE)
	local minRadius = LevelDefinitions.MINIMUM_RADIUS
	local buildingNodes = LevelService.GenerateNodes(buildings, minRadius, stageRadiusSize, buildingAmount)

	-- 2] Collisions Detection + Solver
	-- local collisions = LevelService.CollisionsDetection(buildingNodes)
	-- LevelService.Solver(buildingNodes, collisions)

	-- 3] Spawn Buildings
	-- Add Prefab in the Nodes
	for i = 1, buildingAmount do
		buildingNodes[i].prefab = buildings[i].prefab
	end

	LevelService.SpawnBuildings(buildingNodes)

	LevelState.totalParts *= 0.5 -- Require 50% of the stage to be completed
end

--- Generate Building Nodes at random positions within 2 Circles
function LevelService.GenerateNodes(buildings, innerRadius, outerRadius, amount)
	local buildingNodes = {}

	local buildingIndex = math.random(1, #buildings)
	local positions = LevelService.GetPosWithinCircles(innerRadius, outerRadius, amount)

	-- Generate Building Nodes
	for i = 1, amount do
		-- Roll Building
		local building = buildings[buildingIndex]
		LevelState.totalParts += building.nbrOfParts

		-- Build Circular Nodes
		local buildingNode = { position = positions[i], radius = building.radius }
		buildingNodes[i] = buildingNode

		buildingIndex = Gears.LoopValue(buildingIndex + 1, #buildings, 1)
	end

	return buildingNodes
end

--- Get random points within 2 Circles -> Inner Circle is at the Center of Outer Circle
function LevelService.GetPosWithinCircles(innerRadius, outerRadius, amount)
	local positions = {}

	for i = 1, amount do
		local radius = Gears.FloatRandom(innerRadius, outerRadius)
		local progress = Gears.FloatRandom(0, CONSTANTS.MAX_RADIANT)

		positions[i] = Gears.CirclePos(radius, progress)
	end

	return positions
end

--- Get random points within a Circle
function LevelService.GetPosWithinCircle(outerRadius, amount, constraints)
	local positions = {}

	for i = 1, amount do
		local radius = Gears.FloatRandom(0, outerRadius)
		local progress = Gears.FloatRandom(0, CONSTANTS.MAX_RADIANT)

		local pos = Gears.CirclePos(radius, progress)

		for j = 1, #constraints do
			pos = constraints[j](pos)
		end

		positions[i] = pos
	end

	return positions
end

--- Get a 2D Point out of a circle
function LevelService.CircleContraint(point: Vector2, circlePos: Vector2, radius: number)
	local circleToPoint = point - circlePos
	local pointCircleDistance = vector.magnitude(circleToPoint)
	local isInCircle = pointCircleDistance < radius

	if not isInCircle then
		return point
	end

	local circlePointNormal = vector.normalize(circleToPoint)
	point = circlePointNormal * radius

	return point
end

--- Detect the Collisions between (Circular) Nodes
function LevelService.CollisionsDetection(circularNodes)
	local collisions = {}
	-- TODO
	return collisions
end

--- Solve collisions between Nodes within 2 Circles
function LevelService.Solver(innerRadius, outerRadius, circularNodes, collisions)
	-- TODO
end

--- Spawn Buildings based on Node Locations
function LevelService.SpawnBuildings(buildingNodes)
	for i = 1, #buildingNodes do
		-- DEBUG : Draw Nodes Radius
		local node = buildingNodes[i]
		PlayerService.StateUpdate:Connect(function(state, dt)
			local pos = Vector3.new(node.position.X, 3, node.position.Y)
			local outerRadiusPoints = Gears.CirclePoints(node.radius, 20)
			Gears.DrawCircle(pos, outerRadiusPoints)
		end)
	end
end

--- Destroy Every Buildings
function LevelService.ClearBuildings()
	-- TODO
end

--- Scatter random weapons in the Map
function LevelService.GenerateWeapons()
	-- TODO
end

-- #endregion

-- Start Service
function LevelService:KnitInit()
	print("LevelService Initialized")
end

function LevelService:KnitStart()
	PlayerService = Knit.GetService("PlayerService")
	EnemyService = Knit.GetService("EnemyService")
	ItemService = Knit.GetService("ItemService")
end

return LevelService
