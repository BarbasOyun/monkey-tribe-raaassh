local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local RoduxStore = require(ReplicatedStorage.Shared.RoduxStore)
local store = RoduxStore.Store
local selectors = RoduxStore.Selectors

local RoactRodux = require(ReplicatedStorage.Shared.RoactRodux)
local Roact = require(ReplicatedStorage.Shared.Roact)

local Knit = require(ReplicatedStorage.Packages.Knit)
Knit.OnStart():await() -- Wait for KnitControllersStart

local PlayerController = Knit.GetController("PlayerController")

local player = Players.LocalPlayer
local playerGui = Players.LocalPlayer.PlayerGui

local controlsBoard = workspace.Wiki.ControlsBoard.Board
local shopBoard = workspace.Main.ShopBoard.Board

-- Shop
-- TODO : Shop Module or Service in ReplicatedStorage
local hundredDonationId = 3607471778
local thousandDonationId = 3607471867

-- ROACT COMPONENTS

local textLabel = require(ReplicatedStorage.Shared.Components.TextLabel)
local textButton = require(ReplicatedStorage.Shared.Components.TextButton)
local resourceBar = require(ReplicatedStorage.Shared.Components.ResourceBar)

-- Image Component : ImageId, Pos, Size
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

-- Main Gui

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

-- Augments Panel + LevelUp
local augmentPanel = require(ReplicatedStorage.Shared.Components.AugmentPanel)

AugmentPanel = RoactRodux.connect(function(state, props)
	local isVisible = false
	local augments = {}

	local playerData = selectors.PlayerData(state, player.UserId)

	if playerData then
		isVisible = playerData.state == "PickingAugment"
		augments = playerData.currentAugments
	end

	return {
		isVisible = isVisible,
		augments = augments,
	}
end)(augmentPanel)

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

	local playerData = selectors.PlayerData(state, player.UserId)

	if playerData then
		waitingLevel = playerData.waitingLevel
		isVisible = waitingLevel > 0
	end

	return {
		isVisible = isVisible,
		waitingLevel = waitingLevel,
	}
end)(levelUpLabel)

-- Resource Bars
XpBar = RoactRodux.connect(function(state, props)
	local currentXp = 0
	local xpRequired = 10

	local playerData = selectors.PlayerData(state, player.UserId)

	if playerData then
		currentXp = playerData.currentXp
		xpRequired = playerData.xpRequired
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

-- FINAL GUIS

local function mainGui()
	return Roact.createElement("ScreenGui", {}, {
		EnteringGameLabel = Roact.createElement(enteringGameLabel),
		Bananas = Roact.createElement(BananasMain),
		BananaImage = image(bananaImageProps),
		LevelUpLabel = Roact.createElement(LevelUpLabel),
		AugmentPanel = Roact.createElement(AugmentPanel),
		XpBar = Roact.createElement(XpBar),
		LifeBar = lifeBar,
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

local upgradeGui = require(ReplicatedStorage.Shared.Components.UpgradesGui)

-- App
local app = Roact.createElement(RoactRodux.StoreProvider, {
	store = store,
}, {
	Container = Roact.createElement("Folder", {}, {
		MainGui = mainGui(),
		ControlsGui = controlsGui(),
		ShopGui = shopGui(),
		UpgradeGui = upgradeGui,
	}),
})

Roact.mount(app, playerGui)

-- #region AFTER UI IS CREATED

-- LifeBar Update
local lBar = playerGui.RoactTree.MainGui.LifeBar[2]
local lifeText = playerGui.RoactTree.MainGui.LifeBar[1]

PlayerController.LifeUpdate:Connect(function(state, life)
	local playerData = selectors.PlayerData(state, player.UserId)

	if not playerData then
		return
	end

	local maxLife = playerData.stats.maxLife

	local percentage = life / maxLife
	lBar.Size = UDim2.fromScale(percentage, 1)

	lifeText.Text = "Life : " .. math.ceil(life) .. " / " .. maxLife
end)

--#endregion
