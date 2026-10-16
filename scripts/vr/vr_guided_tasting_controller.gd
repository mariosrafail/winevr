extends Node3D
class_name VRGuidedTastingController

const PANEL_SCENE: PackedScene = preload("res://scenes/vr/VRGuidedStepPanel.tscn")
const PANEL_OFFSET: Vector3 = Vector3(0.0, -0.35, -1.2)
const FOLLOW_SPEED: float = 7.5
const COMPLETE_DELAY_SECONDS: float = 0.7
const FALLBACK_STEPS: Array[Dictionary] = [
	{
		"id": "origin",
		"title": "Step 1",
		"instruction": "Discover where this wine comes from.",
		"target_type": "hotspot",
		"target_id": "origin"
	},
	{
		"id": "aroma",
		"title": "Step 2",
		"instruction": "Explore the aroma notes.",
		"target_type": "hotspot",
		"target_id": "aroma"
	},
	{
		"id": "craft",
		"title": "Step 3",
		"instruction": "Learn how this wine was crafted.",
		"target_type": "hotspot",
		"target_id": "craft"
	},
	{
		"id": "cellar_door",
		"title": "Step 4",
		"instruction": "Open the cellar door and enter the winery story.",
		"target_type": "door",
		"target_id": "cellar_door"
	}
]

var _camera: Camera3D
var _panel: Node3D
var _step_label: Label3D
var _instruction_label: Label3D
var _progress_label: Label3D
var _steps: Array[Dictionary] = []
var _current_index: int = -1
var _enabled: bool = false
var _completion_pending: bool = false
var _highlight_target: Callable
var _clear_highlight: Callable
var _target_available: Callable


func _ready() -> void:
	_build_panel()
	set_process(false)


func setup(camera: Camera3D, highlight_target: Callable, clear_highlight: Callable, target_available: Callable) -> void:
	_camera = camera
	_highlight_target = highlight_target
	_clear_highlight = clear_highlight
	_target_available = target_available


func configure_from_profile(client_data: Dictionary) -> void:
	_steps = _build_steps(client_data)
	_current_index = -1
	_completion_pending = false


func set_enabled(enabled: bool) -> void:
	_enabled = enabled and _camera != null and not _steps.is_empty()
	set_process(_enabled)
	if not _enabled:
		_hide_panel()
		_call_clear_highlight()
		return
	if _current_index < 0:
		_current_index = 0
		print("[WineVR][VR] Guided tasting started")
	_show_current_step()


func notify_interaction(data: Dictionary) -> void:
	if not _enabled or _completion_pending or _current_index < 0 or _current_index >= _steps.size():
		return
	var current_step: Dictionary = _steps[_current_index]
	var target_id: String = str(current_step.get("target_id", ""))
	var interacted_id: String = str(data.get("id", ""))
	if target_id.is_empty() or interacted_id != target_id:
		return
	_completion_pending = true
	var step_id: String = str(current_step.get("id", target_id))
	print("[WineVR][VR] Guided step complete: %s" % step_id)
	_show_completion_message("Tasting step complete")
	_call_clear_highlight()
	await get_tree().create_timer(COMPLETE_DELAY_SECONDS).timeout
	if not _enabled:
		return
	_current_index += 1
	_completion_pending = false
	if _current_index >= _steps.size():
		print("[WineVR][VR] Guided tasting complete")
		_show_completion_message("Tasting journey complete")
		await get_tree().create_timer(1.6).timeout
		_hide_panel()
		set_process(false)
		_enabled = false
		return
	var next_step: Dictionary = _steps[_current_index]
	print("[WineVR][VR] Guided next step: %s" % str(next_step.get("id", next_step.get("target_id", ""))))
	_show_current_step()


func _process(delta: float) -> void:
	if _panel == null or _camera == null or not _panel.visible:
		return
	var target_position: Vector3 = _camera.global_transform * PANEL_OFFSET
	var factor: float = clampf(delta * FOLLOW_SPEED, 0.0, 1.0)
	_panel.global_position = _panel.global_position.lerp(target_position, factor)
	_panel.look_at(_camera.global_position, Vector3.UP)


