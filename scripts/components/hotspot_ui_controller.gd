extends Node
class_name HotspotUIController

signal hotspot_viewed(hotspot_data: Dictionary)
signal enter_winery_state_changed(all_required_viewed: bool)

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


func setup(hotspots_layer: Control, hotspot_panel: PanelContainer, title: Label, text: RichTextLabel, close: Button, dim: ColorRect, preview: VialPreviewController) -> void:
	layer = hotspots_layer
	panel = hotspot_panel
	title_label = title
	text_label = text
	close_button = close
	panel_dim = dim
	vial_preview = preview
	close_button.pressed.connect(close_panel)
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.96, 0.96)


func reset_viewed() -> void:
	viewed_ids.clear()
	_update_marker_viewed_state()
	_update_enter_winery_state()


func build_hotspots(raw_hotspots: Array) -> void:
	for child in layer.get_children():
		child.free()

	active_hotspots.clear()
	required_ids.clear()
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


func highlight_target(hotspot_id: String) -> bool:
	active_target_id = hotspot_id
	var found: bool = false
	for child in layer.get_children():
		var marker: HotspotMarker = child as HotspotMarker
		if marker == null:
			continue
		var is_target: bool = get_hotspot_id(marker.hotspot_data) == active_target_id
		marker.set_active_target(is_target)
		found = found or is_target
	return found


func pulse_target(hotspot_id: String) -> bool:
	var found: bool = highlight_target(hotspot_id)
	if not found:
		return false
	for child in layer.get_children():
		var marker: HotspotMarker = child as HotspotMarker
		if marker != null and get_hotspot_id(marker.hotspot_data) == hotspot_id:
			var tween: Tween = create_tween()
			tween.set_loops(3)
			tween.tween_property(marker, "scale", Vector2(1.22, 1.22), 0.16)
			tween.tween_property(marker, "scale", Vector2.ONE, 0.16)
			return true
	return false


func clear_target_highlight() -> void:
	active_target_id = ""
	for child in layer.get_children():
		var marker: HotspotMarker = child as HotspotMarker
		if marker != null:
			marker.set_active_target(false)


func _on_hotspot_pressed(hotspot_data: Dictionary) -> void:
	var hotspot_id: String = get_hotspot_id(hotspot_data)
	viewed_ids[hotspot_id] = true
	title_label.text = str(hotspot_data.get("title", "Hotspot"))
	text_label.text = str(hotspot_data.get("text", ""))
	_update_marker_viewed_state()
	_update_enter_winery_state()
	hotspot_viewed.emit(hotspot_data)
	_show_panel()


func _show_panel() -> void:
	panel.visible = true
	panel.pivot_offset = panel.size * 0.5
	vial_preview.set_idle_rotation_paused(true)
	_set_panel_dim(true)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.16)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _hide_panel() -> void:
	if not panel.visible:
		return
	vial_preview.set_idle_rotation_paused(false)
	_set_panel_dim(false)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 0.0, 0.12)
	tween.tween_property(panel, "scale", Vector2(0.96, 0.96), 0.12)
	await tween.finished
	panel.visible = false


func _set_panel_dim(is_visible: bool) -> void:
	var target_alpha: float = 1.0 if is_visible else 0.0
	var tween: Tween = create_tween()
	tween.tween_property(panel_dim, "modulate:a", target_alpha, 0.16)


func _update_marker_viewed_state() -> void:
	for child in layer.get_children():
		var marker: HotspotMarker = child as HotspotMarker
		if marker != null:
			marker.viewed = viewed_ids.has(get_hotspot_id(marker.hotspot_data))


func _update_enter_winery_state() -> void:
	var all_required_viewed: bool = true
	for hotspot_id in required_ids.keys():
		if not viewed_ids.has(str(hotspot_id)):
			all_required_viewed = false
			break
	enter_winery_state_changed.emit(all_required_viewed)
