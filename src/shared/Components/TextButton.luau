local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Roact = require(ReplicatedStorage.Shared.Roact)

return function(props)
	local position = props.position or UDim2.fromScale(0, 0)
	local size = props.size or UDim2.fromScale(0.2, 0.2)

	local text = props.text or "Button"
	local onClick = props.onClick
	local borderColor = props.borderColor or Color3.new(1, 1, 0)

	local childs = props.childs or {}

	return Roact.createElement("TextButton", {
		Position = position,
		Size = size,
		Text = text,
		[Roact.Event.MouseButton1Click] = onClick,
		-- TextScaled = true,
		TextSize = 45,
		TextWrap = true,
		Font = Enum.Font.Bangers,
		TextColor3 = Color3.new(),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderColor3 = borderColor,
		BorderSizePixel = 10,
	}, childs)
end
