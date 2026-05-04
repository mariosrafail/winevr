extends Node
class_name HotspotUIController

signal hotspot_viewed(hotspot_data: Dictionary)
signal enter_winery_state_changed(all_required_viewed: bool)
signal layout_refresh_requested(reason: String)
signal annotation_closed

var layer: Control
var panel: PanelContainer
var title_label: Label
var text_label: RichTextLabel
var close_button: Button
var panel_dim: ColorRect
var vial_preview: VialPreviewController
var active_hotspots: Array[Dictionary] = []
var viewed_ids: Dictionary = {}
var required_ids: Dictionary = {}
var active_target_id: String = ""
var guided_lock_enabled: bool = false
var _pulse_tween: Tween
var _panel_tween: Tween
var _dim_tween: Tween
var _text_scroll: ScrollContainer


func setup(hotspots_layer: Control, hotspot_panel: PanelContainer, title: Label, text: RichTextLabel, close: Button, dim: ColorRect, preview: VialPreviewController) -> void:
	layer = hotspots_layer
	panel = hotspot_panel
	title_label = title
	text_label = text
	close_button = close
	panel_dim = dim
	vial_preview = preview
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PremiumUIStyles.apply_gold_outline_button(close_button)
	close_button.pressed.connect(close_panel)
	_text_scroll = _wrap_text_with_scroll(text_label)
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.96, 0.96)


func reset_viewed() -> void:
	viewed_ids.clear()
	_update_marker_viewed_state()
	_update_enter_winery_state()


func build_hotspots(raw_hotspots: Array) -> void:
	clear_target_highlight()
	for child in layer.get_children():
		child.free()

	active_hotspots.clear()
	required_ids.clear()
	active_target_id = ""
	for raw_hotspot in raw_hotspots:
		if typeof(raw_hotspot) == TYPE_DICTIONARY:
			var hotspot_data: Dictionary = raw_hotspot
			active_hotspots.append(hotspot_data)
			var hotspot_id: String = get_hotspot_id(hotspot_data)
			if bool(hotspot_data.get("viewed_required_for_winery", true)):
				required_ids[hotspot_id] = true

	for hotspot_data in active_hotspots:
		var marker: HotspotMarker = HotspotMarker.new()
		marker.configure(hotspot_data, viewed_ids.has(get_hotspot_id(hotspot_data)))
		marker.set_active_target(get_hotspot_id(hotspot_data) == active_target_id)
		marker.set_locked_state(_is_hotspot_locked(get_hotspot_id(hotspot_data)))
		marker.hotspot_selected.connect(_on_hotspot_pressed)
		layer.add_child(marker)

	layout_hotspots()
	_update_enter_winery_state()


func layout_hotspots() -> void:
	for index in range(mini(active_hotspots.size(), layer.get_child_count())):
		var hotspot_data: Dictionary = active_hotspots[index]
		var marker: Control = layer.get_child(index) as Control
		if marker == null:
			continue

		var position_data: Array = hotspot_data.get("screen_position", [0.72, 0.5])
		if position_data.size() < 2:
			position_data = [0.72, 0.5]

		var normalized_x: float = clampf(float(position_data[0]), 0.05, 0.95)
		var normalized_y: float = clampf(float(position_data[1]), 0.08, 0.92)
		var marker_size: Vector2 = marker.size if marker.size != Vector2.ZERO else marker.custom_minimum_size
		marker.position = Vector2(layer.size.x * normalized_x - marker_size.x * 0.5, layer.size.y * normalized_y - marker_size.y * 0.5)


func close_panel() -> void:
	_hide_panel()


func get_hotspot_id(hotspot_data: Dictionary) -> String:
	return str(hotspot_data.get("id", hotspot_data.get("title", "")))


func can_enter_winery() -> bool:
	for hotspot_id in required_ids.keys():
		if not viewed_ids.has(str(hotspot_id)):
			return false
	return true


func highlight_target(hotspot_id: String) -> bool:
	active_target_id = hotspot_id
	var found: bool = false
	for child in layer.get_children():
		var marker: HotspotMarker = child as HotspotMarker
		if marker == null:
			continue
		var is_target: bool = get_hotspot_id(marker.hotspot_data) == active_target_id
		marker.set_active_target(is_target)
		marker.set_locked_state(_is_hotspot_locked(get_hotspot_id(marker.hotspot_data)))
		found = found or is_target
	return found


func pulse_target(hotspot_id: String) -> bool:
	var found: bool = highlight_target(hotspot_id)
	if not found:
		return false
	_stop_pulse()
	for child in layer.get_children():
		var marker: HotspotMarker = child as HotspotMarker
		if marker != null and get_hotspot_id(marker.hotspot_data) == hotspot_id:
			marker.scale = Vector2.ONE
			_pulse_tween = create_tween()
			_pulse_tween.set_loops(3)
			_pulse_tween.tween_property(marker, "scale", Vector2(1.22, 1.22), 0.16)
			_pulse_tween.tween_property(marker, "scale", Vector2.ONE, 0.16)
			return true
	return false


func clear_target_highlight() -> void:
	_stop_pulse()
	active_target_id = ""
	for child in layer.get_children():
		var marker: HotspotMarker = child as HotspotMarker
		if marker != null:
			marker.scale = Vector2.ONE
			marker.set_active_target(false)
			marker.set_locked_state(_is_hotspot_locked(get_hotspot_id(marker.hotspot_data)))


