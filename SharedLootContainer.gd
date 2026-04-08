extends "res://Scripts/LootContainer.gd"

const LEGACY_STASH_PATH = "user://SharedStash.tres"
const PAGED_STASH_PATH = "user://SharedStashPages.tres"
const SHARED_CONTAINER_NAME = "Shared Stash"
var _settings = preload("res://SharedStash/SharedStashSettings.tres")

func _is_legacy_shared() -> bool:
	return containerName == SHARED_CONTAINER_NAME

func _is_paged_shared() -> bool:
	if !furniture and containerName != "Office Cabinet":
		return false
	if FileAccess.file_exists(PAGED_STASH_PATH):
		var save = load(PAGED_STASH_PATH)
		if save and "pageNames" in save:
			var pos = global_position
			var id = containerName + "_" + str(snapped(pos.x, 0.1)) + "_" + str(snapped(pos.y, 0.1)) + "_" + str(snapped(pos.z, 0.1))
			return save.pageNames.has(id)
	return false

func _ready():
	if _is_legacy_shared():
		containerSize = Vector2(_settings.containerWidth, _settings.containerHeight)
		_load_shared_storage()
	else:
		super()

func _load_shared_storage():
	if FileAccess.file_exists(LEGACY_STASH_PATH):
		var save = load(LEGACY_STASH_PATH) as ContainerSave
		if save and save.storage.size() > 0:
			storage = save.storage
			storaged = true
			print("Shared Stash: Loaded " + str(storage.size()) + " items from legacy save")
		else:
			storaged = false
	else:
		storaged = false

func Storage(containerGrid: Grid):
	if _is_legacy_shared():
		super(containerGrid)
		_save_shared_storage()
	else:
		super(containerGrid)

func _save_shared_storage():
	var save = ContainerSave.new()
	save.name = SHARED_CONTAINER_NAME
	save.storage = storage.duplicate()
	ResourceSaver.save(save, LEGACY_STASH_PATH)
	print("Shared Stash: Saved " + str(storage.size()) + " items to legacy save")

func UpdateTooltip():
	if _is_legacy_shared():
		if locked:
			gameData.tooltip = containerName + " [Locked]"
		else:
			gameData.tooltip = containerName + " [Open]"
	elif _is_paged_shared():
		if locked:
			gameData.tooltip = containerName + " [Shared] [Locked]"
		else:
			gameData.tooltip = containerName + " [Shared] [Open]"
	else:
		super()
