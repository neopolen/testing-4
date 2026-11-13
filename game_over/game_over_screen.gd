extends CanvasLayer

const ANIMATION_SIZE := Vector2(320, 180)
const PROMPT_ART_RECT := Rect2(56, 136, 208, 30)

@onready var animation_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var prompt_mask: ColorRect = $PromptMask
@onready var prompt_label: Label = $PromptLabel

var _is_restarting := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	get_viewport().size_changed.connect(_fit_to_viewport)
	animation_sprite.stop()
	animation_sprite.frame = 0
	_fit_to_viewport()

func _input(event: InputEvent) -> void:
	if _is_restarting or not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if key_event.keycode == KEY_SPACE and key_event.pressed and not key_event.echo:
		get_viewport().set_input_as_handled()
		_restart_after_animation()

func _restart_after_animation() -> void:
	_is_restarting = true
	prompt_label.hide()
	animation_sprite.play(&"game_over")
	await animation_sprite.animation_finished
	get_tree().paused = false
	get_tree().reload_current_scene()

func _fit_to_viewport() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var image_scale := minf(viewport_size.x / ANIMATION_SIZE.x, viewport_size.y / ANIMATION_SIZE.y)
	var image_offset := (viewport_size - ANIMATION_SIZE * image_scale) * 0.5
	animation_sprite.position = viewport_size * 0.5
	animation_sprite.scale = Vector2.ONE * image_scale
	prompt_mask.position = image_offset + PROMPT_ART_RECT.position * image_scale
	prompt_mask.size = PROMPT_ART_RECT.size * image_scale
	prompt_label.position = prompt_mask.position
	prompt_label.size = prompt_mask.size
