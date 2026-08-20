local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Get Constants
local statsDefinition = require(ReplicatedStorage.Shared.AuthoringData.StatsDefinitions)

-- Get State
local RoduxStore = require(ReplicatedStorage.Shared.RoduxStore)
local Store = RoduxStore.Store
local StoreActions = RoduxStore.Actions

-- Get MutState
local MutState = require(ReplicatedStorage.Shared.ClientMutState)

-- Knit
local Knit = require(ReplicatedStorage.Packages.Knit)
Signal = require(ReplicatedStorage.Packages._Index["sleitnick_signal@1.5.0"].signal)

local PlayerService, RpgService, AugmentsService, CombatService, ItemService

local PlayerController = Knit.CreateController({
	Name = "PlayerController",
	SoundFolder = MutState.soundFolder,
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

function PlayerController.GetSounds()
	MutState.playerGui = MutState.player:WaitForChild("PlayerGui")
	MutState.soundFolder = MutState.playerGui:WaitForChild("ClientSounds")
	MutState.mainSounds = MutState.soundFolder:WaitForChild("MainSounds")

	MutState.getOrbSound = MutState.mainSounds.GetOrb
	MutState.levelUpSound = MutState.mainSounds.LevelUp
	MutState.augmentPanelSound = MutState.mainSounds.AugmentMenu
	MutState.playerDamagedSfx = MutState.mainSounds.PlayerDamaged
end

-- #region ANIMATIONS

local function loadAnimation(animationId)
	local anim = Instance.new("Animation")
	anim.AnimationId = animationId

	local animationTrack = MutState.animator:LoadAnimation(anim)
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

	table.insert(MutState.animationTracks, horizontalSlash)
	table.insert(MutState.animationTracks, verticalSlash)
end

-- On Respawn
local function onCharacterAdded(newCharacter)
	-- print("Character Added for player: " .. player.Name)
	MutState.animator = newCharacter:WaitForChild("Humanoid"):WaitForChild("Animator")
	table.clear(MutState.animationTracks)
	loadAllAnimations()
end

local function playAttackAnim(animationId, animationSpeed)
	-- print(localPlayer.Name .. " Combo: " .. animationId .. " Animation Speed: " .. animationSpeed)
	MutState.animationTracks[animationId]:Play()
	MutState.animationTracks[animationId]:AdjustSpeed(animationSpeed)
end

-- #endregion

-- #region CONTROLS

local function toggleMusic(isEnabled)
	local music = MutState.soundFolder:FindFirstChild("Music")

	if not music then
		warn("Music not found")
		return
	end

	if isEnabled then
		music:Play()
	else
		music:Stop()
	end

	local patch = { isMusicEnabled = isEnabled }
	Store:dispatch(StoreActions.PatchPlayer(MutState.player.UserId, patch))
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
			local playerState = state.players[MutState.player.UserId]
			local isEnabled = not playerState.isMusicEnabled
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
			CombatService:StartAttack()
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
	-- On joining game -> Replicate Server Game State
	PlayerService.ReplicateStore:Connect(function(worldState)
		-- Convert string UserIds back to number
		-- TODO : use RunService:IsStudio to run only in editor
		local players = {}

		for userId, player in pairs(worldState.players) do
			players[tonumber(userId)] = player
		end

		worldState.players = players

		Store:dispatch(StoreActions.SetWorldState(MutState.player.UserId, worldState))
	end)

	-- Players Added & Removed
	PlayerService.PlayerAdded:Connect(function(player)
		local userId = player.UserId
		local username = player.Name

		-- Avoid adding self
		if userId == player.UserId then
			return
		end

		-- Replicate Action Client side
		Store:dispatch(StoreActions.AddPlayer(userId, username))
	end)

	PlayerService.PlayerRemoved:Connect(function(player)
		local userId = player.UserId
		Store:dispatch(StoreActions.RemovePlayer(userId))
	end)

	-- Self Data

	PlayerService.PatchPlayer:Connect(function(patch)
		Store:dispatch(StoreActions.PatchPlayer(MutState.player.UserId, patch))
	end)

	PlayerService.PatchGameState:Connect(function(patch)
		Store:dispatch(StoreActions.PatchGameState(patch))
	end)

	PlayerService.EnteringGame:Connect(function()
		-- enteringGameSound:Play()
		MutState.levelUpSound:Play()
	end)
end

local function setupRpgService()
	-- StatsPatch
	RpgService.PatchStats:Connect(function(patch)
		Store:dispatch(StoreActions.PatchStat(MutState.player.UserId, patch))
	end)

	-- Damage
	RpgService.PlayerDamaged:Connect(function()
		MutState.playerDamagedSfx:Play()
	end)

	-- Resource Bars
	RpgService.LifeUpdate:Connect(function(life)
		MutState.serverLife = life
	end)

	-- Level Up
	RpgService.LevelUp:Connect(function(patch)
		MutState.levelUpSound:Play()
		Store:dispatch(StoreActions.PatchPlayer(MutState.player.UserId, patch))
	end)

	-- Meta Upgrades
	RpgService.MetaUpgradesChanged:Connect(function(upgradeType, newUpgrade)
		Store:dispatch(StoreActions.SetMetaUpgrade(MutState.player.UserId, upgradeType, newUpgrade))
	end)
end

local function setupAugmentsService()
	AugmentsService.NewAugments:Connect(function(augmentChoices)
		-- warn(augmentChoices)

		local patch = { state = "PickingAugment", currentAugments = augmentChoices }
		Store:dispatch(StoreActions.PatchPlayer(MutState.player.UserId, patch))

		-- Picking Augment State
		if not MutState.blur then
			local lighting = game.Lighting
			MutState.blur = Instance.new("BlurEffect")
			MutState.blur.Size = 10
			MutState.blur.Parent = lighting
		end

		MutState.augmentPanelSound:Play()
		MutState.controls:Disable()
	end)

	AugmentsService.FinishPickingAugments:Connect(function()
		-- Playing State
		MutState.blur:Destroy()
		MutState.controls:Enable()

		local patch = { state = "Playing", currentAugments = nil }
		Store:dispatch(StoreActions.PatchPlayer(MutState.player.UserId, patch))
	end)
end

local function setupItemService()
	-- Orb Pickup Feedback
	ItemService.GetOrb:Connect(function()
		MutState.getOrbSound:Play()
	end)
end

-- #endregion

-- #region UPDATE

local function stateUpdate()
	local state = Store:getState() -- Get state once every frame

	PlayerController.UpdateLife(state)
	PlayerController.StateUpdate:Fire(state)
end

function PlayerController.UpdateLife(state)
	MutState.visualLife = math.lerp(MutState.visualLife, MutState.serverLife, 0.1)

	-- Apply to UI
	PlayerController.LifeUpdate:Fire(state, MutState.visualLife)
end

-- #endregion

-- Start Controller
function PlayerController:KnitInit()
	print("PlayerController Init")

	loadAllAnimations()
	MutState.player.CharacterAdded:Connect(onCharacterAdded)
end

function PlayerController:KnitStart()
	PlayerService = Knit.GetService("PlayerService")

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

	-- Start StateUpdate
	RunService.Heartbeat:Connect(stateUpdate)

	PlayerController.GetSounds()
end

return PlayerController
