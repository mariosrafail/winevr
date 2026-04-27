extends SceneTree

const REGISTRY_PATH := "res://data/client_registry.json"
const CLIENTS_DIR := "res://clients"

var _errors: int = 0
var _warnings: int = 0


func _initialize() -> void:
	print("WineVR config validation")
	_validate()
	print("Validation finished: %s error(s), %s warning(s)" % [_errors, _warnings])
	quit(1 if _errors > 0 else 0)


func _validate() -> void:
	var registry: Array = _read_json_array(REGISTRY_PATH)
	if registry.is_empty():
		_error("Registry is empty or invalid: %s" % REGISTRY_PATH)
		return

	var client_ids: Dictionary = {}
	var qr_ids: Dictionary = {}
	for index in range(registry.size()):
		var entry: Variant = registry[index]
		if typeof(entry) != TYPE_DICTIONARY:
			_error("Registry entry %s must be an object." % index)
			continue
		var client_id: String = str((entry as Dictionary).get("client_id", ""))
		var qr_id: String = str((entry as Dictionary).get("qr_id", ""))
		if client_id.is_empty():
			_error("Registry entry %s is missing client_id." % index)
		elif client_ids.has(client_id):
			_error("Duplicate client_id in registry: %s" % client_id)
		else:
			client_ids[client_id] = true
		if qr_id.is_empty():
			_error("Registry entry %s is missing qr_id." % index)
		elif qr_ids.has(qr_id):
			_error("Duplicate qr_id in registry: %s" % qr_id)
		else:
			qr_ids[qr_id] = true

		if not client_id.is_empty():
			var profile_path: String = _profile_path(client_id)
			if not FileAccess.file_exists(profile_path):
				_error("Registry client '%s' is missing profile file: %s" % [client_id, profile_path])

	_validate_profile_files(client_ids)


func _validate_profile_files(registry_client_ids: Dictionary) -> void:
	var dir: DirAccess = DirAccess.open(CLIENTS_DIR)
	if dir == null:
		_error("Unable to open clients directory: %s" % CLIENTS_DIR)
		return

	var profile_client_ids: Dictionary = {}
	var profile_qr_ids: Dictionary = {}
	dir.list_dir_begin()
	var entry_name: String = dir.get_next()
	while not entry_name.is_empty():
		if dir.current_is_dir() and not entry_name.begins_with("."):
			var profile_path: String = "%s/%s/config.json" % [CLIENTS_DIR, entry_name]
			if FileAccess.file_exists(profile_path):
				_validate_profile(profile_path, registry_client_ids, profile_client_ids, profile_qr_ids)
			else:
				_warn("Client folder has no config.json: %s" % entry_name)
		entry_name = dir.get_next()
	dir.list_dir_end()


