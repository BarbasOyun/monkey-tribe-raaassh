local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Gears = require(ReplicatedStorage.Shared.Gears)
local Knit = require(ReplicatedStorage.Packages.Knit)

-- Get Constants
local CONSTANTS = require(ServerScriptService.SharedServer.Constants)

-- Get Rodux Store
local RoduxStore = require(ReplicatedStorage.Shared.RoduxStore)
local Store = RoduxStore.Store
local Selectors = RoduxStore.Selectors
-- local StoreActions = RoduxStore.Actions

-- Get Mutable State
local MutState = require(ServerScriptService.SharedServer.MutableState)
local CombatState = MutState.CombatState

-- Get Other Services
local PlayerService
local EnemyService
local ItemService

local CombatService = Knit.CreateService({
	Name = "CombatService",
	Client = {
		startAttack = Knit.CreateSignal(),
	},
})

-- #region HIT DETECTION + DMG

local function attackFeedback(weaponData, isCrit)
	-- VFX
	weaponData.attackVFX:Emit(5)

	-- SFX
	if isCrit then
		Gears.SafePlaySound(weaponData.sounds.crit)
		return
	end

	Gears.SafePlaySound(weaponData.sounds.slash)
end

local function rollCrit(playerStats)
	local isCrit = false
	local critRoll = math.random(0, 100)
	-- print("Crit roll : " .. critRoll .. " Crit Chance : " .. playerStats.critChance)

	if critRoll <= playerStats.critChance then
		isCrit = true
	end

	return isCrit
end

local function rollAttackDamage(playerStats, isCrit)
	-- Attack Damage
	local damage = playerStats.attackDamage

	if isCrit then
		damage *= Gears.IncreaseToMultiplier(playerStats.critMultiplier)
		-- print("Crit " .. damage)
	end

	return damage
end

-- Return a table of every unique humanoid in a Sphere
function CombatService.HitsDetection(position, radius, param, charactersBanned)
	local hits = workspace:GetPartBoundsInRadius(position, radius, param)
	local humanoidsHit = {} -- Unique Humanoids

	-- Debug HitZone
	Gears.ExecuteFor(0.5, function()
		Gears.DrawSphere(position, radius)
	end)

	if #hits <= 0 then
		return humanoidsHit
	end

	for _, hit in pairs(hits) do
		-- print("Hit Part: " .. hit.Name)
		local humanoid = Gears.FindHumanoidFromPart(hit)

		if not humanoid or table.find(humanoidsHit, humanoid) or table.find(charactersBanned, humanoid.Parent) then
			continue
		end

		-- Enemy Hit
		table.insert(humanoidsHit, humanoid)
	end

	return humanoidsHit
end

local function getAttackPosition(player, weaponData)
	local userId = player.UserId
	local character = player.Character or player.CharacterAdded:Wait()
	local playerPos = character.HumanoidRootPart.CFrame.Position

	local attackPosition = weaponData.attackPoint.WorldCFrame.Position

	-- Aim toward Closet Enemy
	local closestEnemy = CombatState.playersClosestEnemy[userId]

	if closestEnemy then
		local targetPart = closestEnemy.Head
		local playerToEnemyNormal = vector.normalize(targetPart.CFrame.Position - playerPos)

		local hitDistance = vector.magnitude(weaponData.attackPoint.WorldCFrame.Position - playerPos)
		attackPosition = playerPos + playerToEnemyNormal * hitDistance
	end

	-- Adjust VFX pos
	local localPosition = weaponData.attackVFX.Parent.Parent.CFrame:PointToObjectSpace(attackPosition)
	weaponData.attackVFX.Parent.CFrame = CFrame.new(localPosition)

	return attackPosition
end

-- Context = After Validation
local function attackHit(player, playerStats, weaponData)
	-- warn("Attack Hit AOE = " .. playerStats.aoe)

	local character = player.Character or player.CharacterAdded:Wait()
	local attackPosition = getAttackPosition(player, weaponData)

	-- Hits Detection
	local hits = CombatService.HitsDetection(attackPosition, playerStats.aoe, CONSTANTS.WEAPON_HIT_PARAM, { character })

	local isCrit = rollCrit(playerStats)

	if #hits <= 0 then
		attackFeedback(weaponData, isCrit)
		return
	end

	-- Damage
	local damage = rollAttackDamage(playerStats, isCrit)

	for _, humanoid in pairs(hits) do
		EnemyService.DamageEnemy(player, humanoid.Parent:GetAttribute("EntityId"), humanoid, damage)
	end

	attackFeedback(weaponData, isCrit)
end

-- #endregion

-- #region ATTACK : START + ANIMATION
-- 1) Client : Player Input -> Ask Server to Attack
-- 2) Server : Validation + Setup Expected Attack -> startAttack Event
-- 3) Clients : Animation
-- 4) Server : Attack Callback + validation

local function incrementCombo(player, weaponData)
	local userId = player.UserId
	CombatState.comboIndexes[userId] = (CombatState.comboIndexes[userId] + 1) % weaponData.maxCombo

	-- Reset Combo Index -> after 2 sec of not Attacking
	-- if playerStat.comboReset then
	-- 	task.cancel(playerStat.comboReset)
	-- end

	-- playerStat.comboReset = task.delay(2, function()
	-- 	print("Combo Reset")
	-- 	playerStat.comboIndex = 0
	-- end)
end

