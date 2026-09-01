-- Item System :
-- Item = data
-- ItemModel = 3D Model

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Gears = require(ReplicatedStorage.Shared.Gears)

-- Get Constants
local CONSTANTS = require(ServerScriptService.SharedServer.Constants)

local itemTypes = CONSTANTS.itemTypes
local CategoryStore = CONSTANTS.CategoryStore
local CategoryDefinitions = CONSTANTS.CategoryDefinitions
local CategoryRegistries = CONSTANTS.CategoryRegistries

local statsDefinition = require(ReplicatedStorage.Shared.AuthoringData.StatsDefinitions)

-- Get State
local RoduxStore = require(ReplicatedStorage.Shared.RoduxStore)
local Store = RoduxStore.Store
local StoreActions = RoduxStore.Actions

-- Get MutState
local MutState = require(ServerScriptService.SharedServer.MutableState)
local ItemServiceState = MutState.ItemServiceState
local EcsState = MutState.EcsState

-- Knit
local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages._Index["sleitnick_signal@1.5.0"].signal)

local PlayerService, RpgService, EcsService, PoolService

local ItemService = Knit.CreateService({
	Name = "ItemService",
	EquipWeapon = Signal.new(),
	UnequipWeapon = Signal.new(),
	Client = {
		GetOrb = Knit.CreateSignal(),
		EquipWeapon = Knit.CreateSignal(),
		UnequipWeapon = Knit.CreateSignal(),
	},
})

function ItemService:KnitInit()
	print("ItemService Init")
end

function ItemService:KnitStart()
	PlayerService = Knit.GetService("PlayerService")
	RpgService = Knit.GetService("RpgService")
	EcsService = Knit.GetService("EcsService")
	PoolService = Knit.GetService("PoolService")

	PlayerService.StateUpdate:Connect(function(state, dt)
		ItemService.LootMovementUpdate()
	end)
end

-- #region ITEMS LOGIC

local smallXpOrbOnUse = function(player, itemDefinition, itemModel, entityID)
	-- print("Add Small XP Orb to : " .. player.Name)
	RpgService.AddXpToAllPlayers(itemDefinition.xp)
	ItemService.Client.GetOrb:Fire(player) -- SFX Feedback
	PoolService.Disable(entityID)
end

local bananaOnUse = function(player, itemDefinition, itemModel, entityID)
	local bananas = itemDefinition.banana
	-- print("Add Banana to all players : " .. bananas)
	PlayerService.AddCurrencyToAllPlayers(CONSTANTS.CURRENCIES.bananas, bananas)
	ItemService.Client.GetOrb:Fire(player)
	PoolService.Disable(entityID)
end

local stickOnUse = function(player, itemDefinition, itemModel, entityID)
	print("Add Stick to : " .. player.Name)
	PlayerService.AddCurrencyToPlayer(player, CONSTANTS.CURRENCIES.sticks, itemDefinition.stick)
	ItemService.Client.GetOrb:Fire(player)
	PoolService.Disable(entityID)
end

local stoneOnUse = function(player, itemDefinition, itemModel)
	print("Add Stone to : " .. player.Name)
	PlayerService.IncrementStone(player.UserId, itemDefinition.stone)
	ItemService.Client.GetOrb:Fire(player)
	ItemService.RemoveGroundItem(itemModel)
end

local usablesLogicDefinition = {
	smallXpOrbOnUse,
	bananaOnUse,
	stickOnUse,
	stoneOnUse,
}

-- #endregion

-- #region UTILS

--- Get an Item's Definition using GlobalId
function ItemService.GetItemDefinition(globalId: number)
	-- warn("Get Item Definition Global ID = " .. globalId)
	local count = 0

	for i = 1, #CategoryDefinitions do
		local category = CategoryDefinitions[i]
		local threshold = count + #category

		if globalId <= threshold then
			local index = globalId - count
			local definition = category[index]

			-- warn(definition)
			return definition
		end

		count += threshold
	end

	return nil
