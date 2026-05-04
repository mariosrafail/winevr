extends Node

signal client_profile_changed(client_id: String, client_data: Dictionary)

const CLIENTS_ROOT := "res://clients"
const CLIENT_REGISTRY_PATH := "res://data/client_registry.json"

const REQUIRED_FIELDS := [
	"client_id",
	"winery_name",
	"wine_name",
	"region_name",
	"country",
	"qr_id",
	"vial_settings",
	"experience_settings",
	"environment_settings",
	"narrative_steps"
]

var active_client_id: String = ""
var active_client_data: Dictionary = {}
var client_registry: Array[Dictionary] = []


func _ready() -> void:
	load_client_registry()
	var default_client_id: String = _get_default_client_id()
	if not default_client_id.is_empty():
		load_client_profile(default_client_id)


func load_client_registry() -> bool:
	client_registry.clear()

	if not FileAccess.file_exists(CLIENT_REGISTRY_PATH):
		push_warning("Client registry not found: %s" % CLIENT_REGISTRY_PATH)
		return false

	var file: FileAccess = FileAccess.open(CLIENT_REGISTRY_PATH, FileAccess.READ)
	if file == null:
		push_warning("Unable to open client registry: %s" % CLIENT_REGISTRY_PATH)
		return false

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		push_warning("Client registry must be a JSON array.")
		return false

	for index in range((parsed as Array).size()):
		var raw_entry: Variant = (parsed as Array)[index]
		if typeof(raw_entry) != TYPE_DICTIONARY:
			push_warning("Skipping invalid client registry entry at index %s." % index)
			continue

		var entry: Dictionary = raw_entry as Dictionary
		if not _validate_registry_entry(entry, index):
			continue

		client_registry.append(_normalize_registry_entry(entry))

	return true


func get_client_registry(include_disabled: bool = false) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for entry in client_registry:
		if include_disabled or bool(entry.get("enabled", false)):
			entries.append(entry.duplicate(true))
	return entries


func load_client_profile(client_id: String) -> bool:
	var config_path: String = get_profile_path(client_id)
	if not FileAccess.file_exists(config_path):
		push_warning("Client profile not found: %s" % config_path)
		return false

	var file: FileAccess = FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		push_warning("Unable to open client profile: %s" % config_path)
		return false

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Invalid JSON profile format for client '%s'." % client_id)
		return false

	var profile: Dictionary = parsed as Dictionary
	_normalize_profile(profile)
	if not _validate_profile(profile):
		push_warning("Client profile failed validation: %s" % client_id)
		return false

	active_client_id = client_id
	active_client_data = profile
	client_profile_changed.emit(active_client_id, active_client_data)
	return true


func load_runtime_profile(client_id: String, profile_data: Dictionary) -> bool:
	if profile_data.is_empty():
		push_warning("Runtime profile is empty for client '%s'." % client_id)
		return false
	var profile: Dictionary = profile_data.duplicate(true)
	_normalize_profile(profile)
	if not _validate_profile(profile):
		push_warning("Runtime profile failed validation: %s" % client_id)
		return false
	active_client_id = client_id
	active_client_data = profile
	client_profile_changed.emit(active_client_id, active_client_data)
	print("[ClientProfileLoader] Runtime profile loaded: %s" % client_id)
	return true


func profile_exists(client_id: String) -> bool:
	return FileAccess.file_exists(get_profile_path(client_id))


func get_profile_path(client_id: String) -> String:
	return "%s/%s/config.json" % [CLIENTS_ROOT, client_id]


func load_profile_by_qr_id(qr_id: String) -> bool:
	for entry in client_registry:
		if str(entry.get("qr_id", "")) == qr_id:
			return load_client_profile(str(entry.get("client_id", "")))

	push_warning("No client registry entry found for QR id: %s" % qr_id)
	return false


func get_active_client_data() -> Dictionary:
	return active_client_data.duplicate(true)


func get_active_value(key: String, default_value = null):
	return active_client_data.get(key, default_value)


func get_active_vial_settings() -> Dictionary:
	return active_client_data.get("vial_settings", {}).duplicate(true)


