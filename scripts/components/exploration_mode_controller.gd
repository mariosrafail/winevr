extends Node
class_name ExplorationModeController

signal exploration_mode_entered
signal exploration_mode_exited

var canvas_layer: CanvasLayer
var winery_interior: WineryInteriorController
var graphics_panel: GraphicsSettingsPanelController
var crosshair: CrosshairController
var explore_button: Button
var active: bool = false
var available: bool = false


func setup(parent_canvas_layer: CanvasLayer, winery: WineryInteriorController, crosshair_controller: CrosshairController, options_panel: GraphicsSettingsPanelController = null) -> void:
	canvas_layer = parent_canvas_layer
	winery_interior = winery
	crosshair = crosshair_controller
	graphics_panel = options_panel
	_build_button()


func set_available(is_available: bool) -> void:
	available = is_available
	if explore_button != null:
		explore_button.visible = available
	if not available and active:
		exit_mode()


func toggle() -> void:
	if active:
		exit_mode()
	else:
		enter_mode()


func enter_mode() -> void:
	if active or not available:
		return
	if graphics_panel != null and graphics_panel.is_open():
		graphics_panel.close()
	active = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if winery_interior != null:
		winery_interior.set_exploration_mode_active(true)
	if crosshair != null:
		crosshair.set_active(true)
	if explore_button != null:
		explore_button.text = "Exploring"
	exploration_mode_entered.emit()


func exit_mode() -> void:
	if not active:
		return
	active = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if winery_interior != null:
		winery_interior.set_exploration_mode_active(false)
	if crosshair != null:
		crosshair.set_active(false)
	if explore_button != null:
		explore_button.text = "Explore"
	exploration_mode_exited.emit()


func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed("toggle_explore_mode") and (available or active):
		toggle()
		return true
	if active and event.is_action_pressed("exit_mode"):
		exit_mode()
		return true
	return false


func layout(viewport_size: Vector2) -> void:
	if explore_button == null:
		return
	var safe_margin: float = 20.0 if viewport_size.x >= 760.0 else 16.0
	explore_button.size = Vector2(128.0, 44.0)
	explore_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT, false)
	explore_button.set_offset(SIDE_LEFT, safe_margin)
	explore_button.set_offset(SIDE_TOP, -explore_button.size.y * 2.0 - safe_margin - 10.0)
	explore_button.set_offset(SIDE_RIGHT, safe_margin + explore_button.size.x)
	explore_button.set_offset(SIDE_BOTTOM, -explore_button.size.y - safe_margin - 10.0)
	if crosshair != null:
		crosshair.layout(viewport_size)


func _build_button() -> void:
	explore_button = Button.new()
	explore_button.name = "ExploreModeButton"
	explore_button.text = "Explore"
	explore_button.tooltip_text = "Toggle Explore Mode"
	explore_button.visible = false
	explore_button.z_index = 98
	explore_button.custom_minimum_size = Vector2(128.0, 44.0)
	PremiumUIStyles.apply_gold_outline_button(explore_button)
	explore_button.pressed.connect(toggle)
	canvas_layer.add_child(explore_button)