end

--- Get an Item's GlobalId
function ItemService.GetGlobalId(category, id)
	-- TODO
end

function ItemService.GetModelInfo(itemModel)
	local entityID = itemModel:GetAttribute("EntityId")

	local DefinitionStorage = EcsService.GetStorage(CONSTANTS.EcsStorages.definition)
	local _typeID, definitionID = DefinitionStorage.GetDefinition(entityID)

	return entityID, definitionID
end

-- #endregion

-- #region CREATE ITEMS

--- Create a new item + OnSpawn
function ItemService.CreateItem(definitionID, itemModel)
	-- ECS Item Setup
	local entityId = EcsService.CreateEntity()

	local spawnCtx = {
		entityId = entityId,
		definitionId = definitionID,
		model = itemModel,
	}

	ItemService.SetupItemModel(spawnCtx)

	return entityId
end

--- Model + OnSpawn
function ItemService.SetupItemModel(spawnCtx)
	local entityId = spawnCtx.entityId
	local itemModel = spawnCtx.model

	-- Add GameObject Component
	local GameObjectStorage = EcsState.storages[CONSTANTS.EcsStorages.gameObject]
	GameObjectStorage.AddComponentToEntity(entityId, itemModel)

	ItemService.ItemOnSpawn(spawnCtx)
end

--- Setup an item and its model
function ItemService.ItemOnSpawn(spawnCtx)
	local entityId = spawnCtx.entityId
	local definitionId = spawnCtx.definitionId

	-- Add Definition Component
	local DefinitionStorage = EcsState.storages[CONSTANTS.EcsStorages.definition]
	local typeID = CONSTANTS.DefinedTypes.Items
	DefinitionStorage.AddComponentToEntity(entityId, typeID, definitionId)
end

--- Create an Instance of statsDefinition.WeaponData struct using WeaponDefinition
function ItemService.CreateWeapon(itemDefinition, weaponModel)
	if itemDefinition.itemType ~= itemTypes.weapon then
		return
	end

	local handle = weaponModel.Handle

	-- Dynamic Data / Instance
	local weaponData: statsDefinition.WeaponData = {
		name = itemDefinition.name,
		-- Model
		weaponSize = weaponModel:GetScale(),
		attackPoint = handle.AttackPoint,
		-- Offense
		damage = itemDefinition.damage, -- Calculate using Weapon Definition + Weapon Modifiers
		attackSpeed = itemDefinition.attackSpeed,
		-- Utility
		aoe = itemDefinition.range,
		-- Misc
		attackVFX = handle.VFXPoint.AttackHitVFX,
		maxCombo = itemDefinition.maxCombo,
		-- Modifiers
		-- Rarity = "Common",
		-- Modifiers = nil,
	}

	return weaponData
end

-- #endregion

-- #region SPAWN ITEMS

--- Spawn Item Model at Position,
--- eg : ItemService.SpawnItem(ItemRegistries[CategoryStore.Weapons].WoodenClub, Vector3.zero)
function ItemService.SpawnItem(item, position: Vector3)
	local usePos = position or Vector3.zero
	local itemDefinition = item.definition

	-- Spawn Model
	local itemModel = item.prefab:Clone()
	local entityId = ItemService.CreateItem(item.id, itemModel)

	ItemServiceState.groundItemsModels[entityId] = itemModel

	-- Set Item Model
	-- itemModel.Name = itemDefinition.name
	-- itemModel:SetAttribute("DefinitionId", item.id)
	itemModel.Parent = workspace

	-- Set Position
	local partToMove = itemModel

	local isWeapon = itemDefinition.itemType == itemTypes.weapon
	if isWeapon then
		ItemService.SetupWeapon(itemModel)
		itemModel:PivotTo(CFrame.new(position))
		return
	end

	partToMove.CFrame = CFrame.new(usePos)

	return itemModel
end

