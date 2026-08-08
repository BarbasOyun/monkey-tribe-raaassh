local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local RoactRodux = require(ReplicatedStorage.Shared.RoactRodux)
local Roact = require(ReplicatedStorage.Shared.Roact)

-- Get Store
local RoduxStore = require(ReplicatedStorage.Shared.RoduxStore)
local Selectors = RoduxStore.Selectors

local player = Players.LocalPlayer

-- Get Components
local textLabel = require(ReplicatedStorage.Shared.Components.TextLabel)

-- TODO : FrameLabel + Move to Components
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

return LevelUpLabel
