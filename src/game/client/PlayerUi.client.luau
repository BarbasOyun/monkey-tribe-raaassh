-- Player Ui in Game / Client PlayerManager
-- TODO : Use UiAspectRatioConstraint

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Gears = require(ReplicatedStorage.Shared.Gears)

local RoactRodux = require(ReplicatedStorage.Shared.RoactRodux)
local Roact = require(ReplicatedStorage.Shared.Roact)

-- Get Constants
local LevelDefinitions = require(ReplicatedStorage.Shared.AuthoringData.LevelDefinitions)
local EventsIcons = LevelDefinitions.EventsIcons

-- Get State
local RoduxStore = require(ReplicatedStorage.Shared.RoduxStore)
local Store = RoduxStore.Store
local Selectors = RoduxStore.Selectors

-- Get MutState
local MutState = require(ReplicatedStorage.Shared.ClientMutState)

-- Get Knit
local Knit = require(ReplicatedStorage.Packages.Knit)
Knit.OnStart():await()

local PlayerController = Knit.GetController("PlayerController")
local LevelService = Knit.GetService("LevelService")

-- #region ROACT COMPONENTS

-- Get Components
local textLabel = require(ReplicatedStorage.Shared.Components.TextLabel)
local image = require(ReplicatedStorage.Shared.Components.Image)
local resourceBar = require(ReplicatedStorage.Shared.Components.ResourceBar)
local frameGridLayout = require(ReplicatedStorage.Shared.Components.FrameGridLayout)

-- Get Elements
local AugmentPanel = require(ReplicatedStorage.Shared.Elements.AugmentPanel)
local LevelUpLabel = require(ReplicatedStorage.Shared.Elements.LevelUpLabel)
local Bars = require(ReplicatedStorage.Shared.Elements.ResourceBars)
local LvlText = Bars.LvlText
local XpBar = Bars.XpBar
local LifeBar = Bars.LifeBar
local updateLifeBar = Bars.updateLifeBar
local GetBananasUi = require(ReplicatedStorage.Shared.Elements.BananasText)
local BananaIcon, BananasText = GetBananasUi(2)

-- #endregion

-- #region MAIN MISC

-- Global Enemy Lvl Display
local robotImageProps = {
	position = UDim2.fromScale(0, 0),
	size = UDim2.fromScale(0.05, 0.1),
	imageLink = "rbxassetid://130840043704422",
}

globalEnemyLvlText = RoactRodux.connect(function(state, props)
	-- mapStateToProps
	local globalEnemyLvl = 1

	if state.gameState.globalEnemyLvl then
		globalEnemyLvl = state.gameState.globalEnemyLvl
	end

	return {
		position = UDim2.fromScale(0.025, 0),
		size = UDim2.fromScale(0.1, 0.1),
		text = "Lvl " .. globalEnemyLvl,
	}
end)(textLabel)

-- Enemy Kills
local EnemyKills = RoactRodux.connect(function(state)
	local enemyKills = 0
	local enemiesDeathCount = state.gameState.enemiesDeathCount

	if enemiesDeathCount then
		enemyKills = enemiesDeathCount
	end

	return {
		position = UDim2.fromScale(0.15, 0),
		size = UDim2.fromScale(0.05, 0.05),
		text = "Kills: " .. enemyKills,
	}
end)(textLabel)

-- Stage Countdown
local stageCountdownProps = {
	position = UDim2.fromScale(0.45, 0.175),
	size = UDim2.fromScale(0.1, 0.1),
	text = "10",
	textTransparency = 1,
}

-- GameTimer
local gameTimerProps = {
	position = UDim2.fromScale(0.1, 0.0),
	size = UDim2.fromScale(0.05, 0.05),
	text = "00:00",
}

-- Sticks Display
sticksImageProps = {
	position = UDim2.fromScale(0.77, 0.175),
	size = UDim2.fromScale(0.05, 0.09),
	imageLink = "rbxassetid://109738929660031",
}