func get_active_experience_settings() -> Dictionary:
	return active_client_data.get("experience_settings", {}).duplicate(true)


func get_active_environment_settings() -> Dictionary:
	return active_client_data.get("environment_settings", {}).duplicate(true)


func _validate_profile(profile: Dictionary) -> bool:
	for field in REQUIRED_FIELDS:
		if not profile.has(field):
			push_warning("Client profile missing required field: %s" % field)
			return false

	var vial_settings: Dictionary = profile.get("vial_settings", {})
	if typeof(vial_settings) != TYPE_DICTIONARY:
		push_warning("Client profile vial_settings must be a dictionary.")
		return false

	for field in ["liquid_fill_amount", "liquid_color", "cap_color"]:
		if not vial_settings.has(field):
			push_warning("Client profile missing vial_settings.%s" % field)
			return false

	var experience_settings: Dictionary = profile.get("experience_settings", {})
	if typeof(experience_settings) != TYPE_DICTIONARY:
		push_warning("Client profile experience_settings must be a dictionary.")
		return false

	for field in ["intro_title", "intro_text", "hotspots", "scenes", "winery_scene_name", "winery_info_text"]:
		if not experience_settings.has(field):
			push_warning("Client profile missing experience_settings.%s" % field)
			return false

	var environment_settings: Dictionary = profile.get("environment_settings", {})
	if typeof(environment_settings) != TYPE_DICTIONARY:
		push_warning("Client profile environment_settings must be a dictionary.")
		return false

	for field in ["environment_id", "scene_type", "lighting_preset", "wall_color", "floor_color", "barrel_color", "door_color", "ambience_text", "interactables", "props", "zones", "camera_start"]:
		if not environment_settings.has(field):
			push_warning("Client profile missing environment_settings.%s" % field)
			return false

	if typeof(environment_settings.get("interactables")) != TYPE_ARRAY:
		push_warning("Client profile environment_settings.interactables must be an array.")
		return false

	if typeof(environment_settings.get("props")) != TYPE_ARRAY:
		push_warning("Client profile environment_settings.props must be an array.")
		return false

	if typeof(environment_settings.get("zones")) != TYPE_ARRAY:
		push_warning("Client profile environment_settings.zones must be an array.")
		return false

	if typeof(environment_settings.get("camera_start")) != TYPE_DICTIONARY:
		push_warning("Client profile environment_settings.camera_start must be a dictionary.")
		return false

	if typeof(profile.get("narrative_steps")) != TYPE_ARRAY:
		push_warning("Client profile narrative_steps must be an array.")
		return false

	return true


func _normalize_profile(profile: Dictionary) -> void:
	var experience_settings: Dictionary = profile.get("experience_settings", {})
	if typeof(experience_settings) != TYPE_DICTIONARY:
		experience_settings = {}

	if not experience_settings.has("hotspots") and experience_settings.has("info_hotspots"):
		experience_settings["hotspots"] = experience_settings.get("info_hotspots", [])

	var normalized_hotspots: Array = []
	for raw_hotspot in experience_settings.get("hotspots", []):
		if typeof(raw_hotspot) != TYPE_DICTIONARY:
			continue
		var hotspot: Dictionary = raw_hotspot.duplicate(true)
		hotspot["category"] = str(hotspot.get("category", "general"))
		hotspot["viewed_required_for_winery"] = bool(hotspot.get("viewed_required_for_winery", true))
		normalized_hotspots.append(hotspot)
	experience_settings["hotspots"] = normalized_hotspots

	profile["experience_settings"] = experience_settings
	_normalize_environment_settings(profile)
	_normalize_narrative_steps(profile)


