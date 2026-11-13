extends CanvasLayer

const FRAME_ONE_DELAY := 1.5
const FRAME_STEP_DELAY := 0.28
const MOVING_FRAME_STEP_DELAY := 0.12
const AFTER_FRAME_THREE_DELAY := 1.0
const INTRO_FRAME_SIZE := Vector2(320.0, 180.0)
const LAST_FRAME := 6

@onready var intro_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var player: CharacterBody2D = get_parent().get_node_or_null("Player") as CharacterBody2D
@onready var player_visual: AnimatedSprite2D = player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D if is_instance_valid(player) else null
@onready var portal_visual: AnimatedSprite2D = get_parent().get_node_or_null("StartPortal/AnimatedSprite2D") as AnimatedSprite2D

var _frame_delay_left := FRAME_ONE_DELAY
var _after_frame_three := false
var _movement_started := false
var _first_frame_pending := true

func _ready() -> void:
	get_viewport().size_changed.connect(_fit_intro_to_viewport)
	intro_sprite.animation = &"intro"
	intro_sprite.stop()
	intro_sprite.frame = 0
	_fit_intro_to_viewport()

func _process(delta: float) -> void:
	_fit_intro_to_viewport()
	if not _movement_started and _player_is_moving():
		_movement_started = true
		if _after_frame_three:
			_after_frame_three = false
			_advance_frame()
		elif not _first_frame_pending:
			_frame_delay_left = minf(_frame_delay_left, MOVING_FRAME_STEP_DELAY)

	if _after_frame_three:
		_frame_delay_left -= delta
		if _frame_delay_left <= 0.0:
			_after_frame_three = false
			_advance_frame()
		return

	_frame_delay_left -= delta
	if _frame_delay_left <= 0.0:
		_advance_frame()

func _player_is_moving() -> bool:
	if Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right"):
		return true
	if Input.is_action_just_pressed("jump") or Input.is_action_pressed("dash"):
		return true
	# Vertical fall speed at spawn comes from gravity, so only horizontal velocity counts.
	return is_instance_valid(player) and absf(player.velocity.x) > 1.0

func _advance_frame() -> void:
	var next_frame := intro_sprite.frame + 1
	if next_frame > LAST_FRAME:
		queue_free()
		return

	intro_sprite.frame = next_frame
	_first_frame_pending = false
	if next_frame == 2 and not _movement_started:
		_after_frame_three = true
		_frame_delay_left = AFTER_FRAME_THREE_DELAY
	else:
		_frame_delay_left = MOVING_FRAME_STEP_DELAY if _movement_started else FRAME_STEP_DELAY

func _fit_intro_to_viewport() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var center := _get_intro_focus_screen_position(viewport_size)
	var half_width := maxf(center.x, viewport_size.x - center.x)
	var half_height := maxf(center.y, viewport_size.y - center.y)
	var fit_scale := maxf(
		(half_width * 2.0 + 2.0) / INTRO_FRAME_SIZE.x,
		(half_height * 2.0 + 2.0) / INTRO_FRAME_SIZE.y
	)
	intro_sprite.scale = Vector2.ONE * fit_scale
	intro_sprite.position = center

func _get_intro_focus_screen_position(viewport_size: Vector2) -> Vector2:
	var focus_points: Array[Vector2] = []
	if is_instance_valid(player_visual):
		focus_points.append(player_visual.get_global_transform_with_canvas().origin)
	elif is_instance_valid(player):
		focus_points.append(player.get_global_transform_with_canvas().origin)
	if is_instance_valid(portal_visual):
		focus_points.append(portal_visual.get_global_transform_with_canvas().origin)
	if focus_points.size() == 2:
		# Keep the player and the portal together in the center of the opening.
		return (focus_points[0] + focus_points[1]) * 0.5
	if focus_points.size() == 1:
		return focus_points[0]
	return viewport_size * 0.5
