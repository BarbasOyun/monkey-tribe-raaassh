local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Gears = require(ReplicatedStorage.Shared.Gears)

-- Get Constants
local CONSTANTS = require(ServerScriptService.SharedServer.Constants)
local LevelConst = CONSTANTS.LevelConst

-- TODO : Move to Consts?
local LevelDefinitions
local Events, EventsSounds, Maps, MapsMusics, MapsBuildings

local CategoryStore = CONSTANTS.CategoryStore
local CategoryRegistries = CONSTANTS.CategoryRegistries

-- Get State
local RoduxStore = require(ReplicatedStorage.Shared.RoduxStore)
local Store = RoduxStore.Store
local StoreActions = RoduxStore.Actions
-- local Selectors = RoduxStore.Selectors

-- Get Mutable State
local MutState = require(ServerScriptService.SharedServer.MutableState)
local LevelState = MutState.LevelState

-- Knit
local Knit = require(ReplicatedStorage.Packages.Knit)
-- local Signal = require(ReplicatedStorage.Packages._Index["sleitnick_signal@1.5.0"].signal)

local PlayerService, EnemyService, ItemService, CombatService, PoolService

local LevelService = Knit.CreateService({
	Name = "LevelService",
	Client = {
		StageCountDownUpdate = Knit.CreateSignal(),
		GameTimerUpdate = Knit.CreateSignal(),
		ProgressUpdate = Knit.CreateSignal(),
	},
})

function LevelService:KnitInit()
	print("LevelService Initialized")
end

function LevelService:KnitStart()
	PlayerService = Knit.GetService("PlayerService")
	EnemyService = Knit.GetService("EnemyService")
	ItemService = Knit.GetService("ItemService")
	CombatService = Knit.GetService("CombatService")
	PoolService = Knit.GetService("PoolService")
end

-- #region BOUNDS

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
	local yLimit = LevelConst.Y_LIMIT

	if point.Y <= -yLimit or yLimit <= point.Y then
		return true
	end

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

	local minOffSet = Vector2.new(5, 5)
	local maxOffSet = Vector2.new(-5, -5)

	local minLimit = state.gameState.minLimit + minOffSet
	local maxLimit = state.gameState.maxLimit + maxOffSet

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
	local respawnPos = workspace.Main.SpawnLocation.CFrame.Position + Vector3.new(0, 5, 0)
	character:PivotTo(CFrame.new(respawnPos))

	local root = character.HumanoidRootPart
	root.AssemblyLinearVelocity = Vector3.zero
end

-- #endregion

-- #region STAGE

--- Load Authoring data required for Stages / Game Place
function LevelService.LoadLevelDefinitions()
	-- warn("Set Game Place")
	-- Get Consts
	LevelDefinitions = require(ReplicatedStorage.Shared.AuthoringData.LevelDefinitions)

	Maps = LevelDefinitions.Maps
	MapsMusics = LevelDefinitions.MapsMusics
	MapsBuildings = LevelDefinitions.MapsBuildings

	Events = LevelDefinitions.Events
	EventsSounds = LevelDefinitions.EventsSounds

	-- Buildings Setup
	LevelState.buildingFolder = workspace.Buildings

	-- Buildings Detection
	local buildingsDetectionParam = OverlapParams.new()
	buildingsDetectionParam.FilterType = Enum.RaycastFilterType.Include
	buildingsDetectionParam.FilterDescendantsInstances = { LevelState.buildingFolder }
	buildingsDetectionParam.MaxParts = 10

	LevelState.buildingsDetectionParam = buildingsDetectionParam

	-- Add Buildings Folder to weapon Detection
	MutState.CombatState.weaponHitParam.FilterDescendantsInstances =
		{ CONSTANTS.WEAPON_HIT_FOLDER, LevelState.buildingFolder }

	-- Start Buildings Detection + AutoTarget
	PlayerService.StateUpdate:Connect(function(state, dt)
		for _, player in pairs(Players:GetPlayers()) do
			PlayerService.BuildingsDetection(state, player)
			CombatService.FindClosestBuilding(player)
			CombatService.AutoTargetBuildings(state, player)
		end
	end)

	-- Save Bananas when Player Leave
	PlayerService.PlayerRemoved:Connect(function(player)
		local state = Store:getState()
		PlayerService.SaveBananaDelta(state, player)
	end)
end

