-- Dynamic Client Side State

-- Player
local player = game.Players.LocalPlayer
local userId = player.UserId
-- local camera = workspace.CurrentCamera
local playerScripts = player:WaitForChild("PlayerScripts")

-- Controls
-- TODO : StateMachine -> States define controls
local controls = require(playerScripts:WaitForChild("PlayerModule")):GetControls() -- Fake Error
local isLClickDown = false

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
local soundFolder = nil
local mainSounds = nil

local getOrbSound = nil
local levelUpSound = nil
local augmentPanelSound = nil
local playerDamagedSfx = nil

local MutState = {
	-- Player
	player = player,
	userId = userId,
	-- camera = camera,
	playerScripts = playerScripts,

	-- Character
	character = character,
	humanoid = humanoid,
	animator = animator,
	animationTracks = animationTracks,

	-- UI
	playerGui = playerGui,
	blur = blur,
	visualLife = visualLife,
	serverLife = serverLife,

	-- Sounds
	soundFolder = soundFolder,
	mainSounds = mainSounds,
	getOrbSound = getOrbSound,
	levelUpSound = levelUpSound,
	augmentPanelSound = augmentPanelSound,
	playerDamagedSfx = playerDamagedSfx,

	-- Controls
	controls = controls,
	isLClickDown = isLClickDown,
}

return MutState
