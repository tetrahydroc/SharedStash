extends "res://Scripts/LootContainer.gd"

const PAGED_STASH_PATH = "user://SharedStashPages.tres"

func _is_paged_shared() -> bool:
	if !furniture and containerName != "Office Cabinet":
		return false
	var pos = global_position
	var id = containerName + "_" + str(snapped(pos.x, 0.1)) + "_" + str(snapped(pos.y, 0.1)) + "_" + str(snapped(pos.z, 0.1))

	if FileAccess.file_exists(PAGED_STASH_PATH):
		var cfg = ConfigFile.new()
		if cfg.load(PAGED_STASH_PATH) == OK:
			var count = cfg.get_value("stash", "page_count", 0)
			for i in count:
				if cfg.get_value("page_" + str(i), "id", "") == id:
					return true

	return false

func UpdateTooltip():
	if _is_paged_shared():
		if locked:
			gameData.tooltip = containerName + " [Shared] [Locked]"
		else:
			gameData.tooltip = containerName + " [Shared] [Open]"
	else:
		super()
	if !_is_paged_shared():
		return
	var pos = global_position
	var id = containerName + "_" + str(snapped(pos.x, 0.1)) + "_" + str(snapped(pos.y, 0.1)) + "_" + str(snapped(pos.z, 0.1))

	if !FileAccess.file_exists(PAGED_STASH_PATH):
		return

	var cfg = ConfigFile.new()
	if cfg.load(PAGED_STASH_PATH) != OK:
		return

	var count = cfg.get_value("stash", "page_count", 0)
	for i in count:
		if cfg.get_value("page_" + str(i), "id", "") == id:
			# Found our page - move items back to local storage before removal
			var slot_count = cfg.get_value("page_" + str(i), "slot_count", 0)
			storage.clear()
			for j in slot_count:
				var key = "page_" + str(i) + "_slot_" + str(j)
				var item_file = cfg.get_value(key, "item_file", "")
				if item_file != "":
					var sd = SlotData.new()
					var item_scene = Database.get(item_file)
					if item_scene and item_scene is PackedScene:
						var item_path = item_scene.resource_path.replace(".tscn", ".tres")
						if ResourceLoader.exists(item_path):
							var item_data = load(item_path)
							if item_data is ItemData:
								sd.itemData = item_data
								sd.condition = cfg.get_value(key, "condition", 100)
								sd.amount = cfg.get_value(key, "amount", 0)
								sd.gridPosition = cfg.get_value(key, "grid_position", Vector2.ZERO)
								sd.gridRotated = cfg.get_value(key, "grid_rotated", false)
								storage.append(sd)
			storaged = storage.size() > 0

			# Remove this page from the save - shift remaining pages down
			var new_cfg = ConfigFile.new()
			var new_count = 0
			for k in count:
				if k == i:
					continue
				var old_section = "page_" + str(k)
				var new_section = "page_" + str(new_count)
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
				new_count += 1
			new_cfg.set_value("stash", "page_count", new_count)
			new_cfg.save(PAGED_STASH_PATH)
			break