--- SpawnItem + LootMovement
function ItemService.SpawnLoot(item, position)
	local partToMove = ItemService.SpawnItem(item, position)
	ItemService.LootMovement(partToMove, position)
end

--- Spawn Multiple Items + Loot Movement
function ItemService.SpawnManyItem(item, position, amount)
	for _ = 1, amount do
		ItemService.SpawnLoot(item, position)
	end
end

function ItemService.RemoveGroundItem(itemModel)
	itemModel:Destroy()
end

function ItemService.ClearGroundItems()
	-- for _, child in pairs(CONSTANTS.AUTOPICKUP_FOLDER:GetChildren()) do
	-- 	ItemService.RemoveGroundItem(child)
	-- end

	for i = 1, #ItemServiceState.groundItemsModels do
		local itemModel = ItemServiceState.groundItemsModels[i]
		itemModel:Destroy()
	end

	table.clear(ItemServiceState.groundItemsModels)
end

-- #endregion

-- #region ITEM POOL

function ItemService.CreatePool(item, size)
	local definitionID = item.id
	local prefab = item.prefab
	local onSpawn = ItemService.ItemOnSpawn

	local _pool, poolID = PoolService.CreatePool(item.definition.name, definitionID, prefab, onSpawn, size)

	ItemServiceState.poolIDs[definitionID] = poolID
end

--- Use PoolService to Enable Item
function ItemService.EnableItem(definitionID, position)
	local poolID = ItemServiceState.poolIDs[definitionID]
	local parent = workspace
	local entityId, model = PoolService.EnableNextInPool(poolID, parent, position)

	return entityId, model
end

--- Enable + Loot Movement
function ItemService.EnableLoot(definitionID, position)
	local _entityId, model = ItemService.EnableItem(definitionID, position)

	if not model then
		return
	end

	ItemService.LootMovement(model, position)
end

--- Enable Multiple Items + Loot Movement
function ItemService.EnableManyItem(item, position, amount)
	for _ = 1, amount do
		ItemService.EnableLoot(item.id, position)
	end
end

-- #endregion

-- #region MOVEMENTS

--- Make a Part (Item Model) move along a Parabola
function ItemService.LootMovement(part, startPos)
	part.CFrame = CFrame.new(startPos)

	-- Find Target Pos
	local dist = 4
	local targetPos = Vector3.new(startPos.X + math.random(-dist, dist), 2.5, startPos.Z + math.random(-dist, dist))

	-- Raycast
	-- local targetPos = startPos + Vector3.new(math.random(-dist, dist), 5, math.random(-dist, dist))
	-- local result = workspace:Raycast(targetPos, Vector3.new(0, -10, 0))

	-- if not result then
	-- 	return
	-- end

	-- local posOffset = Vector3.new(0, 2, 0)
	-- local finalTargetPos = result.Position + posOffset

	-- Perform Movement in X Steps
	local steps = math.random(15, 30)
	local height = math.random(2, 10)

	-- Create Movement Context
	local movementCtx = {
		part = part,
		steps = steps,
		currentStep = 0,
		-- delay
		startPos = startPos,
		endPos = targetPos,
		height = height,
	}

	table.insert(ItemServiceState.itemsMovement, movementCtx)
end

function ItemService.LootMovementUpdate()
	for i = #ItemServiceState.itemsMovement, 1, -1 do
		local movementCtx = ItemServiceState.itemsMovement[i]

		-- Move
		movementCtx.currentStep += 1

		local progress = movementCtx.currentStep / movementCtx.steps

		local newPos = Gears.ParabolaPos(movementCtx.startPos, movementCtx.endPos, movementCtx.height, progress)
		movementCtx.part.CFrame = CFrame.new(newPos)

		-- End Movement
		if progress >= 1 then
			-- warn("End Movement")
			movementCtx.part.Parent = CONSTANTS.AUTOPICKUP_FOLDER -- Enable Pickup
			table.remove(ItemServiceState.itemsMovement, i)
		end
	end
end

