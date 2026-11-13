class_name Player
extends CharacterBody2D

signal died

enum State { GROUND, JUMP, DOUBLE_JUMP, FALL }

const MAX_JUMPS := 2
const BOUNCE_JUMP_MULTIPLIER := 1.55
const MAX_HEALTH := 100.0
const DAMAGE_FLASH_COLOR := Color(1.0, 0.12, 0.16, 1.0)
const SUPER_DASH_SPEED_MULTIPLIER := 3.4
const SUPER_DASH_EXTRA_DURATION := 1.0
const TOXIC_HEAT_LIMIT := 6

var jump_count := 0
var _bounce_extra_jump_available := false

@export var acceleration := 650.0
@export var deceleration := 1200.0
@export var max_speed := 180.0
@export var jump_acceleration := 500.0
@export_range(1.0, 2.5, 0.05) var dash_speed_multiplier := 2.1
@export_range(0.1, 2.0, 0.05) var dash_duration := 0.5
@export_range(0.1, 10.0, 0.1) var dash_cooldown := 3.0
@export_range(1.0, 1.5, 0.01) var dash_camera_zoom_multiplier := 1.12

@export_category("jump")
@export_range(10.0, 200.0) var jump_height := 110.0
@export_range(0.1, 1.5) var jump_time_to_peak := 0.45
@export_range(0.1, 1.5) var jump_time_to_descent := 0.4
@export_range(50.0, 200.0) var jump_horizontal_distance := 100.0

@export_range(5.0, 50.0) var jump_cut_divider := 15.0

@export_category("Double Jump")
@export_range(10.0, 200.0) var double_jump_height := 48.0
@export_range(0.1, 1.5) var double_jump_time_to_peak := 0.3
@export_range(0.1, 1.5) var double_jump_time_to_descent := 0.25

@export_category("Wall Climb")
@export_range(0.5, 1.5, 0.05) var wall_climb_jump_multiplier := 0.95
@export_range(0.0, 180.0, 1.0) var wall_climb_horizontal_push := 48.0

@onready var double_jump_speed := calculate_jump_speed(double_jump_height, double_jump_time_to_peak)
@onready var double_jump_gravity := calculate_jump_gravity(double_jump_height, double_jump_time_to_peak)
@onready var double_jump_fall_gravity := calculate_fall_gravity(double_jump_height, double_jump_time_to_descent)

var direction_x := 0.0
var current_state: State = State.GROUND
var current_gravity := 0.0

@onready var jump_speed := calculate_jump_speed(jump_height, jump_time_to_peak)
@onready var jump_gravity := calculate_jump_gravity(jump_height, jump_time_to_peak)
@onready var fall_gravity := calculate_fall_gravity(jump_height, jump_time_to_descent)
@onready var jump_horizontal_speed := calculate_jump_horizontal_speed(jump_horizontal_distance, jump_time_to_peak, jump_time_to_descent)

@onready var dust: GPUParticles2D = $Dust
@onready var dash_particles: GPUParticles2D = $DashParticles
@onready var double_jump_effect: AnimatedSprite2D = $DoubleJumpEffect
@onready var animated_sprite: AnimatedSprite2D = %AnimatedSprite2D
@onready var health_bar: ProgressBar = $HealthBar
@onready var camera: Camera2D = get_node_or_null("Camera2D") as Camera2D
@onready var coyote_timer := Timer.new()

const CAMERA_LOOK_OFFSET := 40.0
const CAMERA_LOOK_DURATION := 0.18

var _look_direction := 0
var _camera_default_position := Vector2.ZERO
var _camera_default_zoom := Vector2.ONE
var _camera_tween: Tween
var _dash_camera_tween: Tween
var _is_dashing := false
var _is_super_dashing := false
var _active_dash_multiplier := 1.0
var _is_downward_dashing := false
var _dash_time_left := 0.0
var _dash_cooldown_left := 0.0
var _dash_color_tween: Tween
var _damage_flash_tween: Tween
var _damage_flash_restore_color := Color.WHITE
var _camera_shake_tween: Tween
var _sprite_base_scale := Vector2.ONE
var _sprite_scale_tween: Tween
var _skip_initial_landing_tween := true
var _wall_climb_dust_time_left := 0.0
var health := MAX_HEALTH
var _is_dead := false

