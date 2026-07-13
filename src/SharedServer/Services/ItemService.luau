local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Gears = require(ReplicatedStorage.Shared.Gears)
local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages._Index["sleitnick_signal@1.5.0"].signal)

local RoduxStore = require(ReplicatedStorage.Shared.RoduxStore)
local store = RoduxStore.Store
local storeActions = RoduxStore.Actions

-- Get Items Data
local itemDef = require(ReplicatedStorage.Shared.AuthoringData.ItemDefinitions)
local itemDefinitions = itemDef.itemDefinitions
local itemStore = itemDef.itemStore
local itemTypes = itemDef.itemTypes
local itemPrefabs = itemDef.itemPrefabs

local PlayerService
local StatService

local ItemService = Knit.CreateService({
	Name = "ItemService",
	ItemStore = nil, -- Hold an ItemStore for other services -> ensure item spawn
	EquipWeapon = Signal.new(),
	UnequipWeapon = Signal.new(),
	Client = {
		-- 3D / Models
		GetOrb = Knit.CreateSignal(),
		EquipWeapon = Knit.CreateSignal(),
		UnequipWeapon = Knit.CreateSignal(),
	},
})

-- ITEM SERVICE DEFINITIONS

-- TODO : useItem(player)
local usablesLogicDefinition = {
	-- Small XP Orb
	["Small XP Orb"] = function(player, itemDefinition, itemModel)
		-- print("Add Small XP Orb to : " .. player.Name)
		-- StatService:AddXpToAllPlayers(itemDefinition.xp)
		ItemService.Client.GetOrb:Fire(player) -- SFX Feedback
		ItemService:RemoveGroundItem(itemModel)
	end,
	["Banana"] = function(player, itemDefinition, itemModel)
		local bananas = itemDefinition.banana
		print("Add Banana to all players : " .. bananas)
		PlayerService:AddCurrencyToAllPlayers(PlayerService.CURRENCIES.bananas, bananas)
		ItemService.Client.GetOrb:Fire(player)
		ItemService:RemoveGroundItem(itemModel)
	end,
	["Stick"] = function(player, itemDefinition, itemModel)
		print("Add Stick to : " .. player.Name)
		PlayerService:IncrementStick(player.UserId, itemDefinition.stick)
		ItemService.Client.GetOrb:Fire(player)
		ItemService:RemoveGroundItem(itemModel)
	end,
	["Stone"] = function(player, itemDefinition, itemModel)
		print("Add Stone to : " .. player.Name)
		PlayerService:IncrementStone(player.UserId, itemDefinition.stone)
		ItemService.Client.GetOrb:Fire(player)
		ItemService:RemoveGroundItem(itemModel)
	end,
}

-- CREATE ITEMS

