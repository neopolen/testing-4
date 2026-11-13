extends Area2D

const DAMAGE_PER_TOUCH := 11.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

@export var fall_speed := 360.0
@export var max_fall_distance := 600.0

var _spawn_y := 0.0

func _ready() -> void:
	_spawn_y = global_position.y
	animated_sprite.play(&"fg_blue")
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	global_position.y += fall_speed * delta
	if global_position.y - _spawn_y >= max_fall_distance:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.call("take_damage", DAMAGE_PER_TOUCH)
	queue_free()
