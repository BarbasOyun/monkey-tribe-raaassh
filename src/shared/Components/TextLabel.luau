local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Roact = require(ReplicatedStorage.Shared.Roact)

return function(props)
	local position = props.position or UDim2.fromScale(0, 0)
	local size = props.size or UDim2.fromScale(0.2, 0.2)

	-- Text
	local text = props.text or ""
	local textScaled = props.textScaled or true
	local textColor = props.textColor or Color3.new(1, 1, 1)
	local textXAlign = props.textXAlign or "Center"

	-- Style
	local transparency = props.transparency or 1
	local backgroundColor = props.backgroundColor or Color3.new(1, 1, 1)
	local borderPixels = props.borderPixels or 1

	return Roact.createElement("TextLabel", {
		-- Text
		Text = text,
		Font = Enum.Font.Bangers,
		TextScaled = textScaled,
		TextColor3 = textColor,
		TextXAlignment = textXAlign,
		-- Style
		BackgroundTransparency = transparency,
		BackgroundColor3 = backgroundColor,
		BorderSizePixel = borderPixels,
		Position = position,
		Size = size,
	})
end
