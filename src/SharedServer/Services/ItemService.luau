local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Gears = require(ReplicatedStorage.Shared.Gears)

-- Get Constants
local CONSTANTS = require(ServerScriptService.SharedServer.Constants)

local statsDefinition = require(ReplicatedStorage.Shared.AuthoringData.StatsDefinitions)

local itemDef = require(ReplicatedStorage.Shared.AuthoringData.ItemDefinitions)
local itemTypes = itemDef.itemTypes

local CategoryStore = itemDef.CategoryStore
local CategoryDefinitions = itemDef.CategoryDefinitions
local CategoryRegistries = itemDef.CategoryRegistries

-- Get State
local RoduxStore = require(ReplicatedStorage.Shared.RoduxStore)
local Store = RoduxStore.Store
local StoreActions = RoduxStore.Actions

-- Get MutState
local MutState = require(ServerScriptService.SharedServer.MutableState)
local ItemServiceState = MutState.ItemServiceState

-- Get Knit
local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages._Index["sleitnick_signal@1.5.0"].signal)

local PlayerService, RpgService

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

-- #region ITEMS LOGIC

-- TODO : useItem(player)
local usablesLogicDefinition = {
	-- Small XP Orb
	function(player, itemDefinition, itemModel)
		-- print("Add Small XP Orb to : " .. player.Name)
		RpgService.AddXpToAllPlayers(itemDefinition.xp)
		ItemService.Client.GetOrb:Fire(player) -- SFX Feedback
		ItemService.RemoveGroundItem(itemModel)
	end,
	-- Banana
	function(player, itemDefinition, itemModel)
		local bananas = itemDefinition.banana
		-- print("Add Banana to all players : " .. bananas)
		PlayerService.AddCurrencyToAllPlayers(CONSTANTS.CURRENCIES.bananas, bananas)
		ItemService.Client.GetOrb:Fire(player)
		ItemService.RemoveGroundItem(itemModel)
	end,
	-- Stick
	function(player, itemDefinition, itemModel)
		print("Add Stick to : " .. player.Name)
		PlayerService.AddCurrencyToPlayer(player, CONSTANTS.CURRENCIES.sticks, itemDefinition.stick)
		ItemService.Client.GetOrb:Fire(player)
		ItemService.RemoveGroundItem(itemModel)
	end,
	-- Stone : TODO
	function(player, itemDefinition, itemModel)
		print("Add Stone to : " .. player.Name)
		PlayerService.IncrementStone(player.UserId, itemDefinition.stone)
		ItemService.Client.GetOrb:Fire(player)
		ItemService.RemoveGroundItem(itemModel)
	end,
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

-- #endregion

-- #region CREATE ITEMS

--- Create an Instance of statsDefinition.WeaponData struct using WeaponDefinition
local function createWeapon(itemDefinition, weaponModel)
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

	-- TODO : Create Entity

	-- Spawn Model
	local newModel = item.prefab:Clone()

	-- TODO : Add GameObject Component

	-- Set Item Model
	-- newModel.Name = itemDefinition.name
	newModel:SetAttribute("DefinitionId", item.id)
	newModel.Parent = workspace

	-- Set Position
	local partToMove = newModel

	if itemDefinition.itemType == itemTypes.weapon then
		newModel:PivotTo(CFrame.new(position))
		return
	end

	partToMove.CFrame = CFrame.new(usePos)

	return newModel
end

--- SpawnItem + LootMovement
function ItemService.SpawnLoot(item, position)
	local partToMove = ItemService.SpawnItem(item, position)
	ItemService.LootMovement(partToMove, position)
end

--- Spawn Multiple Items + Loot Movement
function ItemService.SpawnManyItem(item, position, amount)
	for i = 1, amount do
		ItemService.SpawnLoot(item, position)
	end
end

--- Generate Loot of a Killed Enemy
function ItemService.GenerateLoot(player, enemyHumanoid)
	-- TODO : Generate Loot based on : PlayerStats, Enemy type + Modifier, Area Modifiers

	local pos = enemyHumanoid.Parent:GetPivot().Position
	local orbsRng = math.random(1, 3)

	ItemService.SpawnManyItem(CategoryRegistries[CategoryStore.Usable].SmallXpOrb, pos, orbsRng)
end

--- eg ItemService.SpawnRandomItem(ItemDefinitions.Weapons, ItemRegistries.Weapons)
function ItemService.SpawnRandomItem(categoryId, position)
	local defintions = CategoryDefinitions[categoryId]
	local registry = CategoryRegistries[categoryId]

	assert(defintions, "wrong categoryId")
	assert(registry, "wrong categoryId")

	local randomItem = math.random(1, #defintions)
	local itemDef = defintions[randomItem]
	local item = registry[itemDef.name]

	ItemService.SpawnItem(item, position)
end

function ItemService.RemoveGroundItem(itemModel, instanceId)
	-- TODO : Object Pooling
	itemModel:Destroy()
end

function ItemService.ClearGroundItems()
	-- FIXME : List all ground Items

	for _, child in pairs(CONSTANTS.AUTOPICKUP_FOLDER:GetChildren()) do
		child:Destroy()
		-- ItemService.RemoveGroundItem(child)
	end
end

--- Make a Part (Item Model) move along a Parabola
function ItemService.LootMovement(part, startPos)
	part.CFrame = CFrame.new(startPos)

	-- Find Target Pos
	local dist = 4
	local targetPos = Vector3.new(startPos.X + math.random(-dist, dist), 2.5, startPos.Z + math.random(-dist, dist))

	-- local targetPos = startPos + Vector3.new(math.random(-dist, dist), 5, math.random(-dist, dist))
	-- local result = workspace:Raycast(targetPos, Vector3.new(0, -10, 0))

	-- if not result then
	-- 	return
	-- end

	-- local posOffset = Vector3.new(0, 2, 0)
	-- local finalTargetPos = result.Position + posOffset
	local finalTargetPos = targetPos

	-- Perform Movement in X Steps
	local steps = math.random(30, 90)
	local height = math.random(3, 6)

	-- Create Movement Context
	local movementCtx = {
		part = part,
		steps = steps,
		currentStep = 0,
		-- delay
		startPos = startPos,
		endPos = finalTargetPos,
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

-- #region ITEM PICKUP

function ItemService.PickupItem(player, itemModel)
	-- TODO : Validations :
	-- itemModel parent = ManualPickup or AutoPickup -> Only Pickup & Unowned item
	-- Distance item / player

	local definitionId = itemModel:GetAttribute("DefinitionId")
	local itemDefinition = ItemService.GetItemDefinition(definitionId)

	if not itemDefinition then
		warn("Pickup item : itemDefinition not found for " .. itemModel.name)
		return
	end

	-- print(player.Name .. " Pickup Item : " .. itemDefinition.name)

	-- Use Item on Pickup
	usablesLogicDefinition[definitionId](player, itemDefinition, itemModel)
end

-- #endregion

-- #region WEAPON : SETUP & EQUIP

function ItemService.EquipDefaultWeapon(player)
	local humanoid = player.Character:FindFirstChild("Humanoid")
	local backpack = player:FindFirstChild("Backpack")

	if not humanoid or not backpack then
		return
	end

	local defaultTool = backpack:FindFirstChild("WoodenClub")
	-- print("Equip Default tool : " .. defaultTool)
	if defaultTool then
		humanoid:EquipTool(defaultTool)
	end
end

function ItemService.SetWeapon(player, weapon)
	-- warn(player.Name .. " new Weapon Data")

	local UserId = player.UserId

	local patch = { weaponData = weapon }
	Store:dispatch(StoreActions.PatchPlayer(UserId, patch))

	RpgService.CalculateAllStats(player) -- TODO : Calculate only Weapon Stats
end

local function addSounds(player, weapon)
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

local function onEquipped(weaponModel, weaponData)
	local character = weaponModel.Parent
	local player = Players:GetPlayerFromCharacter(character)

	if not player then
		return
	end

	print("Equip Weapon : " .. player.Name .. " -> " .. weaponModel.Name)

	-- TODO : Check if sounds are available -> Spawn & Delete sounds
	addSounds(player, weaponData)
	ItemService.SetWeapon(player, weaponData)

	weaponData.sounds.unsheath:Play()

	ItemService.EquipWeapon:Fire()
	-- Signal client > custom tool system
	ItemService.Client.EquipWeapon:Fire(player, true) -- pass weapon?
end

local function onUnequipped(weaponModel)
	if not weaponModel or not weaponModel.Parent then
		return
	end

	local player = weaponModel.Parent.Parent

	if not player or not player:IsA("Player") then
		return
	end

	warn("Unequip Weapon : " .. player.Name .. " -> " .. weaponModel.Name)

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

local function SetupWeaponType(weaponType)
	local function setupWeapon(weaponModel)
		-- Avoid setuping prefabs
		if not weaponModel:IsDescendantOf(workspace) and not weaponModel:IsDescendantOf(Players) then
			return
		end

		-- print("Setup weapon model : " .. weaponModel.Name)

		local definitionId = weaponModel:GetAttribute("DefinitionId")
		local itemDefinition = ItemService.GetItemDefinition(definitionId)

		local weaponData = createWeapon(itemDefinition, weaponModel)

		-- TODO : Use custom tool system
		weaponModel.Equipped:Connect(function()
			onEquipped(weaponModel, weaponData)
		end)

		weaponModel.Unequipped:Connect(function()
			onUnequipped(weaponModel)
		end)
	end

	-- Setup Existing Weapons
	for _, weaponModel in pairs(CollectionService:GetTagged(weaponType)) do
		setupWeapon(weaponModel)
	end

	-- Setup Future Weapons
	CollectionService:GetInstanceAddedSignal(weaponType):Connect(function(weaponModel)
		setupWeapon(weaponModel)
	end)
end

-- #endregion

-- KNIT SERVICE

function ItemService:KnitInit()
	print("ItemService Init")
end

function ItemService:KnitStart()
	PlayerService = Knit.GetService("PlayerService")
	RpgService = Knit.GetService("RpgService")

	SetupWeaponType("WoodenClub")
	SetupWeaponType("IronMace")
	SetupWeaponType("IronAxe")

	PlayerService.StateUpdate:Connect(function(state, dt)
		ItemService.LootMovementUpdate()
	end)
end

return ItemService
