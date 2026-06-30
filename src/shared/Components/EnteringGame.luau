local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Roact = require(ReplicatedStorage.Shared.Roact)
local Knit = require(ReplicatedStorage.Packages.Knit)

local EnteringGameLabel = Roact.Component:extend("EnteringGameLabel")

function EnteringGameLabel:init()
	self:setState({
		isVisible = false,
	})
end

function EnteringGameLabel:didMount()
	local PlayerService = Knit.GetService("PlayerService")

	-- Connect to the Knit Event
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
		MyLabel = self.state.isVisible and Roact.createElement("TextLabel", {
			Text = "Entering Game...",
			TextScaled = true,
			BackgroundTransparency = 1,
			Font = Enum.Font.Bangers,
			Size = UDim2.fromScale(1, 1),
		}),
	})
end

return EnteringGameLabel
