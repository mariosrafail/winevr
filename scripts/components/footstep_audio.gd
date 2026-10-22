extends Node

const SAMPLES: Array[AudioStream] = [
	preload("res://assets/audio/footsteps/footstep_concrete_000.ogg"),
	preload("res://assets/audio/footsteps/footstep_concrete_001.ogg"),
	preload("res://assets/audio/footsteps/footstep_concrete_002.ogg"),
	preload("res://assets/audio/footsteps/footstep_concrete_003.ogg"),
	preload("res://assets/audio/footsteps/footstep_concrete_004.ogg"),
]
var player: AudioStreamPlayer
var _last_sample: int = -1
var _random: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_random.randomize()
	player = AudioStreamPlayer.new()
	add_child(player)

func play_step(strength: float) -> void:
	var index: int = _random.randi_range(0, SAMPLES.size() - 2)
	if index >= _last_sample:
		index += 1
	_last_sample = index
	player.stream = SAMPLES[index]
	player.volume_db = lerpf(-23.0, -16.0, clampf(strength, 0.0, 1.0))
	player.pitch_scale = _random.randf_range(0.96, 1.04)
	player.play()

func stop() -> void:
	player.stop()
