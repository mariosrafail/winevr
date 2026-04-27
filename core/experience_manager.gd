extends Node

signal state_changed(previous_state: int, current_state: int)

enum ExperienceState {
	QR_SCAN,
	INTRO,
	VIAL_INSPECTION,
	WINERY_ENTRY,
	WINERY_INTERIOR
}

var current_state: int = ExperienceState.QR_SCAN


func show_qr_scan() -> void:
	_set_state(ExperienceState.QR_SCAN)


func enter_intro() -> void:
	_set_state(ExperienceState.INTRO)


func start_experience() -> void:
	_set_state(ExperienceState.VIAL_INSPECTION)


func enter_vial_inspection() -> void:
	_set_state(ExperienceState.VIAL_INSPECTION)


func enter_winery() -> void:
	_set_state(ExperienceState.WINERY_ENTRY)


func finish_winery_entry() -> void:
	_set_state(ExperienceState.WINERY_INTERIOR)


func return_to_vial() -> void:
	_set_state(ExperienceState.VIAL_INSPECTION)


func return_to_intro() -> void:
	_set_state(ExperienceState.INTRO)


func _set_state(next_state: int) -> void:
	if current_state == next_state:
		return

	var previous_state: int = current_state
	current_state = next_state
	state_changed.emit(previous_state, current_state)
