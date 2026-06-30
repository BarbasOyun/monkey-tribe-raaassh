local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local PlayerGui = Players.LocalPlayer.PlayerGui

local RoactRodux = require(ReplicatedStorage.Shared.RoactRodux)
local Roact = require(ReplicatedStorage.Shared.Roact)

local Knit = require(ReplicatedStorage.Packages.Knit)
Knit.OnStart():await() -- Wait for KnitControllersStart

local PlayerController = Knit.GetController("PlayerController")

local player = Players.LocalPlayer
local controlsBoard = workspace.Wiki.ControlsBoard.Board
local shopBoard = workspace.Wiki.ShopBoard.Board

-- IN WORLD UI

-- attackSpeedButton.MouseButton1Click:Connect(function()
-- 	local PlayerService = Knit.GetService("PlayerService")
-- 	PlayerService.GiveMeAttackSpeed:Fire()
-- end)

-- ROACT COMPONENTS

local enteringGameLabel = require(ReplicatedStorage.Shared.Components.EnteringGame)

local function textLabel(props)
	local text = props.text or ""
	local textScaled = props.textScaled or true
	local textColor = props.textColor or Color3.fromRGB(255, 255, 255)
	local transparency = props.transparency or 1

	local position = props.position or UDim2.fromScale(0, 0)
	local size = props.size or UDim2.fromScale(0.2, 0.2)

	return Roact.createElement("TextLabel", {
		Text = text,
		Font = Enum.Font.Bangers,
		TextScaled = textScaled,
		TextColor3 = textColor,
		BackgroundTransparency = transparency,
		Position = position,
		Size = size,
	})
end

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

local controlsTextProps = {
	text = "WASD = Movements\nSpace = Jump\nA = Open Augment Menu\nF = Center Camera",
	size = UDim2.fromScale(1, 1),
}

local bananaImageProps = {
	position = UDim2.fromScale(0.77, 0),
	size = UDim2.fromScale(0.08, 0.18),
	imageLink = "rbxassetid://92617984020165",
}

-- Bananas Count
local function Bananas(props)
	local position = props.position or UDim2.fromScale(0, 0)
	local size = props.size or UDim2.fromScale(0.2, 0.2)

	local text = props.text or "Bananas: "
	local bananas = props.bananas or 0

	return Roact.createElement("TextLabel", {
		Text = text .. bananas,
		Font = Enum.Font.Bangers,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		Position = position,
		Size = size,
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

-- App
local app = Roact.createElement(RoactRodux.StoreProvider, {
	store = PlayerController.store,
}, {
	Container = Roact.createElement("Folder", {}, {
		-- Main
		MainGui = Roact.createElement("ScreenGui", {}, {
			EnteringGameLabel = Roact.createElement(enteringGameLabel),
			Bananas = Roact.createElement(BananasMain),
			BananaImage = image(bananaImageProps),
		}),
		-- Controls = SurfaceGui
		ControlsGui = Roact.createElement("SurfaceGui", {
			Adornee = controlsBoard,
			Face = "Left",
		}, {
			ControlsTextLabel = textLabel(controlsTextProps),
		}),
		-- Shop = SurfaceGui
		Shop = Roact.createElement("SurfaceGui", {
			Adornee = shopBoard,
			Face = "Left",
		}, {
			ControlsTextLabel = textLabel(controlsTextProps),
		}),
	}),
})

Roact.mount(app, PlayerGui)
