extends Node

signal client_profile_changed(client_id: String, client_data: Dictionary)

const CLIENTS_ROOT := "res://clients"
const DEFAULT_CLIENT_ID := "demo_winery"

const REQUIRED_FIELDS := [
	"client_id",
	"winery_name",
	"wine_name",
	"region_name",
	"country",
	"qr_id",
	"vial_settings",
	"experience_settings"
]

var active_client_id: String = ""
var active_client_data: Dictionary = {}


func _ready() -> void:
	load_client_profile(DEFAULT_CLIENT_ID)


func load_client_profile(client_id: String) -> bool:
	var config_path: String = "%s/%s/config.json" % [CLIENTS_ROOT, client_id]
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


func get_active_client_data() -> Dictionary:
	return active_client_data.duplicate(true)


func get_active_value(key: String, default_value = null):
	return active_client_data.get(key, default_value)


func get_active_vial_settings() -> Dictionary:
	return active_client_data.get("vial_settings", {}).duplicate(true)


func get_active_experience_settings() -> Dictionary:
	return active_client_data.get("experience_settings", {}).duplicate(true)


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

	return true


func _normalize_profile(profile: Dictionary) -> void:
	var experience_settings: Dictionary = profile.get("experience_settings", {})
	if typeof(experience_settings) != TYPE_DICTIONARY:
		return

	if not experience_settings.has("hotspots") and experience_settings.has("info_hotspots"):
		experience_settings["hotspots"] = experience_settings.get("info_hotspots", [])

	profile["experience_settings"] = experience_settings
