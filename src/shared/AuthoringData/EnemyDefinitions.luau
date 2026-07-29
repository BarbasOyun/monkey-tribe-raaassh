local ReplicatedStorage = game:GetService("ReplicatedStorage")
local prefabs = ReplicatedStorage.Shared.Prefabs

local Enemies = {
	Dummy = 1,
	Robot = 2,
}

-- Endgame Setup = csv file
local EnemiesDefinitions = {
	{
		Name = "Dummy",
		MaxLife = 100,
	},
	{
		Name = "Robot",
		MaxLife = 100,
		Damage = 10,
		AttackSpeed = 1,
		MovementSpeed = 5,
	},
}

local EnemiesPrefabs = {
	prefabs.Enemies:FindFirstChild("Dummy"),
	prefabs.Enemies:FindFirstChild("Robot"),
}

local Archetypes = {
	{
		name = "Dummy",
		count = 100,
		setup = {},
		startIndex = 0,
		endIndex = 0,
		activeCount = 0,
	},
	{
		name = "Robot",
		count = 100,
		setup = {},
		startIndex = 0,
		endIndex = 0,
		activeCount = 0,
	},
}

local archetypesTotalSize = 200

return {
	Enemies = Enemies,
	EnemiesDefinitions = EnemiesDefinitions,
	EnemiesPrefabs = EnemiesPrefabs,
	Archetypes = Archetypes,
}
