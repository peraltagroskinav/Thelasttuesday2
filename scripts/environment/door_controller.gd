extends Node3D

@export_range(45.0, 120.0, 1.0) var open_angle_degrees: float = 96.0
@export_range(0.1, 1.5, 0.05) var movement_duration: float = 0.55

@onready var _creak: AudioStreamPlayer3D = $DoorCreak

var _is_open: bool = false
var _base_rotation_y: float = 0.0
var _movement: Tween


func _ready() -> void:
	_base_rotation_y = rotation.y
	var creak_stream := load("res://assets/audio/door_creak.wav") as AudioStreamWAV
	if creak_stream == null:
		push_error("Door creak WAV could not be loaded.")
		return
	_creak.stream = creak_stream


func get_interaction_prompt() -> String:
	return "Fechar a porta" if _is_open else "Abrir a porta"


func interact(_interactor: Node) -> void:
	if _movement != null and _movement.is_running():
		return
	_is_open = not _is_open
	_creak.play()
	var target_angle: float = deg_to_rad(open_angle_degrees) * (1.0 if _is_open else 0.0)
	_movement = create_tween()
	_movement.set_trans(Tween.TRANS_SINE)
	_movement.set_ease(Tween.EASE_IN_OUT)
	_movement.tween_property(
		self,
		"rotation:y",
		_base_rotation_y + target_angle,
		movement_duration
	)