func _normalize_environment_settings(profile: Dictionary) -> void:
	var experience_settings: Dictionary = profile.get("experience_settings", {})
	var fallback_info_text: String = str(experience_settings.get("winery_info_text", "A lightweight configurable winery environment."))
	var raw_environment: Variant = profile.get("environment_settings", {})
	var environment_settings: Dictionary = {}
	if typeof(raw_environment) == TYPE_DICTIONARY:
		environment_settings = (raw_environment as Dictionary).duplicate(true)

	environment_settings["environment_id"] = str(environment_settings.get("environment_id", "default_cellar"))
	environment_settings["scene_type"] = str(environment_settings.get("scene_type", "classic_stone_cellar"))
	environment_settings["lighting_preset"] = str(environment_settings.get("lighting_preset", "warm_classic"))
	environment_settings["wall_color"] = str(environment_settings.get("wall_color", "#8B8172"))
	environment_settings["floor_color"] = str(environment_settings.get("floor_color", "#51483D"))
	environment_settings["barrel_color"] = str(environment_settings.get("barrel_color", "#734A2D"))
	environment_settings["door_color"] = str(environment_settings.get("door_color", "#51341F"))
	environment_settings["ambience_text"] = str(environment_settings.get("ambience_text", fallback_info_text))

	var normalized_interactables: Array = []
	for raw_interactable in environment_settings.get("interactables", []):
		if typeof(raw_interactable) != TYPE_DICTIONARY:
			continue
		var interactable: Dictionary = (raw_interactable as Dictionary).duplicate(true)
		interactable["id"] = str(interactable.get("id", "interactable_%s" % normalized_interactables.size()))
		interactable["title"] = str(interactable.get("title", "Interactable"))
		interactable["text"] = str(interactable.get("text", fallback_info_text))
		interactable["type"] = str(interactable.get("type", "generic"))
		if not interactable.has("position"):
			interactable["position"] = []
		normalized_interactables.append(interactable)

	if normalized_interactables.is_empty():
		normalized_interactables.append({
			"id": "cellar_door",
			"title": "Cellar Door",
			"text": fallback_info_text,
			"type": "door",
			"position": [0.0, 0.0, -2.9]
		})

	environment_settings["interactables"] = normalized_interactables
	environment_settings["props"] = _normalize_environment_props(environment_settings)
	environment_settings["zones"] = _normalize_environment_zones(environment_settings, normalized_interactables, fallback_info_text)
	environment_settings["camera_start"] = _normalize_camera_start(environment_settings)
	profile["environment_settings"] = environment_settings


func _normalize_environment_props(environment_settings: Dictionary) -> Array:
	var normalized_props: Array = []
	for raw_prop in environment_settings.get("props", []):
		if typeof(raw_prop) != TYPE_DICTIONARY:
			continue
		var prop: Dictionary = (raw_prop as Dictionary).duplicate(true)
		prop["id"] = str(prop.get("id", "prop_%s" % normalized_props.size()))
		prop["type"] = str(prop.get("type", "crate"))
		prop["position"] = _normalize_number_array(prop.get("position", [0.0, 0.0, 0.0]), 3, [0.0, 0.0, 0.0])
		prop["rotation"] = _normalize_number_array(prop.get("rotation", [0.0, 0.0, 0.0]), 3, [0.0, 0.0, 0.0])
		prop["scale"] = _normalize_number_array(prop.get("scale", [1.0, 1.0, 1.0]), 3, [1.0, 1.0, 1.0])
		prop["color"] = str(prop.get("color", ""))
		prop["visible"] = bool(prop.get("visible", true))
		normalized_props.append(prop)
	return normalized_props


func _normalize_environment_zones(environment_settings: Dictionary, normalized_interactables: Array, fallback_text: String) -> Array:
	var normalized_zones: Array = []
	for raw_zone in environment_settings.get("zones", []):
		if typeof(raw_zone) != TYPE_DICTIONARY:
			continue
		var zone: Dictionary = (raw_zone as Dictionary).duplicate(true)
		zone["id"] = str(zone.get("id", "zone_%s" % normalized_zones.size()))
		zone["title"] = str(zone.get("title", "Info Zone"))
		zone["text"] = str(zone.get("text", fallback_text))
		zone["type"] = str(zone.get("type", "info_zone"))
		zone["position"] = _normalize_number_array(zone.get("position", [0.0, 1.1, -1.0]), 3, [0.0, 1.1, -1.0])
		zone["radius"] = float(zone.get("radius", 0.7))
		normalized_zones.append(zone)

	var has_door_zone: bool = false
	for zone in normalized_zones:
		if str((zone as Dictionary).get("type", "")) == "door":
			has_door_zone = true
			break

	if not has_door_zone:
		var door_interactable: Dictionary = {}
		for raw_interactable in normalized_interactables:
			var interactable: Dictionary = raw_interactable as Dictionary
			if str(interactable.get("type", "")) == "door":
				door_interactable = interactable
				break
		if not door_interactable.is_empty():
			normalized_zones.append({
				"id": str(door_interactable.get("id", "cellar_door")),
				"title": str(door_interactable.get("title", "Cellar Door")),
				"text": str(door_interactable.get("text", fallback_text)),
				"type": "door",
				"position": _normalize_number_array(door_interactable.get("position", [0.0, 0.0, -2.9]), 3, [0.0, 0.0, -2.9]),
				"radius": 0.9
			})

	return normalized_zones