sticksTextProps = RoactRodux.connect(function(state, props)
	local sticks = 0
	local playerState = state.players[MutState.player.UserId]

	if playerState then
		sticks = playerState.sticks
	end

	return {
		position = UDim2.fromScale(0.7, 0.175),
		size = UDim2.fromScale(0.1, 0.1),
		text = sticks,
	}
end)(textLabel)

-- Death Panel
local function deathPanel(props)
	if not props.isVisible then
		return nil
	end

	return Roact.createElement("Frame", {
		Position = UDim2.fromScale(0.125, 0.0),
		Size = UDim2.fromScale(0.75, 0.9),
		BackgroundTransparency = 0.5,
	}, {
		Title = textLabel({
			text = "You are Dead\n Wait for next Stage to Respawn",
			position = UDim2.fromScale(0.125, 0.05),
			size = UDim2.fromScale(0.75, 0.25),
			zIndex = 5,
			textColor = Color3.fromRGB(172, 30, 30),
		}),
	})
end

local DeathPanel = RoactRodux.connect(function(state, props)
	local isVisible = false

	local playerState = Selectors.PlayerState(state, MutState.player.UserId)

	if playerState then
		isVisible = playerState.isDead
	end

	return {
		isVisible = isVisible,
	}
end)(deathPanel)

-- TODO : Loading Screen

-- #endregion

-- #region SCORE

local function PlayerScore(props)
	local position = props.position or UDim2.new(0, 0, 0, 0)
	local size = props.size or UDim2.new(0.2, 0, 0.2, 0)

	local username = props.username or "Player"
	local text = props.text or "Score: "
	local score = props.score or 0

	return Roact.createElement("TextLabel", {
		Text = username .. text .. score,
		Position = position,
		Size = size,
		BackgroundTransparency = 1,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(255, 255, 255),
	})
end

PlayerScoreMain = RoactRodux.connect(function(state, props)
	-- mapStateToProps
	-- print("Local player UserID : ", Players.LocalPlayer.UserId)
	local score = 0
	local username = ""

	if state.players[MutState.player.UserId] then
		score = state.players[MutState.player.UserId].score
		username = state.players[MutState.player.UserId].username
	end

	return {
		position = UDim2.fromScale(0.45, 0), -- X_pos = 0.5 (half screen) - size.x / 2
		size = UDim2.fromScale(0.2, 0.2),
		username = username,
		score = score,
	}
end)(PlayerScore)

local function ScoreBoard(props)
	local players = props.players
	local playerScores = {}

	for userId, player in pairs(players) do
		playerScores[userId] = Roact.createElement(PlayerScore, {
			position = UDim2.new(0, 0, 0, 0),
			size = UDim2.new(1, 0, 0.2, 0),
			username = player.username,
			text = ": ",
			score = player.score,
		})
	end

	local playersFragment = Roact.createFragment(playerScores)
	local scoreList = Roact.createElement("Frame", {
		Position = UDim2.fromScale(0, 0.2),
		Size = UDim2.fromScale(1, 0.8),
		BackgroundTransparency = 1,
	}, { Layout = Roact.createElement("UIListLayout"), ListItems = playersFragment })

	return Roact.createElement("Frame", {
		Size = UDim2.fromScale(0.2, 0.7),
		BackgroundTransparency = 0.5,
	}, {
		Title = Roact.createElement("TextLabel", {
			Text = "Score Board",
			Size = UDim2.fromScale(1, 0.2),
			BackgroundTransparency = 0.75,
			TextScaled = true,
			TextColor3 = Color3.fromRGB(255, 255, 255),
		}),
		ScoreList = scoreList,
	})
end

ScoreBoard = RoactRodux.connect(function(state, props)
	-- mapStateToProps
	local players = state.players

	return {
		players = players,
	}
end)(ScoreBoard)

-- #endregion

-- #region PROGRESS BAR

-- Current Stage Text
currentStageText = RoactRodux.connect(function(state, props)
	-- mapStateToProps
	local currentStage = 1

	if state.gameState.currentStage then
		currentStage = state.gameState.currentStage
	end

	return {
		position = UDim2.fromScale(0.23, 0),
		size = UDim2.fromScale(0.05, 0.05),
		text = "Stage " .. currentStage,
	}
end)(textLabel)