func set_guided_active_hotspot(hotspot_id: String, enabled: bool = true) -> void:
	guided_lock_enabled = enabled
	active_target_id = hotspot_id if enabled else ""
	for child in layer.get_children():
		var marker: HotspotMarker = child as HotspotMarker
		if marker == null:
			continue
		var marker_id: String = get_hotspot_id(marker.hotspot_data)
		marker.set_active_target(enabled and marker_id == active_target_id)
		marker.set_locked_state(_is_hotspot_locked(marker_id))


func _on_hotspot_pressed(hotspot_data: Dictionary) -> void:
	var hotspot_id: String = get_hotspot_id(hotspot_data)
	if _is_hotspot_locked(hotspot_id):
		return
	viewed_ids[hotspot_id] = true
	_debug_enter_winery_state("hotspot viewed: %s" % hotspot_id)
	_update_marker_viewed_state()
	_update_enter_winery_state()
	await open_centered_annotation_panel(str(hotspot_data.get("title", "Tasting Note")), str(hotspot_data.get("text", "")))
	await annotation_closed
	hotspot_viewed.emit(hotspot_data)


func open_centered_annotation_panel(title: String, body: String, extra_data: Dictionary = {}) -> void:
	title_label.text = title
	text_label.text = body
	if extra_data.has("min_height"):
		panel.custom_minimum_size.y = float(extra_data.get("min_height", 120.0))
	await _show_panel()


func _show_panel() -> void:
	_stop_panel_tween()
	panel.visible = true
	layout_refresh_requested.emit("panel opened")
	await get_tree().process_frame
	ResponsiveLayoutController.center_panel_safe(panel, panel.get_viewport(), clampf(panel.get_viewport().get_visible_rect().size.x * 0.36, 360.0, 560.0), 0.45)
	if _text_scroll != null:
		_text_scroll.custom_minimum_size.y = clampf(panel.size.y - 118.0, 80.0, maxf(80.0, panel.size.y - 96.0))
	panel.pivot_offset = panel.size * 0.5
	vial_preview.set_idle_rotation_paused(true)
	_set_panel_dim(true)
	_panel_tween = PremiumUIStyles.animate_panel_open(panel, 10.0)


func _hide_panel() -> void:
	if not panel.visible:
		return
	_stop_panel_tween()
	vial_preview.set_idle_rotation_paused(false)
	_set_panel_dim(false)
	_panel_tween = create_tween()
	_panel_tween.set_parallel(true)
	_panel_tween.tween_property(panel, "modulate:a", 0.0, 0.12)
	_panel_tween.tween_property(panel, "scale", Vector2(0.96, 0.96), 0.12)
	await _panel_tween.finished
	panel.visible = false
	annotation_closed.emit()


func _set_panel_dim(is_visible: bool) -> void:
	if _dim_tween != null:
		_dim_tween.kill()
		_dim_tween = null
	var target_alpha: float = 1.0 if is_visible else 0.0
	_dim_tween = create_tween()
	_dim_tween.tween_property(panel_dim, "modulate:a", target_alpha, 0.16)


func _update_marker_viewed_state() -> void:
	for child in layer.get_children():
		var marker: HotspotMarker = child as HotspotMarker
		if marker != null:
			var marker_id: String = get_hotspot_id(marker.hotspot_data)
			marker.viewed = viewed_ids.has(marker_id)
			marker.set_locked_state(_is_hotspot_locked(marker_id))


func _update_enter_winery_state() -> void:
	var all_required_viewed: bool = can_enter_winery()
	_debug_enter_winery_state("required hotspots complete" if all_required_viewed else "required hotspots pending")
	enter_winery_state_changed.emit(all_required_viewed)


func _debug_enter_winery_state(reason: String) -> void:
	if not OS.is_debug_build():
		return
	print("[WineVR][EnterWinery] %s | required=%s viewed=%s" % [
		reason,
		_debug_sorted_keys(required_ids),
		_debug_sorted_keys(viewed_ids)
	])


func _debug_sorted_keys(source: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	for key in source.keys():
		keys.append(str(key))
	keys.sort()
	return keys


func _is_hotspot_locked(hotspot_id: String) -> bool:
	if not guided_lock_enabled:
		return false
	if viewed_ids.has(hotspot_id):
		return true
	return not hotspot_id == active_target_id


func _stop_pulse() -> void:
	if _pulse_tween != null:
		_pulse_tween.kill()
		_pulse_tween = null


func _stop_panel_tween() -> void:
	if _panel_tween != null:
		_panel_tween.kill()
		_panel_tween = null


func _wrap_text_with_scroll(rich_text: RichTextLabel) -> ScrollContainer:
	var vbox: VBoxContainer = rich_text.get_parent() as VBoxContainer
	if vbox == null:
		return null
	var old_index: int = rich_text.get_index()
	vbox.remove_child(rich_text)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = rich_text.name + "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var content: VBoxContainer = VBoxContainer.new()
	content.name = "ContentVBox"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	rich_text.fit_content = true
	rich_text.scroll_active = false
	rich_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(rich_text)
	vbox.add_child(scroll)
	vbox.move_child(scroll, old_index)
	return scroll
