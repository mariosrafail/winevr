extends SceneTree

const PACKER: Script = preload("res://scripts/winery/grape_bunch_spacing.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var report: Dictionary = {}
	for id in ["liatiko", "kotsifali"]:
		var body: Node3D = Node3D.new()
		root.add_child(body)
		var model: Node3D = load("res://assets/models/grape_museum/" + id + "_bunch.glb").instantiate()
		body.add_child(model)
		model.scale = Vector3.ONE * 2.5
		var result: Dictionary = PACKER.pack_model(model, body)
		print("[GrapeSpacing] ", id, " ", JSON.stringify(result))
		if float(result["after_gap_mm"]) < 1.5:
			quit(1)
			return
		model.scale = Vector3.ONE
		model.scene_file_path = ""
		for node in model.find_children("*", "Node", true, false):
			node.owner = model
		var packed: PackedScene = PackedScene.new()
		var error: Error = packed.pack(model)
		if error == OK:
			error = ResourceSaver.save(packed, "res://assets/models/grape_museum/" + id + "_bunch_spaced.scn", ResourceSaver.FLAG_COMPRESS)
		if error != OK:
			push_error("Could not save spaced grape model: " + str(error))
			quit(1)
			return
		report[id] = result
		body.free()
	var file: FileAccess = FileAccess.open("res://assets/models/grape_museum/spacing_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	quit(0)