-- Stage Progress Bar
local progressBarProps = {
	-- Background
	position = UDim2.fromScale(0.3, 0.0),
	size = UDim2.fromScale(0.4, 0.05),
	value = 0,
	maxValue = 100,
	backgroundTransparency = 0.5,
	borderPixels = 5,
	-- Bar
	barColor = Color3.fromRGB(223, 151, 17),
	barTransparency = 0.2,
	-- Text
	textPos = UDim2.fromScale(0, 1.2),
	resourceName = "Stage Progress",
}

--- mapStateToProps / Connection
local eventsIcons = RoactRodux.connect(function(state)
	local iconList = {}

	if state.gameState.currentEvents then
		local currentEvents = state.gameState.currentEvents

		-- Create each Event's Icon
		for i = 1, #currentEvents do
			local iconLink = EventsIcons[currentEvents[i]]
			local iconProps = {
				imageLink = iconLink,
			}
			local icon = image(iconProps)

			table.insert(iconList, icon)
		end
	end

	return {
		position = UDim2.fromScale(0.3, 0.0),
		size = UDim2.fromScale(0.4, 0.04),
		listItems = iconList,
	}
end)(frameGridLayout)

-- #endregion

-- #region APP

local function mainGui()
	return Roact.createElement("ScreenGui", {}, {
		-- Top Left
		-- ScoreBoard = Roact.createElement(ScoreBoard),
		RobotImage = image(robotImageProps),
		GlobalEnemyLvlText = Roact.createElement(globalEnemyLvlText),
		EnemyKills = Roact.createElement(EnemyKills),
		GameTimer = textLabel(gameTimerProps),
		-- Top Mid
		StageCountdown = textLabel(stageCountdownProps),
		CurrentStageText = Roact.createElement(currentStageText),
		ProgressBar = resourceBar(progressBarProps),
		EventsIcons = Roact.createElement(eventsIcons),
		-- Top Right
		BananaIcon = BananaIcon,
		BananasText = BananasText,
		SticksImage = image(sticksImageProps),
		SticksText = Roact.createElement(sticksTextProps),
		-- TODO : Sticks, Rocks
		-- Bot Mid
		LvlText = Roact.createElement(LvlText),
		XpBar = Roact.createElement(XpBar),
		LifeBar = Roact.createElement(LifeBar),
		-- Panels
		LevelUpLabel = Roact.createElement(LevelUpLabel),
		AugmentPanel = Roact.createElement(AugmentPanel),
		DeathPanel = Roact.createElement(DeathPanel),
	})
end

local app = Roact.createElement(RoactRodux.StoreProvider, {
	store = Store,
}, {
	Container = Roact.createElement("Folder", {}, {
		MainGui = mainGui(),
	}),
})

local function generateUi()
	Roact.mount(app, MutState.playerGui)

	-- After UI Creation
	updateLifeBar()

	local mainGuiRef = MutState.playerGui.RoactTree.MainGui

	-- ProgressBar
	local progressText = mainGuiRef.ProgressBar[1]
	local progressBarRef = mainGuiRef.ProgressBar[2]

	LevelService.ProgressUpdate:Connect(function(progress)
		local useProgress = math.floor(progress * 100)
		progressText.Text = "Stage Progress " .. useProgress .. " / 100" -- TODO : string table
		progressBarRef.Size = UDim2.fromScale(progress, 1)
	end)

	-- Stage Countdown Update
	local stageCountdown = mainGuiRef.StageCountdown

	LevelService.StageCountDownUpdate:Connect(function(countDown)
		if countDown <= -1 then
			stageCountdown.TextTransparency = 1
			return
		end

		stageCountdown.TextTransparency = 0
		stageCountdown.Text = countDown
	end)

	-- GameTimer Update
	local timerText = mainGuiRef.GameTimer

	LevelService.GameTimerUpdate:Connect(function(gameTimer)
		timerText.Text = Gears.ToMS(gameTimer)
	end)
end

generateUi()

-- Generate UI on Character Spawn
MutState.player.CharacterAdded:Connect(function(character)
	PlayerController.GetSounds()
	generateUi()
end)

-- #endregion
