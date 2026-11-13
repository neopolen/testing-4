extends Area2D

signal collected

@onready var berry_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("toxic_berries")
	body_entered.connect(_on_body_entered)
	berry_sprite.play("idle")

func _on_body_entered(body: Node2D) -> void:
	if body.name != "Player":
		return

	collected.emit()
	queue_free()
