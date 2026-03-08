local ForestMap = {
	id = "Forest",
	name = "Forest",
	selectionWeight = 1,
	source = {
		serverStorage = "Forest",
	},
	origin = Vector3.new(0, 10, 0),
	spawnZones = {
		containerPath = "SpawnZones",
	},
	keySpawnPoints = {
		containerPath = "KeySpawnPoints",
		defaultWeight = 1,
		defaultShowcasePriority = 12,
	},
	gearSpawnPoints = {
		containerPath = "GearSpawnPoints",
		defaultWeight = 1,
		defaultShowcasePriority = 7,
	},
	exitDoor = "ExitDoor",
	qualificationZone = "QualificationZone",
	introCutsceneNodes = {
		containerPath = "IntroCutsceneNodes",
	},
}

local MapManifest = {
	Forest = ForestMap,
	Default = ForestMap,
}

MapManifest.DefaultId = "Forest"

return MapManifest
