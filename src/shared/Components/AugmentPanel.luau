local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Roact = require(ReplicatedStorage.Shared.Roact)
local Knit = require(ReplicatedStorage.Packages.Knit)

local StatService = Knit.GetService("StatService")
local PlayerController = Knit.GetController("PlayerController")
local AUGMENTS = PlayerController.AUGMENTS
local DISPLAY_TEXT = PlayerController.DISPLAY_TEXT

local textLabel = require(ReplicatedStorage.Shared.Components.TextLabel)

local AugmentPanel = Roact.Component:extend("AugmentPanel")

local function augmentCard(props)
	local xSize = props.xSize
	local size = UDim2.fromScale(xSize, 0.5)

	local color = props.color or AUGMENTS.colors[AUGMENTS.rarity.common]
	local title = props.title or "Augment"
	local value = props.value or "0"

	local index = props.index

	local onClick = function()
		StatService:PickAugment(index)
	end

	return Roact.createElement("TextButton", {
		Size = size,
		Text = "",
		[Roact.Event.MouseButton1Click] = onClick,
		Font = Enum.Font.Bangers,
		TextColor3 = Color3.new(),
		BackgroundColor3 = color,
		BorderColor3 = Color3.new(0.15, 0.1, 0.0),
		BorderSizePixel = 10,
	}, {
		Title = textLabel({
			text = title,
		}),
		Value = textLabel({
			text = value,
		}),
	})
end

function AugmentPanel:cardsPanel()
	local augmentsCards = {}

	local columns = #self.augments
	local gapSize = 0.5
	local cardXSize = columns + gapSize * (columns - 1)

	for index, augment in pairs(self.augments) do
		local augmentCard = augmentCard({
			xSize = cardXSize,
			title = DISPLAY_TEXT[augment.modStat],
			color = AUGMENTS.colors[augment.rarity],
			value = augment.value,
			index = index,
		})

		table.insert(augmentsCards, augmentCard)
	end

	return Roact.createElement("Frame", {
		Position = UDim2.fromScale(0.0, 0.0),
		Size = UDim2.fromScale(1.0, 1.0),
	}, {
		Layout = Roact.createElement("UIListLayout", {
			-- Props for UIListLayout...
			-- gapSize = cardXSize * gapSize
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

	self.eventConnection = StatService.NewAugments:Connect(function(patch)
		self:setState({
			isVisible = true,
			augments = patch.currentAugments,
		})
	end)
end

function AugmentPanel:willUnmount()
	if self.eventConnection then
		self.eventConnection:Disconnect()
	end
end

function AugmentPanel:render()
	return Roact.createElement("Frame", {
		Position = UDim2.fromScale(0.125, 0.125),
		Size = UDim2.fromScale(0.75, 0.75),
		BackgroundTransparency = 1,
	}, {
		Title = self.state.isVisible and textLabel({
			text = "Choose an Augment",
			transparency = 1,
			size = UDim2.fromScale(1, 1),
		}),
		CardsPanel = self.state.isVisible and AugmentPanel:cardsPanel(),
	})
end

return AugmentPanel
