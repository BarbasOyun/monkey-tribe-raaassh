local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local RoactRodux = require(ReplicatedStorage.Shared.RoactRodux)
local Roact = require(ReplicatedStorage.Shared.Roact)
local Gears = require(ReplicatedStorage.Shared.Gears)

-- Get Knit
local Knit = require(ReplicatedStorage.Packages.Knit)
local AugmentsService = Knit.GetService("AugmentsService")
local PlayerController = Knit.GetController("PlayerController")

-- Get Constants
local AUGMENTS = PlayerController.AUGMENTS
local STATS_DISPLAY = PlayerController.STATS_DISPLAY

-- Get Store
local RoduxStore = require(ReplicatedStorage.Shared.RoduxStore)
local Selectors = RoduxStore.Selectors

-- Components
local textLabel = require(ReplicatedStorage.Shared.Components.TextLabel)

local player = Players.LocalPlayer

-- TODO : Move to Components
--- Rarity, ModStat, Value
local function augmentCard(props)
	local xSize = props.xSize
	local size = UDim2.fromScale(xSize, 0.75)

	local color = props.color or AUGMENTS.colors[AUGMENTS.rarity.common]
	local rarity = props.rarity
	local value = props.value or "0"
	local modStat = props.modStat or "Augment"

	local index = props.index

	local onClick = function()
		local augmentPickSound = player.PlayerGui.ClientSounds.MainSounds.AugmentPick
		augmentPickSound:Play()
		AugmentsService:PickAugment(index)
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

local function rerollButton()
	local onClick = function()
		AugmentsService:RerollAugment()
	end

	return Roact.createElement("TextButton", {
		Position = UDim2.fromScale(1.05, 0.5), -- UDim2.fromScale(0.75, 0.175)
		Size = UDim2.fromScale(0.15, 0.15),
		Text = "Reroll \n Cost : 10 Sticks",
		[Roact.Event.MouseButton1Click] = onClick,
		BackgroundColor3 = Color3.new(0.694117, 0.498039, 0.078431),
		BorderColor3 = Color3.new(0.15, 0.1, 0.0),
		BorderSizePixel = 3,
		TextScaled = true,
	})
end

-- TODO : Replace with frameGridLayout Component
local function cardsPanel(props)
	local augments = props.augments

	local augmentsCards = {}

	local columns = #augments
	local gapSize = 0.5
	local cardXSize = Gears.ElementXSize(false, columns, gapSize)

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
		Position = UDim2.fromScale(0, 0.25), -- 0.3
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

local function augmentPanel(props)
	if not props.isVisible then
		return nil
	end

	local cardsPanelProps = {
		augments = props.augments,
	}

	return Roact.createElement("Frame", {
		Position = UDim2.fromScale(0.05125, 0.0),
		Size = UDim2.fromScale(0.75, 0.9),
		BackgroundTransparency = 1,
	}, {
		Title = textLabel({
			text = "Choose an Augment",
			size = UDim2.fromScale(0.75, 0.25),
			position = UDim2.fromScale(0.125, -0.125),
			zIndex = 5,
		}),
		CardsPanel = cardsPanel(cardsPanelProps),
		RerollButton = rerollButton(),
	})
end

AugmentPanel = RoactRodux.connect(function(state, props)
	local isVisible = false
	local augments = {}

	local playerState = Selectors.PlayerState(state, player.UserId)

	if playerState then
		isVisible = playerState.state == "PickingAugment"
		augments = playerState.currentAugments
	end

	return {
		isVisible = isVisible,
		augments = augments,
	}
end)(augmentPanel)

return AugmentPanel
