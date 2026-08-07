local ReplicatedStorage = game:GetService("ReplicatedStorage")

local prefabsFolder = ReplicatedStorage.Shared.Prefabs

-- Buildings
-- local militaryBase = { prefab = prefabsFolder.MilitaryBase, nbrOfParts = 800, radius = 55 } -- Real Nbr of parts = 1110
-- local militaryCamp = { prefab = prefabsFolder.MilitaryCamp, nbrOfParts = 912, radius = 60 }
-- local militaryCanvas = { prefab = prefabsFolder.MilitaryCanvas, nbrOfParts = 336, radius = 40 }
-- local smallCamp = { prefab = prefabsFolder.SmallCamp, nbrOfParts = 1000, radius = 35 } -- Real Nbr of parts = 1806
-- local sniperTower = { prefab = prefabsFolder.SniperTower, nbrOfParts = 139, radius = 20 }
-- local woodCrates = { prefab = prefabsFolder.WoodCrates, nbrOfParts = 76, radius = 15 }

-- local reactor = { prefab = prefabsFolder.Reactor, nbrOfParts = 700, radius = 55 } -- Real Nbr of parts = 1230
-- local galileoLaboratorty = { prefab = prefabsFolder.GalileoLaboratorty, nbrOfParts = 38, radius = 20 }
-- local alchemyLab = { prefab = prefabsFolder.AlchemyLab, nbrOfParts = 175, radius = 30 }
-- local labRoom = { prefab = prefabsFolder.LabRoom, nbrOfParts = 129, radius = 45 }
-- local labBattery = { prefab = prefabsFolder.LabBattery, nbrOfParts = 25, radius = 15 }

-- Maps
local Maps = { militaryMap = 1, researchLabMap = 2 }

-- local MapsBuildings = {
-- 	{ militaryBase, militaryCamp, militaryCanvas, smallCamp, sniperTower, woodCrates },
-- 	{ reactor, galileoLaboratorty, alchemyLab, labRoom, labBattery },
-- }

-- local MapsMusics = {
-- 	prefabsFolder.MilitaryMapMusic,
-- 	prefabsFolder.ResearchMapMusic,
-- }

-- Events
local Events = { Swarm = 1 } -- TODO : Add More Events

local EventsIcons = {
	"rbxassetid://137332832474710",
}

local LevelDefinitions = {
	MINIMUM_RADIUS = 40,
	SPAWN_POS = Vector2.new(0, 170),
	-- CIRCLE_DIVISION = 20,
	ADDITIONAL_BUILDINGS = 2,
	BUILDING_LIMIT = 10,
	-- Maps
	Maps = Maps,
	-- MapsBuildings = MapsBuildings,
	-- MapsMusics = MapsMusics,
	-- Events
	Events = Events,
	EventsIcons = EventsIcons,
}

return LevelDefinitions
