extends Node

var gameData = preload("res://Resources/GameData.tres")

const SHARED_STASH_PATH = "user://SharedStashPages.tres"
const LEGACY_CFG_PATH = "user://SharedStashPages.cfg"

var _SaveScript = preload("res://SharedStash/SharedStashSave.gd")

var _currentPage: int = 0
var _totalPages: int = 0
var _stashSave = null

var _shareButton: Button = null
var _prevButton: Button = null
var _nextButton: Button = null
var _pageLabel: Label = null
var _navContainer: HBoxContainer = null

var _interface = null
var _lib = null

# Orphan cleanup state
var _lastFurnitureCount: int = -1

func _ready():
	if Engine.has_meta("RTVModLib"):
		var lib = Engine.get_meta("RTVModLib")
		if lib._is_ready:
			_register_hooks()
		else:
			lib.frameworks_ready.connect(_register_hooks)
	else:
		push_warning("Shared Stash: RTVModLib not found")
	print("Shared Stash: Loaded")

func _register_hooks():
	if !Engine.has_meta("RTVModLib"):
		print("Shared Stash: RTVModLib not found")
		return
	_lib = Engine.get_meta("RTVModLib")

	_lib.hook("lootcontainer-updatetooltip-post", _on_tooltip_update)
	_lib.hook("interface-open-post", _on_interface_open)
	_lib.hook("interface-close-pre", _on_interface_close)
	_lib.hook("interface-updatecontainergrid", _on_update_container_grid)
	_lib.hook("interface-fillcontainergrid", _on_fill_container_grid)
	_lib.hook("interface-storagecontainergrid", _on_storage_container_grid)

	print("Shared Stash: Hooks registered")

func _process(_delta):
	# Orphan page cleanup: monitor furniture count in shelter
	if !gameData.shelter:
		_lastFurnitureCount = -1
		return
	var furniture_nodes = get_tree().get_nodes_in_group("Furniture")
	var count = furniture_nodes.size()
	if _lastFurnitureCount >= 0 and count < _lastFurnitureCount:
		_cleanup_orphaned_pages()
	_lastFurnitureCount = count

func _get_interface():
	if _interface and is_instance_valid(_interface):
		return _interface
	var scene = get_tree().current_scene
	if !scene:
		return null
	_interface = scene.get_node_or_null("Core/UI/Interface")
	return _interface

# --- Stash Save/Load ---

func _load_stash():
	if !FileAccess.file_exists(SHARED_STASH_PATH):
		return _SaveScript.new()
	if _is_legacy_config_format(SHARED_STASH_PATH):
		var save = _load_stash_cfg(SHARED_STASH_PATH)
		_save_stash(save)
		print("Shared Stash: Migrated legacy save format")
		return save
	var save = load(SHARED_STASH_PATH)
	if save == null:
		return _SaveScript.new()
	return save

func _is_legacy_config_format(path: String) -> bool:
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var first_line = f.get_line()
	f.close()
	return not first_line.begins_with("[gd_resource")

func _load_stash_cfg(path: String):
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
		var slots = []
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

func _save_stash(save):
	ResourceSaver.save(save, SHARED_STASH_PATH)

func _find_item_data(file_name: String) -> ItemData:
	# Route through the mod loader's items registry. It resolves vanilla
	# items from LT_Master and mod-registered ones the same way, so mods
	# that correctly register their items (like Cash System ideally would)
	# are reachable without special-casing. Falls back to the legacy
	# Database.get + .tres lookup if the registry isn't initialized yet
	# (e.g., very early boot before lib is ready).
	if file_name == "":
		return null
	if _lib != null:
		var resolved = _lib.get_entry(_lib.Registry.ITEMS, file_name)
		if resolved != null and resolved is ItemData:
			return resolved
	# Legacy fallback: Database scene -> sibling .tres path.
	var scene = Database.get(file_name)
	if scene and scene is PackedScene:
		var path = scene.resource_path.replace(".tscn", ".tres")
		if ResourceLoader.exists(path):
			var res = load(path)
			if res is ItemData:
				return res
	# Final fallback: Cash System runtime items (for Cash versions that
	# don't register through the items registry).
	if Engine.has_meta("CashMain"):
		var cash = Engine.get_meta("CashMain")
		if cash.cash_item_data and cash.cash_item_data.file == file_name:
			return cash.cash_item_data
	return null

func _get_container_id(container) -> String:
	var pos = container.global_position
	return container.containerName + "_" + str(snapped(pos.x, 0.1)) + "_" + str(snapped(pos.y, 0.1)) + "_" + str(snapped(pos.z, 0.1))

func _is_container_shared(container) -> bool:
	if !container or (!container.furniture and container.containerName != "Office Cabinet"):
		return false
	_stashSave = _load_stash()
	return _stashSave.pageNames.has(_get_container_id(container))

