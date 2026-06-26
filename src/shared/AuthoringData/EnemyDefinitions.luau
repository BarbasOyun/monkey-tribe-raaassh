local ReplicatedStorage = game:GetService("ReplicatedStorage")
local prefabs = ReplicatedStorage.Shared.Prefabs

local enemyStore = {
	Dummy = 1,
	Robot = 2,
}

-- Endgame Setup = csv file
local enemyDefinitions = {
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

local enemyPrefabs = {
	prefabs.Enemies:FindFirstChild("Dummy"),
	prefabs.Enemies:FindFirstChild("Robot"),
}

return {
	enemyStore = enemyStore,
	enemyDefinitions = enemyDefinitions,
	enemyPrefabs = enemyPrefabs,
}
