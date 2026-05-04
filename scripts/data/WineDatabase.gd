extends Node

const PROFILES_PATH: String = "res://data/tasting_profiles/profiles.json"
const USER_PROFILES_PATH: String = "user://profiles.json"
const EXTERNAL_PROFILES_FILENAME: String = "profiles.json"

var _profiles: Array[Dictionary] = []
var _profiles_by_id: Dictionary = {}
var _used_fallback: bool = false
var _loaded_source: String = ""


func _ready() -> void:
	_export_profiles_next_to_executable_if_missing()
	export_default_profiles_to_user_folder()
	load_profiles()


func load_profiles() -> void:
	_profiles.clear()
	_profiles_by_id.clear()
	_used_fallback = false
	_loaded_source = ""

	var loaded_ok: bool = false
	var executable_neighbor_path: String = _get_executable_neighbor_profiles_path()

	# Priority 1: user://profiles.json
	loaded_ok = _load_profiles_from_json(USER_PROFILES_PATH, "user://profiles.json")

	# Priority 2: profiles.json next to exported executable
	if not loaded_ok:
		loaded_ok = _load_profiles_from_json(executable_neighbor_path, executable_neighbor_path)

	# Priority 3: internal bundled default
	if not loaded_ok:
		loaded_ok = _load_profiles_from_json(PROFILES_PATH, PROFILES_PATH)

	# Priority 4: built-in hardcoded fallback
	if not loaded_ok:
		_used_fallback = true
		_loaded_source = "built-in fallback"
		print("[WineDB] All JSON sources failed. Using built-in fallback demo profiles.")
		_load_fallback_profiles()

	if _profiles.is_empty():
		push_error("[WineDB] No tasting profiles available (JSON + fallback failed).")
	else:
		print("[WineDB] Database loaded. source=%s profiles=%s fallback_used=%s" % [_loaded_source, str(_profiles.size()), str(_used_fallback)])


func export_default_profiles_to_user_folder() -> bool:
	if FileAccess.file_exists(USER_PROFILES_PATH):
		return true
	if not FileAccess.file_exists(PROFILES_PATH):
		print("[WineDB] Cannot export defaults: missing " + PROFILES_PATH)
		return false

	var source: FileAccess = FileAccess.open(PROFILES_PATH, FileAccess.READ)
	if source == null:
		print("[WineDB] Cannot export defaults: failed to open " + PROFILES_PATH)
		return false
	var content: String = source.get_as_text()

	var output: FileAccess = FileAccess.open(USER_PROFILES_PATH, FileAccess.WRITE)
	if output == null:
		print("[WineDB] Cannot export defaults: failed to write " + USER_PROFILES_PATH)
		return false
	output.store_string(content)
	print("[WineDB] Exported default profiles to " + USER_PROFILES_PATH)
	return true


func _export_profiles_next_to_executable_if_missing() -> bool:
	var external_path: String = _get_executable_neighbor_profiles_path()
	if external_path.is_empty():
		return false
	if FileAccess.file_exists(external_path):
		return true

	var content: String = ""
	if FileAccess.file_exists(PROFILES_PATH):
		var source: FileAccess = FileAccess.open(PROFILES_PATH, FileAccess.READ)
		if source != null:
			content = source.get_as_text()
	if content.is_empty():
		content = JSON.stringify(_fallback_profiles(), "\t")

	var output: FileAccess = FileAccess.open(external_path, FileAccess.WRITE)
	if output == null:
		print("[WineDB] Cannot export defaults next to executable: " + external_path)
		return false
	output.store_string(content)
	print("[WineDB] Exported default profiles next to executable: " + external_path)
	return true


func has_profiles() -> bool:
	return not _profiles.is_empty()


func get_all_profiles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for profile in _profiles:
		result.append(profile.duplicate(true))
	return result


func get_profile_by_id(profile_id: String) -> Dictionary:
	if _profiles_by_id.has(profile_id):
		return (_profiles_by_id[profile_id] as Dictionary).duplicate(true)
	return {}


func get_default_profile() -> Dictionary:
	for profile in _profiles:
		if bool(profile.get("unlocked_by_default", false)):
			return profile.duplicate(true)
	if not _profiles.is_empty():
		return (_profiles[0] as Dictionary).duplicate(true)
	return {}


func get_hotspots_for_profile(profile_id: String) -> Array[Dictionary]:
	var profile: Dictionary = get_profile_by_id(profile_id)
	if profile.is_empty():
		return []
	var hotspots: Array[Dictionary] = []
	for raw_hotspot in profile.get("hotspots", []):
		if typeof(raw_hotspot) == TYPE_DICTIONARY:
			hotspots.append((raw_hotspot as Dictionary).duplicate(true))
	return hotspots


