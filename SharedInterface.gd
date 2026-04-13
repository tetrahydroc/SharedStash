extends "res://Scripts/Interface.gd"

const SHARED_STASH_PATH = "user://SharedStashPages.tres"
const LEGACY_CFG_PATH = "user://SharedStashPages.cfg"
var _SaveScript = preload("res://SharedStash/SharedStashSave.gd")

# Page navigation state
var _currentPage: int = 0
var _totalPages: int = 0
var _stashSave = null

# UI elements
var _shareButton: Button = null
var _prevButton: Button = null
var _nextButton: Button = null
var _pageLabel: Label = null
var _navContainer: HBoxContainer = null
var _uiCreated = false

func _create_shared_ui():
	if _uiCreated:
		return

	var header = containerUI.get_node_or_null("Header")
	if !header:
		print("Shared Stash: ERROR - Header not found")
		return

	# Share button
	_shareButton = Button.new()
	_shareButton.name = "ShareButton"
	_shareButton.text = "Share"
	_shareButton.custom_minimum_size = Vector2(56, 24)
	_shareButton.add_theme_font_size_override("font_size", 11)
	_shareButton.position = Vector2(258, 4)
	_shareButton.pressed.connect(_on_share_pressed)
	header.add_child(_shareButton)
	_shareButton.hide()

	# Page navigation
	_navContainer = HBoxContainer.new()
	_navContainer.name = "PageNav"
	_navContainer.position = Vector2(0, -56)
	_navContainer.custom_minimum_size = Vector2(256, 24)
	_navContainer.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_child(_navContainer)

	_prevButton = Button.new()
	_prevButton.text = "<"
	_prevButton.custom_minimum_size = Vector2(32, 24)
	_prevButton.add_theme_font_size_override("font_size", 11)
	_prevButton.pressed.connect(_on_prev_page)
	_navContainer.add_child(_prevButton)

	_pageLabel = Label.new()
	_pageLabel.text = "Page 1 / 1"
	_pageLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pageLabel.add_theme_font_size_override("font_size", 11)
	_pageLabel.custom_minimum_size = Vector2(120, 24)
	_navContainer.add_child(_pageLabel)

	_nextButton = Button.new()
	_nextButton.text = ">"
	_nextButton.custom_minimum_size = Vector2(32, 24)
	_nextButton.add_theme_font_size_override("font_size", 11)
	_nextButton.pressed.connect(_on_next_page)
	_navContainer.add_child(_nextButton)

	_navContainer.hide()
	_uiCreated = true

# --- Stash save/load ---

func _load_stash():
	# Primary path (ConfigFile saved as .tres)
	if FileAccess.file_exists(SHARED_STASH_PATH):
		return _load_stash_cfg(SHARED_STASH_PATH)

	# Migrate from old .cfg path
	if FileAccess.file_exists(LEGACY_CFG_PATH):
		var save = _load_stash_cfg(LEGACY_CFG_PATH)
		if save.pageNames.size() > 0:
			_save_stash(save)
			DirAccess.remove_absolute(ProjectSettings.globalize_path(LEGACY_CFG_PATH))
			return save

	return _SaveScript.new()

func _load_stash_cfg(path: String = SHARED_STASH_PATH):
	var cfg = ConfigFile.new()
	if cfg.load(path) != OK:
		return _SaveScript.new()

	var save = _SaveScript.new()
	var count = cfg.get_value("stash", "page_count", 0)

	for i in count:
		var section = "page_" + str(i)
		save.pageNames.append(cfg.get_value(section, "id", ""))
		save.pageSizes.append(cfg.get_value(section, "size", Vector2(8, 6)))
		save.pageLabels.append(cfg.get_value(section, "label", ""))

		var slot_count = cfg.get_value(section, "slot_count", 0)
		var slots: Array[SlotData] = []
		for j in slot_count:
			var key = section + "_slot_" + str(j)
			var item_file = cfg.get_value(key, "item_file", "")
			if item_file == "":
				continue
			var item_data = _find_item_data(item_file)
			if !item_data:
				continue
			var sd = SlotData.new()
			sd.itemData = item_data
			sd.condition = cfg.get_value(key, "condition", 100)
			sd.amount = cfg.get_value(key, "amount", 0)
			sd.position = cfg.get_value(key, "position", 0)
			sd.mode = cfg.get_value(key, "mode", 1)
			sd.zoom = cfg.get_value(key, "zoom", 1)
			sd.chamber = cfg.get_value(key, "chamber", false)
			sd.casing = cfg.get_value(key, "casing", false)
			sd.state = cfg.get_value(key, "state", "")
			sd.gridPosition = cfg.get_value(key, "grid_position", Vector2.ZERO)
			sd.gridRotated = cfg.get_value(key, "grid_rotated", false)
			var nested_count = cfg.get_value(key, "nested_count", 0)
			for k in nested_count:
				var nd = _find_item_data(cfg.get_value(key, "nested_" + str(k), ""))
				if nd:
					sd.nested.append(nd)
			slots.append(sd)
		save.pageStorage.append(slots)

	return save