-- Weapon Definition -> WeaponStats Data Struct instance
local function createWeaponData(itemDefinition, weaponModel)
	if itemDefinition.itemType ~= itemTypes.weapon then
		return
	end

	local handle = weaponModel.Handle

	-- Dynamic Data / Instance
	local weaponData = {
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

-- SPAWN ITEMS MODELS

-- Spawn model at Position
local function spawnItemDef(itemDefinitionId, position)
	local itemDefinition = itemDefinitions[itemDefinitionId]

	-- Spawn Model
	local newModel = itemPrefabs[itemDefinition.id]:Clone()

	local partToMove = newModel

	if itemDefinition.itemType == itemTypes.weapon then
		partToMove = newModel.Handle
	end

	partToMove.CFrame = CFrame.new(position)
	-- newModel.Name = itemDefinition.name
	newModel.Parent = workspace

	return newModel
end

local function lootMovement(partToMove, startPos)
	partToMove.CFrame = CFrame.new(startPos)

	local targetPos = startPos + Vector3.new(math.random(-2, 2), 0, math.random(-2, 2))
	local finalTargetPos = targetPos
	local result = workspace:Raycast(targetPos, Vector3.new(0, -10, 0))

	if result then
		finalTargetPos = result.Position
	else
		return
	end

	local steps = 60
	local height = math.random(2, 5)

	for i = 1, steps do
		local progress = i / steps
		partToMove.CFrame = CFrame.new(Gears.parabolaPos(startPos, finalTargetPos, height, progress))
		RunService.Heartbeat:Wait()
	end
end

-- Allow other services to spawn item with itemDefinitionId
function ItemService:SpawnItem(itemDefinitionId, position)
	-- local itemDefinition = itemDefinitions[itemDefinitionId]
	local newModel = spawnItemDef(itemDefinitionId, position)

	return newModel --, itemDefinition
end

-- SpawnItem + lootMovement
function ItemService:SpawnLoot(itemDefinitionId, position)
	local partToMove = spawnItemDef(itemDefinitionId, position)

	task.wait(lootMovement(partToMove, position))
	partToMove.Parent = workspace.AutoPickup -- Enable Pickup
end

function ItemService:SpawnManyItem(itemDefinitionId, position, itemCount)
	for i = 0, itemCount, 1 do
		task.spawn(function()
			local partToMove = spawnItemDef(itemDefinitionId, position)

			task.wait(lootMovement(partToMove, position))
			partToMove.Parent = workspace.AutoPickup -- Enable Pickup
		end)
		task.wait() -- delay between item
	end
end

function ItemService:GenerateLoot(player, enemyHumanoid)
	-- TODO : Generate Loot based on : PlayerStats, Enemy type + Modifier, Area Modifiers

	local orbsRng = math.random(1, 3)
	self:SpawnManyItem(itemStore.SmallXPOrb, enemyHumanoid.Parent:GetPivot().Position, orbsRng)
end

function ItemService:RemoveGroundItem(itemModel, instanceId)
	-- TODO : Object Pooling
	itemModel:Destroy()
end

-- ITEM PICKUP

function ItemService:PickupItem(player, itemModel)
	-- TODO : Validations :
	-- itemModel parent = ManualPickup or AutoPickup -> Only Pickup & Unowned item
	-- Distance item / player

	local definitionId = itemModel:GetAttribute("DefinitionId")
	local itemDefinition = itemDefinitions[definitionId]

	if not itemDefinition then
		warn("Pickup item : itemDefinition not found for " .. itemModel.name)
		return
	end

	-- print(player.Name .. " Pickup Item : " .. itemDefinition.name)

	-- Use Item on Pickup
	usablesLogicDefinition[itemDefinition.name](player, itemDefinition, itemModel)
end

-- WEAPON : SETUP & EQUIP

function ItemService:EquipDefaultWeapon(player)
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

local function setWeapon(player, weapon)
	-- print(player.Name .. " new Weapon Data")
	local patch = { weaponData = weapon }
	store:dispatch(storeActions.PatchPlayer(player.UserId, patch))

	StatService:CalculateAllStats(player.UserId) -- TODO : Calculate Weapon Stats
end

local function addSounds(player, weapon)
	local playerGUi = player.PlayerGui

	-- Create Sounds
	local soundsPrefab = ReplicatedStorage.Shared.Prefabs.Sounds
	soundsPrefab.Unsheath:clone().Parent = playerGUi
	soundsPrefab.Slash:clone().Parent = playerGUi
	soundsPrefab.CriticalSlash:clone().Parent = playerGUi

	weapon.sounds = {
		unsheath = playerGUi.Unsheath,
		slash = playerGUi.Slash,
		crit = playerGUi.CriticalSlash,
	}
end

local function onEquipped(weaponModel, weaponData)
	local character = weaponModel.Parent
	local player = Players:GetPlayerFromCharacter(character)
	print("Equip Weapon : " .. player.Name .. " -> " .. weaponModel.Name)

	-- TODO : Check if sounds are available -> Spawn & Delete sounds
	addSounds(player, weaponData)
	setWeapon(player, weaponData)

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

	if not player then
		return
	end

	print("Unequip Weapon : " .. player.Name .. " -> " .. weaponModel.Name)

	local state = store.getState(store)
	local playerData = state.players[player.UserId]

	if not playerData then
		return
	end

	local weaponData = playerData.weaponData

	-- Remove Sounds
	for _, sound in pairs(weaponData.sounds) do
		sound:Destroy()
	end

	-- Reset Data
	setWeapon(player, nil)

	-- Events
	ItemService.UnequipWeapon:Fire(player)
	ItemService.Client.UnequipWeapon:Fire(player)
end

local function SetupWeaponType(weaponType)
	local function setupWeapon(weaponModel)
		-- Avoid setuping prefabs
		if not weaponModel:IsDescendantOf(workspace) and not weaponModel:IsDescendantOf(Players) then
			return
		end

		print("Setup weapon model : " .. weaponModel.Name)

		local definitionId = weaponModel:GetAttribute("DefinitionId")
		local itemDefinition = itemDefinitions[definitionId]

		local weaponData = createWeaponData(itemDefinition, weaponModel)

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

-- KNIT SERVICE

function ItemService:KnitInit()
	print("ItemService Init")

	self.ItemStore = itemStore
end

function ItemService:KnitStart()
	PlayerService = Knit.GetService("PlayerService")
	StatService = Knit.GetService("StatService")

	SetupWeaponType("WoodenClub")
	SetupWeaponType("IronMace")
	SetupWeaponType("IronAxe")
end

return ItemService
