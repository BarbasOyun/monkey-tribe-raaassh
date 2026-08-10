-- Player Ui in Hub
-- TODO : Use UiAspectRatioConstraint

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local RoactRodux = require(ReplicatedStorage.Shared.RoactRodux)
local Roact = require(ReplicatedStorage.Shared.Roact)

-- Get Constants
-- local LevelDefinitions = require(ReplicatedStorage.Shared.AuthoringData.LevelDefinitions)

-- Get Store
local RoduxStore = require(ReplicatedStorage.Shared.RoduxStore)
local Store = RoduxStore.Store
local Selectors = RoduxStore.Selectors

-- Get Knit
local Knit = require(ReplicatedStorage.Packages.Knit)
Knit.OnStart():await() -- Wait for KnitControllersStart

local PlayerController = Knit.GetController("PlayerController")

-- TODO : Client side Mutable State
local player = Players.LocalPlayer
local playerGui = player.PlayerGui

local controlsBoard = workspace.Wiki.ControlsBoard.Board
local shopBoard = workspace.Main.ShopBoard.Board

-- Shop
-- TODO : ShopDefinitions Module in ReplicatedStorage
local hundredDonationId = 3607471778
local thousandDonationId = 3607471867

-- Get Components
local textLabel = require(ReplicatedStorage.Shared.Components.TextLabel)
local textButton = require(ReplicatedStorage.Shared.Components.TextButton)

-- Get Elements
local AugmentPanel = require(ReplicatedStorage.Shared.Elements.AugmentPanel)
local LevelUpLabel = require(ReplicatedStorage.Shared.Elements.LevelUpLabel)
local Bars = require(ReplicatedStorage.Shared.Elements.ResourceBars)
local XpBar = Bars.XpBar
local LifeBar = Bars.LifeBar
local updateLifeBar = Bars.updateLifeBar
local enteringGameLabel = require(ReplicatedStorage.Shared.Components.EnteringGame)
local GetBananasUi = require(ReplicatedStorage.Shared.Elements.BananasText)
local BananaIcon, BananasText = GetBananasUi(1)

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

-- #region APP

local function mainGui()
	return Roact.createElement("ScreenGui", {}, {
		-- Top
		BananaIcon = BananaIcon,
		BananasText = BananasText,
		-- Bot
		XpBar = Roact.createElement(XpBar),
		LifeBar = Roact.createElement(LifeBar),
		EnteringGameLabel = Roact.createElement(enteringGameLabel),
		-- Panels
		LevelUpLabel = Roact.createElement(LevelUpLabel),
		AugmentPanel = Roact.createElement(AugmentPanel),
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

-- #region UI LIFETIME
-- Manual / Roact less UI -> Dynamic UI

updateLifeBar()

--#endregion