func _find_item_data(file_name: String) -> ItemData:
	if file_name == "":
		return null
	var scene = Database.get(file_name)
	if scene and scene is PackedScene:
		var path = scene.resource_path.replace(".tscn", ".tres")
		if ResourceLoader.exists(path):
			var res = load(path)
			if res is ItemData:
				return res
	return null

func _save_stash(save):
	var cfg = ConfigFile.new()
	cfg.set_value("stash", "page_count", save.pageNames.size())

	for i in save.pageNames.size():
		var section = "page_" + str(i)
		cfg.set_value(section, "id", save.pageNames[i])
		cfg.set_value(section, "size", save.pageSizes[i] if i < save.pageSizes.size() else Vector2(8, 6))
		cfg.set_value(section, "label", save.pageLabels[i] if i < save.pageLabels.size() else "")

		var slots = save.pageStorage[i] if i < save.pageStorage.size() else []
		cfg.set_value(section, "slot_count", slots.size())
		for j in slots.size():
			var sd = slots[j]
			if !sd or !sd.itemData:
				continue
			var key = section + "_slot_" + str(j)
			cfg.set_value(key, "item_file", sd.itemData.file)
			cfg.set_value(key, "condition", sd.condition)
			cfg.set_value(key, "amount", sd.amount)
			cfg.set_value(key, "position", sd.position)
			cfg.set_value(key, "mode", sd.mode)
			cfg.set_value(key, "zoom", sd.zoom)
			cfg.set_value(key, "chamber", sd.chamber)
			cfg.set_value(key, "casing", sd.casing)
			cfg.set_value(key, "state", sd.state)
			cfg.set_value(key, "grid_position", sd.gridPosition)
			cfg.set_value(key, "grid_rotated", sd.gridRotated)
			cfg.set_value(key, "nested_count", sd.nested.size())
			for k in sd.nested.size():
				cfg.set_value(key, "nested_" + str(k), sd.nested[k].file)

	cfg.save(SHARED_STASH_PATH)

func _get_container_id() -> String:
	if !container:
		return ""
	var pos = container.global_position
	return container.containerName + "_" + str(snapped(pos.x, 0.1)) + "_" + str(snapped(pos.y, 0.1)) + "_" + str(snapped(pos.z, 0.1))

func _is_container_paged() -> bool:
	if !container or (!container.furniture and container.containerName != "Office Cabinet"):
		return false
	_stashSave = _load_stash()
	return _stashSave.pageNames.has(_get_container_id())

func _get_shelter_name() -> String:
	var map = get_tree().current_scene
	if map and "mapName" in map:
		return map.mapName
	return "Unknown"

# --- Share / Unshare ---

func _on_share_pressed():
	if !container:
		return

	_stashSave = _load_stash()
	var container_id = _get_container_id()

	# If currently viewing a shared page, unshare uses the VIEWED page
	# If not shared, share uses the physical container
	if _is_container_paged():
		# Unshare the currently viewed page
		if _currentPage < _stashSave.pageNames.size():
			var page_id = _stashSave.pageNames[_currentPage]
			# Save current page contents first
			_save_current_page()
			# If unsharing the container we're physically at, restore items to it
			if page_id == container_id:
				if _currentPage < _stashSave.pageStorage.size():
					container.storage = _stashSave.pageStorage[_currentPage].duplicate()
					container.storaged = container.storage.size() > 0
			# Remove the page
			_stashSave.pageNames.remove_at(_currentPage)
			_stashSave.pageSizes.remove_at(_currentPage)
			_stashSave.pageStorage.remove_at(_currentPage)
			if _currentPage < _stashSave.pageLabels.size():
				_stashSave.pageLabels.remove_at(_currentPage)
			_save_stash(_stashSave)

			# Update view
			_totalPages = _stashSave.pageNames.size()
			if _totalPages == 0:
				_shareButton.text = "Share"
				_navContainer.hide()
				ClearContainerGrid()
				containerGrid.CreateContainerGrid(container.containerSize)
				if container.storaged:
					for slotData in container.storage:
						LoadGridItem(slotData, containerGrid, slotData.gridPosition)
			else:
				if _currentPage >= _totalPages:
					_currentPage = _totalPages - 1
				ClearContainerGrid()
				_show_paged_container()
	else:
		# Share this container
		_stashSave.pageNames.append(container_id)
		_stashSave.pageSizes.append(container.containerSize)
		var shelterName = _get_shelter_name()
		var label = container.containerName + " [" + shelterName + "]"
		_stashSave.pageLabels.append(label)
		var pageItems: Array[SlotData] = []
		for item in containerGrid.get_children():
			var newSlotData = SlotData.new()
			newSlotData.Update(item.slotData)
			newSlotData.GridSave(item.position, item.rotated)
			pageItems.append(newSlotData)
		_stashSave.pageStorage.append(pageItems)
		_save_stash(_stashSave)
		_shareButton.text = "Unshare"
		_currentPage = _stashSave.pageNames.size() - 1
		_totalPages = _stashSave.pageNames.size()
		ClearContainerGrid()
		_show_paged_container()

	PlayClick()

