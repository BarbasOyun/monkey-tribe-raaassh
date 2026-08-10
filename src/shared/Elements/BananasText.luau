local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local RoactRodux = require(ReplicatedStorage.Shared.RoactRodux)
local Roact = require(ReplicatedStorage.Shared.Roact)

-- Get Components
local textLabel = require(ReplicatedStorage.Shared.Components.TextLabel)
local image = require(ReplicatedStorage.Shared.Components.Image)

local player = Players.LocalPlayer

-- Hub Version
local hubImageProps = {
	position = UDim2.fromScale(0.77, 0),
	size = UDim2.fromScale(0.08, 0.18),
	imageLink = "rbxassetid://92617984020165",
}

local hubConnectionProps = {
	position = UDim2.fromScale(0.56, 0), -- X_pos = 0.75 - size.x / 2
	size = UDim2.fromScale(0.2, 0.2),
}

-- Game Version
local gameImageProps = {
	position = UDim2.fromScale(0.77, 0),
	size = UDim2.fromScale(0.05, 0.09),
	imageLink = "rbxassetid://92617984020165",
}

local gameConnectionProps = {
	position = UDim2.fromScale(0.66, 0), -- X_pos = 0.75 - size.x / 2
	size = UDim2.fromScale(0.1, 0.1),
}

-- Registry
local imageProps = {
	hubImageProps,
	gameImageProps,
}

local connectionsProps = {
	hubConnectionProps,
	gameConnectionProps,
}

local function GetBananasUi(sceneId: number)
	-- Create Image
	local BananaIcon = image(imageProps[sceneId])

	-- Create Text
	local connectionProps = connectionsProps[sceneId]

	local Connection = RoactRodux.connect(function(state)
		-- mapStateToProps
		local bananas = 0

		if state.players[player.UserId] then
			bananas = state.players[player.UserId].bananas
		end

		return {
			position = connectionProps.position,
			size = connectionProps.size,
			text = bananas,
			textXAlign = "Right",
		}
	end)(textLabel)

	local BananasText = Roact.createElement(Connection)

	return BananaIcon, BananasText
end

return GetBananasUi