-- #endregion

-- #region ADVANCED

--- Generate Loot of a Killed Enemy
function ItemService.GenerateLoot(player, position)
	-- TODO : Generate Loot based on : PlayerStats, Enemy type + Modifier, Area Modifiers

	local orbsRng = math.random(1, 3)
	ItemService.EnableManyItem(CategoryRegistries[CategoryStore.Usable].SmallXpOrb, position, orbsRng)
end

function ItemService.LootBananas(position)
	local roll = math.random(0, 100)
	local isLooting = roll <= ItemServiceState.bananaLootChance

	if isLooting then
		local amount = math.random(1, 3)
		ItemService.EnableManyItem(CategoryRegistries[CategoryStore.Usable].Banana, position, amount)
	end

	return isLooting
end

-- TODO : DRY
function ItemService.LootSticks(position)
	local roll = math.random(0, 100)
	local isLooting = roll <= ItemServiceState.stickLootChance

	if isLooting then
		local definitionID = CategoryRegistries[CategoryStore.Usable].Stick.id
		ItemService.EnableLoot(definitionID, position)
	end

	return isLooting
end

--- Spawn a Random Item from a Category
--- eg ItemService.SpawnRandomItem(ItemDefinitions.Weapons, ItemRegistries.Weapons)
function ItemService.SpawnRandomItem(categoryId, position)
	local defintions = CategoryDefinitions[categoryId]
	local registry = CategoryRegistries[categoryId]

	assert(defintions and registry, "wrong categoryId")

	local randomItem = math.random(1, #defintions)
	local itemDef = defintions[randomItem]
	local item = registry[itemDef.name]

	ItemService.SpawnItem(item, position)
end

-- #endregion

-- #region ITEM PICKUP

type ItemUseCtx = {
	player: Player,
	itemDefinition: any,
	itemModel: Model,
	ItemService: any,
	RpgService: any,
	PlayerService: any,
}

function ItemService.PickupItem(player, itemModel)
	-- TODO : Validations :
	-- itemModel parent = ManualPickup or AutoPickup -> Only Pickup & Unowned item
	-- Distance item / player

	-- Get State
	local entityID, definitionID = ItemService.GetModelInfo(itemModel)
	local itemDefinition = ItemService.GetItemDefinition(definitionID)

	if not itemDefinition then
		warn("Pickup item : itemDefinition not found for " .. itemModel.name)
		return
	end

	-- print(player.Name .. " Pickup Item : " .. itemDefinition.name)

	-- local useCtx = {
	-- 	player = player,
	-- 	itemDefinition = itemDefinition,
	-- 	itemModel = itemModel,
	-- 	ItemService = ItemService,
	-- 	RpgService = RpgService,
	-- 	PlayerService = PlayerService,
	-- }

	-- Use Item on Pickup
	usablesLogicDefinition[definitionID](player, itemDefinition, itemModel, entityID)
end

-- #endregion

-- #region WEAPON : SETUP & EQUIP

--- Add the Default weapon in a Player's Backpack
function ItemService.AddDefaultWeapon(player)
	-- Create Default Weapon
	local defaultWeapon = CategoryRegistries[CategoryStore.Weapons].WoodenClub
	local definitionID = defaultWeapon.id
	local model = defaultWeapon.prefab:clone()

	ItemService.CreateItem(definitionID, model)
	ItemService.SetupWeapon(model)

	-- Add it to Backpack
	local backpack = player:WaitForChild("Backpack")
	model.Parent = backpack

	task.wait()
	ItemService.EquipDefaultWeapon(player)
end

function ItemService.EquipDefaultWeapon(player)
	-- warn(player.Name .. " Equip Default Weapon")
	local character = player.Character

	if not character then
		return
	end

	local humanoid = character:FindFirstChild("Humanoid")
	local backpack = player:FindFirstChild("Backpack")

	if not humanoid or not backpack then
		return
	end

	local baseWeapon = backpack:FindFirstChild("WoodenClub")

	if baseWeapon then
		-- warn("Equip Default Weapon : " .. baseWeapon.Name)
		humanoid:EquipTool(baseWeapon)
	end
end

--- Set a Player's Weapon State
function ItemService.SetWeapon(player, weapon)
	-- warn(player.Name .. " new Weapon Data")

	local UserId = player.UserId

	local patch = { weaponData = weapon }
	Store:dispatch(StoreActions.PatchPlayer(UserId, patch))

	RpgService.CalculateAllStats(player) -- TODO : Calculate only Weapon Stats
end

--- Setup a Weapon Model
function ItemService.SetupWeapon(weaponModel)
	-- print("Setup weapon model : " .. weaponModel.Name)

	local _entityID, definitionID = ItemService.GetModelInfo(weaponModel)

	local itemDefinition = ItemService.GetItemDefinition(definitionID)

	local weaponData = ItemService.CreateWeapon(itemDefinition, weaponModel)

	weaponModel.Equipped:Connect(function()
		ItemService.OnEquipped(weaponModel, weaponData)
	end)

	weaponModel.Unequipped:Connect(function()
		ItemService.OnUnequipped(weaponModel)
	end)
end

function ItemService.AddWeaponSounds(player, weapon)
	local playerGUi = player.PlayerGui
	local soundsPrefab = ReplicatedStorage.Shared.Prefabs.Sounds

	-- Create Sounds
	local unsheath = soundsPrefab.Unsheath:clone()
	unsheath.Parent = playerGUi

	local slash = soundsPrefab.Slash:clone()
	slash.Parent = playerGUi

	local crit = soundsPrefab.CriticalSlash:clone()
	crit.Parent = playerGUi

	-- Try to get Building Hit Sound
	local buildingHitSound = soundsPrefab:FindFirstChild("BuildingHit")
	local buildingHit

	if buildingHitSound then
		buildingHit = soundsPrefab.BuildingHit:clone()
		buildingHit.Parent = playerGUi
	end

	weapon.sounds = {
		unsheath = unsheath,
		slash = slash,
		crit = crit,
		buildingHit = buildingHit,
	}
end

function ItemService.OnEquipped(weaponModel, weaponData)
	local character = weaponModel.Parent
	local player = Players:GetPlayerFromCharacter(character)

	if not player then
		return
	end

	-- warn("Equip Weapon : " .. player.Name .. " -> " .. weaponModel.Name)

	-- TODO : OnPickup
	-- Remove from Ground Items
	local entityID, _definitionID = ItemService.GetModelInfo(weaponModel)
	table.remove(ItemServiceState.groundItemsModels, entityID)

	-- TODO : Check if sounds are available -> Spawn & Delete sounds
	ItemService.AddWeaponSounds(player, weaponData)
	ItemService.SetWeapon(player, weaponData)

	weaponData.sounds.unsheath:Play()

	ItemService.EquipWeapon:Fire()
	-- Signal client > custom tool system
	ItemService.Client.EquipWeapon:Fire(player, true) -- pass weapon?
end

function ItemService.OnUnequipped(weaponModel)
	if not weaponModel or not weaponModel.Parent then
		return
	end

	local player = weaponModel.Parent.Parent

	if not player or not player:IsA("Player") then
		return
	end

	-- warn("Unequip Weapon : " .. player.Name .. " -> " .. weaponModel.Name)

	local state = Store:getState()
	local playerState = state.players[player.UserId]

	if not playerState then
		return
	end

	-- Reset WeaponState
	ItemService.SetWeapon(player, {})

	-- Events
	ItemService.UnequipWeapon:Fire(player)
	ItemService.Client.UnequipWeapon:Fire(player)

	-- Remove Sounds
	local weaponData = playerState.weaponData

	if not weaponData.sounds then
		return
	end

	for _, sound in pairs(weaponData.sounds) do
		sound:Destroy()
	end
end

-- #endregion

return ItemService