function LevelService.StartRandomStage()
	local mapID = math.random(1, #MapsBuildings)

	-- Prevent rolling the same map
	local isSameMap = mapID == LevelState.currentMapId
	if isSameMap then
		mapID = math.max((mapID + 1) % #MapsBuildings, 1)
	end

	local buildingsAmount = Gears.RandomRange(LevelState.buildingAmount, LevelDefinitions.BUILDINGS_RANGE)

	LevelService.StartStage(mapID, buildingsAmount)
end

--- Start a New Stage
function LevelService.StartStage(mapID, buildingsAmount)
	local state = Store:getState()

	if not LevelDefinitions then
		warn("Level Definition not loaded -> Call LevelService.LoadLevelDefinitions()")
		return
	end

	LevelState.currentMapId = mapID
	-- warn("Start Stage MapID = " .. LevelState.currentMapId)

	-- Generate Map
	LevelService.GenerateMap(LevelState.currentMapId, LevelState.stageRadius, buildingsAmount)

	LevelState.totalParts *= 0.5 -- Require 50% of the stage to be completed

	-- Additional Setup
	LevelService.SetMusic(LevelState.currentMapId)

	local randomWeaponAmount = math.random(1, 3)
	LevelService.GenerateWeapons(randomWeaponAmount)

	LevelService.GenerateEvents()

	-- Enemy Level Catchup
	EnemyService.CatchupLvl(state, state.gameState.currentStage)
end

function LevelService.ResetLevel()
	LevelState.isWaitingForNextStage = false

	-- Reset Progress
	LevelState.partsCount = 0
	LevelState.totalParts = 0
	LevelState.stageProgress = 0
	LevelService.Client.ProgressUpdate:FireAll(0)

	-- Clear Objects
	LevelService.ClearBuildings()
	PoolService.DisableAllPools()
	ItemService.ClearGroundItems()

	-- Reset Services
	MutState.EnemyServiceState.swarmWaves = 0

	-- Reset Players
	PlayerService.ResurrectAll()
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

	local isStageFinished = stageProgress >= 1

	if isStageFinished then
		LevelService.StartStageCountdown()
	end

	LevelService.Client.ProgressUpdate:FireAll(stageProgress)
end

--- Start Next Stage Countdown -> Trigger Next Stage
function LevelService.StartStageCountdown()
	local countdown = LevelConst.NEXT_STAGE_COUNTDOWN

	LevelState.isWaitingForNextStage = true

	LevelState.stageCountDownTime = 0
	LevelState.stageCountDown = countdown

	-- Refresh Client UI
	LevelService.Client.StageCountDownUpdate:FireAll(LevelState.stageCountDown)

	-- Start Coundown
	local handle = PlayerService.SecondPassed:Connect(function(state)
		LevelState.stageCountDown -= 1
		LevelService.Client.StageCountDownUpdate:FireAll(LevelState.stageCountDown)

		local isCountdownComplete = LevelState.stageCountDown <= 0

		if isCountdownComplete then
			LevelState.stageCountDown = countdown
			LevelService.FinishStage()
		end
	end)

	LevelState.countdownHandle = handle
end

function LevelService.FinishStage()
	-- warn("Finish Stage")

	-- Disable Countdown
	LevelService.Client.StageCountDownUpdate:FireAll(-1)
	LevelState.countdownHandle:Disconnect()
	LevelState.countdownHandle = nil

	-- Map Increments
	local newBuildingAmount = LevelState.buildingAmount + LevelDefinitions.BUILDINGS_INCREMENT
	LevelState.buildingAmount = math.min(newBuildingAmount, LevelDefinitions.BUILDING_LIMIT)

	-- Save Data
	PlayerService.SaveGameData()

	-- Update Game State
	local state = Store:getState()

	local currentStage = state.gameState.currentStage + 1
	local patch = { currentStage = currentStage }

	Store:dispatch(StoreActions.PatchGameState(patch))
	PlayerService.Client.PatchGameState:FireAll(patch)

	-- Reset + Next Stage
	LevelService.ResetLevel()
	LevelService.StartRandomStage()
end

function LevelService.StartGameTimer()
	-- warn("Start Game Timer")
	PlayerService.SecondPassed:Connect(function(state)
		LevelService.GameTimer()
	end)
end

function LevelService.GameTimer()
	MutState.gameTimer += 1

	LevelService.Client.GameTimerUpdate:FireAll(MutState.gameTimer)

	local isLvlBreakpointReached = (MutState.gameTimer % CONSTANTS.EnemyConst.ENEMY_LVL_UP_BREAKPOINT) == 0
	if isLvlBreakpointReached then
		EnemyService.LevelUpEnemies()
	end
end

-- #endregion

-- #region BUILDINGS

--- Associate Health to a Building
function LevelService.GenerateBuildingHealth(building: Part)
	local health = math.random(100, 200)

	LevelState.buildingsHealth[building] = health
end

function LevelService.DamageBuilding(building: Part, damage: number)
	assert(damage > 0, "Damage Building : Damaeg needs to be Higher than 0")

	local buildingHealth = LevelState.buildingsHealth[building]

	if not buildingHealth then
		LevelService.GenerateBuildingHealth(building)
	end

	LevelState.buildingsHealth[building] -= damage
	local damagedHealth = LevelState.buildingsHealth[building]

	-- if damagedHealth <= 50 then
	-- 	-- TODO : Break (Physic)
	-- end

	-- Destroy Building
	if damagedHealth <= 0 then
		LevelService.DestroyBuilding(building)
	end
end

function LevelService.DestroyBuilding(building: Part)
	-- Cleanup Data
	LevelState.buildingsHealth[building] = nil

	-- Roll Loot : Bananas or Sticks
	local isLooting = ItemService.LootBananas(building.CFrame.Position)

	if not isLooting then
		ItemService.LootSticks(building.CFrame.Position)
	end

	-- Destroy
	building:Destroy()
	LevelService.ProgressStage()
end

-- #endregion

-- #region MUSIC

--- Set the Music for a Player
function LevelService.SetPlayerMusic(state, player, mapId)
	-- warn("Set Player Music : " .. player.Name .. " Map Id = " .. mapId)
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
		LevelService.SetPlayerMusic(state, player, mapId)
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
		-- warn("Trigger Event ID = " .. currentEventId)

		EventsSounds[currentEventId]:Play()
		EventsLogic[currentEventId]()

		LevelState.currentEventIndex += 1
	end
end

-- #endregion

-- #region MAP GENERATION

--- Generate Random Buildings
function LevelService.GenerateMap(mapId, stageRadius, buildingsAmount)
	local buildings = MapsBuildings[mapId]

	-- LevelService.DebugDraw(stageRadius)

	local constraints = {
		-- TODO : Spawn Constraint -> Send to Center
		-- Avoid generating building near spawn point
		function(point)
			return LevelService.CircleConstraint(point, LevelDefinitions.SPAWN_POS, LevelDefinitions.MINIMUM_RADIUS)
		end,
		-- Stage Radius Constraint
		function(point)
			return LevelService.CircleContainer(point, Vector2.zero, stageRadius)
		end,
	}

	-- 1] Create Nodes at random Positions
	local circularNodes, prefabs = LevelService.GenerateNodes(buildings, stageRadius, buildingsAmount, constraints)

	-- 2] Collisions Detection + Solver
	circularNodes = LevelService.SeparateCircles(circularNodes, constraints)

	-- 3] Spawn Buildings
	LevelService.SpawnBuildings(circularNodes, prefabs)
