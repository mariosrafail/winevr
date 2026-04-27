extends Node

signal narrative_changed(current_step: Dictionary, current_index: int, total_steps: int)
signal step_completed(step_id: String)
signal narrative_completed

var narrative_steps: Array[Dictionary] = []
var completed_step_ids: Dictionary = {}
var current_step_index: int = 0


func _ready() -> void:
	ClientProfileLoader.client_profile_changed.connect(_on_client_profile_changed)
	load_from_client_data(ClientProfileLoader.get_active_client_data())


func load_from_client_data(client_data: Dictionary) -> void:
	narrative_steps.clear()
	completed_step_ids.clear()
	current_step_index = 0

	for raw_step in client_data.get("narrative_steps", []):
		if typeof(raw_step) != TYPE_DICTIONARY:
			continue
		var step: Dictionary = (raw_step as Dictionary).duplicate(true)
		step["id"] = str(step.get("id", "step_%s" % narrative_steps.size()))
		step["title"] = str(step.get("title", "Guided Step"))
		step["text"] = str(step.get("text", ""))
		step["target_type"] = str(step.get("target_type", "free"))
		step["target_id"] = str(step.get("target_id", ""))
		step["required"] = bool(step.get("required", true))
		if step.has("next_step_id"):
			step["next_step_id"] = str(step.get("next_step_id", ""))
		narrative_steps.append(step)

	_emit_current_step()


func reset() -> void:
	completed_step_ids.clear()
	current_step_index = 0
	_emit_current_step()


func get_current_step() -> Dictionary:
	if narrative_steps.is_empty() or current_step_index < 0 or current_step_index >= narrative_steps.size():
		return {}
	return narrative_steps[current_step_index].duplicate(true)


func get_progress_text() -> String:
	if narrative_steps.is_empty():
		return "0/0"
	return "%s/%s" % [current_step_index + 1, narrative_steps.size()]


func can_advance_current_step() -> bool:
	var step: Dictionary = get_current_step()
	if step.is_empty():
		return false

	return true


func next_step() -> void:
	var step: Dictionary = get_current_step()
	if step.is_empty():
		return

	complete_step(str(step.get("id", "")), false)

	if not can_advance_current_step():
		_emit_current_step()
		return

	var next_step_id: String = str(step.get("next_step_id", ""))
	if not next_step_id.is_empty():
		var explicit_index: int = _find_step_index(next_step_id)
		if explicit_index >= 0:
			current_step_index = explicit_index
			_skip_completed_steps()
			_emit_current_step()
			return

	current_step_index += 1
	_skip_completed_steps()
	if current_step_index >= narrative_steps.size():
		current_step_index = narrative_steps.size()
		narrative_changed.emit({}, current_step_index, narrative_steps.size())
		narrative_completed.emit()
		return

	_emit_current_step()


func complete_step(step_id: String, advance_if_current: bool = true) -> void:
	if step_id.is_empty() or completed_step_ids.has(step_id):
		return

	completed_step_ids[step_id] = true
	step_completed.emit(step_id)

	var current_step: Dictionary = get_current_step()
	if advance_if_current and str(current_step.get("id", "")) == step_id:
		next_step()
	else:
		_emit_current_step()


func complete_target(target_type: String, target_id: String) -> void:
	if target_type.is_empty() or target_id.is_empty():
		return

	for raw_step in narrative_steps:
		var step: Dictionary = raw_step
		var step_id: String = str(step.get("id", ""))
		if completed_step_ids.has(step_id):
			continue
		if str(step.get("target_type", "")) == target_type and str(step.get("target_id", "")) == target_id:
			complete_step(step_id)
			return


func is_step_completed(step_id: String) -> bool:
	return completed_step_ids.has(step_id)


func _on_client_profile_changed(_client_id: String, client_data: Dictionary) -> void:
	load_from_client_data(client_data)


func _find_step_index(step_id: String) -> int:
	for index in range(narrative_steps.size()):
		if str(narrative_steps[index].get("id", "")) == step_id:
			return index
	return -1


func _skip_completed_steps() -> void:
	while current_step_index < narrative_steps.size():
		var step: Dictionary = narrative_steps[current_step_index]
		var step_id: String = str(step.get("id", ""))
		if not completed_step_ids.has(step_id):
			return
		current_step_index += 1


func _emit_current_step() -> void:
	narrative_changed.emit(get_current_step(), current_step_index, narrative_steps.size())
