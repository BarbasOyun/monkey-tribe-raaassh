local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

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

-- Controls
local controlsText = textLabel({
	text = "WASD = Movements\nSpace = Jump\nA = Open Augment Menu\nF = Center Camera\nT = Toggle Music",
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

-- FINAL GUIS

local function mainGui()
	return Roact.createElement("ScreenGui", {}, {
		EnteringGameLabel = Roact.createElement(enteringGameLabel),
		Bananas = Roact.createElement(BananasMain),
		BananaImage = image(bananaImageProps),
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
	store = PlayerController.store,
}, {
	Container = Roact.createElement("Folder", {}, {
		MainGui = mainGui(),
		ControlsGui = controlsGui(),
		ShopGui = shopGui(),
		UpgradeGui = upgradeGui,
	}),
})

Roact.mount(app, playerGui)
