local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local RoactRodux = require(ReplicatedStorage.Shared.RoactRodux)

-- Get Store
local RoduxStore = require(ReplicatedStorage.Shared.RoduxStore)
local Selectors = RoduxStore.Selectors

local player = Players.LocalPlayer

local resourceBar = require(ReplicatedStorage.Shared.Components.ResourceBar)

XpBar = RoactRodux.connect(function(state, props)
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

local lifeBar = resourceBar({
	-- Background
	position = UDim2.fromScale(0.35, 0.76),
	size = UDim2.fromScale(0.3, 0.025),
	value = 100,
	maxValue = 100,
	backgroundTransparency = 0.5,
	borderPixels = 5,
	-- Bar
	barColor = Color3.fromRGB(255, 10, 10),
	barTransparency = 0.2,
	-- Text
	resourceName = "Life",
})

local Bars = {
	XpBar = XpBar,
	lifeBar = lifeBar,
}

return Bars
