extends Node
class_name UIModalPriorityManager

signal modal_opened(id: String)
signal modal_closed(id: String)
signal modal_focus_applied(id: String)

var _panels: Dictionary = {}
var _active_modal_id: String = ""
var _applying_focus: bool = false
var _raised_canvas: CanvasLayer
var _original_canvas_layer: int = 0


func register_panel(id: String, control: Control, priority: int, close_callback: Callable = Callable()) -> void:
	if id.is_empty() or control == null:
		return
	_panels[id] = {
		"control": control,
		"priority": priority,
		"close_callback": close_callback,
		"mouse_filters": _capture_mouse_filters(control)
	}
	_apply_focus()


func open_modal(id: String) -> void:
	if not _panels.has(id):
		return
	close_all_except(id)
	_active_modal_id = id
	_bring_to_front(_panel_control(id))
	_apply_focus()
	print("[WineVR][UI] Modal opened: %s" % id)
	modal_opened.emit(id)


func close_modal(id: String) -> void:
	if not _panels.has(id):
		return
	if _active_modal_id == id:
		_active_modal_id = ""
	print("[WineVR][UI] Modal closed: %s" % id)
	modal_closed.emit(id)
	_apply_focus()


func close_all_except(id: String) -> void:
	for panel_id in _panels.keys():
		var panel_key: String = str(panel_id)
		if panel_key == id:
			continue
		var control: Control = _panel_control(panel_key)
		if control == null or not control.visible:
			continue
		var close_callback: Callable = _panels[panel_key].get("close_callback", Callable())
		if close_callback.is_valid():
			close_callback.call()
		elif _active_modal_id == panel_key:
			_active_modal_id = ""


func has_active_modal() -> bool:
	var active_control: Control = _panel_control(_active_modal_id)
	if active_control == null or not active_control.visible:
		_active_modal_id = ""
		_apply_focus()
		return false
	return not _active_modal_id.is_empty()


func get_active_modal_id() -> String:
	has_active_modal()
	return _active_modal_id


func refresh() -> void:
	_apply_focus()


func suppress_tooltip_if_needed() -> bool:
	if not has_active_modal():
		return false
	print("[WineVR][UI] Suppressed tooltip because modal active: %s" % _active_modal_id)
	return true


func _apply_focus() -> void:
	if _applying_focus:
		return
	_applying_focus = true
	var active_control: Control = _panel_control(_active_modal_id)
	_restore_canvas_layer()
	for panel_id in _panels.keys():
		var id: String = str(panel_id)
		var control: Control = _panel_control(id)
		if control == null:
			continue
		if active_control != null and id != _active_modal_id:
			_set_mouse_filter_recursive(control, Control.MOUSE_FILTER_IGNORE)
		else:
			_restore_mouse_filters(id)
			if active_control != null and id == _active_modal_id:
				control.mouse_filter = Control.MOUSE_FILTER_STOP
	if active_control != null:
		# z_index cannot bring a panel above a different CanvasLayer. The
		# winery info panel lives outside the main HUD canvas.
		var canvas: Node = active_control.get_parent()
		while canvas != null and not canvas is CanvasLayer:
			canvas = canvas.get_parent()
		if canvas is CanvasLayer:
			_raised_canvas = canvas as CanvasLayer
			_original_canvas_layer = _raised_canvas.layer
			_raised_canvas.layer = 100
		_bring_to_front(active_control)
		print("[WineVR][UI] Modal focus applied: %s" % _active_modal_id)
		modal_focus_applied.emit(_active_modal_id)
	_applying_focus = false


func _restore_canvas_layer() -> void:
	if is_instance_valid(_raised_canvas):
		_raised_canvas.layer = _original_canvas_layer
	_raised_canvas = null


func _panel_control(id: String) -> Control:
	if id.is_empty() or not _panels.has(id):
		return null
	return _panels[id].get("control", null) as Control


func _bring_to_front(control: Control) -> void:
	if control == null:
		return
	control.z_index = maxi(control.z_index, 1000 + int(_priority_for_control(control)))
	var parent: Node = control.get_parent()
	if parent != null:
		parent.move_child(control, parent.get_child_count() - 1)


func _priority_for_control(control: Control) -> int:
	for panel_id in _panels.keys():
		var data: Dictionary = _panels[panel_id]
		if data.get("control", null) == control:
			return int(data.get("priority", 0))
	return control.z_index


func _capture_mouse_filters(control: Control) -> Dictionary:
	var filters: Dictionary = {}
	_capture_mouse_filters_recursive(control, filters)
	return filters


func _capture_mouse_filters_recursive(node: Node, filters: Dictionary) -> void:
	if node is Control:
		filters[node.get_instance_id()] = (node as Control).mouse_filter
	for child in node.get_children():
		_capture_mouse_filters_recursive(child, filters)


func _restore_mouse_filters(id: String) -> void:
	if not _panels.has(id):
		return
	var data: Dictionary = _panels[id]
	var control: Control = data.get("control", null) as Control
	var filters: Dictionary = data.get("mouse_filters", {})
	if control == null:
		return
	for instance_id in filters.keys():
		var target: Control = instance_from_id(int(instance_id)) as Control
		if target != null:
			target.mouse_filter = int(filters[instance_id])
	_restore_uncaptured_active_controls(control, filters)


func _restore_uncaptured_active_controls(node: Node, filters: Dictionary) -> void:
	if node is Control:
		var control: Control = node as Control
		if not filters.has(control.get_instance_id()) and control.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			control.mouse_filter = Control.MOUSE_FILTER_PASS
	for child in node.get_children():
		_restore_uncaptured_active_controls(child, filters)


func _set_mouse_filter_recursive(node: Node, filter: int) -> void:
	if node is Control:
		(node as Control).mouse_filter = filter
	for child in node.get_children():
		_set_mouse_filter_recursive(child, filter)
