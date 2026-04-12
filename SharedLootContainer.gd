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
