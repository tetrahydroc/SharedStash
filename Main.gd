extends Node

var _saveScript = preload("res://SharedStash/SharedStashSave.gd")

func _ready():
	overrideScript("res://SharedStash/SharedLootContainer.gd")
	overrideScript("res://SharedStash/SharedInterface.gd")
	overrideScript("res://SharedStash/SharedLoader.gd")
	print("Shared Stash: Loaded")

func overrideScript(modded_path: String):
	var script: Script = load(modded_path)
	script.reload()
	var parentScript = script.get_base_script()
	script.take_over_path(parentScript.resource_path)
