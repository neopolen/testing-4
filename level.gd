extends Node2D

var moon_berry_count := 0
var toxic_berry_count := 0
var elapsed_time := 0.0

const HINT_FULL_ALPHA_DISTANCE := 125.0
const HINT_HIDDEN_DISTANCE := 340.0
const TOXIC_HEAT_LIMIT := 6
const HEAT_GAUGE_EMPTY_COLOR := Color(0.18, 0.26, 0.18, 0.75)

@onready var count_label: Label = $HUD/MoonBerryCount
@onready var toxic_count_label: Label = $HUD/ToxicBerryCount
@onready var timer_label: Label = $HUD/TimerLabel
@onready var heat_gauge: HBoxContainer = $HUD/HeatGauge
@onready var heat_gauge_glow: HBoxContainer = $HUD/HeatGaugeGlow
@onready var player: Player = $Player
@onready var end_portal: Node2D = get_node_or_null("End Portal") as Node2D
@onready var victory_audio: AudioStreamPlayer = $VictoryAudio
@onready var game_over_audio: AudioStreamPlayer = $GameOverAudio

var movement_hints: Array[Label] = []
var heat_gauge_bars: Array[TextureRect] = []
var _game_finished := false
var super_dash_screen_glow: ColorRect

func _ready() -> void:
	player.died.connect(_on_player_died)
	for child in heat_gauge.get_children():
		if child is TextureRect:
			heat_gauge_bars.append(child as TextureRect)

	for child in get_children():
		if child is Label and str(child.name).begins_with("MovementHint"):
			movement_hints.append(child as Label)

	for berry in get_tree().get_nodes_in_group("moon_berries"):
		berry.connect("collected", _on_moon_berry_collected)
	for berry in get_tree().get_nodes_in_group("toxic_berries"):
		berry.connect("collected", _on_toxic_berry_collected)
	_create_super_dash_screen_glow()
	_create_end_portal_trigger()
	_update_count_label()
	_update_timer_label()
	_update_heat_gauge()

func _process(delta: float) -> void:
	if _game_finished:
		return
	if _player_touches_end_portal():
		_finish_game()
		return
	elapsed_time += delta
	_update_timer_label()
	_update_movement_hint()

func _on_moon_berry_collected() -> void:
	moon_berry_count += 1
	_update_count_label()

func _on_player_died() -> void:
	game_over_audio.play()
	var game_over_scene := preload("res://game_over/game_over_screen.tscn")
	var game_over_screen := game_over_scene.instantiate()
	add_child(game_over_screen)

func _on_toxic_berry_collected() -> void:
	toxic_berry_count += 1
	_update_count_label()
	_update_heat_gauge(true)

func _on_end_portal_body_entered(body: Node2D) -> void:
	if _game_finished or body != player:
		return
	_finish_game()

func _finish_game() -> void:
	if _game_finished:
		return
	_game_finished = true
	victory_audio.play()
	get_tree().paused = true

func _player_touches_end_portal() -> bool:
	if not is_instance_valid(end_portal):
		return false
	var portal_bounds := Rect2(end_portal.global_position - Vector2(70, 74), Vector2(140, 148))
	return portal_bounds.has_point(player.global_position)

func _create_end_portal_trigger() -> void:
	if not is_instance_valid(end_portal):
		return
	var trigger := Area2D.new()
	trigger.name = "FinishTrigger"
	trigger.collision_layer = 0
	trigger.collision_mask = 1
	var trigger_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(110, 116)
	trigger_shape.shape = rectangle
	trigger.add_child(trigger_shape)
	end_portal.add_child(trigger)
	trigger.body_entered.connect(_on_end_portal_body_entered)

