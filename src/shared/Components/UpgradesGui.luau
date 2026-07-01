local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Roact = require(ReplicatedStorage.Shared.Roact)
local RoactRodux = require(ReplicatedStorage.Shared.RoactRodux)
local Knit = require(ReplicatedStorage.Packages.Knit)

local PlayerController = Knit.GetController("PlayerController")
local STATS_STORE = PlayerController.StatsStore
local STATS_DISPLAY = PlayerController.StatsDisplay
local META_UPRGADES = PlayerController.MetaUpgrades

local upgradesBoard = workspace.Main.UpgradeBoard.Board
local player = Players.LocalPlayer

local textLabel = require(ReplicatedStorage.Shared.Components.TextLabel)
local textButton = require(ReplicatedStorage.Shared.Components.TextButton)

-- BASE COMPONENT

local function title(statType, backgroundColor)
	return RoactRodux.connect(function(state, props)
		local playerData = state.players[player.UserId]

		local upgradeLvl = 0
		local maxUpgradeLvl = 10

		if playerData then
			upgradeLvl = playerData.metaUpgrades[statType]
			maxUpgradeLvl = META_UPRGADES[statType].maxLevel
		end

		return {
			position = UDim2.fromScale(0, -0.1),
			size = UDim2.fromScale(1, 0.35),
			text = STATS_DISPLAY[statType] .. " " .. upgradeLvl .. "/" .. maxUpgradeLvl,
			textScaled = true,
			textColor = Color3.new(1, 1, 1),
			backgroundColor = backgroundColor,
			transparency = 0,
			borderPixels = 0,
		}
	end)(textLabel)
end

local function currentStat(statType)
	return RoactRodux.connect(function(state, props)
		local playerData = state.players[player.UserId]

		local currentStat = 0

		local upgradeLevel = playerData.metaUpgrades[statType]

		if playerData then
			currentStat = upgradeLevel * META_UPRGADES[statType].incrementValue
		end

		return {
			position = UDim2.fromScale(0, 0.3),
			size = UDim2.fromScale(1, 0.4),
			text = currentStat,
			textScaled = true,
			textColor = Color3.new(0, 0, 0),
		}
	end)(textLabel)
end

local function cost(statType)
	return RoactRodux.connect(function(state, props)
		local playerData = state.players[player.UserId]
		local statData = META_UPRGADES[statType]

		local cost = 0

		local upgradeLevel = playerData.metaUpgrades[statType]

		if playerData then
			cost = statData.baseCost + statData.baseCost * statData.costMultiplier * upgradeLevel
		end

		return {
			position = UDim2.fromScale(0, 0.7),
			size = UDim2.fromScale(1, 0.25),
			text = "Cost: " .. cost .. " Bananas",
			textScaled = true,
			textColor = Color3.new(0, 0, 0),
		}
	end)(textLabel)
end

local function statButton(statType, borderColor)
	return textButton({
		text = "",
		borderColor = borderColor,
		onClick = function()
			PlayerController:BuyUpgrade(statType)
		end,
		childs = {
			Roact.createElement(title(statType, borderColor)),
			Roact.createElement(currentStat(statType)),
			Roact.createElement(cost(statType)),
		},
	})
end

-- PER STAT PROPS

-- Offense
local attackDamageButton = statButton(STATS_STORE.increasedAttackDamage, Color3.new(1, 0, 0))
local critChanceButton = statButton(STATS_STORE.critChance, Color3.new(1, 0, 0))
local critMultiButton = statButton(STATS_STORE.critMultiplier, Color3.new(1, 0, 0))
local attackSpeedButton = statButton(STATS_STORE.increasedAttackSpeed, Color3.new(1, 0, 0))
local aoeButton = statButton(STATS_STORE.increasedAoe, Color3.new(1, 0, 0))

-- Defense
local maxLifeButton = statButton(STATS_STORE.maxLife, Color3.new(0, 0, 1))
local lifeRegenButton = statButton(STATS_STORE.lifeRegen, Color3.new(0, 0, 1))
local damageReductionButton = statButton(STATS_STORE.damageReduction, Color3.new(0, 0, 1))

-- Utility
local mobilityButton = statButton(STATS_STORE.mobility, Color3.new(0, 1, 0))
local luckButton = statButton(STATS_STORE.luck, Color3.new(0, 1, 0))
local increasedXpButton = statButton(STATS_STORE.increasedXp, Color3.new(0, 1, 0))
local increasedPickupRangeButton = statButton(STATS_STORE.increasedPickupRange, Color3.new(0, 1, 0))

return Roact.createElement("SurfaceGui", {
	Adornee = upgradesBoard,
	Face = "Left",
}, {
	Frame = Roact.createElement("Frame", {
		Position = UDim2.fromScale(0.025, 0.05),
		Size = UDim2.fromScale(0.95, 0.9),
		BackgroundTransparency = 1,
	}, {
		Roact.createElement("UIGridLayout", {
			CellPadding = UDim2.fromScale(0.05, 0.1),
			CellSize = UDim2.fromScale(0.2, 0.2), -- 4 Cell / Row
			HorizontalAlignment = "Center",
			VerticalAlignment = "Center",
		}),
		aoeButton,
		-- Defense
		maxLifeButton,
		lifeRegenButton,
		damageReductionButton,
		-- Utility
		mobilityButton,
		luckButton,
		increasedXpButton,
		increasedPickupRangeButton,
		-- Offense
		attackDamageButton,
		critChanceButton,
		critMultiButton,
		attackSpeedButton,
	}),
})
