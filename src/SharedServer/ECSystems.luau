local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Packages._Index["sleitnick_signal@1.5.0"].signal)
local Gears = require(ReplicatedStorage.Shared.Gears)

local MutState = ServerScriptService.SharedServer.MutableState

-- local systemCount = 0

-- TODO : DynamicState
-- TODO : Stateless Systems

-- Meta table
local system = {
	addComponentToEntity = function(ecsState, systemState, entityId)
		table.insert(systemState.entities, entityId)

		local componentId = #systemState.entities
		systemState.sparse[entityId] = componentId

		-- Update Entity Bitmask
		ecsState.entitiesBitmask[entityId] =
			Gears:AddMask(ecsState.entitiesBitmask[entityId], Gears:GetMask(systemState.id))

		return componentId
	end,
	getComponentId = function(systemState, entityId)
		local componentId = systemState.sparse[entityId]

		if componentId == 0 then
			warn("EntityId = " .. entityId .. " Doesn't have Component " .. systemState.name)
		end

		if not componentId then
			warn("EntityId = " .. entityId .. " Is out of Sparse Range of : " .. systemState.name)
		end

		return componentId
	end,
	updateComponent = function(systemState, entityId)
		-- implement in child tables
	end,
	removeComponent = function(ecsState, systemState, entityId)
		local componentId = systemState.sparse[entityId]

		-- Update Entities
		table.remove(systemState.entities, componentId)

		-- Update Sparse
		systemState.sparse[entityId] = 0

		-- Update Entity Bitmask
		ecsState.entitiesBitmask[entityId] =
			Gears:RemoveMask(ecsState.entitiesBitmask[entityId], Gears:GetMask(systemState.id))

		return componentId
	end,
	--[[
		removeEntity = function(self, entityId)
		local componentId = self.sparse[entityId]

		-- Update Entities
		table.remove(self.entities, componentId)
		for i = componentId, #self.entities, 1 do
			self.entities[i] -= 1
		end

		-- Update Sparse
		table.remove(self.sparse, entityId)
		for i = entityId, #self.sparse, 1 do
			self.sparse[i] -= 1
		end

		return componentId
	end,
	]]
	removeEntity = function(self, entityId)
		local componentId = self.sparse[entityId]
		local lastCompId = self.sparse[#self.sparse]
		local hasComp = lastCompId ~= 0

		-- Update Entities
		table.remove(self.entities, lastCompId)

		-- Delete Comp if last Entity doesn't have it, else keep
		if not hasComp then
			table.remove(self.entities, entityId)
			self.sparse[entityId] = 0

			for i = entityId, #self.entities, 1 do
				self.sparse[self.entities[i]] -= 1
			end
		end

		-- Update Sparse
		table.remove(self.sparse, #self.sparse)

		return componentId, lastCompId, hasComp
	end,
	clearComponents = function(self)
		table.clear(self.sparse)
		table.clear(self.entities)
	end,
}
system.__index = system

function system.new(id, name)
	local self = {
		id = id,
		name = name,
		sparse = {},
		entities = {},
	}

	setmetatable(self, system)
	return self
end

local systemData = {}

function systemData.new(id, name)
	local self = {
		id = id,
		name = name,
		sparse = {},
		entities = {},
	}

	setmetatable(self, system)
	return self
end

-- GameObject System Struct
local gameObjectSystemData = systemData.new(1, "GameObjectSystem")
gameObjectSystemData.gameObjects = {}

-- GameObject System Impl
-- TODO : Function / Logic Only
local gameObjectSystem = system.new(1, "GameObjectSystem")
gameObjectSystem.gameObjects = {}

function gameObjectSystem:addComponentToEntity(ecsState, entityId, gameobject)
	local systemState = nil -- Selector

	local componentId = system.addComponentToEntity(ecsState, systemState, entityId)

	gameobject:SetAttribute("EntityId", entityId)
	gameobject:SetAttribute("Version", ecsState.versions[entityId])

	table.insert(self.gameObjects, gameobject)

	return componentId
end

function gameObjectSystem:removeComponent(entityId)
	-- TODO
end

--[[
function gameObjectSystem:removeEntity(entityId)
	local componentId = system.removeEntity(self, entityId)

	warn("Delete Gameobject Component : EntityId = " .. entityId .. " componentId = " .. componentId)

	self.gameObjects[componentId]:Destroy()
	table.remove(self.gameObjects, componentId)

	for i = entityId, #self.entities, 1 do
		self.gameObjects[i]:SetAttribute("EntityId", self.entities[i])
		-- self.gameObjects[i]:SetAttribute("Version", versions[entityId])
	end
end
]]

function gameObjectSystem:removeEntity(entityId)
	local componentId, lastCompId, hasComp = system.removeEntity(self, entityId)

	-- warn("Delete GameObject Component : EntityId = " .. entityId .. " componentId = " .. componentId)

	self.gameObjects[componentId]:Destroy()

	if not hasComp then
		-- Delete at compId
		table.remove(self.gameObjects, componentId)
		return
	end

	-- Swap Values + Delete Last
	local lastGameObject = table.remove(self.gameObjects, lastCompId)
	self.gameObjects[componentId] = lastGameObject

	-- local lastGameObject = moveLastElement(self.gameObjects, componentId)

	-- Update GameObject EntityId
	lastGameObject:SetAttribute("EntityId", entityId)
	-- lastGameObject:SetAttribute("Version", versions[entityId])
end

function gameObjectSystem:clearComponents()
	system.clearComponents(self)

	-- Destroy All Entities Gameobjects
	for i = 1, #self.gameObjects, 1 do
		self.gameObjects[i]:Destroy()
	end

	table.clear(self.gameObjects)
end

-- Unit System
local unitSystem = system.new(2, "UnitSystem")
unitSystem.definitionId = {}
unitSystem.life = {}
unitSystem.lifeBar = {}
unitSystem.deathEvent = {}

function unitSystem:addComponentToEntity(entityId, definitionId, life, lifeBar)
	local componentId = system.addComponentToEntity(self, entityId)

	table.insert(self.definitionId, definitionId)
	table.insert(self.life, life)
	table.insert(self.lifeBar, lifeBar)
	table.insert(self.deathEvent, Signal.new())

	return componentId
end

function unitSystem:updateComponent(entityId, life)
	local componentId = system.getComponentId(self, entityId)
	self.life[componentId] = life
end

function unitSystem:removeComponent(entityId)
	-- TODO
end

function unitSystem:removeEntity(entityId)
	local componentId, lastCompId, hasComp = system.removeEntity(self, entityId)

	-- warn("Delete Unit Component : EntityId = " .. entityId .. " componentId = " .. componentId)

	if not hasComp then
		-- Delete at compId
		table.remove(self.life, componentId)
		table.remove(self.lifeBar, componentId)
		table.remove(self.deathEvent, componentId)
		return
	end

	-- Swap Values + Delete Last
	Gears.moveLastElement(self.life, componentId)
	Gears.moveLastElement(self.lifeBar, componentId)
	Gears.moveLastElement(self.deathEvent, componentId)
end

function unitSystem:clearComponents()
	system.clearComponents(self)

	table.clear(self.life)
	table.clear(self.lifeBar)
	table.clear(self.deathEvent)
end

-- TODO : MobBehaviorSystem

local EcsData = {
	entitiesId = {},
	entitiesBitmask = {},
	versions = {},
	gameObjectSystemData,
	unitSystem,
}

return EcsData
