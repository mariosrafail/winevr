extends Node3D

var winery: WineryInteriorController
var museum: GrapeMuseum
var physics: MuseumPhysicsController
var paused: bool = false
var _dragging: bool = false
var _started: bool = false
var settings: GraphicsSettingsPanelController
var graphics: GraphicsSettingsManager
var _start_button: Button
var _title: Label
var _hint: Label
var _crosshair: Label
var _interaction_prompt: Control
var _target_id: String = ""
var _pause_panel: PanelContainer
var _inspection_light: SpotLight3D
const INSPECTION_LAYER: int = 1 << 19
var _inspection_viewport: SubViewport
var _inspection_camera: Camera3D
var _inspection_canvas: CanvasLayer
var _inspection_nodes: Dictionary = {}
var _overlay_id: String = ""
var _menu_showing: bool = false
var _menu_tween: Tween

func _ready() -> void:
	get_window().title = "Grapes of Crete"
	winery = (load("res://scenes/WineryInterior.tscn") as PackedScene).instantiate() as WineryInteriorController
	winery.name = "WineryInterior"
	winery.force_desktop_mode = true
	winery.visible = true
	winery.set_meta("room_demo", true)
	add_child(winery)
	museum = winery.get("_grape_museum") as GrapeMuseum
	physics = museum.physics as MuseumPhysicsController
	winery.set_presentation_mode("museum")
	winery.set_controls_enabled(true)
	winery.set_camera_active(true)
	winery.set_exploration_mode_active(true)
	winery.reset_view()
	winery.camera.fov = 62.0
	winery.camera.near = 0.08
	winery._movement.enable_natural_walk()
	var footsteps: Node = preload("res://scripts/components/footstep_audio.gd").new()
	footsteps.name = "Footsteps"
	add_child(footsteps)
	winery._movement.footstep.connect(footsteps.play_step)
	winery._movement.walking_stopped.connect(footsteps.stop)
	museum.get("_desktop_hint").visible = false
	museum.set_process(false)
	_polish_gallery()
	_build_inspection_overlay()
	_build_ui()
	_build_settings()
	_pause(true)
	settings.open()
	print("[GrapeRoomDemo] Ready: three exhibits, no hand, no grab, vertical-axis inspection")

func _build_inspection_overlay() -> void:
	# A separate depth buffer keeps the inspected object in front of the room,
	# while preserving depth between the berries and the existing chart controls.
	_inspection_canvas = CanvasLayer.new()
	_inspection_canvas.layer = 5
	add_child(_inspection_canvas)
	var container: SubViewportContainer = SubViewportContainer.new()
	_inspection_canvas.add_child(container)
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inspection_viewport = SubViewport.new()
	_inspection_viewport.transparent_bg = true
	_inspection_viewport.world_3d = get_world_3d()
	_inspection_viewport.msaa_3d = Viewport.MSAA_2X
	_inspection_viewport.handle_input_locally = false
	container.add_child(_inspection_viewport)
	_inspection_camera = Camera3D.new()
	_inspection_camera.cull_mask = INSPECTION_LAYER
	_inspection_camera.environment = winery.world_environment.environment.duplicate() as Environment
	_inspection_camera.environment.background_mode = Environment.BG_CLEAR_COLOR
	_inspection_camera.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_inspection_camera.environment.ambient_light_color = Color("fff8ee")
	_inspection_camera.environment.ambient_light_energy = 0.85
	_inspection_camera.environment.ambient_light_sky_contribution = 0.0
	_inspection_viewport.add_child(_inspection_camera)
	_inspection_camera.current = true
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	_inspection_camera.add_child(fill)
	fill.rotation_degrees = Vector3(-20, -25, 0)
	fill.light_energy = 1.2
	fill.light_color = Color("fff3e5")
	fill.layers = INSPECTION_LAYER
	fill.light_cull_mask = INSPECTION_LAYER
	winery.camera.cull_mask &= ~INSPECTION_LAYER
	_inspection_light.layers = INSPECTION_LAYER
	_inspection_light.light_cull_mask = INSPECTION_LAYER
	_inspection_light.shadow_enabled = false
	_inspection_canvas.hide()
	_inspection_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func _sync_inspection_overlay() -> void:
	var visible_id: String = physics.inspecting_id if not physics.inspecting_id.is_empty() else physics.demo_returning_id
	if _overlay_id != visible_id:
		for node: VisualInstance3D in _inspection_nodes:
			if is_instance_valid(node):
				node.layers = _inspection_nodes[node]
		_inspection_nodes.clear()
		_overlay_id = visible_id
		if not _overlay_id.is_empty():
			for root: Node3D in [physics._body(_overlay_id), museum.exhibit_nodes[_overlay_id]["panel"]]:
				for node in root.find_children("*", "VisualInstance3D", true, false):
					_inspection_nodes[node] = node.layers
					node.layers = INSPECTION_LAYER
	_inspection_canvas.visible = not _overlay_id.is_empty()
	_inspection_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if _inspection_canvas.visible else SubViewport.UPDATE_DISABLED
	_inspection_camera.global_transform = winery.camera.global_transform
	_inspection_camera.fov = winery.camera.fov
	_inspection_camera.near = winery.camera.near
	_inspection_camera.keep_aspect = winery.camera.keep_aspect