func _normalize_camera_start(environment_settings: Dictionary) -> Dictionary:
	var raw_camera_start: Variant = environment_settings.get("camera_start", {})
	var camera_start: Dictionary = {}
	if typeof(raw_camera_start) == TYPE_DICTIONARY:
		camera_start = (raw_camera_start as Dictionary).duplicate(true)

	camera_start["position"] = _normalize_number_array(camera_start.get("position", [0.0, 0.0, 1.55]), 3, [0.0, 0.0, 1.55])
	camera_start["rotation"] = _normalize_number_array(camera_start.get("rotation", [0.0, 0.0, 0.0]), 3, [0.0, 0.0, 0.0])
	return camera_start


func _normalize_number_array(value: Variant, expected_size: int, fallback: Array) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return fallback.duplicate(true)

	var source: Array = value as Array
	if source.size() < expected_size:
		return fallback.duplicate(true)

	var normalized: Array = []
	for index in range(expected_size):
		normalized.append(float(source[index]))
	return normalized


func _normalize_narrative_steps(profile: Dictionary) -> void:
	var normalized_steps: Array = []
	for raw_step in profile.get("narrative_steps", []):
		if typeof(raw_step) != TYPE_DICTIONARY:
			continue
		var step: Dictionary = (raw_step as Dictionary).duplicate(true)
		step["id"] = str(step.get("id", "step_%s" % normalized_steps.size()))
		step["title"] = str(step.get("title", "Tasting Step"))
		step["text"] = str(step.get("text", ""))
		step["target_type"] = str(step.get("target_type", "free"))
		step["target_id"] = str(step.get("target_id", ""))
		step["required"] = bool(step.get("required", true))
		if step.has("next_step_id"):
			step["next_step_id"] = str(step.get("next_step_id", ""))
		normalized_steps.append(step)

	profile["narrative_steps"] = normalized_steps


func _validate_registry_entry(entry: Dictionary, index: int) -> bool:
	for field in ["client_id", "display_name", "wine_name", "region", "qr_id", "enabled"]:
		if not entry.has(field):
			push_warning("Skipping client registry entry %s: missing '%s'." % [index, field])
			return false

	if typeof(entry.get("enabled")) != TYPE_BOOL:
		push_warning("Skipping client registry entry %s: 'enabled' must be a boolean." % index)
		return false

	for field in ["client_id", "display_name", "wine_name", "region", "qr_id"]:
		if str(entry.get(field, "")).strip_edges().is_empty():
			push_warning("Skipping client registry entry %s: '%s' cannot be empty." % [index, field])
			return false

	if entry.has("thumbnail_path") and typeof(entry.get("thumbnail_path")) != TYPE_STRING:
		push_warning("Skipping client registry entry %s: 'thumbnail_path' must be a string." % index)
		return false

	return true


func _normalize_registry_entry(entry: Dictionary) -> Dictionary:
	return {
		"client_id": str(entry.get("client_id", "")),
		"display_name": str(entry.get("display_name", "")),
		"wine_name": str(entry.get("wine_name", "")),
		"region": str(entry.get("region", "")),
		"qr_id": str(entry.get("qr_id", "")),
		"enabled": bool(entry.get("enabled", false)),
		"thumbnail_path": str(entry.get("thumbnail_path", ""))
	}


func _get_default_client_id() -> String:
	for entry in client_registry:
		if bool(entry.get("enabled", false)):
			return str(entry.get("client_id", ""))
	return ""
