extends RefCounted
class_name GuidedExperienceManager

signal step_started(step_index: int, interactable_id: String)
signal step_completed(step_index: int, interactable_id: String)

var ordered_interactable_ids: Array[String] = []
var _current_step_index: int = -1
var _active: bool = false


func configure(step_ids: Array) -> void:
	ordered_interactable_ids.clear()
	for raw_id in step_ids:
		ordered_interactable_ids.append(str(raw_id))
	_current_step_index = -1
	_active = not ordered_interactable_ids.is_empty()
	if _active:
		_current_step_index = 0
		step_started.emit(_current_step_index, get_current_interactable_id())


func is_active() -> bool:
	return _active


func get_current_interactable_id() -> String:
	if _current_step_index < 0 or _current_step_index >= ordered_interactable_ids.size():
		return ""
	return ordered_interactable_ids[_current_step_index]


func can_interact(interactable_id: String) -> bool:
	if not _active:
		return true
	return interactable_id == get_current_interactable_id()


func try_complete_step(interactable_id: String) -> bool:
	if not can_interact(interactable_id):
		return false
	if not _active:
		return true

	var completed_index: int = _current_step_index
	step_completed.emit(completed_index, interactable_id)
	_current_step_index += 1

	if _current_step_index >= ordered_interactable_ids.size():
		_active = false
		_current_step_index = -1
		return true

	step_started.emit(_current_step_index, get_current_interactable_id())
	return true
