extends Node2D

const FALLING_SPIKE_SCENE: PackedScene = preload("res://hazards/falling_spikes/falling_spike.tscn")

@export_range(0.0, 160.0, 1.0) var spawn_width := 48.0
@export_range(0.5, 10.0, 0.1) var minimum_interval := 1.6
@export_range(0.5, 10.0, 0.1) var maximum_interval := 3.4

var _random := RandomNumberGenerator.new()
var _spawn_timer: Timer

func _ready() -> void:
	_random.randomize()
	_spawn_timer = Timer.new()
	_spawn_timer.one_shot = true
	_spawn_timer.timeout.connect(_spawn_spike)
	add_child(_spawn_timer)
	_schedule_next_spawn()

func _schedule_next_spawn() -> void:
	_spawn_timer.start(_random.randf_range(minimum_interval, maximum_interval))

func _spawn_spike() -> void:
	var spike := FALLING_SPIKE_SCENE.instantiate() as Area2D
	get_parent().add_child(spike)
	spike.global_position = global_position + Vector2(_random.randf_range(-spawn_width * 0.5, spawn_width * 0.5), 0.0)
	_schedule_next_spawn()
