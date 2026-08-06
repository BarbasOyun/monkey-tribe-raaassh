local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- local Gears = require(ReplicatedStorage.Shared.Gears)
local Knit = require(ReplicatedStorage.Packages.Knit)
-- local Signal = require(ReplicatedStorage.Packages._Index["sleitnick_signal@1.5.0"].signal)

-- Get Constants
-- local CONSTANTS = require(ServerScriptService.SharedServer.Constants)

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

local LevelService = Knit.CreateService({
	Name = "LevelService",
	-- Client = {},
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

-- #region Stage + Map Generation

function LevelService.StartStage()
	LevelState.stageProgress = 0
	LevelService.GenerateMap()

	-- TODO : ItemService.ClearGroundItems

	-- Reset every players Pos
	for _, player in pairs(Players:GetPlayers()) do
		LevelService.ResetPlayerPos(player.character)
	end
end

function LevelService.GenerateSwarmWaves()
	-- TODO : Roll 3 or 4
end

function LevelService.ProgressStage()
	-- TODO
end

function LevelService.GenerateMap()
	-- TODO
end

-- #endregion

-- Start Service
function LevelService:KnitInit()
	print("LevelService Initialized")
end

function LevelService:KnitStart()
	PlayerService = Knit.GetService("PlayerService")
end

return LevelService
