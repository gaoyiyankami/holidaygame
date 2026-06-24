class_name TrainingDummy
extends CharacterBody2D

signal defeated

enum State {
	IDLE,
	CHASE,
	WINDUP,
	ATTACK,
	RECOVERY,
	HURT,
	DEAD,
}

@export var max_health: int = 3
@export var knockback_speed: float = 340.0
@export_category("Movement")
@export var move_speed: float = 105.0
@export var chase_range: float = 520.0
@export var attack_range: float = 76.0
@export_category("Attack")
@export var attack_damage: int = 1
@export var attack_windup: float = 0.28
@export var attack_duration: float = 0.16
@export var attack_cooldown: float = 1.0
@export var hurt_duration: float = 0.2

var _health: int
var _gravity: float = 1600.0
var _target: Player
var _state: State = State.IDLE
var _state_timer: float = 0.0
var _attack_has_hit: bool = false
var _parts: Dictionary = {}
var _movement_multiplier: float = 1.0
var _attack_multiplier: float = 1.0
var _attack_speed_multiplier: float = 1.0
var _animation_time: float = 0.0

@onready var _visual: Node2D = $Visual
@onready var _parts_root: Node2D = $Visual/Parts
@onready var _attack_area: Area2D = $Visual/AttackArea
@onready var _attack_visual: Polygon2D = $Visual/AttackArea/AttackVisual
@onready var _health_label: Label = $HealthLabel


func _ready() -> void:
	_create_body_parts()
	_gravity = float(ProjectSettings.get_setting("physics/2d/default_gravity", 1600.0))
	_target = get_tree().get_first_node_in_group("player") as Player
	_update_health_label()


func _physics_process(delta: float) -> void:
	_animation_time += delta
	if not is_on_floor():
		velocity.y += _gravity * delta

	_update_state(delta)
	move_and_slide()
	_animate_body_parts()


func _update_state(delta: float) -> void:
	if _state == State.DEAD:
		return

	if not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("player") as Player
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		return

	var direction := _face_target()
	match _state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if _can_attack():
				_change_state(State.WINDUP)
			elif global_position.distance_to(_target.global_position) <= chase_range:
				_change_state(State.CHASE)
		State.CHASE:
			if _can_attack():
				_change_state(State.WINDUP)
			elif global_position.distance_to(_target.global_position) > chase_range:
				_change_state(State.IDLE)
			else:
				velocity.x = direction * move_speed * _movement_multiplier
		State.WINDUP:
			_stop_horizontal(delta)
			_tick_timed_state(delta, State.ATTACK)
		State.ATTACK:
			_stop_horizontal(delta)
			_try_damage_player()
			_tick_timed_state(delta, State.RECOVERY)
		State.RECOVERY:
			_stop_horizontal(delta)
			_tick_timed_state(delta, State.IDLE)
		State.HURT:
			velocity.x = move_toward(velocity.x, 0.0, 520.0 * delta)
			_tick_timed_state(delta, State.IDLE)


func _change_state(next_state: State) -> void:
	_state = next_state
	_attack_visual.visible = false
	_set_parts_tint(Color.WHITE)

	match _state:
		State.WINDUP:
			_state_timer = attack_windup / _attack_speed_multiplier
			_set_parts_tint(Color(1.0, 0.72, 0.25, 1.0))
		State.ATTACK:
			_state_timer = attack_duration / _attack_speed_multiplier
			_attack_has_hit = false
			_attack_visual.visible = true
			_try_damage_player()
		State.RECOVERY:
			_state_timer = attack_cooldown / _attack_speed_multiplier
			_set_parts_tint(Color(0.72, 0.72, 0.72, 1.0))
		State.HURT:
			_state_timer = hurt_duration
		State.DEAD:
			_state_timer = 0.0


func _tick_timed_state(delta: float, next_state: State) -> void:
	_state_timer = maxf(_state_timer - delta, 0.0)
	if _state_timer <= 0.0:
		_change_state(next_state)


func _face_target() -> float:
	var direction := signf(_target.global_position.x - global_position.x)
	if not is_zero_approx(direction) and _state not in [State.HURT, State.DEAD]:
		_visual.scale.x = direction
	return direction


func _can_attack() -> bool:
	return absf(global_position.x - _target.global_position.x) <= attack_range \
		and absf(global_position.y - _target.global_position.y) < 80.0


func _stop_horizontal(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)


func _try_damage_player() -> void:
	if _attack_has_hit:
		return
	var closest_part: BodyPart
	var closest_distance := INF
	for area in _attack_area.get_overlapping_areas():
		if area is BodyPart:
			var part := area as BodyPart
			var distance := _attack_area.global_position.distance_squared_to(part.global_position)
			if distance < closest_distance:
				closest_part = part
				closest_distance = distance
	if is_instance_valid(closest_part):
		var damage := maxi(1, roundi(attack_damage * _attack_multiplier))
		if closest_part.receive_damage(damage, global_position):
			_attack_has_hit = true


func take_damage(amount: int, source_position: Vector2) -> void:
	if _state == State.DEAD:
		return
	var torso: BodyPart = _parts.get("torso")
	if is_instance_valid(torso):
		torso.receive_damage(amount, source_position)