const DASH_TINT := Color(0.55, 0.85, 1.0, 1.0)

func _ready() -> void:
	_sprite_base_scale = animated_sprite.scale
	health_bar.max_value = MAX_HEALTH
	health_bar.value = health
	if camera:
		_camera_default_position = camera.position
		_camera_default_zoom = camera.zoom
	_transition_to_state(current_state)
	coyote_timer.wait_time = 0.1
	coyote_timer.one_shot = true
	add_child(coyote_timer)
	double_jump_effect.animation_finished.connect(_on_double_jump_effect_finished)

func _physics_process(delta: float) -> void:
	direction_x = signf(Input.get_axis("move_left", "move_right"))
	_dash_cooldown_left = maxf(0.0, _dash_cooldown_left - delta)
	_wall_climb_dust_time_left = maxf(0.0, _wall_climb_dust_time_left - delta)
	if Input.is_action_just_pressed("jump") and not _is_dashing:
		_try_wall_climb_jump()
	if not _is_dashing and is_zero_approx(_dash_cooldown_left):
		if Input.is_action_just_pressed("super_dash") and _can_super_dash():
			_start_dash(true)
		elif Input.is_action_just_pressed("dash"):
			_start_dash()
	if _is_dashing:
		_dash_time_left -= delta
		if _dash_time_left <= 0.0:
			_finish_dash()

	match current_state:
		State.GROUND:
			_process_ground_state(delta)
		State.JUMP:
			_process_jump_state(delta)
		State.FALL:
			_process_fall_state(delta)
		State.DOUBLE_JUMP:
			_process_double_jump_state(delta)

	if not _is_dashing:
		velocity.y += current_gravity * delta
	move_and_slide()
	if not _is_dashing:
		_handle_bouncing_platform_landing()
	if _is_dashing and _is_downward_dashing and is_on_floor():
		_finish_dash()
	var wall_climbing := is_on_wall() and not is_on_floor() and not _is_dashing and _is_moving_toward_wall()
	dust.emitting = (is_on_floor() and not is_zero_approx(direction_x)) or wall_climbing or _wall_climb_dust_time_left > 0.0

func _try_wall_climb_jump() -> void:
	if not is_on_wall() or is_zero_approx(direction_x):
		return
	var wall_normal := get_wall_normal()
	if absf(wall_normal.x) < 0.6 or direction_x * wall_normal.x >= 0.0:
		return

	_transition_to_state(State.JUMP)
	velocity.y = jump_speed * wall_climb_jump_multiplier
	velocity.x = wall_normal.x * wall_climb_horizontal_push
	current_gravity = jump_gravity
	_bounce_extra_jump_available = false
	_wall_climb_dust_time_left = 0.26
	coyote_timer.stop()
	_set_look_direction(0)
	if not is_zero_approx(wall_normal.x):
		animated_sprite.flip_h = wall_normal.x < 0.0

func _is_moving_toward_wall() -> bool:
	if not is_on_wall() or is_zero_approx(direction_x):
		return false
	var wall_normal := get_wall_normal()
	return absf(wall_normal.x) >= 0.6 and direction_x * wall_normal.x < 0.0

func _handle_bouncing_platform_landing() -> void:
	if velocity.y < 0.0:
		return
	for collision_index in get_slide_collision_count():
		var collision := get_slide_collision(collision_index)
		if collision.get_normal().y > -0.6:
			continue
		var collider := collision.get_collider() as Node
		if not is_instance_valid(collider) or not collider.is_in_group("bouncing_platforms"):
			continue
		velocity.y = jump_speed * BOUNCE_JUMP_MULTIPLIER
		current_gravity = jump_gravity
		current_state = State.JUMP
		jump_count = 1
		_bounce_extra_jump_available = true
		coyote_timer.stop()
		_set_look_direction(0)
		_play_animation_or_idle("jump")
		play_tween_jump()
		if collider.has_method("play_bounce"):
			collider.call("play_bounce")
		break

func _can_super_dash() -> bool:
	var level := get_parent()
	return level != null and int(level.get("toxic_berry_count")) >= TOXIC_HEAT_LIMIT

