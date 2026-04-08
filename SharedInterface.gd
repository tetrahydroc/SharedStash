extends "res://Scripts/Interface.gd"

const SHARED_STASH_PATH = "user://SharedStashPages.tres"
const SHARED_CONTAINER_NAME = "Shared Stash"
var _settings = preload("res://SharedStash/SharedStashSettings.tres")
var _SaveScript = preload("res://SharedStash/SharedStashSave.gd")

# V1 legacy: the custom "Shared Stash" crate uses ContainerSave
const LEGACY_STASH_PATH = "user://SharedStash.tres"

# Page navigation state
var _currentPage: int = 0
var _totalPages: int = 0
var _stashSave = null  # SharedStashSave resource

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
	print("Shared Stash: Share UI created")

# --- Stash save/load (paged) ---

func _load_stash():
	if FileAccess.file_exists(SHARED_STASH_PATH):
		var save = load(SHARED_STASH_PATH)
		if save and save.has_method("get"):
			# Verify it has our expected properties
			if "pageNames" in save:
				return save
	var save = _SaveScript.new()
	return save

func _save_stash(save):
	ResourceSaver.save(save, SHARED_STASH_PATH)

func _get_container_id() -> String:
	if !container:
		return ""
	var pos = container.global_position
	return container.containerName + "_" + str(snapped(pos.x, 0.1)) + "_" + str(snapped(pos.y, 0.1)) + "_" + str(snapped(pos.z, 0.1))

func _is_container_paged() -> bool:
	# Check if this furniture container is in the paged shared system
	if !container or (!container.furniture and container.containerName != "Office Cabinet"):
		return false
	_stashSave = _load_stash()
	return _stashSave.pageNames.has(_get_container_id())

func _get_shelter_name() -> String:
	var map = get_tree().current_scene
	if map and "mapName" in map:
		return map.mapName
	return "Unknown"

func _is_legacy_shared() -> bool:
	# V1 custom shared crate
	return container and container.containerName == SHARED_CONTAINER_NAME

# --- Share / Unshare ---

func _on_share_pressed():
	if !container:
		return

	_stashSave = _load_stash()
	var id = _get_container_id()

	if _stashSave.pageNames.has(id):
		# Unshare
		var idx = _stashSave.pageNames.find(id)
		if idx < _stashSave.pageStorage.size():
			container.storage = _stashSave.pageStorage[idx].duplicate()
			container.storaged = container.storage.size() > 0
		_stashSave.pageNames.remove_at(idx)
		_stashSave.pageSizes.remove_at(idx)
		_stashSave.pageStorage.remove_at(idx)
		if idx < _stashSave.pageLabels.size():
			_stashSave.pageLabels.remove_at(idx)
		_save_stash(_stashSave)
		_shareButton.text = "Share"
		_navContainer.hide()
		ClearContainerGrid()
		containerGrid.CreateContainerGrid(container.containerSize)
		# Reload local storage
		if container.storaged:
			for slotData in container.storage:
				LoadGridItem(slotData, containerGrid, slotData.gridPosition)
		print("Shared Stash: Unshared container")
	else:
		# Share - grab current grid items into a new page
		_stashSave.pageNames.append(id)
		_stashSave.pageSizes.append(container.containerSize)
		# Store display label with shelter name
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
		print("Shared Stash: Shared container as page " + str(_currentPage + 1))

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
	# Update header with this page's container name + shelter
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
	if _currentPage >= _totalPages:
		_currentPage = 0
	if _navContainer:
		_navContainer.show()
	_load_page(_currentPage)

# --- Overrides ---

func Open():
	if !_uiCreated:
		_create_shared_ui()

	# Show share button for furniture containers in shelters
	# (but not for the legacy shared crate - that's always shared)
	if container and (container.furniture or container.containerName == "Office Cabinet") and gameData.shelter:
		if _shareButton:
			if _is_legacy_shared():
				# Legacy crate: no share button needed, always shared
				_shareButton.hide()
			else:
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
	# Save paged container
	if container and (container.furniture or container.containerName == "Office Cabinet") and _is_container_paged():
		_save_current_page()
	if _navContainer:
		_navContainer.hide()
	if _shareButton:
		_shareButton.hide()
	super()

func UpdateContainerGrid():
	# Legacy shared crate: apply MCM size
	if _is_legacy_shared():
		container.containerSize = Vector2(_settings.containerWidth, _settings.containerHeight)
		super()
		return

	# Paged shared container: handle our own grid
	if container and (container.furniture or container.containerName == "Office Cabinet") and _is_container_paged():
		_show_paged_container()
		return

	super()

func FillContainerGrid():
	# Legacy shared crate: reload from legacy save
	if _is_legacy_shared():
		container._load_shared_storage()
		super()
		return

	# Paged: already filled by _show_paged_container
	if container and (container.furniture or container.containerName == "Office Cabinet") and _is_container_paged():
		return

	super()

func StorageContainerGrid():
	# Legacy shared crate: save to legacy file
	if _is_legacy_shared():
		super()
		return

	# Paged: already saved in Close()
	if container and (container.furniture or container.containerName == "Office Cabinet") and _is_container_paged():
		return

	super()