func _polish_gallery() -> void:
	get_viewport().msaa_3d = Viewport.MSAA_2X
	get_viewport().positional_shadow_atlas_size = 2048
	get_viewport().scaling_3d_scale = 1.0
	var environment: Environment = winery.world_environment.environment
	var sky: Sky = environment.sky if environment.sky != null else Sky.new()
	var panorama: PanoramaSkyMaterial = PanoramaSkyMaterial.new()
	panorama.panorama = load("res://assets/hdri/studio_small_09_1k.hdr") as Texture2D
	panorama.energy_multiplier = 0.65
	sky.sky_material = panorama
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.ambient_light_energy = 0.50
	environment.tonemap_exposure = 0.95
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		environment.ssao_enabled = true
		environment.ssao_radius = 0.08
		environment.ssao_intensity = 1.1
	for node in museum.architecture.find_children("*", "Light3D", true, false):
		var light: Light3D = node as Light3D
		light.light_energy *= 0.65
		light.light_size = 0.12
	_inspection_light = SpotLight3D.new()
	_inspection_light.name = "InspectionSoftbox"
	winery.camera.add_child(_inspection_light)
	_inspection_light.position = Vector3(-0.55, 0.55, 0.10)
	_inspection_light.look_at(winery.camera.to_global(Vector3(0, 0, -1.0)), Vector3.UP)
	_inspection_light.light_color = Color("fff3e5")
	_inspection_light.light_energy = 0.85
	_inspection_light.light_size = 0.18
	_inspection_light.spot_range = 2.5
	_inspection_light.spot_angle = 48.0
	_inspection_light.shadow_enabled = true
	for entry: Dictionary in museum.exhibit_nodes.values():
		var springs: Node3D = (entry["pivot"] as RigidBody3D).get_node("BerryPhysics")
		springs.secondary_rotation = true
		springs.configure_neighbor_contacts()
		for index in range(springs.berries.size()):
			var berry: Dictionary = springs.berries[index]
			berry["frequency"] = lerpf(24.0, 17.0, clampf(float(berry["radius"]) / 0.05, 0.0, 1.0)) * (0.94 + float(index % 7) * 0.02)

