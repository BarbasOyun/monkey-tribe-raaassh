local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Roact = require(ReplicatedStorage.Shared.Roact)
local Knit = require(ReplicatedStorage.Packages.Knit)

local textLabel = require(ReplicatedStorage.Shared.Components.TextLabel)

local EnteringGameLabel = Roact.Component:extend("EnteringGameLabel")

function EnteringGameLabel:init()
	self:setState({
		isVisible = false,
	})
end

function EnteringGameLabel:didMount()
	local PlayerService = Knit.GetService("PlayerService")

	self.eventConnection = PlayerService.EnteringGame:Connect(function()
		self:setState({
			isVisible = true,
		})
	end)
end

function EnteringGameLabel:willUnmount()
	if self.eventConnection then
		self.eventConnection:Disconnect()
	end
end

function EnteringGameLabel:render()
	return Roact.createElement("Frame", {
		Position = UDim2.fromScale(0.3, 0.55),
		Size = UDim2.fromScale(0.4, 0.4),
		BackgroundTransparency = 1,
	}, {
		Label = self.state.isVisible and textLabel({
			text = "Entering Game...",
			transparency = 1,
			size = UDim2.fromScale(1, 1),
		}),
	})
end

return EnteringGameLabel
