extends Node

var failures: Array[String] = []
var checks: int = 0


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("[SampleQA] " + label)


func _run() -> void:
	var before: Array[Dictionary] = WineDatabase.get_all_profiles()
	var codes: Dictionary = {"WV-LIA-01": "liatiko_dafnes_demo", "WV-KOT-02": "kotsifali_crete_demo", "WV-VID-03": "vidiano_crete_demo"}
	for code in codes:
		var result: Dictionary = WineDatabase.resolve_sample_code(code)
		_check(bool(result.get("ok", false)) and result.get("profile_id") == codes[code], code + " resolves its exact existing record")
		var normalized: Dictionary = WineDatabase.resolve_sample_code(" \t" + str(code).to_lower() + "\r\n")
		_check(normalized == result, code + " normalizes outer whitespace and case")
	for invalid in ["", "WV-LIA", "WV-LIA-010", "WV LIA 01", "WV-LIA-01/path", "WV-LIΑ-01", "UNKNOWN-42", "X".repeat(33), "WV-LIA-01" + " ".repeat(65), "https://example.org/WV-LIA-01"]:
		_check(not bool(WineDatabase.resolve_sample_code(invalid).get("ok", false)), "Rejects invalid or non-exact input: " + invalid.left(20))
	var duplicate: Array = [{"id": "one", "sample_codes": ["WV-LIA-01"]}, {"id": "two", "sample_codes": [" wv-lia-01 "]}]
	var duplicate_snapshot: Array = duplicate.duplicate(true)
	_check(WineDatabase.resolve_sample_code_from_profiles("WV-LIA-01", duplicate).get("error") == "duplicate", "Duplicate aliases do not select the first record")
	_check(duplicate == duplicate_snapshot, "Resolver never mutates supplied records")
	_check(WineDatabase.resolve_sample_code_from_profiles("WV-LIA-01", [{"id": "one", "sample_codes": ["WV-LIA-01", "wv-lia-01"]}]).get("error") == "duplicate", "Repeated alias within one record is rejected")
	_check(WineDatabase.get_all_profiles() == before, "Pure lookups preserve the loaded database")
	var app: Node = (load("res://scenes/WineVRExperience.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(app)
	await get_tree().create_timer(1.5).timeout
	app.call("_open_tasting_catalog")
	await get_tree().create_timer(0.3).timeout
	get_tree().root.size = Vector2i(390, 844)
	var catalog: QRScreenController = app.get("_qr_screen") as QRScreenController
	catalog.code_toggle.pressed.emit()
	# Programmatic pressed emission does not toggle a ToggleButton's property.
	catalog.set_code_entry_visible(true)
	await app.call("refresh_all_ui_layouts", "sample code QA")
	await get_tree().create_timer(0.2).timeout
	_check(catalog.code_field.is_visible_in_tree() and not catalog.results_scroll.visible, "Dedicated code entry replaces the catalog list")
	for size in [Vector2i(320, 568), Vector2i(360, 640), Vector2i(844, 390), Vector2i(390, 844)]:
		get_tree().root.size = size
		await app.call("refresh_all_ui_layouts", "expanded sample entry QA")
		await get_tree().create_timer(0.1).timeout
		_check(get_viewport().get_visible_rect().encloses(catalog.card.get_global_rect()), "Expanded code card fits " + str(size))
		catalog.content_scroll.ensure_control_visible(catalog.code_submit_button)
		await get_tree().process_frame
		_check(get_viewport().get_visible_rect().encloses(catalog.code_submit_button.get_global_rect()), "Code submit can scroll into view " + str(size))
	catalog.content_scroll.scroll_vertical = 0
	var previous_client: String = AppState.selected_profile_id
	var selection_events: Array[String] = []
	catalog.client_selected.connect(func(id: String) -> void: selection_events.append(id))
	catalog.code_field.text = "NO-SUCH-SAMPLE"
	catalog.code_field.text_changed.emit(catalog.code_field.text)
	catalog.code_field.text_submitted.emit(catalog.code_field.text)
	await get_tree().process_frame
	_check(selection_events.is_empty() and AppState.selected_profile_id == previous_client, "Unknown code neither emits selection nor changes the active profile")
	_check(not catalog.error_label.text.is_empty(), "Unknown code has visible feedback")
	catalog.code_field.text = "wv-vid-03"
	catalog.code_field.text_changed.emit(catalog.code_field.text)
	await get_tree().process_frame
	_check(selection_events.is_empty(), "Typing alone never auto-selects a sample")
	if "--sample-capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://work/sample_code_entry.png")
	_check(get_viewport().get_visible_rect().encloses(catalog.code_submit_button.get_global_rect()), "Code submission stays reachable on portrait touch")
	catalog.code_field.grab_focus()
	var enter: InputEventKey = InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	Input.parse_input_event(enter)
	Input.flush_buffered_events()
	await get_tree().create_timer(0.4).timeout
	_check(selection_events == ["vidiano_crete_demo"], "Enter submits the keyboard-emulating reader through client_selected exactly once")
	_check(AppState.selected_profile_id == "vidiano_crete_demo", "Existing application selection activates the matched profile")
	catalog.submit_sample_code("WV-LIA-01")
	_check(selection_events.size() == 1, "A hidden or submitting code entry cannot trigger a second selection")
	_check(WineDatabase.get_all_profiles() == before, "UI selection does not modify sample configuration")
	var report: Dictionary = {"passed": failures.is_empty(), "checks": checks, "failures": failures, "camera_used": false, "exact_matching": true}
	var file: FileAccess = FileAccess.open("res://work/sample_code_qa.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
	print("[SampleQA] " + JSON.stringify(report))
	app.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
