local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local RoactRodux = require(ReplicatedStorage.Shared.RoactRodux)

-- Get Store
local RoduxStore = require(ReplicatedStorage.Shared.RoduxStore)
local Selectors = RoduxStore.Selectors

-- TODO : MutState
local player = Players.LocalPlayer
local playerGui = player.PlayerGui

-- Get Knit
local Knit = require(ReplicatedStorage.Packages.Knit)
Knit.OnStart():await()

local PlayerController = Knit.GetController("PlayerController")

-- Get Components
local resourceBar = require(ReplicatedStorage.Shared.Components.ResourceBar)
local textLabel = require(ReplicatedStorage.Shared.Components.TextLabel)

local LvlText = RoactRodux.connect(function(state, props)
	local currentLevel = 1

	local playerState = Selectors.PlayerState(state, player.UserId)

	if playerState then
		currentLevel = playerState.level
	end

	return {
		position = UDim2.fromScale(0.3, 0.8),
		size = UDim2.fromScale(0.05, 0.05),
		text = currentLevel,
	}
end)(textLabel)

local XpBar = RoactRodux.connect(function(state, props)
	local currentXp = 0
	local xpRequired = 10

	local playerState = Selectors.PlayerState(state, player.UserId)

	if playerState then
		currentXp = playerState.currentXp
		xpRequired = playerState.xpRequired
	end

	return {
		-- Background
		position = UDim2.fromScale(0.35, 0.8),
		size = UDim2.fromScale(0.3, 0.025),
		value = currentXp,
		maxValue = xpRequired,
		backgroundTransparency = 0.5,
		borderPixels = 5,
		-- Bar
		barColor = Color3.fromRGB(0, 157, 255),
		barTransparency = 0.2,
		-- Text
		resourceName = "Xp",
	}
end)(resourceBar)

local LifeBar = RoactRodux.connect(function(state, props)
	local maxLife = 100

	local playerState = Selectors.PlayerState(state, player.UserId)

	if playerState then
		maxLife = playerState.stats.maxLife
	end

	return {
		-- Background
		position = UDim2.fromScale(0.35, 0.76),
		size = UDim2.fromScale(0.3, 0.025),
		value = maxLife,
		maxValue = maxLife,
		backgroundTransparency = 0.5,
		borderPixels = 5,
		-- Bar
		barColor = Color3.fromRGB(255, 10, 10),
		barTransparency = 0.2,
		-- Text
		resourceName = "Life",
	}
end)(resourceBar)

--- Call after the UI is Created -> Update LifeBar visual
local function updateLifeBar()
	local mainGuiRef = playerGui.RoactTree.MainGui

	local lBar = mainGuiRef.LifeBar[2]
	local lifeText = mainGuiRef.LifeBar[1]

	PlayerController.LifeUpdate:Connect(function(state, life)
		local playerState = Selectors.PlayerState(state, player.UserId)

		if not playerState then
			return
		end

		local maxLife = playerState.stats.maxLife

		local percentage = life / maxLife
		lBar.Size = UDim2.fromScale(percentage, 1)

		lifeText.Text = "Life : " .. math.ceil(life) .. " / " .. maxLife
	end)
end

local Bars = {
	LvlText = LvlText,
	XpBar = XpBar,
	LifeBar = LifeBar,
	updateLifeBar = updateLifeBar,
}

return Bars
