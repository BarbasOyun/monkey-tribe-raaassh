local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Roact = require(ReplicatedStorage.Shared.Roact)
local Knit = require(ReplicatedStorage.Packages.Knit)
local Gears = require(ReplicatedStorage.Shared.Gears)

local StatService = Knit.GetService("StatService")
local PlayerController = Knit.GetController("PlayerController")
local AUGMENTS = PlayerController.AUGMENTS
local STATS_DISPLAY = PlayerController.STATS_DISPLAY

local textLabel = require(ReplicatedStorage.Shared.Components.TextLabel)

local AugmentPanel = Roact.Component:extend("AugmentPanel")

-- Rarity
-- Value
-- ModStat
local function augmentCard(props)
	local xSize = props.xSize
	local size = UDim2.fromScale(xSize, 0.75)

	local color = props.color or AUGMENTS.colors[AUGMENTS.rarity.common]
	local rarity = props.rarity
	local value = props.value or "0"
	local modStat = props.modStat or "Augment"

	local index = props.index

	local onClick = function()
		StatService:PickAugment(index)
	end

	return Roact.createElement("TextButton", {
		Size = size,
		Text = "",
		[Roact.Event.MouseButton1Click] = onClick,
		BackgroundColor3 = color,
		BorderColor3 = Color3.new(0.15, 0.1, 0.0),
		BorderSizePixel = 3,
	}, {
		Rarity = textLabel({
			text = rarity,
			textColor = Color3.new(0, 0, 0),
			textStrokeTransparency = 1,
			size = UDim2.fromScale(0.9, 0.2),
			position = UDim2.fromScale(0.05, 0.1),
		}),
		Value = textLabel({
			text = value,
			textColor = Color3.new(0, 0, 0),
			textStrokeTransparency = 1,
			size = UDim2.fromScale(0.9, 0.35),
			position = UDim2.fromScale(0.05, 0.3),
		}),
		ModStat = textLabel({
			text = modStat,
			textColor = Color3.new(0, 0, 0),
			textStrokeTransparency = 1,
			size = UDim2.fromScale(0.9, 0.35),
			position = UDim2.fromScale(0.05, 0.65),
		}),
	})
end

function AugmentPanel:cardsPanel()
	local augmentsCards = {}

	local augments = self.state.augments

	local columns = #augments
	local gapSize = 0.5
	local cardXSize = Gears.elementXSize(false, columns, gapSize)

	for index, augment in pairs(augments) do
		local augmentCard = augmentCard({
			xSize = cardXSize,
			color = AUGMENTS.colors[augment.rarity],
			rarity = augment.rarity,
			value = augment.value,
			modStat = STATS_DISPLAY[augment.modStat],
			index = index,
		})

		table.insert(augmentsCards, augmentCard)
	end

	return Roact.createElement("Frame", {
		Position = UDim2.fromScale(0.0, 0.3),
		Size = UDim2.fromScale(1.0, 0.7),
		BackgroundTransparency = 1,
	}, {
		Layout = Roact.createElement("UIListLayout", {
			FillDirection = "Horizontal",
			VerticalAlignment = "Center",
			Padding = UDim.new(cardXSize * gapSize),
		}),
		ListItems = Roact.createFragment(augmentsCards),
	})
end

function AugmentPanel:init()
	self:setState({
		isVisible = false,
		augments = {},
	})
end

function AugmentPanel:didMount()
	local StatService = Knit.GetService("StatService")

	self.startEventConnection = StatService.NewAugments:Connect(function(augmentChoices)
		warn(augmentChoices)
		self:setState({
			isVisible = true,
			augments = augmentChoices,
		})
	end)

	self.endEventConnection = StatService.FinishPickingAugments:Connect(function(patch)
		self:setState({
			isVisible = false,
		})
	end)
end

function AugmentPanel:willUnmount()
	if self.startEventConnection then
		self.startEventConnection:Disconnect()
	end

	if self.endEventConnection then
		self.endEventConnection:Disconnect()
	end
end

function AugmentPanel:render()
	-- Main Panel
	return Roact.createElement("Frame", {
		Position = UDim2.fromScale(0.125, 0.0),
		Size = UDim2.fromScale(0.75, 0.9),
		BackgroundTransparency = 1,
	}, {
		Title = self.state.isVisible and textLabel({
			text = "Choose an Augment",
			-- transparency = 1,
			size = UDim2.fromScale(0.75, 0.25),
			position = UDim2.fromScale(0.125, 0.0),
		}),
		CardsPanel = self.state.isVisible and self:cardsPanel(),
	})
end

return AugmentPanel
