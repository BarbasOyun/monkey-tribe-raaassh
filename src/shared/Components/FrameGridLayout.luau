local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Roact = require(ReplicatedStorage.Shared.Roact)

--- Horizontal Grid Layout
local function frameGridLayout(props)
	local position = props.position
	local size = props.size

	local listItems = props.listItems or {}

	-- Calculate Properties
	local columns = #listItems
	local xPadding = (1 - 0.1 * columns) / (columns + 1)

	return Roact.createElement("Frame", {
		Position = position,
		Size = size,
		BackgroundTransparency = 1,
		ZIndex = 5,
	}, {
		Layout = Roact.createElement("UIGridLayout", {
			HorizontalAlignment = "Center",
			VerticalAlignment = "Center",
			CellSize = UDim2.fromScale(0.1, 1.0),
			CellPadding = UDim2.fromScale(xPadding, 0),
		}),
		ListItems = Roact.createFragment(listItems),
	})
end

return frameGridLayout