func _build_ui() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)
	var root: Control = Control.new()
	canvas.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title = Label.new()
	root.add_child(_title)
	_title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_title.position.y = 22
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 23)
	_title.modulate = Color("eee5d2")
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint = Label.new()
	root.add_child(_hint)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -46
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 17)
	_hint.modulate = Color("e4dbc8")
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair = Label.new()
	root.add_child(_crosshair)
	_crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_crosshair.position -= Vector2(6, 15)
	_crosshair.text = "·"
	_crosshair.add_theme_font_size_override("font_size", 30)
	_crosshair.modulate = Color("d8bd7b")
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_interaction_prompt = Control.new()
	root.add_child(_interaction_prompt)
	_interaction_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_interaction_prompt.position -= Vector2(18, 24)
	_interaction_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hand_icon: TextureRect = TextureRect.new()
	_interaction_prompt.add_child(hand_icon)
	hand_icon.texture = load("res://assets/ui/inspect_hand.svg")
	hand_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hand_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hand_icon.size = Vector2(36, 44)
	hand_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var key_badge: PanelContainer = PanelContainer.new()
	_interaction_prompt.add_child(key_badge)
	key_badge.position = Vector2(44, 10)
	key_badge.custom_minimum_size = Vector2(30, 30)
	key_badge.add_theme_stylebox_override("panel", PremiumUIStyles.make_panel_style(0.96))
	key_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var key_label: Label = Label.new()
	key_badge.add_child(key_label)
	key_label.text = "E"
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.add_theme_font_size_override("font_size", 21)
	key_label.modulate = Color("ffe3a0")
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_interaction_prompt.hide()
	_pause_panel = PanelContainer.new()
	root.add_child(_pause_panel)
	_pause_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_pause_panel.offset_left = -160
	_pause_panel.offset_right = 160
	_pause_panel.offset_top = -130
	_pause_panel.offset_bottom = 130
	_pause_panel.add_theme_stylebox_override("panel", PremiumUIStyles.make_panel_style(0.97))
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	_pause_panel.add_child(column)
	var heading: Label = Label.new()
	heading.text = "Grapes of Crete"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	var welcome: Label = Label.new()
	welcome.text = "Διάλεξε πρώτα τις ρυθμίσεις οθόνης σου.\nΜετά ξεκίνησε την εξερεύνηση."
	welcome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(welcome)
	_start_button = _button(column, "Έναρξη εξερεύνησης", func() -> void:
		_started = true
		_pause(false)
	)
	_button(column, "Ρυθμίσεις", func() -> void: settings.open())
	_button(column, "Έξοδος", func() -> void: get_tree().quit())
	_pause_panel.hide()

func _button(parent: Control, text: String, action: Callable) -> Button:
	var button: Button = Button.new()
	parent.add_child(button)
	button.text = text
	button.custom_minimum_size = Vector2(94, 46)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	PremiumUIStyles.apply_gold_outline_button(button)
	button.pressed.connect(action)
	_animate_button(button)
	return button

func _animate_button(button: BaseButton) -> void:
	button.mouse_entered.connect(func() -> void: _button_feedback(button, false))
	button.mouse_exited.connect(func() -> void: _button_feedback(button, false))
	button.focus_entered.connect(func() -> void: _button_feedback(button, false))
	button.focus_exited.connect(func() -> void: _button_feedback(button, false))
	button.button_down.connect(func() -> void: _button_feedback(button, true))
	button.button_up.connect(func() -> void: _button_feedback(button, false))
	button.visibility_changed.connect(func() -> void:
		if not button.is_visible_in_tree():
			if button.has_meta("feedback_tween"):
				(button.get_meta("feedback_tween") as Tween).kill()
			button.scale = Vector2.ONE
			button.modulate = Color.WHITE
	)

func _button_feedback(button: BaseButton, pressed: bool) -> void:
	if button.disabled or not button.is_visible_in_tree():
		return
	if button.has_meta("feedback_tween"):
		(button.get_meta("feedback_tween") as Tween).kill()
	button.pivot_offset = button.size * 0.5
	var highlighted: bool = button.is_hovered() or button.has_focus()
	var target: float = 0.975 if pressed else (1.025 if highlighted else 1.0)
	var tween: Tween = button.create_tween().set_parallel(true)
	button.set_meta("feedback_tween", tween)
	tween.tween_property(button, "scale", Vector2.ONE * target, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "modulate", Color(1.12, 1.08, 1.0) if highlighted else Color.WHITE, 0.15)