func _build_panel() -> void:
	if _panel != null:
		return
	_panel = PANEL_SCENE.instantiate() as Node3D
	if _panel == null:
		push_warning("[WineVR][VR] Guided panel unavailable")
		return
	add_child(_panel)
	_step_label = _panel.get_node_or_null("StepLabel") as Label3D
	_instruction_label = _panel.get_node_or_null("InstructionLabel") as Label3D
	_progress_label = _panel.get_node_or_null("ProgressLabel") as Label3D
	_panel.visible = false


func _build_steps(client_data: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var raw_steps: Array = []
	if client_data.has("narrative_steps") and client_data.get("narrative_steps") is Array:
		raw_steps = client_data.get("narrative_steps") as Array
	for raw_step in raw_steps:
		if raw_step is Dictionary:
			_append_step_if_available(result, raw_step as Dictionary)
	if result.is_empty():
		for fallback_step in FALLBACK_STEPS:
			_append_step_if_available(result, fallback_step)
	return result


func _append_step_if_available(result: Array[Dictionary], raw_step: Dictionary) -> void:
	var target_id: String = str(raw_step.get("target_id", ""))
	var target_type: String = str(raw_step.get("target_type", ""))
	if target_id.is_empty() or target_type == "free":
		return
	if not _is_target_available(target_type, target_id):
		print("[WineVR][VR] Guided target unavailable: %s" % target_id)
		return
	result.append({
		"id": str(raw_step.get("id", target_id)),
		"title": str(raw_step.get("title", "Tasting Step")),
		"instruction": str(raw_step.get("instruction", raw_step.get("text", ""))),
		"target_type": target_type,
		"target_id": target_id
	})


func _show_current_step() -> void:
	if _panel == null or _current_index < 0 or _current_index >= _steps.size():
		return
	var step: Dictionary = _steps[_current_index]
	if _step_label != null:
		_step_label.text = str(step.get("title", "Tasting Step"))
	if _instruction_label != null:
		_instruction_label.text = _wrap_text(str(step.get("instruction", "")), 38, 3)
	if _progress_label != null:
		_progress_label.text = "%s / %s" % [_current_index + 1, _steps.size()]
	_position_panel_now()
	_panel.visible = true
	var step_id: String = str(step.get("id", step.get("target_id", "")))
	print("[WineVR][VR] Guided step shown: %s" % step_id)
	var highlighted: bool = _call_highlight(str(step.get("target_type", "")), str(step.get("target_id", "")))
	if not highlighted:
		print("[WineVR][VR] Guided target unavailable: %s" % str(step.get("target_id", "")))


func _show_completion_message(message: String) -> void:
	if _panel == null:
		return
	if _step_label != null:
		_step_label.text = message
	if _instruction_label != null:
		_instruction_label.text = "Look around the cellar for the next cue."
	if _progress_label != null:
		_progress_label.text = "%s / %s" % [mini(_current_index + 1, _steps.size()), _steps.size()]
	_position_panel_now()
	_panel.visible = true


func _position_panel_now() -> void:
	if _panel == null or _camera == null:
		return
	_panel.global_position = _camera.global_transform * PANEL_OFFSET
	_panel.look_at(_camera.global_position, Vector3.UP)


func _hide_panel() -> void:
	if _panel != null:
		_panel.visible = false


func _call_highlight(target_type: String, target_id: String) -> bool:
	if not _highlight_target.is_valid():
		return false
	var result: Variant = _highlight_target.call(target_type, target_id)
	return bool(result)


func _call_clear_highlight() -> void:
	if _clear_highlight.is_valid():
		_clear_highlight.call()


func _is_target_available(target_type: String, target_id: String) -> bool:
	if not _target_available.is_valid():
		return false
	var result: Variant = _target_available.call(target_type, target_id)
	return bool(result)


func _wrap_text(value: String, max_chars: int, max_lines: int) -> String:
	var words: PackedStringArray = value.strip_edges().split(" ", false)
	var lines: Array[String] = []
	var current: String = ""
	for word in words:
		var candidate: String = word if current.is_empty() else current + " " + word
		if candidate.length() > max_chars and not current.is_empty():
			lines.append(current)
			current = word
			if lines.size() >= max_lines:
				break
		else:
			current = candidate
	if lines.size() < max_lines and not current.is_empty():
		lines.append(current)
	if lines.is_empty():
		lines.append("Follow the highlighted cellar detail.")
	return "\n".join(lines)