# --- Page Navigation ---

func _on_prev_page():
	if _totalPages <= 1:
		return
	_save_current_page()
	_currentPage = (_currentPage - 1 + _totalPages) % _totalPages
	ClearContainerGrid()
	_load_page(_currentPage)
	PlayClick()

func _on_next_page():
	if _totalPages <= 1:
		return
	_save_current_page()
	_currentPage = (_currentPage + 1) % _totalPages
	ClearContainerGrid()
	_load_page(_currentPage)
	PlayClick()

func _save_current_page():
	if !_stashSave or _currentPage >= _stashSave.pageStorage.size():
		return
	var items: Array[SlotData] = []
	for item in containerGrid.get_children():
		var newSlotData = SlotData.new()
		newSlotData.Update(item.slotData)
		newSlotData.GridSave(item.position, item.rotated)
		items.append(newSlotData)
	_stashSave.pageStorage[_currentPage] = items
	_save_stash(_stashSave)

func _load_page(pageIndex: int):
	if !_stashSave or pageIndex >= _stashSave.pageNames.size():
		return
	containerGrid.CreateContainerGrid(_stashSave.pageSizes[pageIndex])
	if pageIndex < _stashSave.pageStorage.size():
		for slotData in _stashSave.pageStorage[pageIndex]:
			LoadGridItem(slotData, containerGrid, slotData.gridPosition)
	if pageIndex < _stashSave.pageLabels.size():
		containerName.text = _stashSave.pageLabels[pageIndex]
	_update_page_label()

func _update_page_label():
	if _pageLabel:
		_pageLabel.text = "Page " + str(_currentPage + 1) + " / " + str(_totalPages)
	if _prevButton:
		_prevButton.disabled = _totalPages <= 1
	if _nextButton:
		_nextButton.disabled = _totalPages <= 1

func _show_paged_container():
	_stashSave = _load_stash()
	_totalPages = _stashSave.pageNames.size()
	if _totalPages == 0:
		return

	# Jump to the page matching the container we just opened
	if container:
		var id = _get_container_id()
		for i in _stashSave.pageNames.size():
			if _stashSave.pageNames[i] == id:
				_currentPage = i
				break

	if _currentPage >= _totalPages:
		_currentPage = 0
	if _navContainer:
		_navContainer.show()
	_load_page(_currentPage)

# --- Overrides ---

func Open():
	if !_uiCreated:
		_create_shared_ui()

	if container and (container.furniture or container.containerName == "Office Cabinet") and gameData.shelter:
		if _shareButton:
			_shareButton.show()
			if _is_container_paged():
				_shareButton.text = "Unshare"
			else:
				_shareButton.text = "Share"
	else:
		if _shareButton:
			_shareButton.hide()
		if _navContainer:
			_navContainer.hide()

	super()

func Close():
	if container and (container.furniture or container.containerName == "Office Cabinet") and _is_container_paged():
		_save_current_page()
	if _navContainer:
		_navContainer.hide()
	if _shareButton:
		_shareButton.hide()
	super()

func UpdateContainerGrid():
	if container and (container.furniture or container.containerName == "Office Cabinet") and _is_container_paged():
		_show_paged_container()
		return
	super()

func FillContainerGrid():
	if container and (container.furniture or container.containerName == "Office Cabinet") and _is_container_paged():
		return
	super()

func StorageContainerGrid():
	if container and (container.furniture or container.containerName == "Office Cabinet") and _is_container_paged():
		return
	super()
