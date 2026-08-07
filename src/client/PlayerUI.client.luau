-- Player Ui in Hub
-- TODO : Use UiAspectRatioConstraint

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local RoactRodux = require(ReplicatedStorage.Shared.RoactRodux)
local Roact = require(ReplicatedStorage.Shared.Roact)
local Gears = require(ReplicatedStorage.Shared.Gears)

local Knit = require(ReplicatedStorage.Packages.Knit)
Knit.OnStart():await() -- Wait for KnitControllersStart

-- Get Constants
local LevelDefinitions = require(ReplicatedStorage.Shared.AuthoringData.LevelDefinitions)
local EventsIcons = LevelDefinitions.EventsIcons

-- Get Store
local RoduxStore = require(ReplicatedStorage.Shared.RoduxStore)
local Store = RoduxStore.Store
local Selectors = RoduxStore.Selectors

-- Get Services & Controller
local PlayerController = Knit.GetController("PlayerController")
LevelService = Knit.GetService("LevelService")

-- TODO : Client side Mutable State
local player = Players.LocalPlayer
local playerGui = Players.LocalPlayer.PlayerGui

local controlsBoard = workspace.Wiki.ControlsBoard.Board
local shopBoard = workspace.Main.ShopBoard.Board

-- Shop
-- TODO : ShopDefinitions Module in ReplicatedStorage
local hundredDonationId = 3607471778
local thousandDonationId = 3607471867

-- #region ROACT COMPONENTS

-- Basic

local textLabel = require(ReplicatedStorage.Shared.Components.TextLabel)
local textButton = require(ReplicatedStorage.Shared.Components.TextButton)

--- Image Component : ImageLink, Pos, Size
local function image(props)
	local position = props.position or UDim2.fromScale(0, 0)
	local size = props.size or UDim2.fromScale(0.2, 0.2)

	local imageLink = props.imageLink

	return Roact.createElement("ImageLabel", {
		Image = imageLink,
		Position = position,
		Size = size,
		BackgroundTransparency = 1,
	})
end

-- Composed

local resourceBar = require(ReplicatedStorage.Shared.Components.ResourceBar)
local augmentPanel = require(ReplicatedStorage.Shared.Components.AugmentPanel)

--- Horizontal Grid Layout
local function frameGridLayout(props)
	local position = props.position
	local size = props.size

	local listItems = props.listItems
	local xPadding = props.xPadding
	local cellYSize = props.cellYSize

	-- Calculate Properties
	local columns = #listItems
	local cellXSize = Gears.ElementXSize(false, columns, xPadding)

	return Roact.createElement("Frame", {
		Position = position,
		Size = size,
		BackgroundTransparency = 1,
		ZIndex = 5,
	}, {
		Layout = Roact.createElement("UIGridLayout", {
			HorizontalAlignment = "Center",
			VerticalAlignment = "Center",
			CellSize = UDim2.new(cellXSize, cellYSize),
			Padding = UDim.new(xPadding),
		}),
		ListItems = listItems,
	})
end

-- #endregion

-- #region MAIN GUI MISC

-- Bananas Count
local bananaImageProps = {
	position = UDim2.fromScale(0.77, 0),
	size = UDim2.fromScale(0.08, 0.18),
	imageLink = "rbxassetid://92617984020165",
}

BananasMain = RoactRodux.connect(function(state, props)
	-- mapStateToProps
	local bananas = 0

	if state.players[player.UserId] then
		bananas = state.players[player.UserId].bananas
	end

	return {
		position = UDim2.fromScale(0.57, 0), -- X_pos = 0.75 - size.x / 2
		size = UDim2.fromScale(0.2, 0.2),
		text = bananas,
		textXAlign = "Right",
	}
end)(textLabel)

local enteringGameLabel = require(ReplicatedStorage.Shared.Components.EnteringGame)

-- #endregion

-- #region RESOURCE BARS

XpBar = RoactRodux.connect(function(state, props)
	local currentXp = 0
	local xpRequired = 10

	local playerState = Selectors.PlayerState(state, player.UserId)

	if playerState then
		currentXp = playerState.currentXp
		xpRequired = playerState.xpRequired
	end

	return {
		-- Background
		position = UDim2.fromScale(0.35, 0.8),
		size = UDim2.fromScale(0.3, 0.025),
		value = currentXp,
		maxValue = xpRequired,
		backgroundTransparency = 0.5,
		borderPixels = 5,
		-- Bar
		barColor = Color3.fromRGB(0, 157, 255),
		barTransparency = 0.2,
		-- Text
		resourceName = "Xp",
	}
end)(resourceBar)

local lifeBar = resourceBar({
	-- Background
	position = UDim2.fromScale(0.35, 0.76),
	size = UDim2.fromScale(0.3, 0.025),
	value = 100,
	maxValue = 100,
	backgroundTransparency = 0.5,
	borderPixels = 5,
	-- Bar
	barColor = Color3.fromRGB(255, 10, 10),
	barTransparency = 0.2,
	-- Text
	resourceName = "Life",
})

-- #endregion

-- #region LVL UP + AUGMENTS PANEL

local function levelUpLabel(props)
	if not props.isVisible then
		return nil
	end

	local waitingLevel = props.waitingLevel

	return Roact.createElement("Frame", {
		Position = UDim2.fromScale(0.0, 0.8),
		Size = UDim2.fromScale(0.15, 0.2),
		BackgroundColor3 = Color3.new(0.75, 0.75, 0.0),
	}, {
		Label = textLabel({
			text = "Lvl Up (A) +" .. waitingLevel,
			textColor = Color3.new(0, 0, 0),
			transparency = 1,
			position = UDim2.fromScale(0.05, 0.05),
			size = UDim2.fromScale(0.9, 0.9),
			textStrokeTransparency = 1,
		}),
	})
