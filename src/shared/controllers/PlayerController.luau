local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
Signal = require(ReplicatedStorage.Packages._Index["sleitnick_signal@1.5.0"].signal)

-- Get Constants
local statsDefinition = require(ReplicatedStorage.Shared.AuthoringData.StatsDefinitions)

-- Get State
local RoduxStore = require(ReplicatedStorage.Shared.RoduxStore)
local Store = RoduxStore.Store
local StoreActions = RoduxStore.Actions

-- Get Services
local PlayerService
local LevelService

local RpgService
local AugmentsService

local CombatService
local ItemService

-- TODO : Client Side Mutable State
local player = Players.LocalPlayer
-- local camera = workspace.CurrentCamera
local PlayerScripts = game.Players.LocalPlayer:WaitForChild("PlayerScripts")
local Controls = require(PlayerScripts:WaitForChild("PlayerModule")):GetControls() -- Rojo error

-- Character
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local animator = humanoid:WaitForChild("Animator")
local animationTracks = {}

-- UI
local playerGui = player:WaitForChild("PlayerGui")
local blur = nil
local visualLife = 0
local serverLife = 0

-- Sounds
local soundFolder = playerGui.ClientSounds -- TODO : Shared CONSTANTS
local getOrbSound = soundFolder.GetOrb
local enteringGameSound = soundFolder.EnteringGame
local levelUpSound = soundFolder.LevelUp
local augmentPanelSound = soundFolder.AugmentMenu

local music = soundFolder.Music

-- Controls
-- TODO : StateMachine -> States define controls
local isLClickDown = false

local PlayerController = Knit.CreateController({
	Name = "PlayerController",
	SoundFolder = soundFolder,
	StateUpdate = Signal.new(),
	LifeUpdate = Signal.new(),
	-- Stores
	STATS_STORE = statsDefinition.STATS_STORE,
	MOD_STATS_STORE = statsDefinition.MOD_STATS_STORE,
	-- Authoring Data
	STATS_DISPLAY = statsDefinition.STATS_DISPLAY,
	META_UPRGADES = statsDefinition.META_UPRGADES,
	AUGMENTS = statsDefinition.AUGMENTS,
})

-- #region ANIMATIONS

local function loadAnimation(animationId)
	local anim = Instance.new("Animation")
	anim.AnimationId = animationId

	local animationTrack = animator:LoadAnimation(anim)
	animationTrack.Priority = Enum.AnimationPriority.Action

	animationTrack:GetMarkerReachedSignal("AttackHit"):Connect(function()
		--print("Hit Event Triggered by player: " .. player.Name)
		CombatService:AttackCallback()
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

-- #endregion

-- #region CONTROLS

local function toggleMusic(isEnabled)
	if isEnabled then
		music:Play()
	else
		music:Stop()
	end

	local patch = { isMusicEnabled = isEnabled }
	Store:dispatch(StoreActions.PatchPlayer(player.UserId, patch))
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

		if input.KeyCode == Enum.KeyCode.Q then
			AugmentsService:StartAugmentPick()
		end

		-- TODO : F = Reset Camera
		-- Camera.CFrame = CFrame.new(newPosition)

		if input.KeyCode == Enum.KeyCode.T then
			local state = Store:getState()
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
			CombatService:AttackValidation()
		end
	end)

	-- 3) Clients : Animation
	-- Server Validated the attack
	CombatService.startAttack:Connect(function(animationId, animationSpeed) -- animationId = comboIndex + 1
		playAttackAnim(animationId, animationSpeed)
	end)
end

-- #endregion

-- #region SERVICES

function PlayerController:BuyUpgrade(upgradeType)
	RpgService:BuyMetaUpgrade(upgradeType)
end