func _get_shelter_name() -> String:
	var map = get_tree().current_scene
	if map and "mapName" in map:
		return map.mapName
	return "Unknown"

# --- Orphan Cleanup ---

func _cleanup_orphaned_pages():
	_stashSave = _load_stash()
	if _stashSave.pageNames.size() == 0:
		return
	var furniture_nodes = get_tree().get_nodes_in_group("Furniture")
	var valid_ids = {}
	for f in furniture_nodes:
		if "containerName" in f:
			var pos = f.global_position
			var id = f.containerName + "_" + str(snapped(pos.x, 0.1)) + "_" + str(snapped(pos.y, 0.1)) + "_" + str(snapped(pos.z, 0.1))
			valid_ids[id] = true
	# Also keep "Office Cabinet" pages
	for i in _stashSave.pageNames.size():
		if _stashSave.pageNames[i].begins_with("Office Cabinet"):
			valid_ids[_stashSave.pageNames[i]] = true

	var removed = 0
	var i = _stashSave.pageNames.size() - 1
	while i >= 0:
		if !valid_ids.has(_stashSave.pageNames[i]):
			_stashSave.pageNames.remove_at(i)
			_stashSave.pageSizes.remove_at(i)
			if i < _stashSave.pageStorage.size():
				_stashSave.pageStorage.remove_at(i)
			if i < _stashSave.pageLabels.size():
				_stashSave.pageLabels.remove_at(i)
			removed += 1
		i -= 1
	if removed > 0:
		_save_stash(_stashSave)
		print("Shared Stash: Cleaned " + str(removed) + " orphaned page(s)")

# --- Hook Callbacks ---

func _on_tooltip_update():
	var iface = _get_interface()
	if !iface or !iface.container:
		return
	if _is_container_shared(iface.container):
		gameData.tooltip = gameData.tooltip.replace(" [Open]", " [Shared] [Open]")
		gameData.tooltip = gameData.tooltip.replace(" [Locked]", " [Shared] [Locked]")

func _on_interface_open():
	var iface = _get_interface()
	if !iface:
		return

	# Refs to the buttons get freed when the previous shelter scene unloads,
	# so check validity rather than relying on a sticky "created once" flag.
	# Re-creating walks the same path as the first-time build.
	if _shareButton == null or not is_instance_valid(_shareButton):
		_create_shared_ui(iface)

	if iface.container and (iface.container.furniture or iface.container.containerName == "Office Cabinet") and gameData.shelter:
		if _shareButton:
			_shareButton.show()
			if _is_container_shared(iface.container):
				_shareButton.text = "Unshare"
			else:
				_shareButton.text = "Share"
	else:
		if _shareButton:
			_shareButton.hide()
		if _navContainer:
			_navContainer.hide()

func _on_interface_close():
	var iface = _get_interface()
	if iface and iface.container and _is_container_shared(iface.container):
		_save_current_page(iface)
	if _navContainer:
		_navContainer.hide()
	if _shareButton:
		_shareButton.hide()

func _on_update_container_grid():
	var iface = _get_interface()
	if !iface or !iface.container:
		return
	if _is_container_shared(iface.container):
		_show_paged_container(iface)
		_lib.skip_super()

func _on_fill_container_grid():
	var iface = _get_interface()
	if !iface or !iface.container:
		return
	if _is_container_shared(iface.container):
		_lib.skip_super()

func _on_storage_container_grid():
	var iface = _get_interface()
	if !iface or !iface.container:
		return
	if _is_container_shared(iface.container):
		_lib.skip_super()

# --- UI Creation ---

func _create_shared_ui(iface):
	var header = iface.containerUI.get_node_or_null("Header")
	if !header:
		return

	_shareButton = Button.new()
	_shareButton.name = "ShareButton"
	_shareButton.text = "Share"
	_shareButton.custom_minimum_size = Vector2(56, 24)
	_shareButton.add_theme_font_size_override("font_size", 11)
	_shareButton.position = Vector2(258, 4)
	_shareButton.pressed.connect(_on_share_pressed)
	header.add_child(_shareButton)
	_shareButton.hide()

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

# --- Share / Unshare ---

