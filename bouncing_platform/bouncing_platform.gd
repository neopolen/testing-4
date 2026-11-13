extends AnimatableBody2D

@onready var sprite: Sprite2D = $Sprite2D

var _rest_scale := Vector2.ONE
var _bounce_tween: Tween

func _ready() -> void:
	add_to_group("bouncing_platforms")
	_rest_scale = sprite.scale

func play_bounce() -> void:
	if _bounce_tween and _bounce_tween.is_running():
		_bounce_tween.kill()
	sprite.scale = _rest_scale
	_bounce_tween = create_tween()
	_bounce_tween.tween_property(sprite, "scale", _rest_scale * Vector2(1.18, 0.68), 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_bounce_tween.tween_property(sprite, "scale", _rest_scale * Vector2(0.92, 1.12), 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_bounce_tween.tween_property(sprite, "scale", _rest_scale, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
