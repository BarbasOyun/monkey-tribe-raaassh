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
local PlayerServiceState = MutState.PlayerServiceState

-- Knit
local Knit = require(ReplicatedStorage.Packages.Knit)

local PlayerService, EnemyService, LevelService, ItemService

local CombatService = Knit.CreateService({
	Name = "CombatService",
	Client = {
		startAttack = Knit.CreateSignal(),
	},
})

-- #region COMBAT SERVICE

function CombatService:KnitInit()
	print("CombatService Init")
end

function CombatService:KnitStart()
	PlayerService = Knit.GetService("PlayerService")
	EnemyService = Knit.GetService("EnemyService")
	LevelService = Knit.GetService("LevelService")
	ItemService = Knit.GetService("ItemService")

	CombatService.SetupPlayerService()

	-- Reset Attack State OnUnequip
	ItemService.UnequipWeapon:Connect(function(player)
		local userId = player.UserId

		CombatState.expectingAttack[userId] = nil
		CombatState.comboIndexes[userId] = 0
		CombatState.comboReset[userId] = nil
	end)

	PlayerService.StateUpdate:Connect(CombatService.CombatServiceUpdate)
end

function CombatService.CombatServiceUpdate(state, dt)
	for _, player in pairs(Players:GetPlayers()) do
		CombatService.FindClosestEnemy(player)
		CombatService.AutoTarget(state, player)
	end

	CombatService.BufferUpdate(state, dt)
end

function CombatService.SetupPlayerService()
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

-- #endregion

-- #region HIT DETECTION + DMG

--- Return a table of every unique humanoid in a Sphere
function CombatService.HitsDetection(position, radius, param, charactersBanned)
	local hits = workspace:GetPartBoundsInRadius(position, radius, param)
	local humanoidsHit = {} -- Unique Humanoids
	local buildingsHit = {} -- Parts

	-- Debug HitZone
	-- Gears.ExecuteFor(0.5, function()
	-- 	Gears.DrawSphere(position, radius)
	-- end)

	if #hits <= 0 then
		return humanoidsHit, buildingsHit
	end

	for _, hit in pairs(hits) do
		local humanoid = Gears.FindHumanoidFromPart(hit)

		-- Hit Building
		if not humanoid then
			table.insert(buildingsHit, hit)
			continue
		end

		-- Hit Humanoid
		local isInBanList = charactersBanned and table.find(charactersBanned, humanoid.Parent)
		local isValid = humanoid and not table.find(humanoidsHit, humanoid) and not isInBanList

		if not isValid then
			continue
		end

		table.insert(humanoidsHit, humanoid)
	end

	return humanoidsHit, buildingsHit
end

-- Context = After Validation
function CombatService.AttackHit(player, playerStats, weaponState)
	-- warn("Attack Hit AOE = " .. playerStats.aoe)

	local character = player.Character or player.CharacterAdded:Wait()
	local attackPosition = CombatService.GetAttackPosition(player, weaponState)

	-- Hits Detection
	local banList = { character }
	local humanoidsHit, buildingsHit =
		CombatService.HitsDetection(attackPosition, playerStats.aoe, CombatState.weaponHitParam, banList)

	local isCrit = CombatService.RollCrit(playerStats)
	local hasHitBuilding = #buildingsHit > 0

	if #humanoidsHit <= 0 and #buildingsHit <= 0 then
		CombatService.AttackFeedback(weaponState, isCrit, hasHitBuilding)
		return
	end

	-- Damage
	local damage = CombatService.RollAttackDamage(playerStats, isCrit)

	-- Damage Building
	for i = 1, #buildingsHit do
		local building = buildingsHit[i]
		-- LevelService.DamageBuilding(building, damage)
		LevelService.DestroyBuilding(building)
	end

	-- Damage Humanoids
	for _, humanoid in pairs(humanoidsHit) do
		local entityID = humanoid.Parent:GetAttribute("EntityId")
		EnemyService.DamageEnemy(player, entityID, humanoid, damage)
	end

	CombatService.AttackFeedback(weaponState, isCrit, hasHitBuilding)
end

function CombatService.AttackFeedback(weaponData, isCrit, hasHitBuilding)
	-- VFX
	weaponData.attackVFX:Emit(5)

	-- SFX
	if isCrit then
		Gears.SafePlaySound(weaponData.sounds.crit)
		return
	end

	if hasHitBuilding then
		Gears.SafePlaySound(weaponData.sounds.buildingHit)
		return
	end

	Gears.SafePlaySound(weaponData.sounds.slash)
end

function CombatService.RollCrit(playerStats)
	local isCrit = false
	local critRoll = math.random(0, 100)
	-- print("Crit roll : " .. critRoll .. " Crit Chance : " .. playerStats.critChance)

	if critRoll <= playerStats.critChance then
		isCrit = true
	end

	return isCrit
end

