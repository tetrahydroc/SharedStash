extends Resource

# Paged shared storage - each shared container is a page
@export var pageNames: Array[String] = []       # Unique container IDs
@export var pageSizes: Array[Vector2] = []       # Grid size per page
@export var pageStorage: Array = []              # Array of Array[SlotData]
@export var pageLabels: Array[String] = []       # Display name per page (e.g. "Crate Military [Cabin]")
