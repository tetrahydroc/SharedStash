extends "res://Scripts/Loader.gd"

const PAGED_STASH_PATH = "user://SharedStashPages.cfg"
const LEGACY_STASH_PATH = "user://SharedStashPages.tres"

func _is_furniture_paged(lootContainer: LootContainer) -> bool:
	var pos = lootContainer.global_position
	var id = lootContainer.containerName + "_" + str(snapped(pos.x, 0.1)) + "_" + str(snapped(pos.y, 0.1)) + "_" + str(snapped(pos.z, 0.1))

	# Check .cfg format
	if FileAccess.file_exists(PAGED_STASH_PATH):
		var cfg = ConfigFile.new()
		if cfg.load(PAGED_STASH_PATH) == OK:
			var count = cfg.get_value("stash", "page_count", 0)
			for i in count:
				if cfg.get_value("page_" + str(i), "id", "") == id:
					return true

	# Check legacy .tres format
	if FileAccess.file_exists(LEGACY_STASH_PATH):
		var save = load(LEGACY_STASH_PATH)
		if save and "pageNames" in save:
			return save.pageNames.has(id)

	return false

func SaveShelter(targetShelter):
	var shelter: ShelterSave = ShelterSave.new()

	shelter.initialVisit = false
	shelter.lastVisit = (Simulation.day * 10000) + Simulation.time

	var furnitures = get_tree().get_nodes_in_group("Furniture")

	for furniture in furnitures:
		var furnitureComponent: Furniture

		for child in furniture.owner.get_children():
			if child is Furniture:
				furnitureComponent = child

		if furnitureComponent:
			var furnitureSave = FurnitureSave.new()
			furnitureSave.name = furnitureComponent.itemData.name
			furnitureSave.itemData = furnitureComponent.itemData
			furnitureSave.position = furniture.owner.global_position
			furnitureSave.rotation = furniture.owner.global_rotation
			furnitureSave.scale = furniture.owner.scale

			if furniture.owner is LootContainer:
				if _is_furniture_paged(furniture.owner):
					pass  # Storage in SharedStashPages.tres
				elif furniture.owner.storage.size() != 0:
					furnitureSave.storage = furniture.owner.storage

			shelter.furnitures.append(furnitureSave)

	var items = get_tree().get_nodes_in_group("Item")

	for item in items:
		if !item.global_position.is_finite() || !item.global_rotation.is_finite():
			print("Invalid transform: " + item.slotData.itemData.file)
			continue

		if item.global_position.y < -10.0:
			print("Falled item: " + item.slotData.itemData.file)
			continue

		var itemSave = ItemSave.new()
		itemSave.name = item.slotData.itemData.name
		itemSave.slotData = item.slotData
		itemSave.position = item.global_position
		itemSave.rotation = item.global_rotation

		shelter.items.append(itemSave)

	var switches = get_tree().get_nodes_in_group("Switch")

	for switch in switches:
		var switchSave = SwitchSave.new()
		switchSave.name = switch.name
		switchSave.active = switch.active

		shelter.switches.append(switchSave)

	ResourceSaver.save(shelter, "user://" + targetShelter + ".tres")
	print("SAVE: " + targetShelter)