func can_receive_part_damage() -> bool:
	return _state != State.DEAD


func get_movement_multiplier() -> float:
	return _movement_multiplier


func get_attack_multiplier() -> float:
	return _attack_multiplier


func on_body_part_damaged(part: BodyPart, _amount: int, source_position: Vector2) -> void:
	var knockback_direction := signf(global_position.x - source_position.x)
	if is_zero_approx(knockback_direction):
		knockback_direction = 1.0
	velocity.x = knockback_direction * knockback_speed
	velocity.y = -140.0
	_update_health_label()

	if part.health <= 0 and part.vital:
		_die()
	else:
		_change_state(State.HURT)


func _update_health_label() -> void:
	_health = 0
	var total_max := 0
	for part in _parts.values():
		var body_part := part as BodyPart
		_health += body_part.health
		total_max += body_part.max_health
	var head: BodyPart = _parts.get("head")
	var torso: BodyPart = _parts.get("torso")
	if is_instance_valid(head) and is_instance_valid(torso):
		_health_label.text = "总血量 %d/%d\n头 %d  身 %d" % [
			_health,
			total_max,
			head.health,
			torso.health,
		]


func _die() -> void:
	_change_state(State.DEAD)
	collision_layer = 0
	collision_mask = 0
	_health_label.text = "击败！"
	defeated.emit()
	var death_tween := create_tween()
	death_tween.set_parallel(true)
	death_tween.tween_property(self, "modulate:a", 0.0, 0.35)
	death_tween.tween_property(self, "scale", Vector2(1.3, 0.2), 0.35)
	death_tween.set_parallel(false)
	death_tween.tween_callback(queue_free)


func _create_body_parts() -> void:
	var torso_hp := maxi(max_health, 4)
	_add_body_part("head", "头部", maxi(torso_hp - 2, 3), true, Vector2(24, 19), Vector2(0, -34), Color(1.0, 0.44, 0.4), 8)
	_add_body_part("torso", "身体", torso_hp, true, Vector2(30, 32), Vector2(0, -7), Color(0.88, 0.2, 0.27), 8)
	_add_body_part("left_arm", "左臂", maxi(torso_hp - 3, 2), false, Vector2(11, 28), Vector2(-22, -7), Color(1.0, 0.34, 0.3), 8)
	_add_body_part("right_arm", "右臂", maxi(torso_hp - 3, 2), false, Vector2(11, 28), Vector2(22, -7), Color(1.0, 0.34, 0.3), 8)
	_add_body_part("left_leg", "左腿", maxi(torso_hp - 2, 3), false, Vector2(12, 30), Vector2(-10, 24), Color(0.66, 0.12, 0.18), 8)
	_add_body_part("right_leg", "右腿", maxi(torso_hp - 2, 3), false, Vector2(12, 30), Vector2(10, 24), Color(0.66, 0.12, 0.18), 8)


func _add_body_part(
	id: StringName,
	label: String,
	hp: int,
	vital: bool,
	part_size: Vector2,
	part_position: Vector2,
	color: Color,
	layer: int
) -> void:
	var part := BodyPart.new()
	_parts_root.add_child(part)
	part.configure(self, id, label, hp, vital, part_size, part_position, color, layer)
	part.health_changed.connect(_on_part_health_changed)
	part.destroyed.connect(_on_part_destroyed)
	_parts[id] = part


func _on_part_health_changed(_part: BodyPart) -> void:
	_update_health_label()


func _on_part_destroyed(part: BodyPart) -> void:
	match part.part_id:
		"left_arm", "right_arm":
			_attack_multiplier *= 0.68
			_attack_speed_multiplier *= 0.78
		"left_leg", "right_leg":
			_movement_multiplier *= 0.62
	_update_health_label()


func _set_parts_tint(color: Color) -> void:
	for part in _parts.values():
		(part as BodyPart).set_tint(color)


func _animate_body_parts() -> void:
	var moving := absf(velocity.x) > 10.0 and is_on_floor()
	var phase := _animation_time * 7.0
	var step := sin(phase)
	var breathe := sin(_animation_time * 1.9)

	_animate_part("torso", Vector2(0, breathe * 0.6), 0.0)
	_animate_part("head", Vector2(0, breathe * 0.75), 0.0)
	_animate_part("left_leg", Vector2(step * 2.0, -maxf(step, 0.0) * 1.6), 0.0)
	_animate_part("right_leg", Vector2(-step * 2.0, maxf(step, 0.0) * 1.6), 0.0)
	_animate_part("left_arm", Vector2(step * 1.7, -step * 0.8), 0.0)
	_animate_part("right_arm", Vector2(-step * 1.7, step * 0.8), 0.0)

	if _state == State.WINDUP:
		_animate_part("right_arm", Vector2(-4, -4), 0.0)
	elif _state == State.ATTACK:
		_animate_part("right_arm", Vector2(6, 1), 0.0)
	elif _state == State.RECOVERY:
		_animate_part("right_arm", Vector2(2, 0), 0.0)


func _animate_part(id: StringName, offset: Vector2, angle: float) -> void:
	var part: BodyPart = _parts.get(id)
	if is_instance_valid(part):
		part.animate_transform(offset, angle)