func _show_pause_menu(showing: bool) -> void:
	if _menu_showing == showing:
		return
	_menu_showing = showing
	if _menu_tween != null and _menu_tween.is_valid():
		_menu_tween.kill()
	for node in _pause_panel.find_children("*", "BaseButton", true, false):
		node.disabled = not showing
	_pause_panel.pivot_offset = _pause_panel.size * 0.5
	if showing and not _pause_panel.visible:
		_pause_panel.modulate.a = 0.0
		_pause_panel.scale = Vector2.ONE * 0.94
	_pause_panel.show()
	_menu_tween = create_tween().set_parallel(true)
	_menu_tween.tween_property(_pause_panel, "modulate:a", 1.0 if showing else 0.0, 0.22 if showing else 0.14)
	_menu_tween.tween_property(_pause_panel, "scale", Vector2.ONE if showing else Vector2.ONE * 0.97, 0.26 if showing else 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if not showing:
		_menu_tween.chain().tween_callback(_pause_panel.hide)

func _build_settings() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 30
	add_child(canvas)
	settings = GraphicsSettingsPanelController.new()
	settings.animated_menus = true
	add_child(settings)
	settings.setup(canvas)
	for node in settings.panel.find_children("*", "BaseButton", true, false):
		_animate_button(node as BaseButton)
	for node in settings.right_column.get_children():
		if node is Label and node.text.begins_with("Εξέταση:"):
			node.text = "WASD: Κίνηση\nE: Εξέταση / επιστροφή\nΑριστερό κλικ + σύρσιμο: Περιστροφή\nΡοδέλα: Ζουμ στο τσαμπί\nEsc: Μενού"
		elif node is Button:
			node.hide()
	graphics = GraphicsSettingsManager.new()
	add_child(graphics)
	graphics.setup(get_tree(), get_viewport(), winery.world_environment.environment)
	settings.set_values(graphics.current_preset, graphics.fps_friendly)
	settings.apply_requested.connect(func(preset: String, friendly: bool) -> void:
		graphics.set_preset(preset)
		graphics.set_fps_friendly(friendly)
		graphics.apply_current()
	)
	settings.options_opened.connect(func() -> void: _pause(true))
	settings.options_closed.connect(func() -> void: _pause(true))
	settings.controls_requested.connect(func() -> void:
		settings.close()
		_hint.text = "WASD κίνηση · E εξέταση / επιστροφή · Σύρε το σταφύλι με αριστερό κλικ"
	)
	get_viewport().size_changed.connect(_layout_settings)
	_layout_settings()
	if DisplayServer.get_name() != "headless":
		settings.apply_saved_display_settings()

func _layout_settings() -> void:
	settings.layout(get_viewport().get_visible_rect().size)
	settings.menu_button.hide()

func _process(delta: float) -> void:
	if museum == null:
		return
	var inspecting: bool = museum.is_inspecting()
	winery._movement.update_view(delta, not paused and not inspecting and not physics._transitioning)
	_sync_inspection_overlay()
	_inspection_light.visible = not _overlay_id.is_empty()
	var exploring: bool = _overlay_id.is_empty() and not paused and not physics._transitioning
	_target_id = _target_grape_id() if exploring else ""
	_interaction_prompt.visible = exploring and not _target_id.is_empty()
	_crosshair.visible = exploring and _target_id.is_empty()
	_title.visible = not paused
	_title.text = "ΛΙΑΤΙΚΟ  ·  ΚΟΤΣΙΦΑΛΙ  ·  ΒΙΔΙΑΝΟ" if not inspecting else str(museum.exhibit_nodes[physics.inspecting_id]["panel"].title).replace(" · Προφίλ", "")
	_hint.text = "WASD κίνηση  ·  Ποντίκι ματιά  ·  E εξέταση σταφυλιού  ·  Esc μενού" if not inspecting else "Σύρε για περιστροφή  ·  Ροδέλα για ζουμ  ·  E / Esc επιστροφή"
	_hint.visible = not paused
	settings.menu_button.hide()
	_show_pause_menu(paused and not settings.is_open())
	var cursor: Input.CursorShape = Input.CURSOR_ARROW
	if not _overlay_id.is_empty():
		var shown_panel: Node3D = museum.exhibit_nodes[_overlay_id]["panel"]
		var reveal: float = physics.demo_panel_reveal
		shown_panel.global_transform = winery.camera.global_transform * Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * lerpf(0.56, 0.62, reveal)), Vector3(lerpf(0.64, 0.48, reveal), -0.015, -1.10))
		shown_panel.visible = reveal > 0.01
	if inspecting and not paused:
		var panel: Node3D = museum.exhibit_nodes[physics.inspecting_id]["panel"]
		var hovered: Node = physics._view_ray(1).get("collider") as Node
		while hovered != null and not hovered.has_meta("museum_action"):
			hovered = hovered.get_parent()
		for index in range(3):
			var tab: Node3D = panel.get_node("museum_" + physics.inspecting_id + "_page_" + str(index))
			museum.style_demo_button(tab, hovered == tab, int(panel.get_meta("profile_page", 0)) == index)
		var back: Node3D = panel.get_node("museum_" + physics.inspecting_id + "_close")
		museum.style_demo_button(back, hovered == back, false)
		if hovered != null and not physics._transitioning:
			cursor = Input.CURSOR_POINTING_HAND
		(museum.exhibit_nodes[physics.inspecting_id]["status"] as Label3D).text = "Σύρε το σταφύλι · E / Esc επιστροφή"
		if _dragging:
			cursor = Input.CURSOR_DRAG
		elif physics._view_ray(4).get("collider") == physics._body(physics.inspecting_id):
			cursor = Input.CURSOR_POINTING_HAND
	Input.set_default_cursor_shape(cursor)

