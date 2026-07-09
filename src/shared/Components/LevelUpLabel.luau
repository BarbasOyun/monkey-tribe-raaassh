local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Roact = require(ReplicatedStorage.Shared.Roact)
local Knit = require(ReplicatedStorage.Packages.Knit)

local textLabel = require(ReplicatedStorage.Shared.Components.TextLabel)

local LevelUpLabel = Roact.Component:extend("LevelUpLabel")

function LevelUpLabel:init()
	self:setState({
		isVisible = false,
		waitingLevels = 0,
	})
end

function LevelUpLabel:didMount()
	-- local StatService = Knit.GetService("StatService")

	-- self.levelUpConnection = StatService.LevelUp:Connect(function(patch)
	-- 	self:setState({
	-- 		isVisible = true,
	-- 		waitingLevels = patch.waitingLevel,
	-- 	})
	-- end)

	-- self.hideConnection = StatService.FinishPickingAugments:Connect(function(patch)
	-- 	self:setState({
	-- 		isVisible = false,
	-- 	})
	-- end)
end

function LevelUpLabel:willUnmount()
	-- if self.levelUpConnection then
	-- 	self.levelUpConnection:Disconnect()
	-- end

	-- if self.hideConnection then
	-- 	self.hideConnection:Disconnect()
	-- end
end

function LevelUpLabel:render()
	return Roact.createElement("Frame", {
		Position = UDim2.fromScale(0.0, 0.8),
		Size = UDim2.fromScale(0.15, 0.2),
		-- BackgroundColor3 = Color3.new(0.75, 0.75, 0.0),
		BackgroundTransparency = 1,
	}, {
		Label = self.state.isVisible and textLabel({
			text = "Lvl Up (A) +" .. self.state.waitingLevels,
			textColor = Color3.new(0, 0, 0),
			transparency = 0,
			backgroundColor = Color3.new(0.75, 0.75, 0.0),
			position = UDim2.fromScale(0.05, 0.05),
			size = UDim2.fromScale(0.9, 0.9),
			textStrokeTransparency = 1,
		}),
	})
end

return LevelUpLabel