func get_selection_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for profile in _profiles:
		entries.append({
			"client_id": str(profile.get("id", "")),
			"display_name": str(profile.get("name", "")),
			"wine_name": str(profile.get("name", "")),
			"winery": str(profile.get("winery", "")),
			"region": str(profile.get("region", "")),
			"wine_type": str(profile.get("wine_type", "")),
			"enabled": true
		})
	return entries


func build_runtime_client_profile(profile: Dictionary) -> Dictionary:
	var profile_id: String = str(profile.get("id", "demo_profile"))
	var wine_name: String = str(profile.get("name", "Demo Wine"))
	var winery: String = str(profile.get("winery", "Demo Winery"))
	var region: String = str(profile.get("region", "Greece"))
	var story_text: String = str(profile.get("story", ""))
	var color_hex: String = str(profile.get("color_hex", "#7A1E2B"))
	var description: String = str(profile.get("description", ""))
	var wine_type: String = str(profile.get("wine_type", "Wine"))
	var vintage: String = str(profile.get("vintage", ""))

	var hotspots: Array = _map_hotspots_to_experience(profile.get("hotspots", []))
	var narrative_steps: Array = _map_hotspots_to_narrative(profile.get("hotspots", []), story_text)

	return {
		"client_id": profile_id,
		"winery_name": winery,
		"wine_name": wine_name,
		"region_name": region,
		"country": "Greece",
		"qr_id": profile_id,
		"vial_settings": {
			"liquid_fill_amount": 0.72,
			"liquid_color": color_hex,
			"cap_color": "#1D1A18"
		},
		"experience_settings": {
			"intro_title": wine_name + " " + vintage,
			"intro_text": description + "\n\n" + story_text,
			"hotspots": hotspots,
			"scenes": ["vial_preview", "winery"],
			"winery_scene_name": str(profile.get("scene_theme", "default_cellar")),
			"winery_info_text": _build_winery_info(profile)
		},
		"environment_settings": {
			"environment_id": str(profile.get("scene_theme", "default_cellar")),
			"scene_type": "classic_stone_cellar",
			"lighting_preset": "cinematic_warm",
			"wall_color": "#8B8172",
			"floor_color": "#51483D",
			"barrel_color": "#734A2D",
			"door_color": "#51341F",
			"ambience_text": _build_winery_info(profile),
			"interactables": [{
				"id": "cellar_door",
				"title": "Cellar Door",
				"text": "Continue to the guided tasting room.",
				"type": "door",
				"position": [0.0, 0.0, -2.9]
			}],
			"props": _build_profile_props(profile),
			"zones": _build_profile_zones(profile),
			"camera_start": {
				"position": [0.0, 0.0, 1.55],
				"rotation": [0.0, 0.0, 0.0]
			}
		},
		"narrative_steps": narrative_steps
	}


func _load_profiles_from_json(path: String, source_label: String) -> bool:
	if path.is_empty():
		return false
	if not FileAccess.file_exists(path):
		print("[WineDB] profiles.json not found at: " + source_label)
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		print("[WineDB] Could not open profiles.json at: " + source_label)
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		print("[WineDB] profiles.json must be a JSON array at: " + source_label)
		return false

	for raw_profile in parsed:
		if typeof(raw_profile) != TYPE_DICTIONARY:
			continue
		var normalized: Dictionary = _normalize_profile(raw_profile as Dictionary)
		if _validate_profile(normalized):
			_add_profile(normalized)

	var success: bool = not _profiles.is_empty()
	if success:
		_loaded_source = source_label
		print("[WineDB] Loaded profiles from " + source_label + " count=" + str(_profiles.size()))
	return success


func _load_fallback_profiles() -> void:
	for profile in _fallback_profiles():
		var normalized: Dictionary = _normalize_profile(profile)
		if _validate_profile(normalized):
			_add_profile(normalized)


func _add_profile(profile: Dictionary) -> void:
	var id: String = str(profile.get("id", ""))
	if id.is_empty() or _profiles_by_id.has(id):
		return
	_profiles.append(profile)
	_profiles_by_id[id] = profile


