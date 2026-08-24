-- Define Enemies Stats

local Enemies = {
	Dummy = 1,
	Robot = 2,
}

local EnemiesStats = {
	{
		Name = "Dummy",
		MaxLife = 100,
	},
	{
		Name = "Robot",
		MaxLife = 100,
		Damage = 3,
		AttackSpeed = 1,
		Range = 9,
		MovementSpeed = 5,
	},
}

local EnemyDefinitions = {
	Enemies = Enemies,
	EnemiesStats = EnemiesStats,
}

return EnemyDefinitions
