extends Node

var gameData = preload("res://Resources/GameData.tres")
var _saveScript = preload("res://SharedStash/SharedStashSave.gd")
var _last_shelter = ""
var _last_furniture_count: int = -1

const PAGED_STASH_PATH = "user://SharedStashPages.tres"

func _ready():
	overrideScript("res://SharedStash/SharedLootContainer.gd")
	overrideScript("res://SharedStash/SharedInterface.gd")
	print("Shared Stash: Loaded")

func _process(_delta):
	if !gameData.shelter:
		_last_shelter = ""
		_last_furniture_count = -1
		return

	if _last_shelter == "":
		var map = get_tree().current_scene
		if map and "mapName" in map:
			_last_shelter = map.mapName
			_last_furniture_count = get_tree().get_nodes_in_group("Furniture").size()

	# Detect furniture count change (container picked up or placed)
	if _last_furniture_count >= 0:
		var current = get_tree().get_nodes_in_group("Furniture").size()
		if current < _last_furniture_count:
			# Furniture was removed - check for orphaned shared pages
			_cleanup_orphaned_pages(_last_shelter)
		_last_furniture_count = current

func _cleanup_orphaned_pages(shelter_name: String):
	if !FileAccess.file_exists(PAGED_STASH_PATH):
		return

	var cfg = ConfigFile.new()
	if cfg.load(PAGED_STASH_PATH) != OK:
		return

	var count = cfg.get_value("stash", "page_count", 0)
	if count == 0:
		return

	# Collect container IDs still in the scene
	var current_ids: Dictionary = {}
	var furnitures = get_tree().get_nodes_in_group("Furniture")
	for furniture in furnitures:
		if furniture.owner is LootContainer:
			var lc = furniture.owner
			var pos = lc.global_position
			var id = lc.containerName + "_" + str(snapped(pos.x, 0.1)) + "_" + str(snapped(pos.y, 0.1)) + "_" + str(snapped(pos.z, 0.1))
			current_ids[id] = true

	# Find orphaned pages for this shelter
	var pages_to_keep: Array = []
	var removed = false
	for i in count:
		var page_id = cfg.get_value("page_" + str(i), "id", "")
		var page_label = cfg.get_value("page_" + str(i), "label", "")

		if page_label.ends_with("[" + shelter_name + "]") and !current_ids.has(page_id):
			removed = true
			continue
		pages_to_keep.append(i)

	if !removed:
		return

	# Rewrite save without orphaned pages
	var new_cfg = ConfigFile.new()
	new_cfg.set_value("stash", "page_count", pages_to_keep.size())
	var new_idx = 0
	for old_idx in pages_to_keep:
		var old_section = "page_" + str(old_idx)
		var new_section = "page_" + str(new_idx)
		new_cfg.set_value(new_section, "id", cfg.get_value(old_section, "id", ""))
		new_cfg.set_value(new_section, "size", cfg.get_value(old_section, "size", Vector2(8, 6)))
		new_cfg.set_value(new_section, "label", cfg.get_value(old_section, "label", ""))
		var sc = cfg.get_value(old_section, "slot_count", 0)
		new_cfg.set_value(new_section, "slot_count", sc)
		for s in sc:
			var old_key = old_section + "_slot_" + str(s)
			var new_key = new_section + "_slot_" + str(s)
			for prop in ["item_file", "condition", "amount", "position", "mode", "zoom", "chamber", "casing", "state", "grid_position", "grid_rotated", "nested_count"]:
				if cfg.has_section_key(old_key, prop):
					new_cfg.set_value(new_key, prop, cfg.get_value(old_key, prop))
			var nc = cfg.get_value(old_key, "nested_count", 0)
			for n in nc:
				if cfg.has_section_key(old_key, "nested_" + str(n)):
					new_cfg.set_value(new_key, "nested_" + str(n), cfg.get_value(old_key, "nested_" + str(n)))
		new_idx += 1
	new_cfg.save(PAGED_STASH_PATH)

func overrideScript(modded_path: String):
	var script: Script = load(modded_path)
	script.reload()
	var parentScript = script.get_base_script()
	script.take_over_path(parentScript.resource_path)