func _validate_profile(profile_path: String, registry_client_ids: Dictionary, profile_client_ids: Dictionary, profile_qr_ids: Dictionary) -> void:
	var profile: Dictionary = _read_json_dict(profile_path)
	if profile.is_empty():
		_error("Profile is empty or invalid: %s" % profile_path)
		return

	var client_id: String = str(profile.get("client_id", ""))
	if client_id.is_empty():
		_error("%s missing client_id." % profile_path)
	elif profile_client_ids.has(client_id):
		_error("Duplicate client_id across profile files: %s" % client_id)
	else:
		profile_client_ids[client_id] = true
		if not registry_client_ids.has(client_id):
			_warn("Profile '%s' is not listed in registry." % client_id)

	var qr_id: String = str(profile.get("qr_id", ""))
	if qr_id.is_empty():
		_error("%s missing qr_id." % profile_path)
	elif profile_qr_ids.has(qr_id):
		_error("Duplicate qr_id across profile files: %s" % qr_id)
	else:
		profile_qr_ids[qr_id] = true

	var hotspots: Dictionary = {}
	var experience_settings: Dictionary = _dict_value(profile.get("experience_settings", {}))
	for raw_hotspot in experience_settings.get("hotspots", []):
		if typeof(raw_hotspot) != TYPE_DICTIONARY:
			_warn("%s has a non-object hotspot entry." % profile_path)
			continue
		var hotspot: Dictionary = raw_hotspot as Dictionary
		var hotspot_id: String = str(hotspot.get("id", hotspot.get("title", "")))
		if hotspot_id.is_empty():
			_error("%s has a hotspot without id/title." % profile_path)
		elif hotspots.has(hotspot_id):
			_error("%s has duplicate hotspot id: %s" % [profile_path, hotspot_id])
		else:
			hotspots[hotspot_id] = true

	var environment_settings: Dictionary = _dict_value(profile.get("environment_settings", {}))
	var visual_quality: String = str(environment_settings.get("visual_quality", "medium"))
	if not ["low", "medium", "high"].has(visual_quality):
		_warn("%s has unknown visual_quality '%s'." % [profile_path, visual_quality])
	var floor_pattern: String = str(environment_settings.get("floor_pattern", "stone"))
	if not ["stone", "tile", "plank", "smooth"].has(floor_pattern):
		_warn("%s has unknown floor_pattern '%s'." % [profile_path, floor_pattern])
	var wall_pattern: String = str(environment_settings.get("wall_pattern", "blocks"))
	if not ["blocks", "panels", "smooth"].has(wall_pattern):
		_warn("%s has unknown wall_pattern '%s'." % [profile_path, wall_pattern])
	var zones: Dictionary = {}
	for raw_zone in environment_settings.get("zones", []):
		if typeof(raw_zone) != TYPE_DICTIONARY:
			_warn("%s has a non-object zone entry." % profile_path)
			continue
		var zone_id: String = str((raw_zone as Dictionary).get("id", ""))
		if not zone_id.is_empty():
			zones[zone_id] = true

	var props: Dictionary = {}
	for raw_prop in environment_settings.get("props", []):
		if typeof(raw_prop) != TYPE_DICTIONARY:
			_warn("%s has a non-object prop entry." % profile_path)
			continue
		var prop_id: String = str((raw_prop as Dictionary).get("id", ""))
		if not prop_id.is_empty():
			props[prop_id] = true

	for raw_step in profile.get("narrative_steps", []):
		if typeof(raw_step) != TYPE_DICTIONARY:
			_warn("%s has a non-object narrative step." % profile_path)
			continue
		var step: Dictionary = raw_step as Dictionary
		var step_id: String = str(step.get("id", "<missing id>"))
		var target_type: String = str(step.get("target_type", "free"))
		var target_id: String = str(step.get("target_id", ""))
		match target_type:
			"hotspot":
				if not hotspots.has(target_id):
					_error("%s narrative step '%s' references missing hotspot '%s'." % [profile_path, step_id, target_id])
			"zone", "door":
				if not zones.has(target_id):
					_error("%s narrative step '%s' references missing zone/door '%s'." % [profile_path, step_id, target_id])
			"prop":
				if not props.has(target_id):
					_error("%s narrative step '%s' references missing prop '%s'." % [profile_path, step_id, target_id])
			"free":
				pass
			_:
				_warn("%s narrative step '%s' has unknown target_type '%s'." % [profile_path, step_id, target_type])


func _read_json_array(path: String) -> Array:
	var parsed: Variant = _read_json(path)
	if typeof(parsed) == TYPE_ARRAY:
		return parsed as Array
	return []


func _read_json_dict(path: String) -> Dictionary:
	var parsed: Variant = _read_json(path)
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed as Dictionary
	return {}


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		_error("Missing JSON file: %s" % path)
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_error("Unable to open JSON file: %s" % path)
		return null
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed == null:
		_error("Invalid JSON: %s" % path)
	return parsed


func _dict_value(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return value as Dictionary
	return {}


func _profile_path(client_id: String) -> String:
	return "%s/%s/config.json" % [CLIENTS_DIR, client_id]


func _error(message: String) -> void:
	_errors += 1
	push_error(message)


func _warn(message: String) -> void:
	_warnings += 1
	push_warning(message)
