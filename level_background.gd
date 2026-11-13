extends Node2D

const NIGHT_TEXTURE: Texture2D = preload("res://background/night_background.png")
const BACKGROUND_OVERSCAN := 1.0
const PARALLAX_FACTOR := 0.08
const STAR_SPARKLE_POSITIONS := [
	Vector2(375, 12),
	Vector2(428, 12),
	Vector2(222, 28),
	Vector2(581, 28),
	Vector2(89, 17),
	Vector2(713, 17),
]

@onready var player: CharacterBody2D = get_parent().get_parent().get_node_or_null("Player") as CharacterBody2D

var _background_offset := Vector2.ZERO
var _sparkle_time := 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var viewport_size := get_viewport().get_visible_rect().size
	var draw_size := Vector2(NIGHT_TEXTURE.get_width(), NIGHT_TEXTURE.get_height()) * _get_background_scale(viewport_size)
	_background_offset.x = (draw_size.x - viewport_size.x) * 0.5

func _process(delta: float) -> void:
	_sparkle_time += delta
	if is_instance_valid(player) and player.velocity.length_squared() > 4.0:
		var viewport_size := get_viewport().get_visible_rect().size
		var draw_size := Vector2(NIGHT_TEXTURE.get_width(), NIGHT_TEXTURE.get_height()) * _get_background_scale(viewport_size)
		var max_offset := (draw_size - viewport_size) * 0.5
		_background_offset.x -= player.velocity.x * delta * PARALLAX_FACTOR
		_background_offset.x = clampf(_background_offset.x, -max_offset.x, max_offset.x)
	queue_redraw()

func _draw() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var draw_size := Vector2(NIGHT_TEXTURE.get_width(), NIGHT_TEXTURE.get_height()) * _get_background_scale(viewport_size)
	var draw_position := (viewport_size - draw_size) * 0.5 + _background_offset
	draw_texture_rect(NIGHT_TEXTURE, Rect2(draw_position, draw_size), false)
	_draw_star_sparkles(draw_position, draw_size.x / NIGHT_TEXTURE.get_width())

func _draw_star_sparkles(draw_position: Vector2, scale: float) -> void:
	var pixel_size := maxf(scale, 1.0)
	for index in range(STAR_SPARKLE_POSITIONS.size()):
		var pulse := 0.5 + 0.5 * sin(_sparkle_time * 2.4 + float(index) * 2.1)
		var arm_length := 1 + floori(pulse * 2.0)
		var star_position: Vector2 = STAR_SPARKLE_POSITIONS[index]
		var center: Vector2 = draw_position + (star_position + Vector2(0.5, 0.5)) * scale
		center = (center / pixel_size).round() * pixel_size + Vector2.ONE * pixel_size * 0.5
		var color := Color(0.78, 0.9, 1.0, 0.24 + pulse * 0.58)
		var center_rect := Rect2(center - Vector2.ONE * pixel_size * 0.5, Vector2.ONE * pixel_size)
		draw_rect(center_rect, color)
		for arm in range(1, arm_length + 1):
			var arm_alpha := 0.18 + pulse * 0.4
			var arm_color := Color(color.r, color.g, color.b, arm_alpha)
			var distance := float(arm) * pixel_size
			draw_rect(Rect2(center + Vector2(distance, -pixel_size * 0.5), Vector2(pixel_size, pixel_size)), arm_color)
			draw_rect(Rect2(center + Vector2(-distance - pixel_size, -pixel_size * 0.5), Vector2(pixel_size, pixel_size)), arm_color)
			draw_rect(Rect2(center + Vector2(-pixel_size * 0.5, distance), Vector2(pixel_size, pixel_size)), arm_color)
			draw_rect(Rect2(center + Vector2(-pixel_size * 0.5, -distance - pixel_size), Vector2(pixel_size, pixel_size)), arm_color)

func _get_background_scale(viewport_size: Vector2) -> float:
	var fit_scale := maxf(
		viewport_size.x / float(NIGHT_TEXTURE.get_width()),
		viewport_size.y / float(NIGHT_TEXTURE.get_height())
	)
	return fit_scale * BACKGROUND_OVERSCAN
