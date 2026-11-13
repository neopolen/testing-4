extends Area2D

const DAMAGE_PER_TOUCH := 11.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var trigger_shape: CollisionShape2D = $CollisionShape2D
@onready var player: CharacterBody2D = get_parent().get_node_or_null("Player") as CharacterBody2D

var _player_touching := false

func _ready() -> void:
	animated_sprite.play(&"fg_purple")

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player) or not player.has_method("take_damage"):
		return
	var player_shape := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var player_center := player.global_position
	var player_half_size := Vector2(10, 15)
	if player_shape and player_shape.shape is RectangleShape2D:
		player_center = player_shape.global_position
		var body_rectangle := player_shape.shape as RectangleShape2D
		player_half_size = (body_rectangle.size * player_shape.global_scale.abs()) * 0.5

	var hazard_center := trigger_shape.global_position
	var hazard_rectangle := trigger_shape.shape as RectangleShape2D
	var hazard_half_size := (hazard_rectangle.size * trigger_shape.global_scale.abs()) * 0.5
	var offset := (player_center - hazard_center).abs()
	var exit_margin := 2.0 if _player_touching else 0.0
	var touching := offset.x <= player_half_size.x + hazard_half_size.x + exit_margin and offset.y <= player_half_size.y + hazard_half_size.y + exit_margin
	if touching and not _player_touching:
		player.call("take_damage", DAMAGE_PER_TOUCH)
	_player_touching = touching
