-- Player Ui in Game
-- TODO : Use UiAspectRatioConstraint

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local PlayerGui = Players.LocalPlayer.PlayerGui

local RoactRodux = require(ReplicatedStorage.Shared.RoactRodux)
local Roact = require(ReplicatedStorage.Shared.Roact)

-- Get Constants
local LevelDefinitions = require(ReplicatedStorage.Shared.AuthoringData.LevelDefinitions)
local EventsIcons = LevelDefinitions.EventsIcons

-- Get Store
local RoduxStore = require(ReplicatedStorage.Shared.RoduxStore)
local Store = RoduxStore.Store
-- local Selectors = RoduxStore.Selectors

-- Get Knit
local Knit = require(ReplicatedStorage.Packages.Knit)
Knit.OnStart():await()

-- local PlayerController = Knit.GetController("PlayerController")
local LevelService = Knit.GetService("LevelService")

-- TODO : Client MutState
local player = Players.LocalPlayer
local playerGui = Players.LocalPlayer.PlayerGui

-- #region ROACT COMPONENTS

-- Get Components
local textLabel = require(ReplicatedStorage.Shared.Components.TextLabel)
-- local textButton = require(ReplicatedStorage.Shared.Components.TextButton)
local image = require(ReplicatedStorage.Shared.Components.Image)
local resourceBar = require(ReplicatedStorage.Shared.Components.ResourceBar)
local frameGridLayout = require(ReplicatedStorage.Shared.Components.FrameGridLayout)

-- Get Elements
local AugmentPanel = require(ReplicatedStorage.Shared.Elements.AugmentPanel)
local LevelUpLabel = require(ReplicatedStorage.Shared.Elements.LevelUpLabel)
local Bars = require(ReplicatedStorage.Shared.Components.ResourceBars)
local XpBar = Bars.XpBar
local lifeBar = Bars.lifeBar

-- #endregion

-- #region MAIN MISC

-- Global Enemy Lvl Display
local robotImageProps = {
	-- position = UDim2.fromScale(0.22, 0.1),
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
		-- position = UDim2.fromScale(0.25, 0.1),
		position = UDim2.fromScale(0.025, 0),
		size = UDim2.fromScale(0.1, 0.1),
		text = "Lvl " .. globalEnemyLvl,
	}
end)(textLabel)

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

	if state.players[player.UserId] then
		score = state.players[player.UserId].score
		username = state.players[player.UserId].username
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
	textPos = UDim2.fromScale(0, 1),
	resourceName = "Stage Progress",
}

eventsIcons = RoactRodux.connect(function(state)
	-- mapStateToProps
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

-- GameTimer
local gameTimerProps = {
	position = UDim2.fromScale(0.25, 0.075),
	size = UDim2.fromScale(0.05, 0.05),
	text = "0",
}

-- #endregion

-- #region CURRENCIES

local bananaImageProp = {
	position = UDim2.fromScale(0.77, 0),
	size = UDim2.fromScale(0.08, 0.18),
	imageLink = "rbxassetid://92617984020165",
}

local function Bananas(props)
	local position = props.position or UDim2.fromScale(0, 0)
	local size = props.size or UDim2.fromScale(0.2, 0.2)

	local text = props.text or "Bananas: "
	local bananas = props.bananas or 0

	return Roact.createElement("TextLabel", {
		Text = text .. bananas,
		Position = position,
		Size = size,
		BackgroundTransparency = 1,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(255, 255, 255),
	})
end

BananasMain = RoactRodux.connect(function(state, props)
	-- mapStateToProps
	local bananas = 0

	if state.players[player.UserId] then
		bananas = state.players[player.UserId].bananas
	end

	return {
		position = UDim2.fromScale(0.65, 0), -- X_pos = 0.75 - size.x / 2
		size = UDim2.fromScale(0.2, 0.2),
		bananas = bananas,
		text = "",
	}
end)(Bananas)

-- TODO : Sticks, Rocks

-- #endregion

-- #region APP

local function mainGui()
	return Roact.createElement("ScreenGui", {}, {
		-- Top
		RobotImage = image(robotImageProps),
		GlobalEnemyLvlText = Roact.createElement(globalEnemyLvlText),
		CurrentStageText = Roact.createElement(currentStageText),
		ProgressBar = resourceBar(progressBarProps),
		EventsIcons = Roact.createElement(eventsIcons),
		GameTimer = textLabel(gameTimerProps),
		-- Bot
		XpBar = Roact.createElement(XpBar),
		LifeBar = lifeBar,
		-- Panels
		LevelUpLabel = Roact.createElement(LevelUpLabel),
		AugmentPanel = Roact.createElement(AugmentPanel),
	})
end

local app = Roact.createElement(RoactRodux.StoreProvider, {
	store = Store,
}, {
	Container = Roact.createElement("Folder", {}, {
		MainGui = mainGui(),
	}),
})

Roact.mount(app, PlayerGui)

-- #endregion

-- #region AFTER UI CREATION
-- Manual / Roact less UI -> Dynamic UI

local mainGuiRef = playerGui.RoactTree.MainGui

-- ProgressBar
local progressBarRef = mainGuiRef.ProgressBar[2]

LevelService.ProgressUpdate:Connect(function(progress)
	progressBarRef.Size = UDim2.fromScale(progress, 1)
end)

-- GameTimer Update
local timerText = mainGuiRef.GameTimer

LevelService.GameTimerUpdate:Connect(function(gameTimer)
	timerText.Text = gameTimer
end)

--#endregion
