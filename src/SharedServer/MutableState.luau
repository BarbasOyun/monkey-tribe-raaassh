-- Dynamic State
-- > Data is Mutable != RoduxStore
-- For High Frequency Data eg ECS Components
-- This Data might be sent to the Rodux Store in the Throttled Update -> Use Commands Buffer

local combatState = {
	playersClosestEnemy = {},
	expectingAttack = {},
	attackBuffer = {},
	lastAttacks = {},
	comboIndexes = {}, -- For Weapon Animation
	comboReset = {},
}

local statState = {
	totalXp = 0, -- Add to joining players
	positionStart = {},
	playersLife = {},
	lifeRegenUpdates = {},
}

local MutState = {
	frameCount = 0,
	playersDetections = {}, -- TODO : Flatten -> use playersDetectionCount
	combatState = combatState,
	statState = statState,
}

return MutState
