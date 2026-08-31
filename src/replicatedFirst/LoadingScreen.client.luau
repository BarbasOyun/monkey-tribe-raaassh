local ContentProvider = game:GetService("ContentProvider")
local players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local playerGui = players.LocalPlayer.PlayerGui

local loadingScreen = ReplicatedFirst.LoadingScreenObj:Clone()
loadingScreen.Parent = playerGui

local frame = loadingScreen.Frame
local loadingBarBg = frame.LoadingBarBg
local loadingText = loadingBarBg.LoadingText
local progressBar = frame.LoadingBarBg.LoadingBar

local assets = game:GetChildren()

for i, asset in pairs(assets) do
	loadingText.Text = "Loading " .. asset.Name .. "..."
	ContentProvider:PreloadAsync({ asset })

	local progress = i / #assets
	progressBar.Size = UDim2.fromScale(progress, 1)
end

loadingText.Text = "Loading Complete"

task.wait(1)
loadingScreen:Destroy()