function CombatService.RollAttackDamage(playerStats, isCrit)
	-- Attack Damage
	local damage = playerStats.attackDamage

	if isCrit then
		damage *= Gears.IncreaseToMultiplier(playerStats.critMultiplier)
		-- print("Crit " .. damage)
	end

	return damage
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

function CombatService.StartAttackPlayer(player, attackSpeed)
	local userId = player.UserId

	-- Validation
	local comboIndex = CombatState.comboIndexes[userId]

	if not comboIndex then
		warn("Start Attack Validation failed")
		return
	end

	-- print("Attack By : " .. player.Name .. " At : " .. tick())

	CombatState.attackBuffer[userId] = nil

	-- Setup Attack
	CombatState.lastAttacks[userId] = tick()
	CombatState.expectingAttack[userId] = true

	-- Start Animation
	local comboId = comboIndex + 1
	CombatService.Client.startAttack:Fire(player, comboId, attackSpeed)
end

--- 2) Start a Player Attack (Server Validation)
function CombatService.StartAttack(state, player, playerStats, weaponState)
	-- Validation
	local userId = player.UserId
	local playerState = Selectors.PlayerState(state, userId)

	local isPlayerReady = playerState and playerState.state == CONSTANTS.PLAYER_STATES.playing
	local hasWeapon = next(weaponState) ~= nil

	local isValid = hasWeapon and isPlayerReady
	if not isValid then
		return
	end

	-- Get Attack State
	local currentTime = tick()
	local lastAttack = CombatState.lastAttacks[userId]
	local attackDelta = currentTime - lastAttack -- Time between last attack and now
	local isAttackReady = attackDelta > playerStats.animationTime

	-- Input Buffer
	if not isAttackReady then
		local missingTime = playerStats.animationTime - attackDelta -- Time to wait before attacking
		local isBuffering = CombatState.attackBuffer[userId] ~= nil

		if missingTime <= 0.1 and not isBuffering then
			-- print("Attack Buffer: " .. player.Name)
			CombatState.attackBuffer[userId] = missingTime -- Lock Input Buffer
			-- task.delay(missingTime, function() -- FIXME : Perf
			-- 	startAttack()
			-- end)
		end

		return
	end

	-- print("Attack non buffer: " .. player.Name)
	CombatService.StartAttackPlayer(player, playerStats.attackSpeed)
end

function CombatService.BufferUpdate(state, dt)
	for userId, missingTime in pairs(CombatState.attackBuffer) do
		missingTime -= dt

		if missingTime <= 0 then
			local player = Players:GetPlayerByUserId(userId)
			local playerState = state.players[userId]
			local playerStats = playerState.stats

			CombatService.StartAttackPlayer(player, playerStats.attackSpeed)
		end
	end
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

	-- Reset Attack State
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

--- Get the Range at which a Player can Hit a Target
function CombatService.PlayerRange(playerStats)
	assert(playerStats, "Player Stats = nil")
	return playerStats.aoe * 2
end

--- Make a Player Attack Automatically Closest Enemy
function CombatService.AutoTarget(state, player)
	-- Validation
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
	local targetDistance = PlayerServiceState.playersDetections[userId][closestEnemy]

	local playerStats, weaponState = Selectors.PlayerStats(playerState)
	local isInRange = targetDistance <= CombatService.PlayerRange(playerStats)

	-- Start Attack
	if weaponState and isInRange then
		CombatService.StartAttack(state, player, playerStats, weaponState)
	end
end

--- Find Closest Enemy to a Player
function CombatService.FindClosestEnemy(player)
	local userId = player.UserId
	local playerDetection = PlayerServiceState.playersDetections[userId]

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

--- Make a Player Attack Automatically Closest Building
function CombatService.AutoTargetBuildings(state, player)
	-- Validation
	local userId = player.UserId
	local playerState = Selectors.PlayerState(state, userId)

	if not playerState then
		return
	end

	local closestBuilding = CombatState.playersClosestBuilding[userId]

	if not closestBuilding then
		return
	end

	-- Check closestEnemy Distance
	local targetDistance = PlayerServiceState.buildingsDetections[userId][closestBuilding]

	local playerStats, weaponState = Selectors.PlayerStats(playerState)
	local isInRange = targetDistance <= CombatService.PlayerRange(playerStats)

	-- Start Attack
	if weaponState and isInRange then
		CombatService.StartAttack(state, player, playerStats, weaponState)
	end
end

--- Find Closest Building to a Player
function CombatService.FindClosestBuilding(player)
	local userId = player.UserId
	local buildingDetection = PlayerServiceState.buildingsDetections[userId]

	if not buildingDetection then
		-- warn(player.Name .. " No player Detection")
		return
	end

	-- Find Closest Enemy
	local closestDistance = math.huge
	local closestBuilding = nil -- Model

	for building, distance in pairs(buildingDetection) do
		if distance < closestDistance then
			closestDistance = distance
			closestBuilding = building
		end
	end

	CombatState.playersClosestBuilding[userId] = closestBuilding
end

-- #endregion

return CombatService