func _normalize_profile(profile: Dictionary) -> Dictionary:
	var p: Dictionary = profile.duplicate(true)
	p["id"] = str(p.get("id", ""))
	p["name"] = str(p.get("name", "Untitled Wine"))
	p["winery"] = str(p.get("winery", "Unknown Winery"))
	p["region"] = str(p.get("region", "Unknown Region"))
	p["grape_variety"] = str(p.get("grape_variety", "Unknown"))
	p["wine_type"] = str(p.get("wine_type", "Wine"))
	p["vintage"] = str(p.get("vintage", ""))
	p["description"] = str(p.get("description", ""))
	p["story"] = str(p.get("story", ""))
	p["color_hex"] = str(p.get("color_hex", "#7A1E2B"))
	p["scene_theme"] = str(p.get("scene_theme", "default_cellar"))
	p["unlocked_by_default"] = bool(p.get("unlocked_by_default", false))
	p["tasting_notes"] = _normalize_string_array(p.get("tasting_notes", []))
	p["aroma_notes"] = _normalize_string_array(p.get("aroma_notes", []))
	p["pairing_suggestions"] = _normalize_string_array(p.get("pairing_suggestions", []))

	var normalized_hotspots: Array = []
	for raw_hotspot in p.get("hotspots", []):
		if typeof(raw_hotspot) != TYPE_DICTIONARY:
			continue
		var hotspot: Dictionary = (raw_hotspot as Dictionary).duplicate(true)
		hotspot["id"] = str(hotspot.get("id", "hotspot_" + str(normalized_hotspots.size())))
		hotspot["title"] = str(hotspot.get("title", "Hotspot"))
		hotspot["description"] = str(hotspot.get("description", ""))
		hotspot["target_node_name"] = str(hotspot.get("target_node_name", "VialBody"))
		hotspot["order"] = int(hotspot.get("order", normalized_hotspots.size() + 1))
		hotspot["completion_required"] = bool(hotspot.get("completion_required", true))
		normalized_hotspots.append(hotspot)
	p["hotspots"] = normalized_hotspots
	return p


func _validate_profile(profile: Dictionary) -> bool:
	for field in [
		"id", "name", "winery", "region", "grape_variety", "wine_type", "vintage", "description", "tasting_notes",
		"aroma_notes", "pairing_suggestions", "story", "color_hex", "unlocked_by_default", "scene_theme", "hotspots"
	]:
		if not profile.has(field):
			print("[WineDB] Profile missing required field: " + field)
			return false
	if typeof(profile.get("hotspots")) != TYPE_ARRAY:
		print("[WineDB] Profile hotspots must be array for id=" + str(profile.get("id", "")))
		return false
	return true


func _normalize_string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item in value as Array:
		result.append(str(item))
	return result


func _build_winery_info(profile: Dictionary) -> String:
	var tasting_notes: Array = _normalize_string_array(profile.get("tasting_notes", []))
	var aroma_notes: Array = _normalize_string_array(profile.get("aroma_notes", []))
	var pairings: Array = _normalize_string_array(profile.get("pairing_suggestions", []))
	return "[%s] %s\n\nTasting: %s\nAroma: %s\nPairing: %s\n\n%s" % [
		str(profile.get("wine_type", "Wine")),
		str(profile.get("name", "")),
		", ".join(tasting_notes),
		", ".join(aroma_notes),
		", ".join(pairings),
		str(profile.get("story", ""))
	]


func _map_hotspots_to_experience(raw_hotspots: Variant) -> Array:
	var result: Array = []
	if typeof(raw_hotspots) != TYPE_ARRAY:
		return result
	var sorted: Array = (raw_hotspots as Array).duplicate(true)
	sorted.sort_custom(func(a: Variant, b: Variant) -> bool:
		return int((a as Dictionary).get("order", 0)) < int((b as Dictionary).get("order", 0))
	)
	for i in range(sorted.size()):
		var hotspot: Dictionary = sorted[i] as Dictionary
		result.append({
			"id": str(hotspot.get("id", "hotspot_" + str(i))),
			"title": str(hotspot.get("title", "Hotspot")),
			"text": str(hotspot.get("description", "")),
			"category": "tasting",
			"viewed_required_for_winery": bool(hotspot.get("completion_required", true)),
			"screen_position": [0.62 + float(i) * 0.08, 0.38 + float(i % 2) * 0.18]
		})
	return result


func _map_hotspots_to_narrative(raw_hotspots: Variant, story_text: String) -> Array:
	var steps: Array = []
	if typeof(raw_hotspots) == TYPE_ARRAY:
		var sorted: Array = (raw_hotspots as Array).duplicate(true)
		sorted.sort_custom(func(a: Variant, b: Variant) -> bool:
			return int((a as Dictionary).get("order", 0)) < int((b as Dictionary).get("order", 0))
		)
		for i in range(sorted.size()):
			var hotspot: Dictionary = sorted[i] as Dictionary
			steps.append({
				"id": "step_hotspot_" + str(i + 1),
				"title": str(hotspot.get("title", "Tasting Step")),
				"text": str(hotspot.get("description", "")),
				"target_type": "hotspot",
				"target_id": str(hotspot.get("id", "")),
				"required": bool(hotspot.get("completion_required", true))
			})
	steps.append({
		"id": "step_story",
		"title": "Winery Story",
		"text": story_text,
		"target_type": "zone",
		"target_id": "story_zone",
		"required": false
	})
	steps.append({
		"id": "step_finish",
		"title": "Open the Cellar Door",
		"text": "Proceed to the next stage of the tasting experience.",
		"target_type": "door",
		"target_id": "cellar_door",
		"required": true
	})
	return steps


