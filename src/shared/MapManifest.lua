local ForestMap = {
	id = "Forest",
	name = "Forest",
	source = {
		serverStorage = "Forest",
	},
	origin = Vector3.new(0, 10, 0),
	spawnZones = {
		root = "SpawnZones",
	},
	keySpawnPoints = {
		root = "KeySpawnPoints",
	},
	gearSpawnPoints = {
		root = "GearSpawnPoints",
	},
	exitDoor = "ExitDoor",
	qualificationZone = "QualificationZone",
	introCutsceneNodes = {
		root = "IntroCutsceneNodes",
	},
}

local MapManifest = {
	Forest = ForestMap,
	Default = ForestMap,
}

MapManifest.DefaultId = "Forest"

return MapManifest
