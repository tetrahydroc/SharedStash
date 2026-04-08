extends "res://Scripts/Database.gd"

var _shared_crate = preload("res://SharedStash/Crate_Shared_F.tscn")

func _get(property: StringName):
	if property == "Crate_Shared":
		return _shared_crate
	return null