func _create_super_dash_screen_glow() -> void:
	var glow_layer := CanvasLayer.new()
	glow_layer.name = "SuperDashReadyGlow"
	glow_layer.layer = 4
	add_child(glow_layer)

	super_dash_screen_glow = ColorRect.new()
	super_dash_screen_glow.name = "ScreenEdgeGlow"
	super_dash_screen_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	super_dash_screen_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	super_dash_screen_glow.visible = false
	var glow_shader := Shader.new()
	glow_shader.code = """
	shader_type canvas_item;
	uniform float edge_width = 0.22;
	uniform float pixel_size = 5.0;
	void fragment() {
		vec2 pixel_count = 1.0 / (SCREEN_PIXEL_SIZE * pixel_size);
		vec2 pixel_uv = (floor(UV * pixel_count) + vec2(0.5)) / pixel_count;
		vec2 edge_distance = min(pixel_uv, vec2(1.0) - pixel_uv);
		float distance_to_edge = min(edge_distance.x, edge_distance.y);
		float outer_glow = 1.0 - smoothstep(0.0, edge_width, distance_to_edge);
		float bright_edge = 1.0 - smoothstep(0.0, 0.065, distance_to_edge);
		float pulse = 0.82 + 0.14 * sin(TIME * 2.4);
		vec3 dark_green = vec3(0.015, 0.2, 0.04);
		vec3 bright_green = vec3(0.06, 0.76, 0.16);
		vec3 glow = mix(dark_green, bright_green, bright_edge);
		float glow_alpha = (outer_glow * 0.39 + bright_edge * 0.23) * pulse;
		COLOR = vec4(glow, glow_alpha);
	}
	"""
	var glow_material := ShaderMaterial.new()
	glow_material.shader = glow_shader
	super_dash_screen_glow.material = glow_material
	glow_layer.add_child(super_dash_screen_glow)

func _update_heat_gauge(animate_increment := false) -> void:
	var heat_level := mini(toxic_berry_count, TOXIC_HEAT_LIMIT)
	if is_instance_valid(super_dash_screen_glow):
		super_dash_screen_glow.visible = heat_level >= TOXIC_HEAT_LIMIT
	var previous_level := mini(maxi(toxic_berry_count - 1, 0), TOXIC_HEAT_LIMIT)
	var newly_filled_bar_tween: Tween
	for index in range(heat_gauge_bars.size()):
		var bar := heat_gauge_bars[index]
		if index < heat_level:
			if animate_increment and heat_level > previous_level and index == heat_level - 1:
				bar.modulate = HEAT_GAUGE_EMPTY_COLOR
				newly_filled_bar_tween = create_tween()
				newly_filled_bar_tween.tween_property(bar, "modulate", Color.WHITE, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			else:
				bar.modulate = Color.WHITE
		else:
			bar.modulate = HEAT_GAUGE_EMPTY_COLOR

	heat_gauge_glow.visible = false
	if heat_level >= TOXIC_HEAT_LIMIT:
		if is_instance_valid(newly_filled_bar_tween):
			newly_filled_bar_tween.finished.connect(_show_full_heat_glow)
		else:
			heat_gauge_glow.visible = true

func _show_full_heat_glow() -> void:
	heat_gauge_glow.visible = mini(toxic_berry_count, TOXIC_HEAT_LIMIT) >= TOXIC_HEAT_LIMIT

func _update_count_label() -> void:
	count_label.text = "Moon Berries: %d" % moon_berry_count
	toxic_count_label.text = "Toxic Berries: %d" % toxic_berry_count

func _update_timer_label() -> void:
	var total_seconds := int(elapsed_time)
	var minutes := floori(total_seconds / 60.0)
	var seconds := total_seconds % 60
	timer_label.text = "Time: %02d:%02d" % [minutes, seconds]

func _update_movement_hint() -> void:
	for hint in movement_hints:
		var hint_center := hint.global_position + hint.size * 0.5
		var distance := player.global_position.distance_to(hint_center)
		var fade_progress := clampf(
			(distance - HINT_FULL_ALPHA_DISTANCE) / (HINT_HIDDEN_DISTANCE - HINT_FULL_ALPHA_DISTANCE),
			0.0,
			1.0
			)
		var eased_progress := fade_progress * fade_progress * (3.0 - 2.0 * fade_progress)
		hint.modulate = Color(1.0, 1.0, 1.0, 1.0 - eased_progress)