func _build_profile_zones(profile: Dictionary) -> Array:
	return [{
		"id": "story_zone",
		"title": "Estate Story",
		"text": str(profile.get("story", "")),
		"type": "info_zone",
		"position": [0.8, 1.1, -1.6],
		"radius": 0.65
	}, {
		"id": "cellar_door",
		"title": "Cellar Door",
		"text": "Continue to the guided tasting room.",
		"type": "door",
		"position": [0.0, 0.0, -2.9],
		"radius": 0.9
	}]


func _build_profile_props(profile: Dictionary) -> Array:
	return [{
		"id": "tasting_card_profile",
		"type": "tasting_card",
		"position": [0.95, 0.72, -1.78],
		"rotation": [0.0, -22.0, 0.0],
		"scale": [1.0, 1.0, 1.0],
		"label": str(profile.get("name", "Wine"))
	}, {
		"id": "wall_plaque_story",
		"type": "wall_plaque",
		"position": [1.95, 1.46, -3.7],
		"rotation": [0.0, 0.0, 0.0],
		"scale": [1.0, 1.0, 1.0],
		"label": str(profile.get("grape_variety", ""))
	}]


func _fallback_profiles() -> Array[Dictionary]:
	return [
		{
			"id": "assyrtiko_demo",
			"name": "Assyrtiko Demo",
			"winery": "Aegean Cellars",
			"region": "Santorini, Greece",
			"grape_variety": "Assyrtiko",
			"wine_type": "White",
			"vintage": "2023",
			"description": "A saline and mineral island white with bright citrus.",
			"tasting_notes": ["Lemon zest", "Wet stone"],
			"aroma_notes": ["Citrus blossom", "Sea breeze"],
			"pairing_suggestions": ["Seafood", "Goat cheese"],
			"story": "A crisp Mediterranean profile driven by volcanic soils.",
			"color_hex": "#EDE5B8",
			"unlocked_by_default": true,
			"scene_theme": "island_modern",
			"hotspots": [{
				"id": "assyrtiko_origin",
				"title": "Volcanic Origin",
				"description": "Volcanic soils shape this wine.",
				"target_node_name": "VialBody",
				"order": 1,
				"completion_required": true
			}]
		},
		{
			"id": "agiorgitiko_demo",
			"name": "Agiorgitiko Demo",
			"winery": "Nemea Heritage",
			"region": "Nemea, Greece",
			"grape_variety": "Agiorgitiko",
			"wine_type": "Red",
			"vintage": "2022",
			"description": "A velvety red with cherry and spice.",
			"tasting_notes": ["Cherry", "Plum"],
			"aroma_notes": ["Rose", "Cocoa"],
			"pairing_suggestions": ["Lamb", "Aged cheese"],
			"story": "Classic Nemea red with modern precision.",
			"color_hex": "#7A1E2B",
			"unlocked_by_default": true,
			"scene_theme": "classic_cellar",
			"hotspots": [{
				"id": "agiorgitiko_color",
				"title": "Color",
				"description": "Observe the ruby density.",
				"target_node_name": "VialBody",
				"order": 1,
				"completion_required": true
			}]
		},
		{
			"id": "xinomavro_demo",
			"name": "Xinomavro Demo",
			"winery": "Naoussa Ridge",
			"region": "Naoussa, Greece",
			"grape_variety": "Xinomavro",
			"wine_type": "Red",
			"vintage": "2021",
			"description": "Structured, aromatic, and age-worthy.",
			"tasting_notes": ["Sour cherry", "Olive"],
			"aroma_notes": ["Herbs", "Black tea"],
			"pairing_suggestions": ["Braised beef", "Mushrooms"],
			"story": "Northern red with savory complexity.",
			"color_hex": "#5C1723",
			"unlocked_by_default": true,
			"scene_theme": "reserve_winery",
			"hotspots": [{
				"id": "xinomavro_structure",
				"title": "Structure",
				"description": "Notice the firm tannic frame.",
				"target_node_name": "VialBody",
				"order": 1,
				"completion_required": true
			}]
		}
	]


func _get_executable_neighbor_profiles_path() -> String:
	var executable_path: String = OS.get_executable_path()
	if executable_path.is_empty():
		return ""
	var executable_dir: String = executable_path.get_base_dir()
	if executable_dir.is_empty():
		return ""
	return executable_dir.path_join(EXTERNAL_PROFILES_FILENAME)
