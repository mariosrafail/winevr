extends Node

var failures: Array[String] = []
var checks: int = 0
var capture: bool = false


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("[TastingQA] " + message)


func _run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	var app: Node = (load("res://scenes/WineVRExperience.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(app)
	await get_tree().create_timer(1.6).timeout
	(app.get("_main_menu") as MainMenuOverlayController).hide_menu()
	var hud: ExperienceHUDController = app.get("_hud") as ExperienceHUDController
	var journey: TastingJourneyController = app.get("_journey") as TastingJourneyController
	var hotspots: HotspotUIController = app.get("_hotspots") as HotspotUIController
	var narrative: NarrativePanelController = app.get("_narrative_panel") as NarrativePanelController
	var profiles: Array[Dictionary] = WineDatabase.get_all_profiles()
	_check(profiles.size() >= 6, "Original and three Cretan profiles coexist")
	for profile in profiles:
		var id: String = str(profile.get("id", ""))
		await app.call("_select_qr_client", id)
		(app.get("_onboarding") as OnboardingOverlayController).hide()
		get_tree().root.size = Vector2i(390, 844)
		await get_tree().create_timer(0.3).timeout
		await app.call("refresh_all_ui_layouts", "tasting portrait QA")
		await get_tree().process_frame
		_check(hud.intro_wine_name.text == str(profile.get("name", "")), id + " uses the chosen profile")
		_check(hud.intro_text.scroll_active and not hud.intro_text.fit_content, id + " long introduction scrolls")
		_check(journey.completed_ids.is_empty(), id + " begins without stale discoveries")
		_check(not journey.show_qr_button.visible if bool(profile.get("demo_collection", false)) else journey.show_qr_button.visible, id + " QR visibility follows collection type")
		_fits(hud.intro_card, id + " intro")
		_check(not narrative.panel.visible and not narrative.show_button.visible, id + " intro has one guide")
		if capture and id == "vidiano_crete_demo":
			await _capture("tasting_mobile_intro")
		ExperienceManager.start_experience()
		await get_tree().create_timer(0.2).timeout
		_fits(hud.inspection_info_card, id + " inspection card")
		_check(not narrative.panel.visible and not narrative.show_button.visible, id + " tasting has one guide")
		_check(not hotspots.can_enter_winery() and hud.enter_winery_button.disabled, id + " required points gate the cellar")
		if capture and id == "vidiano_crete_demo":
			await _capture("tasting_mobile_inspection")
		var step_count: int = journey.steps.size()
		for index in range(step_count):
			if not journey.active:
				journey.continue_button.pressed.emit()
			var active_id: String = journey.get_active_step_id()
			_check(not active_id.is_empty(), id + " next discovery remains reachable")
			for data in hotspots.active_hotspots:
				if hotspots.get_hotspot_id(data) == active_id:
					hotspots.call("_on_hotspot_pressed", data)
					break
			await get_tree().create_timer(0.25).timeout
			_check(hotspots.panel.visible, id + " opens the actual annotation")
			_fits(hotspots.panel, id + " annotation")
			_fits_global(hotspots.close_button, id + " annotation close button")
			if capture and id == "vidiano_crete_demo" and index == 0:
				await _capture("tasting_mobile_annotation")
			hotspots.close_panel()
			await get_tree().create_timer(0.25).timeout
		_check(journey.completed_ids.size() == step_count, id + " required and optional discoveries recorded")
		_check(hotspots.can_enter_winery() and not hud.enter_winery_button.disabled, id + " cellar unlocks after required points")
		_check(journey.completion_panel.visible and not journey.cellar_button.disabled, id + " completion offers the real cellar")
		_fits(journey.completion_panel, id + " completion")
		if capture and id == "vidiano_crete_demo":
			await _capture("tasting_mobile_completion")
		journey.close_completion_panel()
		journey.tasting_card_button.pressed.emit()
		await get_tree().create_timer(0.25).timeout
		_check(not "Locked" in journey.tasting_card_text.text and not "Άνοιξε αυτό" in journey.tasting_card_text.text, id + " notes reflect actual completed steps")
		_fits(journey.tasting_card_panel, id + " tasting notes")
		if capture and id == "vidiano_crete_demo":
			await _capture("tasting_mobile_notes")
		journey.close_tasting_card()
		journey.cellar_button.pressed.emit()
		await get_tree().create_timer(1.0).timeout
		_check(ExperienceManager.current_state == ExperienceManager.ExperienceState.WINERY_INTERIOR, id + " cellar CTA enters the scene")
		hud.show_interactable_modal({"title": "Στο κελάρι", "text": "Το κρασί εξελίσσεται μέσα από την επιλογή του δοχείου, τη θερμοκρασία και τον χρόνο. ".repeat(12)})
		await get_tree().create_timer(0.35).timeout
		_fits(hud.winery_modal, id + " long cellar annotation")
		_fits_global(hud.winery_modal.get_node("Margin/VBox/CloseButton") as Control, id + " cellar close button")
		_check(hud.winery_modal_text.scroll_active, id + " cellar annotation remains scrollable")
		if capture and id == "vidiano_crete_demo":
			await _capture("tasting_mobile_cellar")
		hud.close_winery_modal()
		await get_tree().create_timer(0.2).timeout
	# Narrow and landscape windows exercise content minima after text wraps.
	for dimensions in [Vector2i(320, 568), Vector2i(844, 390), Vector2i(1440, 900)]:
		await app.call("_select_qr_client", "vidiano_crete_demo")
		(app.get("_onboarding") as OnboardingOverlayController).hide()
		get_tree().root.size = dimensions
		await app.call("refresh_all_ui_layouts", "responsive tasting QA")
		await get_tree().create_timer(0.3).timeout
		_fits(hud.intro_card, "intro " + str(dimensions))
		ExperienceManager.start_experience()
		await get_tree().create_timer(0.2).timeout
		_fits(hud.inspection_info_card, "inspection " + str(dimensions))
		hotspots.open_centered_annotation_panel("Η ποικιλία", "Σάκχαρα, οξέα και πολυφαινόλες αλλάζουν στην ωρίμανση. ".repeat(8))
		await get_tree().create_timer(0.25).timeout
		_fits(hotspots.panel, "annotation " + str(dimensions))
		_fits_global(hotspots.close_button, "annotation close " + str(dimensions))
		hotspots.close_panel()
		await get_tree().create_timer(0.2).timeout
	var report: Dictionary = {"passed": failures.is_empty(), "checks": checks, "failures": failures, "profiles": profiles.size(), "portrait_size": get_viewport().get_visible_rect().size, "native_capture": capture}
	var file: FileAccess = FileAccess.open("res://work/tasting_qa.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
	print("[TastingQA] " + JSON.stringify(report))
	app.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)


func _fits(panel: Control, label: String) -> void:
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	_check(panel.size.x <= viewport.x and panel.size.y <= viewport.y - 20 and panel.position.y + panel.size.y <= viewport.y, label + " fits portrait viewport")


func _fits_global(control: Control, label: String) -> void:
	var rect: Rect2 = control.get_global_rect()
	var viewport: Rect2 = get_viewport().get_visible_rect()
	_check(viewport.encloses(rect), label + " stays reachable on screen")


func _capture(name: String) -> void:
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://work/" + name + ".png")