func _pause(value: bool) -> void:
	paused = value
	_dragging = false
	_show_pause_menu(value and not settings.is_open())
	_start_button.text = "Συνέχεια" if _started else "Έναρξη εξερεύνησης"
	winery.set_controls_enabled(not value)
	winery.set_exploration_mode_active(not value)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value or museum.is_inspecting() else Input.MOUSE_MODE_CAPTURED

func _toggle_fullscreen() -> void:
	settings.toggle_fullscreen()

func interact_grape() -> void:
	if not physics.demo_returning_id.is_empty():
		return
	if museum.close_inspection():
		return
	var target: String = _target_grape_id()
	if not target.is_empty():
		museum.inspect_exhibit(target)

func _target_grape_id() -> String:
	var origin: Vector3 = winery.camera.global_position
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin - winery.camera.global_basis.z * 3.5, 1)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	var node: Node = hit.get("collider") as Node
	while node != null:
		if node.has_meta("museum_exhibit"):
			return str(node.get_meta("museum_exhibit"))
		node = node.get_parent()
	return ""

func _input(event: InputEvent) -> void:
	if physics == null:
		return
	if event is InputEventMouse:
		physics._pointer = event.position
		physics._pointer_valid = true
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_dragging = false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if settings.is_open():
				settings.close()
			elif paused:
				if _started:
					_pause(false)
			elif not museum.close_inspection():
				_pause(true)
			_dragging = false
		elif event.keycode == KEY_F11:
			_toggle_fullscreen()
		elif settings.is_open():
			return
		elif event.keycode == KEY_E and not paused:
			_dragging = false
			interact_grape()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if paused or not museum.is_inspecting() or physics._transitioning:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		physics.demo_zoom(1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var pressed_button: Node = physics._view_ray(1).get("collider") as Node
			while pressed_button != null and not pressed_button.has_meta("museum_action"):
				pressed_button = pressed_button.get_parent()
			if pressed_button != null:
				museum.press_demo_button(pressed_button as Node3D)
			if physics._click_profile_action():
				get_viewport().set_input_as_handled()
				return
			_dragging = physics._view_ray(4).get("collider") == physics._body(physics.inspecting_id)
		else:
			_dragging = false
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		physics.demo_rotate(event.relative.x * 0.40)
		get_viewport().set_input_as_handled()