func _on_share_pressed():
	var iface = _get_interface()
	if !iface or !iface.container:
		return

	_stashSave = _load_stash()
	var container_id = _get_container_id(iface.container)

	if _is_container_paged():
		# Unshare the currently viewed page
		if _currentPage < _stashSave.pageNames.size():
			var page_id = _stashSave.pageNames[_currentPage]
			_save_current_page(iface)
			# If unsharing the container we're physically at, restore items
			if page_id == container_id:
				if _currentPage < _stashSave.pageStorage.size():
					iface.container.storage = _stashSave.pageStorage[_currentPage].duplicate()
					iface.container.storaged = iface.container.storage.size() > 0
			_stashSave.pageNames.remove_at(_currentPage)
			_stashSave.pageSizes.remove_at(_currentPage)
			if _currentPage < _stashSave.pageStorage.size():
				_stashSave.pageStorage.remove_at(_currentPage)
			if _currentPage < _stashSave.pageLabels.size():
				_stashSave.pageLabels.remove_at(_currentPage)
			_save_stash(_stashSave)

			_totalPages = _stashSave.pageNames.size()
			if _totalPages == 0:
				_shareButton.text = "Share"
				_navContainer.hide()
				iface.ClearContainerGrid()
				iface.containerGrid.CreateContainerGrid(iface.container.containerSize)
				if iface.container.storaged:
					for slotData in iface.container.storage:
						iface.LoadGridItem(slotData, iface.containerGrid, slotData.gridPosition)
			else:
				if _currentPage >= _totalPages:
					_currentPage = _totalPages - 1
				iface.ClearContainerGrid()
				_show_paged_container(iface)
	else:
		# Share this container
		_stashSave.pageNames.append(container_id)
		_stashSave.pageSizes.append(iface.container.containerSize)
		var shelterName = _get_shelter_name()
		var label = iface.container.containerName + " [" + shelterName + "]"
		_stashSave.pageLabels.append(label)
		var pageItems = []
		for item in iface.containerGrid.get_children():
			var newSlotData = SlotData.new()
			newSlotData.Update(item.slotData)
			newSlotData.GridSave(item.position, item.rotated)
			pageItems.append(newSlotData)
		_stashSave.pageStorage.append(pageItems)
		_save_stash(_stashSave)
		_shareButton.text = "Unshare"
		_currentPage = _stashSave.pageNames.size() - 1
		_totalPages = _stashSave.pageNames.size()
		iface.ClearContainerGrid()
		_show_paged_container(iface)

	iface.PlayClick()

func _is_container_paged() -> bool:
	var iface = _get_interface()
	if !iface or !iface.container:
		return false
	if !iface.container.furniture and iface.container.containerName != "Office Cabinet":
		return false
	_stashSave = _load_stash()
	return _stashSave.pageNames.has(_get_container_id(iface.container))

# --- Page Navigation ---

func _on_prev_page():
	var iface = _get_interface()
	if !iface or _totalPages <= 1:
		return
	_save_current_page(iface)
	_currentPage = (_currentPage - 1 + _totalPages) % _totalPages
	iface.ClearContainerGrid()
	_load_page(iface, _currentPage)
	iface.PlayClick()

func _on_next_page():
	var iface = _get_interface()
	if !iface or _totalPages <= 1:
		return
	_save_current_page(iface)
	_currentPage = (_currentPage + 1) % _totalPages
	iface.ClearContainerGrid()
	_load_page(iface, _currentPage)
	iface.PlayClick()

func _save_current_page(iface):
	if !_stashSave or _currentPage >= _stashSave.pageStorage.size():
		return
	var items = []
	for item in iface.containerGrid.get_children():
		var newSlotData = SlotData.new()
		newSlotData.Update(item.slotData)
		newSlotData.GridSave(item.position, item.rotated)
		items.append(newSlotData)
	_stashSave.pageStorage[_currentPage] = items
	_save_stash(_stashSave)

func _load_page(iface, pageIndex: int):
	if !_stashSave or pageIndex >= _stashSave.pageNames.size():
		return
	iface.containerGrid.CreateContainerGrid(_stashSave.pageSizes[pageIndex])
	if pageIndex < _stashSave.pageStorage.size():
		for slotData in _stashSave.pageStorage[pageIndex]:
			iface.LoadGridItem(slotData, iface.containerGrid, slotData.gridPosition)
	if pageIndex < _stashSave.pageLabels.size():
		iface.containerName.text = _stashSave.pageLabels[pageIndex]
	_update_page_label()

func _update_page_label():
	if _pageLabel:
		_pageLabel.text = "Page " + str(_currentPage + 1) + " / " + str(_totalPages)
	if _prevButton:
		_prevButton.disabled = _totalPages <= 1
	if _nextButton:
		_nextButton.disabled = _totalPages <= 1

func _show_paged_container(iface):
	_stashSave = _load_stash()
	_totalPages = _stashSave.pageNames.size()
	if _totalPages == 0:
		return

	# Jump to the page matching the container we just opened
	if iface.container:
		var id = _get_container_id(iface.container)
		for i in _stashSave.pageNames.size():
			if _stashSave.pageNames[i] == id:
				_currentPage = i
				break

	if _currentPage >= _totalPages:
		_currentPage = 0
	if _navContainer:
		_navContainer.show()
	_load_page(iface, _currentPage)
