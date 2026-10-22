extends Node
class_name MobileGrapeInspector

const ANATOMY: Script = preload("res://scripts/winery/berry_anatomy.gd")
var winery: WineryInteriorController
var panel: PanelContainer
var title: Label
var tabs: TabBar
var scroll: ScrollContainer
var content: VBoxContainer
var _museum: GrapeMuseum
var _selected: String = ""
var _page: int = -1
var _anatomy: Node3D
var _anatomy_view: SubViewport


func setup(canvas: CanvasLayer, owner_winery: WineryInteriorController) -> void:
	winery = owner_winery
	panel = PanelContainer.new()
	panel.name = "MobileGrapeInspector"
	panel.z_index = 85
	panel.visible = false
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("202c28")
	style.border_color = Color("a89259")
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	canvas.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", PremiumUIStyles.TEXT_TITLE)
	box.add_child(title)
	var context: Label = Label.new()
	context.text = "Εκπαιδευτική απεικόνιση · όχι μέτρηση"
	context.add_theme_font_size_override("font_size", 12)
	context.add_theme_color_override("font_color", PremiumUIStyles.TEXT_MUTED)
	context.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(context)
	tabs = TabBar.new()
	tabs.add_theme_font_size_override("font_size", 13)
	tabs.clip_tabs = true
	for label in ["Προφίλ", "Η ρώγα", "Ωρίμανση", "Ρώγα 3D"]:
		tabs.add_tab(label)
	tabs.custom_minimum_size.y = 40
	tabs.tab_changed.connect(func(index: int) -> void:
		if _museum != null and not _selected.is_empty():
			_museum.set_profile_page(_selected, index)
	)
	box.add_child(tabs)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)


func _process(_delta: float) -> void:
	if winery == null or panel == null:
		return
	_museum = winery.get("_grape_museum") as GrapeMuseum
	var show: bool = _museum != null and _museum.is_inspecting() and _museum.controls_enabled and _museum.is_visible_in_tree() and not winery.is_vr_active()
	show = show and bool(_museum.physics.call("uses_portrait_inspector"))
	panel.visible = show
	if _anatomy_view != null:
		_anatomy_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if show else SubViewport.UPDATE_DISABLED
	if not show:
		return
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	var card_height: float = minf(360.0, viewport.y * 0.43)
	panel.position = Vector2(12, viewport.y - 152 - card_height)
	panel.size = Vector2(viewport.x - 24, card_height)
	var id: String = str(_museum.physics.get("inspecting_id"))
	var page: int = int((_museum.exhibit_nodes[id]["panel"] as Node3D).get_meta("profile_page", 0))
	if id != _selected or page != _page:
		_selected = id
		_page = page
		tabs.set_tab_title(3, "Ρώγα 3D")
		tabs.set_current_tab(page)
		_rebuild()


func _rebuild() -> void:
	_anatomy = null
	_anatomy_view = null
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	scroll.scroll_vertical = 0
	var variety: Dictionary = {}
	for item: Dictionary in _museum.data.get("varieties", []):
		if str(item.get("id")) == _selected:
			variety = item
			break
	title.text = str(variety.get("name", "")) + " · " + str(variety.get("number", ""))
	match _page:
		0:
			for metric: Dictionary in _museum.data.get("metrics", []):
				var value: int = int((variety.get("metrics", {}) as Dictionary).get(str(metric.get("id")), 0))
				_text("%s   %d / 100" % [str(metric.get("label")), value], 15)
				var bar: ProgressBar = ProgressBar.new()
				bar.value = value
				bar.show_percentage = false
				bar.custom_minimum_size.y = 7
				var fill: StyleBoxFlat = StyleBoxFlat.new()
				fill.bg_color = Color(str(metric.get("color", "#d8bd7b")))
				fill.set_corner_radius_all(3)
				bar.add_theme_stylebox_override("fill", fill)
				content.add_child(bar)
			_text(str(_museum.data.get("scale_note", "")), 13, true)
		1:
			for card: Dictionary in _museum.data.get("learning_cards", []):
				_text(str(card.get("title", "")), 15, true)
				_text(str(card.get("text", "")).replace("\n", " "), 15)
			_text(str(_museum.data.get("measurement_note", "")), 13, true)
		2:
			_text(str(variety.get("identity", "")).replace("\n", " "), 16)
			_text("ΩΡΙΜΑΝΣΗ", 14, true)
			_text(str(variety.get("ripening_note", "")).replace("\n", " "), 16)
			_text("Αμπελώνας, χρονιά και οινοποίηση αλλάζουν το αποτέλεσμα.", 14, true)
			for source: Dictionary in _museum.data.get("sources", []):
				if str(source.get("id")) in variety.get("sources", []):
					_text(str(source.get("title", "")), 12, true)
		3:
			_build_anatomy(variety)


func _text(value: String, font_size: int, muted: bool = false) -> Label:
	var label: Label = Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", PremiumUIStyles.TEXT_MUTED if muted else PremiumUIStyles.TEXT_TITLE)
	content.add_child(label)
	return label


func _build_anatomy(variety: Dictionary) -> void:
	var container: SubViewportContainer = SubViewportContainer.new()
	container.custom_minimum_size = Vector2(0, 190)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(container)
	_anatomy_view = SubViewport.new()
	_anatomy_view.size = Vector2i(320, 190)
	_anatomy_view.own_world_3d = true
	_anatomy_view.transparent_bg = true
	container.add_child(_anatomy_view)
	_anatomy = ANATOMY.new() as Node3D
	_anatomy_view.add_child(_anatomy)
	_anatomy.call("build", variety)
	_anatomy.call("set_active", true)
	for child in _anatomy.get_children():
		if child is Node3D and child.name != "BerryCutaway":
			(child as Node3D).visible = false
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 0.50
	camera.position = Vector3(0, 0.03, 1.1)
	_anatomy_view.add_child(camera)
	camera.make_current()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0, 0, 0, 0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("e3e7df")
	environment.ambient_light_energy = 0.8
	camera.environment = environment
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-28, -32, 0)
	light.light_energy = 1.4
	_anatomy_view.add_child(light)
	var buttons: HBoxContainer = HBoxContainer.new()
	content.add_child(buttons)
	var detail: Label = _text("", 15)
	for index in range(3):
		var part: String = ["skin", "pulp", "seeds"][index]
		var button: Button = Button.new()
		button.text = ["Φλούδα", "Σάρκα", "Κουκούτσια"][index]
		button.custom_minimum_size.y = 44
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 13)
		PremiumUIStyles.apply_gold_outline_button(button)
		button.pressed.connect(func() -> void:
			_anatomy.call("select_part", part)
			detail.text = str((_anatomy.get("_description") as Label3D).text).replace("\n", " ")
		)
		buttons.add_child(button)
	detail.text = str((_anatomy.get("_description") as Label3D).text).replace("\n", " ")
	_text("Μεγεθυμένο εκπαιδευτικό μοντέλο.", 12, true)