end

LevelUpLabel = RoactRodux.connect(function(state, props)
	local isVisible = false
	local waitingLevel = 0

	local playerState = Selectors.PlayerState(state, player.UserId)

	if playerState then
		waitingLevel = playerState.waitingLevel
		isVisible = waitingLevel > 0
	end

	return {
		isVisible = isVisible,
		waitingLevel = waitingLevel,
	}
end)(levelUpLabel)

AugmentPanel = RoactRodux.connect(function(state, props)
	local isVisible = false
	local augments = {}

	local playerState = Selectors.PlayerState(state, player.UserId)

	if playerState then
		isVisible = playerState.state == "PickingAugment"
		augments = playerState.currentAugments
	end

	return {
		isVisible = isVisible,
		augments = augments,
	}
end)(augmentPanel)

-- #endregion

-- #region WORLD PANELS

-- Controls
local controlsText = textLabel({
	text = "WASD = Movements\nSpace = Jump\n123... = Equip Weapon\nA = Open Augment Menu\nF = Center Camera\nT = Toggle Music",
	size = UDim2.fromScale(1, 1),
})

-- Wiki
-- ...

-- Shop
local hundredDonationProps = {
	text = "Donate\n100 Robux",
	onClick = function()
		MarketplaceService:PromptProductPurchase(player, hundredDonationId)
	end,
}

local thousandDonationProps = {
	text = "Donate\n1 000 Robux",
	onClick = function()
		MarketplaceService:PromptProductPurchase(player, thousandDonationId)
	end,
}

-- #endregion

-- TEST IN GAME UI
-- TODO : Move to Game UI

-- Global Enemy Lvl Display
local robotImageProps = {
	position = UDim2.fromScale(0.22, 0.1),
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
		position = UDim2.fromScale(0.25, 0.1),
		size = UDim2.fromScale(0.1, 0.1),
		text = "Lvl " .. globalEnemyLvl,
	}
end)(textLabel)

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
	resourceName = "Stage Progress",
}

-- TODO : Events Icons

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
		size = UDim2.fromScale(0.4, 0.05),
		listItems = iconList,
		xPadding = 0.1,
		cellYSize = 0.9,
	}
end)(frameGridLayout)

EventsIcons = Roact.createElement(eventsIcons)
warn(EventsIcons)

-- GameTimer
local gameTimerProps = {
	position = UDim2.fromScale(0.45, 0.05),
	size = UDim2.fromScale(0.05, 0.05),
	text = "0",
}

-- Currencies

-- #region FINAL GUIS

local function mainGui()
	return Roact.createElement("ScreenGui", {}, {
		EnteringGameLabel = Roact.createElement(enteringGameLabel),
		Bananas = Roact.createElement(BananasMain),
		BananaImage = image(bananaImageProps),
		LevelUpLabel = Roact.createElement(LevelUpLabel),
		AugmentPanel = Roact.createElement(AugmentPanel),
		XpBar = Roact.createElement(XpBar),
		LifeBar = lifeBar,
		-- Test Game Gui
		RobotImage = image(robotImageProps),
		GlobalEnemyLvlText = Roact.createElement(globalEnemyLvlText),
		CurrentStageText = Roact.createElement(currentStageText),
		ProgressBar = resourceBar(progressBarProps),
		-- EventsIcons = EventsIcons,
		GameTimer = textLabel(gameTimerProps),
	})
end

local function controlsGui()
	return Roact.createElement("SurfaceGui", {
		Adornee = controlsBoard,
		Face = "Left",
	}, {
		ControlsTextLabel = controlsText,
	})
end

local function shopGui()
	return Roact.createElement("SurfaceGui", {
		Adornee = shopBoard,
		Face = "Left",
	}, {
		Frame = Roact.createElement("Frame", {
			Position = UDim2.fromScale(0.05, 0.05),
			Size = UDim2.fromScale(0.9, 0.9),
			BackgroundTransparency = 1,
		}, {
			Roact.createElement("UIGridLayout", {
				CellPadding = UDim2.fromScale(0.05, 0.05),
				CellSize = UDim2.fromScale(0.27, 0.25),
			}),
			textButton(hundredDonationProps),
			textButton(thousandDonationProps),
		}),
	})
end

local metaUpgradeBoard = require(ReplicatedStorage.Shared.Components.UpgradesGui)

-- App
local app = Roact.createElement(RoactRodux.StoreProvider, {
	store = Store,
}, {
	Container = Roact.createElement("Folder", {}, {
		MainGui = mainGui(),
		ControlsGui = controlsGui(),
		ShopGui = shopGui(),
		MetaUpgradeBoard = metaUpgradeBoard,
	}),
})

Roact.mount(app, playerGui)

-- #endregion

-- #region AFTER UI CREATION
-- Manual / Roact less UI -> Dynamic UI

local mainGuiRef = playerGui.RoactTree.MainGui

-- LifeBar Update
local lBar = mainGuiRef.LifeBar[2]
local lifeText = mainGuiRef.LifeBar[1]

PlayerController.LifeUpdate:Connect(function(state, life)
	local playerState = Selectors.PlayerState(state, player.UserId)

	if not playerState then
		return
	end

	local maxLife = playerState.stats.maxLife

	local percentage = life / maxLife
	lBar.Size = UDim2.fromScale(percentage, 1)

	lifeText.Text = "Life : " .. math.ceil(life) .. " / " .. maxLife
end)

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