-- 4) Attack Callback with server validation
-- After Animation
function CombatService.Client:AttackCallback(player)
	local userId = player.UserId
	local state = Store:getState()
	local playerState = state.players[userId]

	local playerStats = playerState.stats
	local weaponData = playerState.weaponData

	local currentTime = tick()
	local attackDelta = currentTime - CombatState.lastAttacks[userId] -- Time between last attack and now

	-- Validation -> Using setup on step 2)
	if not CombatState.expectingAttack[userId] and attackDelta >= playerStats.animationTime then
		warn("Unexpected AttackHit from player: " .. player.Name)
		return
	end

	-- Reset Player speed
	-- player.Character.Humanoid.WalkSpeed = playerStats.mobility

	CombatState.expectingAttack[userId] = nil
	CombatState.attackBuffer[userId] = nil

	if not weaponData then
		return
	end

	attackHit(player, playerStats, weaponData)
	incrementCombo(player, weaponData)
end

-- 2) Server Validation + Setup Expected Attack
-- Player is asking to Attack using their Weapon
local function attackValidation(player, playerStats, weaponData)
	if not playerStats or not weaponData then
		-- warn("No playerStats or weaponData")
		return
	end

	local userId = player.UserId

	-- TODO : Measure animations using frames instead of time
	local currentTime = tick()
	local attackDelta = currentTime - CombatState.lastAttacks[userId] -- Time between last attack and now
	local isAttackReady = attackDelta > playerStats.animationTime

	local function startAttack()
		-- print("Attack By : " .. player.Name .. " At : " .. tick())
		CombatState.lastAttacks[userId] = tick()
		CombatState.expectingAttack[userId] = true
		-- player.Character.Humanoid.WalkSpeed *= 0.5

		CombatService.Client.startAttack:Fire(player, CombatState.comboIndexes[userId] + 1, playerStats.attackSpeed)
	end

	if not isAttackReady then
		-- Input Buffer
		local missingTime = playerStats.animationTime - attackDelta -- Time to wait before attacking

		if missingTime <= 0.1 and CombatState.attackBuffer[userId] == nil then
			-- print("Attack Buffer: " .. player.Name)
			CombatState.attackBuffer[userId] = true -- Lock Input Buffer
			task.delay(missingTime, function()
				startAttack()
			end)
		end

		return
	end

	-- print("Attack non buffer: " .. player.Name)
	startAttack()
end

function CombatService.Client:AttackValidation(player)
	local state = Store:getState()
	local playerData = state.players[player.UserId]
	local playerStats, weaponData = Selectors.PlayerStats(playerData)

	attackValidation(player, playerStats, weaponData)
end

-- #endregion

-- #region AUTO TARGET

local function findClosestEnemies()
	for _, player in pairs(Players:GetPlayers()) do
		local userId = player.UserId
		local playerDetection = MutState.playersDetections[userId]

		if not playerDetection then
			-- warn(player.Name .. " No player Detection")
			return
		end

		-- Find Closest Enemy
		local closestDistance = math.huge
		local closestEnemy = nil

		for enemy, distance in pairs(playerDetection) do
			if distance < closestDistance then
				closestDistance = distance
				closestEnemy = enemy
			end
		end

		CombatState.playersClosestEnemy[userId] = closestEnemy
	end
end

-- Make Players AutoTarget and Attack Closest Enemy
local function autoTarget(state)
	for _, player in pairs(Players:GetPlayers()) do
		local userId = player.UserId
		local closestEnemy = CombatState.playersClosestEnemy[userId]

		if not closestEnemy then
			return
		end

		local character = player.Character or player.CharacterAdded:Wait()
		local playerPos = character.HumanoidRootPart.CFrame.Position

		-- Check closestDistance
		-- > StartAttack
		local targetDistance = vector.magnitude(closestEnemy:GetPivot().Position - playerPos)

		local playerState = Selectors.PlayerState(state, userId)

		if not playerState then
			continue
		end

		local playerStats, weaponData = Selectors.PlayerStats(playerState)
		local isInRange = targetDistance <= playerStats.aoe * 2

		if weaponData and isInRange then
			attackValidation(player, playerStats, weaponData)
		end
	end
end

-- #endregion

-- #region COMBAT SERVICE

local function combatServiceUpdate(state)
	findClosestEnemies()
	autoTarget(state)
end

local function setupPlayerService()
	PlayerService.PlayerAdded:Connect(function(userId)
		CombatState.lastAttacks[userId] = 0
		CombatState.comboIndexes[userId] = 0
	end)

	PlayerService.PlayerRemoved:Connect(function(userId)
		-- Cleanup
		CombatState.lastAttacks[userId] = nil
		CombatState.comboIndexes[userId] = nil
		CombatState.expectingAttack[userId] = nil
		CombatState.attackBuffer[userId] = nil
		CombatState.comboReset[userId] = nil
	end)
end

function CombatService:KnitInit()
	print("CombatService Init")

	-- self.Client.startAttack:Connect(function(player)
	-- 	attackValidation(player)
	-- end)

	-- self.Client.finishAttack:Connect(function(player)
	-- 	attackCallback(player)
	-- end)
end

function CombatService:KnitStart()
	PlayerService = Knit.GetService("PlayerService")
	EnemyService = Knit.GetService("EnemyService")
	ItemService = Knit.GetService("ItemService")

	setupPlayerService()

	ItemService.UnequipWeapon:Connect(function(player)
		local userId = player.UserId

		CombatState.expectingAttack[userId] = nil
		CombatState.comboIndexes[userId] = 0
		CombatState.comboReset[userId] = nil
	end)

	PlayerService.StateUpdate:Connect(combatServiceUpdate)
end

-- #endregion

return CombatService
