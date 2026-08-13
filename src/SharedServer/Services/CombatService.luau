local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Gears = require(ReplicatedStorage.Shared.Gears)

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

-- Get Knit
local Knit = require(ReplicatedStorage.Packages.Knit)

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

	humanoidsHit = Gears.FindUniqueHumanoids(hits, charactersBanned)

	return humanoidsHit
end

function CombatService.GetAttackPosition(player, weaponState)
	local userId = player.UserId
	local character = player.Character or player.CharacterAdded:Wait()
	local playerPos = character.HumanoidRootPart.CFrame.Position

	local attackPosition = weaponState.attackPoint.WorldCFrame.Position

	-- Aim toward Closet Enemy
	local closestEnemy = CombatState.playersClosestEnemy[userId]

	if closestEnemy then
		local targetPart = closestEnemy.Head
		local playerToEnemyNormal = vector.normalize(targetPart.CFrame.Position - playerPos)

		local hitDistance = vector.magnitude(weaponState.attackPoint.WorldCFrame.Position - playerPos)
		attackPosition = playerPos + playerToEnemyNormal * hitDistance
	end

	-- Adjust VFX pos
	if weaponState.attackVFX.Parent then
		local handle = weaponState.attackVFX.Parent.Parent
		local localPosition = handle.CFrame:PointToObjectSpace(attackPosition)
		weaponState.attackVFX.Parent.CFrame = CFrame.new(localPosition)
	end

	return attackPosition
end

-- Context = After Validation
function CombatService.AttackHit(player, playerStats, weaponState)
	-- warn("Attack Hit AOE = " .. playerStats.aoe)

	local character = player.Character or player.CharacterAdded:Wait()
	local attackPosition = CombatService.GetAttackPosition(player, weaponState)

	-- Hits Detection
	local hits = CombatService.HitsDetection(attackPosition, playerStats.aoe, CONSTANTS.WEAPON_HIT_PARAM, { character })

	local isCrit = rollCrit(playerStats)

	if #hits <= 0 then
		attackFeedback(weaponState, isCrit)
		return
	end

	-- Damage
	local damage = rollAttackDamage(playerStats, isCrit)

	for _, humanoid in pairs(hits) do
		EnemyService.DamageEnemy(player, humanoid.Parent:GetAttribute("EntityId"), humanoid, damage)
	end

	attackFeedback(weaponState, isCrit)
end

function CombatService.IncrementCombo(player, weaponData)
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

-- #endregion

-- #region ATTACK : START + ANIMATION

-- 1) Call = Client : Player Input OR Server : AutoTarget
-- 2) StartAttack = Server : Validation -> startAttack Event
-- 3) Animation = Clients
-- 4) Attack Result = Server

--- 2) Start a Player Attack (Server Validation)
function CombatService.StartAttack(state, player, playerStats, weaponState)
	-- Validation
	local userId = player.UserId
	local playerState = Selectors.PlayerState(state, userId)
	local isPlayerReady = playerState and playerState.state == CONSTANTS.PLAYER_STATES.playing

	local hasWeapon = next(weaponState) ~= nil

	if not hasWeapon or not isPlayerReady then
		return
	end

	-- TODO : Measure animations using frames instead of time
	-- Get Attack State
	local currentTime = tick()
	local lastAttack = CombatState.lastAttacks[userId]
	local attackDelta = currentTime - lastAttack -- Time between last attack and now
	local isAttackReady = attackDelta > playerStats.animationTime

	local function startAttack()
		-- print("Attack By : " .. player.Name .. " At : " .. tick())

		-- Setup Attack
		CombatState.lastAttacks[userId] = tick()
		CombatState.expectingAttack[userId] = true

		-- Start Animation
		local comboId = CombatState.comboIndexes[userId] + 1
		CombatService.Client.startAttack:Fire(player, comboId, playerStats.attackSpeed)

		-- TODO : StartAttackEvent
		-- player.Character.Humanoid.WalkSpeed *= 0.5
	end

	-- Input Buffer
	if not isAttackReady then
		local missingTime = playerStats.animationTime - attackDelta -- Time to wait before attacking
		local isBuffering = CombatState.attackBuffer[userId] ~= nil

		if missingTime <= 0.1 and not isBuffering then
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

--- 4) Attack Callback with server validation
--- After Animation
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

	-- Resets
	-- player.Character.Humanoid.WalkSpeed = playerStats.mobility

	CombatState.expectingAttack[userId] = nil
	CombatState.attackBuffer[userId] = nil

	if not weaponData then
		return
	end

	-- Attack Result
	CombatService.AttackHit(player, playerStats, weaponData)
	CombatService.IncrementCombo(player, weaponData)
end

--- Client (Player Input) Initial Call
function CombatService.Client:StartAttack(player)
	local state = Store:getState()
	local playerData = state.players[player.UserId]
	local playerStats, weaponData = Selectors.PlayerStats(playerData)

	CombatService.StartAttack(state, player, playerStats, weaponData)
end

-- #endregion

-- #region AUTO TARGET

--- Make a Player Attack Automatically Closest Enemy
function CombatService.AutoTarget(state, player)
	local userId = player.UserId
	local playerState = Selectors.PlayerState(state, userId)

	if not playerState then
		return
	end

	local closestEnemy = CombatState.playersClosestEnemy[userId]

	if not closestEnemy then
		return
	end

	-- Check closestEnemy Distance
	local targetDistance = MutState.playersDetections[userId][closestEnemy]

	local playerStats, weaponState = Selectors.PlayerStats(playerState)
	local isInRange = targetDistance <= playerStats.aoe * 2

	-- Start Attack
	if weaponState and isInRange then
		CombatService.StartAttack(state, player, playerStats, weaponState)
	end
end

--- Find Closest Enemy to a Player
function CombatService.FindClosestEnemies(player)
	local userId = player.UserId
	local playerDetection = MutState.playersDetections[userId]

	if not playerDetection then
		-- warn(player.Name .. " No player Detection")
		return
	end

	-- Find Closest Enemy
	local closestDistance = math.huge
	local closestEnemy = nil -- Model

	for enemy, distance in pairs(playerDetection) do
		if distance < closestDistance then
			closestDistance = distance
			closestEnemy = enemy
		end
	end

	CombatState.playersClosestEnemy[userId] = closestEnemy
end

-- #endregion

-- #region COMBAT SERVICE

local function combatServiceUpdate(state)
	for _, player in pairs(Players:GetPlayers()) do
		CombatService.FindClosestEnemies(player)
		CombatService.AutoTarget(state, player)
	end
end

local function setupPlayerService()
	PlayerService.PlayerAdded:Connect(function(player)
		local userId = player.UserId

		CombatState.lastAttacks[userId] = 0
		CombatState.comboIndexes[userId] = 0
	end)

	PlayerService.PlayerRemoved:Connect(function(player)
		local userId = player.UserId

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
