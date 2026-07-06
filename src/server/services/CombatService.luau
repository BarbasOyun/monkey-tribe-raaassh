local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Gears = require(ReplicatedStorage.Shared.Gears)
local Knit = require(ReplicatedStorage.Packages.Knit)

-- Get Rodux Store
local RoduxStore = require(ReplicatedStorage.Shared.RoduxStore)
local store = RoduxStore.Store
-- local storeActions = RoduxStore.Actions

local CombatService = Knit.CreateService({
	Name = "CombatService",
	Client = {
		startAttack = Knit.CreateSignal(), -- Func
		finishAttack = Knit.CreateSignal(),
	},
})

local PlayerService = nil
local EnemyService = nil

local weaponHitParam = OverlapParams.new()
weaponHitParam.FilterType = Enum.RaycastFilterType.Include
weaponHitParam.FilterDescendantsInstances = { workspace.WeaponHit }
weaponHitParam.MaxParts = 100

-- Per Player Combat Data
local expectingAttack = {}
local attackBuffer = {}
local lastAttacks = {}
local comboIndexes = {} -- For Weapon Animation
local comboReset = {}

-- ATTACK STEPS
-- 1) Client : Player Input -> Ask Server to Attack
-- 2) Server : Validation + Setup Expected Attack -> startAttack Event
-- 3) Clients : Animation
-- 4) Server : Attack Callback + validation
-- 5) Server : HitDetection + Damage + Feeback -> finishAttack Event

local function attackFeedback(weaponData, isCrit)
	-- VFX
	weaponData.attackVFX:Emit(5)

	-- Attack SFX
	if isCrit then
		Gears.safePlaySound(weaponData.sounds.crit)
		return
	end

	Gears.safePlaySound(weaponData.sounds.slash)
end

-- 5) HitDetection + Damage + Feeback
-- Context = After Validation
local function attackHit(player, playerStats, weaponData)
	-- Damage
	local damage = playerStats.attackDamage
	local isCrit = false
	local critRoll = math.random(0, 100)
	-- print("Crit roll : " .. critRoll .. " Crit Chance : " .. playerStats.critChance)

	if critRoll <= playerStats.critChance then
		damage *= Gears.increaseToMultiplier(playerStats.critMultiplier)
		-- print("Crit " .. damage)
		weaponData.sounds.crit:Play()
		isCrit = true
	end

	-- Hit Detection
	local attackPosition = weaponData.attackPoint.WorldCFrame.Position

	local hits = workspace:GetPartBoundsInRadius(attackPosition, playerStats.aoe, weaponHitParam)
	local humanoidsHit = {} -- Avoid hitting the same Enemy twice

	-- Debug HitZone
	Gears.executeFor(0.5, function()
		Gears.drawSphere(attackPosition, playerStats.aoe)
	end)

	for _, hit in ipairs(hits) do
		-- print("Hit Part: " .. hit.Name)
		local humanoid = Gears.FindHumanoidFromPart(hit)

		if not humanoid or humanoid.Parent == player.Character or humanoidsHit[humanoid] == true then
			continue
		end

		-- Enemy Hit
		humanoidsHit[humanoid] = true

		-- local impulseDirection = humanoid.Parent.PrimaryPart.CFrame.Position
		-- 	- player.Character.PrimaryPart.CFrame.Position
		-- humanoid.Parent:ApplyImpulse(impulseDirection * 50) -- TODO : Per Weapon

		EnemyService:DamageEnemy(player, humanoid, damage)
		-- print(player.Name .. " Hit : " .. humanoid.Parent.Name)
	end

	-- Feedback
	attackFeedback(weaponData, isCrit)
end

-- 4) Attack Callback with server validation
-- After Animation
local function incrementCombo(player, weaponData)
	local userId = player.UserId
	comboIndexes[userId] = (comboIndexes[userId] + 1) % weaponData.maxCombo

	-- Reset Combo Index -> after 2 sec of not Attacking
	-- if playerStat.comboReset then
	-- 	task.cancel(playerStat.comboReset)
	-- end

	-- playerStat.comboReset = task.delay(2, function()
	-- 	print("Combo Reset")
	-- 	playerStat.comboIndex = 0
	-- end)
end

local function attackCallback(player)
	local userId = player.UserId
	local state = store:getState()

	local playerStats = state.players[userId].stats
	local weaponData = state.players[userId].weaponData

	local currentTime = tick()
	local attackDelta = currentTime - lastAttacks[userId] -- Time between last attack and now

	-- Validation -> Using setup on step 2)
	if not expectingAttack[userId] and attackDelta >= playerStats.animationTime then
		warn("Unexpected AttackHit from player: " .. player.Name)
		return
	end

	-- Reset Player speed
	player.Character.Humanoid.WalkSpeed = playerStats.mobility
	expectingAttack[userId] = nil
	attackBuffer[userId] = nil

	if not weaponData then
		return
	end

	attackHit(player, playerStats, weaponData)
	incrementCombo(player, weaponData)
end

-- 2) Server Validation + Setup Expected Attack
-- Player is asking to Attack using their Weapon
local function attackValidation(player)
	local userId = player.UserId
	local state = store:getState()

	local playerStats = state.players[userId].stats
	local weaponData = state.players[userId].weaponData

	if not playerStats or not weaponData then
		-- warn("No playerStats or weaponData")
		return
	end

	-- TODO : Measure animations using frames instead of time
	local currentTime = tick()
	local attackDelta = currentTime - lastAttacks[userId] -- Time between last attack and now
	local isAttackReady = attackDelta > playerStats.animationTime

	local function startAttack()
		-- print("Attack By : " .. player.Name .. " At : " .. tick())
		lastAttacks[userId] = tick()
		expectingAttack[userId] = true
		player.Character.Humanoid.WalkSpeed *= 0.5 -- TODO : Half MS using stats instead

		CombatService.Client.startAttack:Fire(player, comboIndexes[userId] + 1, playerStats.attackSpeed)
	end

	if not isAttackReady then
		-- Input Buffer
		local missingTime = playerStats.animationTime - attackDelta -- Time to wait before attacking

		if missingTime <= 0.1 and attackBuffer[userId] == nil then
			-- print("Attack Buffer: " .. player.Name)
			attackBuffer[userId] = true -- Lock Input Buffer
			task.delay(missingTime, function()
				startAttack()
			end)
		end

		return
	end

	-- print("Attack non buffer: " .. player.Name)
	startAttack()
end

-- COMBAT SERVICE

function CombatService:KnitInit()
	print("CombatService Init")

	self.Client.startAttack:Connect(function(player)
		attackValidation(player)
	end)

	self.Client.finishAttack:Connect(function(player)
		attackCallback(player)
	end)
end

function CombatService:KnitStart()
	PlayerService = Knit.GetService("PlayerService")
	EnemyService = Knit.GetService("EnemyService")
	local ItemService = Knit.GetService("ItemService")

	PlayerService.PlayerAdded:Connect(function(userId)
		lastAttacks[userId] = 0
		comboIndexes[userId] = 0
	end)

	PlayerService.PlayerRemoved:Connect(function(userId)
		-- Cleanup
		lastAttacks[userId] = nil
		comboIndexes[userId] = nil
		expectingAttack[userId] = nil
		attackBuffer[userId] = nil
		comboReset[userId] = nil
	end)

	ItemService.UnequipWeapon:Connect(function(player)
		local userId = player.UserId

		expectingAttack[userId] = nil
		comboIndexes[userId] = 0
		comboReset[userId] = nil
	end)
end

return CombatService
