extends Node

var McmHelpers = load("res://ModConfigurationMenu/Scripts/Doink Oink/MCM_Helpers.tres")
var settings = preload("res://SharedStash/SharedStashSettings.tres")

var config = ConfigFile.new()

const FILE_PATH = "user://MCM/SharedStash"
const MOD_ID = "shared-stash"

func _ready() -> void:
	config.set_value("Int", "containerWidth", {
		"name" = "Container Width",
		"tooltip" = "Width of the shared stash container (in grid cells)",
		"default" = 8,
		"value" = 8,
		"minRange" = 4,
		"maxRange" = 8
	})

	config.set_value("Int", "containerHeight", {
		"name" = "Container Height",
		"tooltip" = "Height of the shared stash container (in grid cells)",
		"default" = 6,
		"value" = 6,
		"minRange" = 1,
		"maxRange" = 13
	})

	if McmHelpers != null:
		if !FileAccess.file_exists(FILE_PATH + "/config.ini"):
			DirAccess.open("user://").make_dir_recursive(FILE_PATH)
			config.save(FILE_PATH + "/config.ini")
		else:
			McmHelpers.CheckConfigurationHasUpdated(MOD_ID, config, FILE_PATH + "/config.ini")
			config.load(FILE_PATH + "/config.ini")

		_on_config_updated(config)

		McmHelpers.RegisterConfiguration(
			MOD_ID,
			"Shared Stash",
			FILE_PATH,
			"Configure the shared stash container size",
			{
				"config.ini" = _on_config_updated
			}
		)

func _on_config_updated(_config: ConfigFile):
	settings.containerWidth = _config.get_value("Int", "containerWidth")["value"]
	settings.containerHeight = _config.get_value("Int", "containerHeight")["value"]
	print("Shared Stash config updated: " + str(settings.containerWidth) + "x" + str(settings.containerHeight))
