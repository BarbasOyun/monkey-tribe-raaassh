local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local PlayerGui = Players.LocalPlayer.PlayerGui

local RoactRodux = require(ReplicatedStorage.Shared.RoactRodux)
local Roact = require(ReplicatedStorage.Shared.Roact)

local Knit = require(ReplicatedStorage.Packages.Knit)
Knit.OnStart():await()

local PlayerController = Knit.GetController("PlayerController")
local player = Players.LocalPlayer

-- ROACT COMPONENTS

-- Image Component : ImageId, Pos, Size
local function Image(props)
	local position = props.position or UDim2.fromScale(0, 0)
	local size = props.size or UDim2.fromScale(0.2, 0.2)
	local imageLink = props.imageLink

	return Roact.createElement("ImageLabel", {
		Image = imageLink,
		Position = position,
		Size = size,
		BackgroundTransparency = 1,
	})
end

local bananaImageProp = {
	position = UDim2.fromScale(0.77, 0),
	size = UDim2.fromScale(0.08, 0.18),
	imageLink = "rbxassetid://92617984020165",
}

-- Bananas Count
local function Bananas(props)
	local position = props.position or UDim2.fromScale(0, 0)
	local size = props.size or UDim2.fromScale(0.2, 0.2)

	local text = props.text or "Bananas: "
	local bananas = props.bananas or 0

	return Roact.createElement("TextLabel", {
		Text = text .. bananas,
		Position = position,
		Size = size,
		BackgroundTransparency = 1,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(255, 255, 255),
	})
end

BananasMain = RoactRodux.connect(function(state, props)
	-- mapStateToProps
	local bananas = 0

	if state.players[player.UserId] then
		bananas = state.players[player.UserId].bananas
	end

	return {
		position = UDim2.fromScale(0.65, 0), -- X_pos = 0.75 - size.x / 2
		size = UDim2.fromScale(0.2, 0.2),
		bananas = bananas,
		text = "",
	}
end)(Bananas)

-- Score = Kills + Destruction
local function PlayerScore(props)
	local position = props.position or UDim2.new(0, 0, 0, 0)
	local size = props.size or UDim2.new(0.2, 0, 0.2, 0)

	local username = props.username or "Player"
	local text = props.text or "Score: "
	local score = props.score or 0

	return Roact.createElement("TextLabel", {
		Text = username .. text .. score,
		Position = position,
		Size = size,
		BackgroundTransparency = 1,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(255, 255, 255),
	})
end

PlayerScoreMain = RoactRodux.connect(function(state, props)
	-- mapStateToProps
	-- print("Local player UserID : ", Players.LocalPlayer.UserId)
	local score = 0
	local username = ""

	if state.players[player.UserId] then
		score = state.players[player.UserId].score
		username = state.players[player.UserId].username
	end

	return {
		position = UDim2.fromScale(0.45, 0), -- X_pos = 0.5 (half screen) - size.x / 2
		size = UDim2.fromScale(0.2, 0.2),
		username = username,
		score = score,
	}
end)(PlayerScore)

-- ScoreBoard
local function ScoreBoard(props)
	local players = props.players
	local playerScores = {}

	for userId, player in pairs(players) do
		playerScores[userId] = Roact.createElement(PlayerScore, {
			position = UDim2.new(0, 0, 0, 0),
			size = UDim2.new(1, 0, 0.2, 0),
			username = player.username,
			text = ": ",
			score = player.score,
		})
	end

	local playersFragment = Roact.createFragment(playerScores)
	local scoreList = Roact.createElement("Frame", {
		Position = UDim2.fromScale(0, 0.2),
		Size = UDim2.fromScale(1, 0.8),
		BackgroundTransparency = 1,
	}, { Layout = Roact.createElement("UIListLayout"), ListItems = playersFragment })

	return Roact.createElement("Frame", {
		Size = UDim2.fromScale(0.2, 0.7),
		BackgroundTransparency = 0.5,
	}, {
		Title = Roact.createElement("TextLabel", {
			Text = "Score Board",
			Size = UDim2.fromScale(1, 0.2),
			BackgroundTransparency = 0.75,
			TextScaled = true,
			TextColor3 = Color3.fromRGB(255, 255, 255),
		}),
		ScoreList = scoreList,
	})
end

ScoreBoard = RoactRodux.connect(function(state, props)
	-- mapStateToProps
	local players = state.players

	return {
		players = players,
	}
end)(ScoreBoard)

-- App
local app = Roact.createElement(RoactRodux.StoreProvider, {
	store = PlayerController.store,
}, {
	-- MainGUI
	Roact.createElement("ScreenGui", {}, {
		Bananas = Roact.createElement(BananasMain),
		BananaImage = Image(bananaImageProp),
		-- ScoreBoard = Roact.createElement(ScoreBoard),
	}),
})

Roact.mount(app, PlayerGui)
