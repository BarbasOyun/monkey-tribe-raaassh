-- local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RoduxStore = require(ReplicatedStorage.Shared.RoduxStore)
local store = RoduxStore.Store
local storeActions = RoduxStore.Actions

local Knit = require(ReplicatedStorage.Packages.Knit)
--  Signal = require(ReplicatedStorage.Packages._Index["sleitnick_signal@1.5.0"].signal)

-- Get Stats Authoring Data
local statsData = require(ReplicatedStorage.Shared.AuthoringData.StatsDefinitions)

local PlayerService
local StatService
local CombatService
local ItemService

local player = Players.LocalPlayer
-- local camera = workspace.CurrentCamera

-- Character
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local animator = humanoid:WaitForChild("Animator")
local animationTracks = {}

-- UI
local playerGui = player:WaitForChild("PlayerGui")

-- Sounds
local soundFolder = playerGui.ClientSounds
local getOrbSound = soundFolder.GetOrb
local enteringGameSound = soundFolder.EnteringGame

local music = soundFolder.Music

-- Controls
-- TODO : StateMachine -> States define controls
local isLClickDown = false

local PlayerController = Knit.CreateController({
	Name = "PlayerController",
	-- Stores
	STATS_STORE = statsData.STATS_STORE,
	MOD_STATS_STORE = statsData.MOD_STATS_STORE,
	-- Authoring Data
	STATS_DISPLAY = statsData.STATS_DISPLAY,
	META_UPRGADES = statsData.META_UPRGADES,
	AUGMENTS = statsData.AUGMENTS,
})

-- ANIMATIONS -> AnimationController

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

local function playAttackAnim(animationId, animationSpeed)
	-- print(localPlayer.Name .. " Combo: " .. animationId .. " Animation Speed: " .. animationSpeed)
	animationTracks[animationId]:Play()
	animationTracks[animationId]:AdjustSpeed(animationSpeed)
end

-- CONTROLS

local function toggleMusic(isEnabled)
	if isEnabled then
		music:Play()
	else
		music:Stop()
	end

	store:dispatch(storeActions.PatchPlayer(player.UserId, { isMusicEnabled = isEnabled }))
	PlayerService:ToggleMusic(isEnabled)
end

local function setupControls()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		--print("Input detected: " .. tostring(input.UserInputType) .. "Game processed: " .. tostring(gameProcessed))
		if gameProcessed then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			isLClickDown = true
		end

		if input.KeyCode == Enum.KeyCode.A then
			StatService.StartAugmentPick()
		end

		-- TODO : F = Reset Camera
		-- Camera.CFrame = CFrame.new(newPosition)

		if input.KeyCode == Enum.KeyCode.T then
			local state = store:getState()
			local isEnabled = not state.players[player.UserId].isMusicEnabled
			toggleMusic(isEnabled)
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
			-- print(player.Name .. " Ask Server to Attack")
			CombatService.startAttack:Fire()
		end
	end)

	-- 3) Clients : Animation
	-- Server Validated the attack
	CombatService.startAttack:Connect(function(animationId, animationSpeed) -- animationId = comboIndex + 1
		playAttackAnim(animationId, animationSpeed)
	end)
end

-- LINK SERVICES

function PlayerController:BuyUpgrade(upgradeType)
	StatService:BuyMetaUpgrade(upgradeType)
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

		-- print("Replicating gameState from Server :")
		-- print(gameState)
		store:dispatch(storeActions.SetGameState(gameState, player.UserId))
	end)

	-- Players Added & Removed
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

	-- Self Data

	PlayerService.PatchPlayer:Connect(function(patch)
		store:dispatch(storeActions.PatchPlayer(player.UserId, patch))
	end)

	PlayerService.EnteringGame:Connect(function()
		enteringGameSound:Play()
	end)
end

local function setupStatService()
	-- Level
	StatService.LevelUp:Connect(function(patch)
		store:dispatch(storeActions.PatchPlayer(player.UserId, patch))
	end)

	-- Meta Upgrades
	StatService.MetaUpgradesChanged:Connect(function(upgradeType, newUpgrade)
		store:dispatch(storeActions.SetMetaUpgrade(player.UserId, upgradeType, newUpgrade))
	end)

	-- Augments
	StatService.NewAugments:Connect(function(patch)
		store:dispatch(storeActions.PatchPlayer(player.UserId, patch))
	end)

	StatService.FinishPickingAugment:Connect(function(patch)
		store:dispatch(storeActions.PatchPlayer(player.UserId, patch))
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
	StatService = Knit.GetService("StatService")
	ItemService = Knit.GetService("ItemService")
	CombatService = Knit.GetService("CombatService")

	setupPlayerService()
	setupStatService()
	setupItemService()

	setupControls()
	setupAttack()

	-- Start Music
	local store = store:getState()
	local playerData = store.players[player.UserId]

	if playerData and playerData.isMusicEnabled then
		music:Play()
	end
end

return PlayerController
