extends CanvasLayer

const POST_TRANSITION_DELAY := 0.65

@onready var title_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var prompt_label: Label = $PromptLabel

var _is_starting := false

func _ready() -> void:
	get_tree().paused = true
	get_viewport().size_changed.connect(_fit_title_to_viewport)
	_fit_title_to_viewport()
	title_sprite.play("title")

func _input(event: InputEvent) -> void:
	if _is_starting:
		return
	if event is InputEventKey and event.keycode == KEY_SPACE and event.pressed and not event.echo:
		_is_starting = true
		prompt_label.hide()
		get_viewport().set_input_as_handled()
		_start_game()

func _start_game() -> void:
	title_sprite.play("start")
	await title_sprite.animation_finished
	await get_tree().create_timer(POST_TRANSITION_DELAY, true).timeout
	get_tree().paused = false
	queue_free()

func _fit_title_to_viewport() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	title_sprite.position = viewport_size * 0.5
	var fit_scale := minf(viewport_size.x / 320.0, viewport_size.y / 180.0)
	title_sprite.scale = Vector2.ONE * fit_scale