local function setupPlayerService()
	-- Players Join/Leave

	-- On joining game -> Replicate Server Game State
	PlayerService.ReplicateStore:Connect(function(worldState)
		-- Convert string UserIds back to number
		-- TODO : use RunService:IsStudio to run only in editor
		local players = {}

		for userId, player in pairs(worldState.players) do
			players[tonumber(userId)] = player
		end

		worldState.players = players

		-- print("Replicating worldState from Server :")
		-- print(worldState)
		Store:dispatch(StoreActions.SetWorldState(player.UserId, worldState))
	end)

	-- Players Added & Removed
	PlayerService.PlayerAdded:Connect(function(userId, username)
		-- only add players after joining
		if userId == player.UserId then
			return
		end

		-- Replicate Action Client side
		Store:dispatch(StoreActions.AddPlayer(userId, username))
	end)

	PlayerService.PlayerRemoved:Connect(function(userId)
		Store:dispatch(StoreActions.RemovePlayer(userId))
	end)

	-- Self Data

	PlayerService.PatchPlayer:Connect(function(patch)
		Store:dispatch(StoreActions.PatchPlayer(player.UserId, patch))
	end)

	PlayerService.PatchGameState:Connect(function(patch)
		Store:dispatch(StoreActions.PatchGameState(patch))
	end)

	PlayerService.EnteringGame:Connect(function()
		enteringGameSound:Play()
	end)
end

local function setupRpgService()
	-- Resource Bars
	RpgService.LifeUpdate:Connect(function(life)
		serverLife = life
	end)

	-- Level Up
	RpgService.LevelUp:Connect(function(patch)
		levelUpSound:Play()
		Store:dispatch(StoreActions.PatchPlayer(player.UserId, patch))
	end)

	-- Meta Upgrades
	RpgService.MetaUpgradesChanged:Connect(function(upgradeType, newUpgrade)
		Store:dispatch(StoreActions.SetMetaUpgrade(player.UserId, upgradeType, newUpgrade))
	end)
end

local function setupAugmentsService()
	AugmentsService.NewAugments:Connect(function(augmentChoices)
		-- warn(augmentChoices)

		local patch = { state = "PickingAugment", currentAugments = augmentChoices }
		Store:dispatch(StoreActions.PatchPlayer(player.UserId, patch))

		-- Picking Augment State
		if not blur then
			local lighting = game.Lighting
			blur = Instance.new("BlurEffect")
			blur.Size = 10
			blur.Parent = lighting
		end

		augmentPanelSound:Play()
		Controls:Disable()
	end)

	AugmentsService.FinishPickingAugments:Connect(function()
		-- Playing State
		blur:Destroy()
		Controls:Enable()

		local patch = { state = "Playing", currentAugments = nil }
		Store:dispatch(StoreActions.PatchPlayer(player.UserId, patch))
	end)
end

local function setupItemService()
	-- Orb Pickup Feedback
	ItemService.GetOrb:Connect(function()
		getOrbSound:Play()
	end)
end

-- #endregion

-- #region UPDATE

function PlayerController.UpdateLife(state)
	visualLife = math.lerp(visualLife, serverLife, 0.1)

	-- Apply to UI
	PlayerController.LifeUpdate:Fire(state, visualLife)
end

local function stateUpdate()
	local state = Store:getState() -- Get state once every frame

	PlayerController.UpdateLife(state)
	PlayerController.StateUpdate:Fire(state)
end

-- #endregion

-- Start Controller
function PlayerController:KnitInit()
	print("PlayerController Init")

	loadAllAnimations()
	player.CharacterAdded:Connect(onCharacterAdded)
end

function PlayerController:KnitStart()
	PlayerService = Knit.GetService("PlayerService")
	LevelService = Knit.GetService("LevelService")

	RpgService = Knit.GetService("RpgService")
	AugmentsService = Knit.GetService("AugmentsService")

	CombatService = Knit.GetService("CombatService")
	ItemService = Knit.GetService("ItemService")

	setupPlayerService()
	setupRpgService()
	setupAugmentsService()
	setupItemService()

	setupControls()
	setupAttack()

	-- Start Music
	local state = Store:getState()
	local playerData = state.players[player.UserId]

	if playerData and playerData.isMusicEnabled then
		music:Play()
	end

	-- Start StateUpdate
	RunService.Heartbeat:Connect(stateUpdate)
end

return PlayerController
