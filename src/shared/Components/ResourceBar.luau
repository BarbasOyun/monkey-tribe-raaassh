local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Roact = require(ReplicatedStorage.Shared.Roact)

local textLabel = require(ReplicatedStorage.Shared.Components.TextLabel)

return function(props)
	local position = props.position or UDim2.fromScale(0, 0)
	local size = props.size or UDim2.fromScale(0.2, 0.2)

	local value = props.value
	local maxValue = props.maxValue

	-- Background
	local backgroundTransparency = props.backgroundTransparency or 1
	local backgroundColor = props.backgroundColor or Color3.new(1, 1, 1)
	local borderPixels = props.borderPixels or 1

	-- Bar
	local barProgress = value / maxValue
	local barColor = props.barColor
	local barTransparency = props.barTransparency

	-- Text
	local resourceName = props.resourceName or "Resources"
	local textColor = props.textColor or Color3.new(0, 0, 0)

	-- Childs

	local bar = Roact.createElement("Frame", {
		Name = "Bar",
		-- Position = UDim2.fromScale(0.0, 0.0),
		Size = UDim2.fromScale(barProgress, 1.0),
		-- Style
		BackgroundTransparency = barTransparency,
		BackgroundColor3 = barColor,
	})

	local resourcesText = textLabel({
		size = UDim2.fromScale(1.0, 1.0),
		text = resourceName .. " " .. value .. " / " .. maxValue,
		textColor3 = textColor,
		zIndex = 10,
	})

	-- Background
	return Roact.createElement("Frame", {
		Position = position,
		Size = size,
		BackgroundTransparency = backgroundTransparency,
		BackgroundColor3 = backgroundColor,
		BorderSizePixel = borderPixels,
	}, {
		resourcesText,
		bar,
	})
end
