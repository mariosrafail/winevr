extends Node

var failures: Array[String] = []
var checks: int = 0

func _ready() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func _fits(control: Control, label: String) -> void:
	_check(get_viewport().get_visible_rect().grow(1).encloses(control.get_global_rect()), label + " " + str(control.get_global_rect()))

func _run() -> void:
	var app: Node = (load("res://scenes/WineVRExperience.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(app)
	await get_tree().create_timer(1.5).timeout
	var menu: MainMenuOverlayController = app.get("_main_menu") as MainMenuOverlayController
	var options: GraphicsSettingsPanelController = app.get("_graphics_panel") as GraphicsSettingsPanelController
	var controls: ControlsOverlayController = app.get("_controls_overlay") as ControlsOverlayController
	var catalog: QRScreenController = app.get("_qr_screen") as QRScreenController
	for dimensions in [Vector2i(320, 568), Vector2i(360, 640), Vector2i(844, 390), Vector2i(768, 1024), Vector2i(1440, 900)]:
		get_tree().root.size = dimensions
		await app.call("refresh_all_ui_layouts", "responsive UI matrix")
		app.call("_show_main_menu")
		await get_tree().create_timer(0.35).timeout
		_fits(menu.panel, "Menu " + str(dimensions))
		menu.options_requested.emit()
		await get_tree().create_timer(0.4).timeout
		_fits(options.panel, "Options " + str(dimensions))
		_fits(options.close_button, "Options close " + str(dimensions))
		_fits(options.apply_button, "Options apply " + str(dimensions))
		options.close()
		await get_tree().create_timer(0.25).timeout
		menu.controls_requested.emit()
		await get_tree().create_timer(0.35).timeout
		_fits(controls.panel, "Controls " + str(dimensions))
		_fits(controls.close_button, "Controls close " + str(dimensions))
		controls.hide_controls()
		await get_tree().create_timer(0.25).timeout
		app.call("_open_tasting_catalog")
		await get_tree().create_timer(0.35).timeout
		_check(catalog.screen.visible, "Catalog visible from initial same-state menu")
		_fits(catalog.card, "Catalog " + str(dimensions))
		app.call("_navigate_section", "museum")
		await get_tree().create_timer(1.0).timeout
		_fits(app.get("_section_bar") as Control, "Navigation " + str(dimensions))
		if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://work/responsive_%dx%d.png" % [dimensions.x, dimensions.y])
	var report: Dictionary = {"passed": failures.is_empty(), "checks": checks, "failures": failures}
	var output: FileAccess = FileAccess.open("res://work/responsive_ui_qa.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "  "))
	print("[ResponsiveQA] " + JSON.stringify(report))
	app.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
