local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RoduxStore = require(ReplicatedStorage.Shared.RoduxStore)
local store = RoduxStore.Store
local storeActions = RoduxStore.Actions

local Knit = require(ReplicatedStorage.Packages.Knit)
--  Signal = require(ReplicatedStorage.Packages._Index["sleitnick_signal@1.5.0"].signal)

local PlayerController = Knit.CreateController({ Name = "PlayerController" })
PlayerController.store = store

local PlayerService
local CombatService
local ItemService

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local animator = humanoid:WaitForChild("Animator")
local animationTracks = {}

-- UI
local playerGui = player:WaitForChild("PlayerGui")

-- Sounds
local soundFolder = playerGui.ClientSounds
local getOrbSound = soundFolder.GetOrb

-- Controls
-- TODO : StateMachine -> States define controls
local isLClickDown = false

-- ANIMATIONS

local function loadAnimation(animationId)
	local anim = Instance.new("Animation")
	anim.AnimationId = animationId

	local animationTrack = animator:LoadAnimation(anim)
	animationTrack.Priority = Enum.AnimationPriority.Action

	animationTrack:GetMarkerReachedSignal("AttackHit"):Connect(function()
		--print("Hit Event Triggered by player: " .. player.Name)
		CombatService.finishAttack:Fire()
	end)

	return animationTrack
end

local function loadAllAnimations()
	local horizontalSlash = loadAnimation("rbxassetid://88145589618998") -- Combo 1
	local verticalSlash = loadAnimation("rbxassetid://119339188916178") -- Combo 2

	table.insert(animationTracks, horizontalSlash)
	table.insert(animationTracks, verticalSlash)
end

-- On Respawn
local function onCharacterAdded(newCharacter)
	-- print("Character Added for player: " .. player.Name)
	animator = newCharacter:WaitForChild("Humanoid"):WaitForChild("Animator")
	table.clear(animationTracks)
	loadAllAnimations()
end

-- CONTROLS

local function setupControls()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		--print("Input detected: " .. tostring(input.UserInputType) .. "Game processed: " .. tostring(gameProcessed))
		if gameProcessed then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			isLClickDown = true
		end
	end)

	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			isLClickDown = false
		end
	end)
end

local function setupAttack()
	-- 1) Client : Player Input -> Ask Server to Attack
	RunService.Heartbeat:Connect(function()
		if isLClickDown then
			print(player.Name .. " Ask Server to Attack")
			CombatService.startAttack:Fire()
		end
	end)

	-- 3) Clients : Animation
	-- Server Validated the attack
	CombatService.startAttack:Connect(function(animationId, animationSpeed) -- animationId = comboIndex + 1
		-- print(localPlayer.Name .. " Combo: " .. animationId .. " Animation Speed: " .. animationSpeed)
		animationTracks[animationId]:Play()
		animationTracks[animationId]:AdjustSpeed(animationSpeed)
	end)
end

local function setupPlayerService()
	-- Players Join/Leave

	-- Replicate Server GameData -> When joining game
	PlayerService.ReplicateStore:Connect(function(gameState)
		-- converte string key to number
		-- TODO : use RunService:IsStudio to run only in editor
		local players = {}

		for userId, player in pairs(gameState.players) do
			players[tonumber(userId)] = player
		end

		gameState.players = players

		print("Replicating gameState from Server :")
		print(gameState)
		store:dispatch(storeActions.SetGameState(gameState, player.UserId))
	end)

	PlayerService.PlayerAdded:Connect(function(userId, username)
		-- only add players after joining
		if userId == player.UserId then
			return
		end

		-- Replicate Action Client side
		store:dispatch(storeActions.AddPlayer(userId, username))
	end)

	PlayerService.PlayerRemoved:Connect(function(userId)
		store:dispatch(storeActions.RemovePlayer(userId))
	end)

	-- Score
	PlayerService.ScoreChanged:Connect(function(userId, newScore)
		-- Update Score instead of Increment
		store:dispatch(storeActions.SetScore(userId, newScore))
	end)
end

local function setupItemService()
	-- Orb Pickup Feedback
	ItemService.GetOrb:Connect(function()
		getOrbSound:Play()
	end)
end

-- Start Controller
function PlayerController:KnitInit()
	print("PlayerController Init")

	loadAllAnimations()
	player.CharacterAdded:Connect(onCharacterAdded)
end

function PlayerController:KnitStart()
	PlayerService = Knit.GetService("PlayerService")
	ItemService = Knit.GetService("ItemService")
	CombatService = Knit.GetService("CombatService")

	setupPlayerService()
	setupItemService()

	setupControls()
	setupAttack()
end

return PlayerController
