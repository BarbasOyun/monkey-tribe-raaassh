local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local RoactRodux = require(ReplicatedStorage.Shared.RoactRodux)
local Roact = require(ReplicatedStorage.Shared.Roact)

-- Get Components
local textLabel = require(ReplicatedStorage.Shared.Components.TextLabel)
local image = require(ReplicatedStorage.Shared.Components.Image)

local player = Players.LocalPlayer

-- Hub Version
local bananaImageProps = {
	position = UDim2.fromScale(0.77, 0),
	size = UDim2.fromScale(0.08, 0.18),
	imageLink = "rbxassetid://92617984020165",
}

BananasConnection = RoactRodux.connect(function(state, props)
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

-- TODO : Game Version

local BananaIcon = image(bananaImageProps)
local BananasText = Roact.createElement(BananasConnection)

local Bananas = {
	BananaIcon = BananaIcon,
	BananasText = BananasText,
}

local function GetBananasUi(sceneId: number)
	if sceneId == 0 then
		-- TODO
	end
end

return Bananas