end

--- DEBUG : Draw Stage Radius + Minimum Radius
function LevelService.DebugDraw(stageRadius)
	PlayerService.StateUpdate:Connect(function(state, dt)
		-- Outer Radius
		local outerRadiusPoints = Gears.CirclePoints(stageRadius, 20)
		Gears.DrawCircle(Vector3.new(0, 3, 0), outerRadiusPoints)

		-- Inner Radius
		local pos = Vector3.new(LevelDefinitions.SPAWN_POS.X, 3, LevelDefinitions.SPAWN_POS.Y)
		local innerRadiusPoints = Gears.CirclePoints(LevelDefinitions.MINIMUM_RADIUS, 20)
		Gears.DrawCircle(pos, innerRadiusPoints)
	end)
end

--- Generate Building Nodes at random positions
function LevelService.GenerateNodes(buildings, stageRadius, amount, constraints)
	local circularNodes = {}
	local prefabs = {}

	local buildingIndex = math.random(1, #buildings)

	-- Generate Nodes Positions
	local positions = Gears.GetPosWithinCircle(stageRadius, amount, constraints)

	-- Generate Building Nodes
	for i = 1, amount do
		-- Roll Building
		local building = buildings[buildingIndex]
		LevelState.totalParts += building.nbrOfParts

		-- Build Circular Nodes
		local buildingNode = { position = positions[i], radius = building.radius } :: Circle
		circularNodes[i] = buildingNode

		-- Add Prefab
		local prefab = buildings[buildingIndex].prefab
		table.insert(prefabs, prefab)

		buildingIndex = Gears.LoopValue(buildingIndex + 1, #buildings, 1)
	end

	return circularNodes, prefabs
end

--- Draw a Building Node
function LevelService.DebugBuilding(node)
	PlayerService.StateUpdate:Connect(function(state, dt)
		local pos = Vector3.new(node.position.X, 3, node.position.Y)
		local outerRadiusPoints = Gears.CirclePoints(node.radius, 20)
		Gears.DrawCircle(pos, outerRadiusPoints)
	end)
end

--- Spawn Buildings based on Node Locations
function LevelService.SpawnBuildings(buildingNodes, prefabs)
	for i = 1, #buildingNodes do
		local node = buildingNodes[i]
		local prefab = prefabs[i]

		-- LevelService.DebugBuilding(node)

		-- Building OnSpawn
		local building = prefab:clone()
		building.Parent = LevelState.buildingFolder

		-- Set Position
		-- TODO : Raycast to find Y (height) value -> Allow Different Terrain Heights
		local buildingHeight = building:GetPivot().Position.Y
		local buildingPos = CFrame.new(node.position.X, buildingHeight, node.position.Y)
		building:PivotTo(buildingPos)

		table.insert(LevelState.currentBuildings, building)
	end
end

--- Destroy Every Buildings
function LevelService.ClearBuildings()
	for i = 1, #LevelState.currentBuildings do
		local building = LevelState.currentBuildings[i]
		building:Destroy()
	end

	table.clear(LevelState.currentBuildings)
end

--- Scatter random weapons in the Map
function LevelService.GenerateWeapons(amount)
	-- warn("Generate " .. amount .. " Weapons")

	local buildings = table.clone(LevelState.currentBuildings)

	for i = 1, amount do
		-- Random Building to Spawn Weapon into
		local buildingIndex = math.random(1, #LevelState.currentBuildings)
		table.remove(buildings, buildingIndex)

		local building = LevelState.currentBuildings[buildingIndex]

		-- Random Weapon
		local weaponRegistry = CategoryRegistries[CategoryStore.Weapons]
		local items = { weaponRegistry.IronMace, weaponRegistry.IronAxe }

		local randomIndex = math.random(1, #items)
		local item = items[randomIndex]
		local pos = building:GetPivot().Position

		ItemService.SpawnItem(item, pos)
	end
end

-- #endregion

-- #region NODE COLLISIONS

type Circle = {
	position: Vector2,
	radius: number,
}

--- Hold Every Collisions in a Frame
type CollisionsData = {
	object1: {},
	object2: {},
	normals: {},
	penetrationDepth: {},
}

--- Use Collisions Detection + Solving to Separate Circles
function LevelService.SeparateCircles(circularNodes, constraints)
	local nodes = circularNodes

	for _ = 1, LevelDefinitions.COLLISIONS_DETECTIONS_ITERATIONS do
		local collisionsData = LevelService.CollisionsDetection(nodes)
		-- warn(#collisionsData.object1 .. " Collisions Detected")
		-- warn(collisionsData)

		if #collisionsData.object1 == 0 then
			break
		end

		nodes = LevelService.Solver(nodes, collisionsData, constraints)
	end

	return nodes
end

--- Detect the Collisions between (Circular) Nodes
function LevelService.CollisionsDetection(circularNodes)
	local collisionsData = {
		object1 = {},
		object2 = {},
		normals = {},
		penetrationDepth = {},
	} :: CollisionsData

	for i = 1, #circularNodes do
		local circularNode: Circle = circularNodes[i]

		if circularNode.radius == 0 then
			continue
		end

		-- Build Ignore List
		local ignoreList = LevelService.IgnoreList(collisionsData, i)

		LevelService.RadiusRadiusesCol(collisionsData, ignoreList, i, circularNodes)
	end

	return collisionsData
end

--- Get a 2D Point OUT of a circle
function LevelService.CircleConstraint(point: Vector2, circlePos: Vector2, radius: number)
	-- Point / Circle Col Detection
	local circleToPoint = point - circlePos
	local distance = circleToPoint.Magnitude
	local isInCircle = distance < radius

	if not isInCircle then
		return point
	end

	local circlePointNormal = Gears.NormalizeOrZero(circleToPoint)
	point = circlePointNormal * radius

	return point
end

--- Keep a 2D Point IN a Circle
function LevelService.CircleContainer(point: Vector2, circlePos: Vector2, radius: number)
	-- Point / Circle Col Detection
	local circleToPoint = point - circlePos
	local distance = circleToPoint.Magnitude
	local isInCircle = distance < radius

	if isInCircle then
		return point
	end

	local circlePointNormal = Gears.NormalizeOrZero(circleToPoint)
	point = circlePointNormal * radius

	return point
end

--- Detect Collision between 2 Circles,
--- Return normal, penetrationDepth or nil
function LevelService.RadiusRadiusCol(circle1: Circle, circle2: Circle)
	local distance_threshold = circle1.radius + circle2.radius
	local direction = circle2.position - circle1.position
	local distance = direction.Magnitude

	local isColliding = distance <= distance_threshold

	if isColliding then
		local normal = Gears.NormalizeOrZero(direction)
		local penetrationDepth = distance_threshold - distance
		-- warn("Distance = " .. distance .. " Radius1 = " .. circle1.radius .. " Pen = " .. penetrationDepth)

		return normal, penetrationDepth
	end

	return nil
end

--- Detect Collisions between a Circle and Others
function LevelService.RadiusRadiusesCol(
	collisionsData: CollisionsData,
	ignoreList: {},
	circleIndex: number,
	circularNodes: { Circle }
)
	local circle = circularNodes[circleIndex]

	for i = 1, #circularNodes do
		local otherCircle = circularNodes[i]
		local isValid = circle ~= otherCircle and otherCircle.radius > 0 and not table.find(ignoreList, i)

		if not isValid then
			continue
		end

		-- Check Collision
		local normal, penetrationDepth = LevelService.RadiusRadiusCol(circle, otherCircle)

		-- Not colliding = Skip
		local isColliding = normal and penetrationDepth

		if not isColliding then
			continue
		end

		-- Register Collision
		table.insert(collisionsData.object1, circleIndex)
		table.insert(collisionsData.object2, i)
		table.insert(collisionsData.normals, normal)
		table.insert(collisionsData.penetrationDepth, penetrationDepth)
	end
end

--- Build an Ignore List of Objects that already Detected a Collision with an Object
function LevelService.IgnoreList(collisionsData: CollisionsData, index: number)
	local ignoreList = {}

	for j = 1, #collisionsData.object2 do
		local object2Index = collisionsData.object2[j]

		if object2Index == index then
			local object1Index = collisionsData.object1[j]
			table.insert(ignoreList, object1Index)
		end
	end

	return ignoreList
end

--- Solve collisions between Circles
function LevelService.Solver(circularNodes, collisionsData: CollisionsData, constraints: {})
	for i = 1, LevelDefinitions.SOLVER_ITERATIONS do
		for j = 1, #collisionsData.object1 do
			local object1Index = collisionsData.object1[j]
			local object2Index = collisionsData.object2[j]

			local object1 = circularNodes[object1Index]
			local object2 = circularNodes[object2Index]
			local normal = collisionsData.normals[j]
			local penetrationDepth = collisionsData.penetrationDepth[j]

			local new1, new2 = LevelService.SolveCol(object1, object2, normal, penetrationDepth, constraints)

			circularNodes[object1Index] = new1
			circularNodes[object2Index] = new2
		end
	end

	return circularNodes
end

--- Solve a Collision Between 2 Circles
function LevelService.SolveCol(
	circle1: Circle,
	circle2: Circle,
	normal: Vector2,
	penetrationDepth: number,
	constraints: {}
)
	local percent = 0.1 -- Resolve X% of the penetration per iteration
	local slop = 0.01 -- Allow 1cm of penetration before fixing

	local invMass1 = 1
	local invMass2 = 1
	local totalInvMass = invMass1 + invMass2

	-- Get Push Vector (Direction & Magnitude)
	local correctionMagnitude = math.max(0.0, penetrationDepth - slop) / totalInvMass * percent
	local correctionVector = normal * correctionMagnitude

	-- Separation
	circle1.position -= correctionVector -- * invMass1
	circle2.position += correctionVector -- * invMass2

	-- Apply Constraints
	if not constraints then
		return
	end

	for i = 1, #constraints do
		circle1.position = constraints[i](circle1.position)
		circle2.position = constraints[i](circle2.position)
	end

	return circle1, circle2
end

-- #endregion

return LevelService
