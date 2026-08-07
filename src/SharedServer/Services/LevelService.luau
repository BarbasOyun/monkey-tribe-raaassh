local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- local Gears = require(ReplicatedStorage.Shared.Gears)
local Knit = require(ReplicatedStorage.Packages.Knit)
-- local Signal = require(ReplicatedStorage.Packages._Index["sleitnick_signal@1.5.0"].signal)

-- Get Constants
local CONSTANTS = require(ServerScriptService.SharedServer.Constants)

local LevelDefinitions = require(ReplicatedStorage.Shared.AuthoringData.LevelDefinitions)
-- local Maps = LevelDefinitions.Maps
local Events = LevelDefinitions.Events

-- Get State
local RoduxStore = require(ReplicatedStorage.Shared.RoduxStore)
local Store = RoduxStore.Store
local StoreActions = RoduxStore.Actions
-- local Selectors = RoduxStore.Selectors

-- Get Mutable State
local MutState = require(ServerScriptService.SharedServer.MutableState)
local LevelState = MutState.LevelState

-- Get Services
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
	PlayerService.StateUpdate:Connect(function(state, dt)
		LevelService.GameTimer(dt)
	end)
end

--- Start a New Stage
function LevelService.StartStage()
	LevelState.stageProgress = 0
	LevelState.currentMapId = math.random(1, 2) -- FIXME : replace 2 with Map Count
	EnemyService.StartStreamSpawn()

	LevelService.GenerateEvents()
	-- LevelService.GenerateMap()
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
	-- TODO
	-- Start Countdown
	-- Stage Increments
	-- stageBuildingNbr = math.clamp(stageBuildingNbr + ADDITIONAL_BUILDINGS, 0, BUILDING_LIMIT)

	task.wait()
	local state = Store:getState()
	local currentStage = state.gameState.currentStage + 1

	local patch = { currentStage = currentStage }
	Store:dispatch(StoreActions.PatchGameState(patch))

	PlayerService.PatchGameState:FireALl(patch)

	LevelService.ResetLevel()
	LevelService.StartStage()
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

	if isEventReached then
		local state = Store:getState()
		local currentEventId = state.gameState.currentEvents[LevelState.currentEventIndex]
		warn("Trigger Event ID = " .. currentEventId)

		EventsLogic[currentEventId]()

		LevelState.currentEventIndex += 1
	end
end

-- #endregion

-- #region MAP GENERATION

--- Generate Random Buildings
function LevelService.GenerateMap(mapId, stageRadiusSize, buildingsAmount)
	-- TODO
	-- 1] Create Nodes at random Positions
	local randomAmount = 0

	LevelService.CreateNodes(randomAmount)

	-- 2] Collisions Detection + Solver
	LevelService.CollisionsDetection()
	LevelService.Solver()

	-- 3] Spawn Buildings
	LevelService.SpawnBuildings()
end

function LevelService.CreateNodes(amount)
	-- TODO
end

--- Detect the Collisions between (Circular) Nodes
function LevelService.CollisionsDetection()
	-- TODO
end

--- Solve collisions between Nodes
function LevelService.Solver()
	-- TODO
end

--- Spawn Buildings based on Node Locations
function LevelService.SpawnBuildings()
	-- TODO
end

--- Destroy Every Buildings
function LevelService.ClearBuildings()
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
