extends Node

var selected_profile_id: String = ""
var selected_profile_data: Dictionary = {}


func set_selected_profile(profile_id: String, profile_data: Dictionary) -> void:
	selected_profile_id = profile_id
	selected_profile_data = profile_data.duplicate(true)
	print("[AppState] selected_profile_id=" + selected_profile_id)


func clear_selected_profile() -> void:
	selected_profile_id = ""
	selected_profile_data = {}
