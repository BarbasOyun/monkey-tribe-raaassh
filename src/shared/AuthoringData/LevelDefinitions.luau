local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- #region BUILDINGS
-- Some numbers are fake for balance reasons

local buildingsFolder = ReplicatedStorage.Shared.Prefabs.Buildings
local soundsFolder = ReplicatedStorage.Shared.Prefabs.Sounds

-- Military
local militaryBase = { prefab = buildingsFolder.MilitaryBase, nbrOfParts = 800, radius = 55 } -- Real Nbr of parts = 1110
local militaryCamp = { prefab = buildingsFolder.MilitaryCamp, nbrOfParts = 912, radius = 60 }
local militaryCanvas = { prefab = buildingsFolder.MilitaryCanvas, nbrOfParts = 336, radius = 40 }
local smallCamp = { prefab = buildingsFolder.SmallCamp, nbrOfParts = 1000, radius = 35 } -- Real Nbr of parts = 1806
local sniperTower = { prefab = buildingsFolder.SniperTower, nbrOfParts = 139, radius = 20 }
local woodCrates = { prefab = buildingsFolder.WoodCrates, nbrOfParts = 76, radius = 15 }

-- Lab
local reactor = { prefab = buildingsFolder.Reactor, nbrOfParts = 700, radius = 55 } -- Real Nbr of parts = 1230
local galileoLaboratorty = { prefab = buildingsFolder.GalileoLaboratorty, nbrOfParts = 38, radius = 20 }
local alchemyLab = { prefab = buildingsFolder.AlchemyLab, nbrOfParts = 175, radius = 30 }
local labRoom = { prefab = buildingsFolder.LabRoom, nbrOfParts = 129, radius = 45 }
local labBattery = { prefab = buildingsFolder.LabBattery, nbrOfParts = 25, radius = 15 }

-- #endregion

-- #region MAPS

local Maps = { militaryMap = 1, researchLabMap = 2 }

-- TODO : Map Objects

local MapsBuildings = {
	{ militaryBase, militaryCamp, militaryCanvas, smallCamp, sniperTower, woodCrates },
	{ reactor, galileoLaboratorty, alchemyLab, labRoom, labBattery },
}

local MapsMusics = {
	soundsFolder.MilitaryMapMusic,
	soundsFolder.ResearchMapMusic,
}

-- #endregion

-- #region EVENTS

local Events = { Swarm = 1 } -- TODO : Add More Events

local EventsIcons = {
	"rbxassetid://137332832474710",
}

local EventsSounds = {
	workspace.GlobalSound.SwarmEvent,
}

-- TODO : Event Objects + Build Registry
--[[
local SwarmEvent = {
	icon = "rbxassetid://137332832474710",
	sound = workspace.GlobalSound.SwarmEvent,
}
]]

-- #endregion

local LevelDefinitions = {
	-- Map Const
	SPAWN_POS = Vector2.new(0, 170),
	MINIMUM_RADIUS = 40,

	-- Buildings Const
	BUILDINGS_INCREMENT = 2,
	BUILDINGS_RANGE = 2,
	BUILDING_LIMIT = 20,

	-- Node Collisions
	COLLISIONS_DETECTIONS_ITERATIONS = 15,
	SOLVER_ITERATIONS = 10,

	-- Maps
	Maps = Maps,
	MapsBuildings = MapsBuildings,
	MapsMusics = MapsMusics,

	-- Events
	Events = Events,
	EventsIcons = EventsIcons,
	EventsSounds = EventsSounds,
}

return LevelDefinitions
