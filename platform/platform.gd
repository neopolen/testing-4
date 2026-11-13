@tool
extends AnimatableBody2D

@export_range(8.0, 2048.0, 1.0) var width := 128.0:
	set(value):
		width = value
		_update_platform()

@export_range(4.0, 256.0, 1.0) var height := 16.0:
	set(value):
		height = value
		_update_platform()

@export var color := Color("586b7a"):
	set(value):
		color = value
		_update_platform()

func _ready() -> void:
	_update_platform()

func _draw() -> void:
	var outer_rect := Rect2(Vector2(-width / 2.0, -height / 2.0), Vector2(width, height))
	draw_rect(outer_rect, Color("101a4a"))
	var inset := 3.0
	if width > inset * 2.0 and height > inset * 2.0:
		draw_rect(outer_rect.grow(-inset), color)

func _update_platform() -> void:
	queue_redraw()
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision and collision.shape is RectangleShape2D:
		var collision_inset := 3.0
		collision.position.y = -2.0
		(collision.shape as RectangleShape2D).size = Vector2(
			maxf(1.0, width - collision_inset * 2.0),
			maxf(1.0, height - collision_inset * 2.0)
		)