func _start_dash(super_dash := false) -> void:
	_is_dashing = true
	_is_super_dashing = super_dash
	_active_dash_multiplier = SUPER_DASH_SPEED_MULTIPLIER if super_dash else dash_speed_multiplier
	_dash_time_left = dash_duration + (SUPER_DASH_EXTRA_DURATION if super_dash else 0.0)
	_dash_cooldown_left = dash_cooldown
	_set_look_direction(0)
	if super_dash:
		if animated_sprite.sprite_frames.has_animation(&"super_dash"):
			animated_sprite.play(&"super_dash")
	else:
		if animated_sprite.sprite_frames.has_animation(&"dash"):
			animated_sprite.play(&"dash")
	var dash_direction := Vector2(Input.get_axis("move_left", "move_right"), 1.0 if Input.is_action_pressed("look_down") else 0.0).normalized()
	if dash_direction.is_zero_approx():
		dash_direction = Vector2.LEFT if animated_sprite.flip_h else Vector2.RIGHT
	_is_downward_dashing = dash_direction.y > 0.0
	velocity = dash_direction * max_speed * _active_dash_multiplier
	if not is_zero_approx(dash_direction.x):
		animated_sprite.flip_h = dash_direction.x < 0.0
	_tween_dash_camera_zoom(_camera_default_zoom * dash_camera_zoom_multiplier, 0.14)
	dash_particles.position = -dash_direction * 10.0
	dash_particles.rotation = dash_direction.angle()
	dash_particles.emitting = not super_dash
	if _dash_color_tween and _dash_color_tween.is_running():
		_dash_color_tween.kill()
	if _damage_flash_tween and _damage_flash_tween.is_running():
		_damage_flash_restore_color = DASH_TINT
	else:
		_dash_color_tween = create_tween()
		_dash_color_tween.tween_property(animated_sprite, "modulate", DASH_TINT, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _finish_dash() -> void:
	_is_dashing = false
	_is_super_dashing = false
	_active_dash_multiplier = 1.0
	_is_downward_dashing = false
	_dash_time_left = 0.0
	velocity.x = clampf(velocity.x, -max_speed, max_speed)
	_tween_dash_camera_zoom(_camera_default_zoom, 0.24)
	dash_particles.emitting = false
	if _damage_flash_tween and _damage_flash_tween.is_running():
		_damage_flash_restore_color = Color.WHITE
	else:
		if _dash_color_tween and _dash_color_tween.is_running():
			_dash_color_tween.kill()
		_dash_color_tween = create_tween()
		_dash_color_tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_restore_animation_after_dash()

func take_damage(amount: float = 11.0) -> void:
	if _is_dead or health <= 0.0:
		return
	health = maxf(0.0, health - amount)
	health_bar.value = health
	if _dash_color_tween and _dash_color_tween.is_running():
		_dash_color_tween.kill()
	if _damage_flash_tween and _damage_flash_tween.is_running():
		_damage_flash_tween.kill()
	_damage_flash_restore_color = DASH_TINT if _is_dashing else Color.WHITE
	animated_sprite.modulate = DAMAGE_FLASH_COLOR
	_damage_flash_tween = create_tween()
	_damage_flash_tween.tween_property(animated_sprite, "modulate", _damage_flash_restore_color, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_shake_camera()
	if health <= 0.0:
		_is_dead = true
		velocity = Vector2.ZERO
		set_physics_process(false)
		died.emit()

func _shake_camera() -> void:
	if not is_instance_valid(camera):
		return
	if _camera_shake_tween and _camera_shake_tween.is_running():
		_camera_shake_tween.kill()
	camera.offset = Vector2.ZERO
	_camera_shake_tween = create_tween()
	_camera_shake_tween.tween_property(camera, "offset", Vector2(6, -3), 0.035)
	_camera_shake_tween.tween_property(camera, "offset", Vector2(-6, 3), 0.045)
	_camera_shake_tween.tween_property(camera, "offset", Vector2(4, -2), 0.04)
	_camera_shake_tween.tween_property(camera, "offset", Vector2(-2, 1), 0.035)
	_camera_shake_tween.tween_property(camera, "offset", Vector2.ZERO, 0.06)

func _restore_animation_after_dash() -> void:
	match current_state:
		State.GROUND:
			if not is_zero_approx(direction_x):
				_play_animation_or_idle("walking")
			else:
				_process_stopped_animation()
		State.JUMP:
			_play_animation_or_idle("jump")
		State.DOUBLE_JUMP:
			_play_animation_or_idle("Jump")
		State.FALL:
			_play_animation_or_idle("fall")

func _current_speed_limit() -> float:
	return max_speed * (_active_dash_multiplier if _is_dashing else 1.0)

func _tween_dash_camera_zoom(target_zoom: Vector2, duration: float) -> void:
	if not camera:
		return
	if _dash_camera_tween and _dash_camera_tween.is_running():
		_dash_camera_tween.kill()
	_dash_camera_tween = create_tween()
	_dash_camera_tween.tween_property(camera, "zoom", target_zoom, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _play_double_jump_effect() -> void:
	double_jump_effect.visible = true
	double_jump_effect.stop()
	double_jump_effect.frame = 0
	double_jump_effect.play(&"double jump effect")

func _on_double_jump_effect_finished() -> void:
	double_jump_effect.visible = false
	
func _process_double_jump_state(delta: float) -> void:
	if direction_x != 0.0:
		velocity.x += jump_acceleration * direction_x * delta
		velocity.x = clampf(velocity.x, -_current_speed_limit(), _current_speed_limit())
		animated_sprite.flip_h = direction_x < 0.0

	if velocity.y >= 0.0:
		_transition_to_state(State.FALL)
	elif is_on_floor():
		_transition_to_state(State.GROUND)
		
func _process_ground_state(delta: float) -> void:
	var is_moving := absf(direction_x) > 0.0
	if is_moving:
		_set_look_direction(0)
		velocity.x += acceleration * direction_x * delta
		velocity.x = clampf(velocity.x, -_current_speed_limit(), _current_speed_limit())
		animated_sprite.flip_h = direction_x < 0.0
		if not _is_dashing and animated_sprite.animation != "walking":
			animated_sprite.play("walking")
	else:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
		if not _is_dashing:
			var can_look := is_zero_approx(velocity.x) and is_on_floor()
			var desired_look := 0
			if can_look and animated_sprite.animation in [&"idle", &"looking up", &"looking down"]:
				if Input.is_action_pressed("look_up"):
					desired_look = -1
				elif Input.is_action_pressed("look_down"):
					desired_look = 1

			if desired_look != 0:
				_set_look_direction(desired_look)
			else:
				_set_look_direction(0)
				_process_stopped_animation()
	
	if Input.is_action_just_pressed("jump"):
		_transition_to_state(State.JUMP)
	elif not is_on_floor():
		_transition_to_state(State.FALL)

func _process_jump_state(delta: float) -> void:
	if Input.is_action_just_pressed("jump") and _bounce_extra_jump_available and not _is_dashing:
		_transition_to_state(State.DOUBLE_JUMP)
		return

	if not is_zero_approx(direction_x):
		velocity.x += jump_acceleration * direction_x * delta
		velocity.x = clampf(velocity.x, -_current_speed_limit(), _current_speed_limit())
		animated_sprite.flip_h = direction_x < 0.0
		
	if Input.is_action_just_released("jump"):
			var jump_cut_speed := jump_speed / jump_cut_divider
			if velocity.y < 0.0 and velocity.y < jump_cut_speed:
				velocity.y = jump_cut_speed


	if velocity.y >= 0.0:
		_transition_to_state(State.FALL)
	elif is_on_floor():
		_transition_to_state(State.GROUND)

func _process_fall_state(delta: float) -> void:
	if not is_zero_approx(direction_x):
		velocity.x += jump_acceleration * direction_x * delta
		velocity.x = clampf(velocity.x, -_current_speed_limit(), _current_speed_limit())
		animated_sprite.flip_h = direction_x < 0.0

	if Input.is_action_just_pressed("jump"):
		if not coyote_timer.is_stopped():
			_transition_to_state(State.JUMP)
		elif not _is_dashing and jump_count == 1:
			_transition_to_state(State.DOUBLE_JUMP)
	elif is_on_floor():
		_transition_to_state(State.GROUND)

func _transition_to_state(new_state: State) -> void:
	if new_state == State.DOUBLE_JUMP and (_is_dashing or jump_count != 1):
		return

	var previous_state := current_state
	current_state = new_state
	
	match previous_state:
		State.FALL:
			coyote_timer.stop()

	match current_state:
		State.GROUND:
			jump_count = 0
			_bounce_extra_jump_available = false
			if previous_state == State.FALL:
				if _skip_initial_landing_tween:
					_skip_initial_landing_tween = false
				else:
					play_tween_touch_ground()

			
		State.JUMP:
			_bounce_extra_jump_available = false
			_set_look_direction(0)
			velocity.y = jump_speed
			current_gravity = jump_gravity
			velocity.x = direction_x * minf(jump_horizontal_speed * (dash_speed_multiplier if _is_dashing else 1.0), _current_speed_limit())
			_play_animation_or_idle("jump")
			jump_count = 1
			play_tween_jump()


		State.DOUBLE_JUMP:
			_bounce_extra_jump_available = false
			_set_look_direction(0)
			velocity.y = double_jump_speed
			current_gravity = double_jump_gravity
			if not is_zero_approx(direction_x):
				velocity.x = direction_x * _current_speed_limit()
			_play_animation_or_idle("Jump")
			jump_count = MAX_JUMPS
			play_tween_jump()
			_play_double_jump_effect()


		State.FALL:
			_set_look_direction(0)
			_play_animation_or_idle("fall")
			if jump_count == MAX_JUMPS:
				current_gravity = double_jump_fall_gravity
			else:
				current_gravity = fall_gravity
			
			if previous_state == State.GROUND:
				coyote_timer.start()

func _set_look_direction(new_direction: int) -> void:
	if new_direction == _look_direction:
		return

	_look_direction = new_direction
	match _look_direction:
		-1:
			animated_sprite.play("looking up")
		1:
			animated_sprite.play("looking down")
		0:
			if animated_sprite.animation in [&"looking up", &"looking down"]:
				animated_sprite.play("idle")

	if camera:
		if _camera_tween and _camera_tween.is_running():
			_camera_tween.kill()
		var target_position := _camera_default_position
		if _look_direction == -1:
			target_position.y -= CAMERA_LOOK_OFFSET
		elif _look_direction == 1:
			target_position.y += CAMERA_LOOK_OFFSET
		_camera_tween = create_tween()
		_camera_tween.tween_property(camera, "position", target_position, CAMERA_LOOK_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _play_animation_or_idle(animation_name: StringName) -> void:
	if _is_dashing:
		return
	if animated_sprite.sprite_frames.has_animation(animation_name):
		animated_sprite.play(animation_name)
	else:
		animated_sprite.play("idle")

func _process_stopped_animation() -> void:
	if animated_sprite.animation == "walking":
		animated_sprite.play("halt")
	elif animated_sprite.animation == "halt":
		if not animated_sprite.is_playing():
			animated_sprite.play("idle")
	elif animated_sprite.animation != "idle":
		animated_sprite.play("idle")
		
func calculate_jump_speed(height: float, time_to_peak: float) -> float:
	return (-2.0 * height) / time_to_peak

func calculate_jump_gravity(height: float, time_to_peak: float) -> float:
	return (2.0 * height) / pow(time_to_peak, 2.0)
	
func calculate_fall_gravity(height: float, time_to_descent: float) -> float:
	return (2.0 * height) / pow(time_to_descent, 2.0)
	
func calculate_jump_horizontal_speed(distance: float, time_to_peak: float, time_to_descent: float) -> float:
	return distance / (time_to_peak + time_to_descent)
	
func play_tween_touch_ground() -> void:
	if _sprite_scale_tween and _sprite_scale_tween.is_running():
		_sprite_scale_tween.kill()
	_sprite_scale_tween = create_tween()
	_sprite_scale_tween.tween_property(animated_sprite, "scale", _sprite_base_scale * Vector2(1.1, 0.9), 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_sprite_scale_tween.tween_property(animated_sprite, "scale", _sprite_base_scale * Vector2(0.9, 1.1), 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_sprite_scale_tween.tween_property(animated_sprite, "scale", _sprite_base_scale, 0.15)

func play_tween_jump() -> void:
	if _sprite_scale_tween and _sprite_scale_tween.is_running():
		_sprite_scale_tween.kill()
	_sprite_scale_tween = create_tween()
	_sprite_scale_tween.tween_property(animated_sprite, "scale", _sprite_base_scale * Vector2(1.15, 0.86), 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_sprite_scale_tween.tween_property(animated_sprite, "scale", _sprite_base_scale * Vector2(0.86, 1.15), 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_sprite_scale_tween.tween_property(animated_sprite, "scale", _sprite_base_scale, 0.15)
