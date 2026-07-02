class_name DogEnemy
extends CharacterBody2D

signal defeated

enum State {
	IDLE,
	CHASE,
	WINDUP,
	LEAP,
	RECOVERY,
	HURT,
	DEAD,
	TURN,
}

const ONE_WAY_PLATFORM_LAYER := 1 << 5

@export var max_health: int = 5
@export var knockback_speed: float = 300.0
@export_category("Movement")
@export var move_speed: float = 145.0
@export var chase_range: float = 560.0
@export var attack_range: float = 135.0
@export var turn_duration: float = 0.16
@export_category("Attack")
@export var attack_damage: int = 3
@export var attack_windup: float = 0.24
@export var attack_duration: float = 0.32
@export var attack_cooldown: float = 1.05
@export var leap_speed: float = 390.0
@export var leap_lift: float = -250.0
@export var hurt_duration: float = 0.18

var _gravity: float = 1600.0
var _target: Player
var _state: State = State.IDLE
var _state_timer: float = 0.0
var _attack_has_hit: bool = false
var _parts: Dictionary = {}
var _movement_multiplier: float = 1.0
var _animation_time: float = 0.0
var _movement_stun_timer: float = 0.0
var _attack_stun_timer: float = 0.0
var _leap_direction: float = 1.0
var _facing_direction: float = 1.0
var _queued_turn_direction: float = 1.0
var _platform_nav := PlatformChaseAgent.new()

@onready var _visual: Node2D = $Visual
@onready var _parts_root: Node2D = $Visual/Parts
@onready var _attack_area: Area2D = $Visual/AttackArea
@onready var _attack_visual: Polygon2D = $Visual/AttackArea/AttackVisual
@onready var _health_label: Label = $HealthLabel


func _ready() -> void:
	add_to_group("enemy")
	collision_mask |= ONE_WAY_PLATFORM_LAYER
	_create_body_parts()
	_gravity = float(ProjectSettings.get_setting("physics/2d/default_gravity", 1600.0))
	_target = get_tree().get_first_node_in_group("player") as Player
	_update_health_label()
	SFX.play_at("enemy_spawn", global_position, 0.05)


func _physics_process(delta: float) -> void:
	_animation_time += delta
	_platform_nav.tick(self, delta)
	_movement_stun_timer = maxf(_movement_stun_timer - delta, 0.0)
	_attack_stun_timer = maxf(_attack_stun_timer - delta, 0.0)
	if not is_on_floor():
		velocity.y += _gravity * delta

	if _movement_stun_timer <= 0.0 and _attack_stun_timer <= 0.0:
		_update_state(delta)
	else:
		velocity.x = 0.0
	move_and_slide()
	_animate_body_parts()


func _update_state(delta: float) -> void:
	if _state == State.DEAD:
		return
	if not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("player") as Player
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		return

	var direction := _target_direction()
	match _state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, 850.0 * delta)
			if _needs_turn(direction):
				_start_turn(direction)
			elif _can_attack():
				_change_state(State.WINDUP)
			elif global_position.distance_to(_target.global_position) <= chase_range:
				_change_state(State.CHASE)
		State.CHASE:
			direction = _platform_nav.steer(self, _target, delta, direction, move_speed * _movement_multiplier)
			if _needs_turn(direction):
				_start_turn(direction)
			elif _can_attack():
				_change_state(State.WINDUP)
			elif global_position.distance_to(_target.global_position) > chase_range:
				_change_state(State.IDLE)
			else:
				velocity.x = direction * move_speed * _movement_multiplier \
					+ _platform_nav.separation(self) * move_speed * 0.45
		State.WINDUP:
			velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
			_tick_timed_state(delta, State.LEAP)
		State.LEAP:
			velocity.x = _leap_direction * leap_speed * _movement_multiplier
			_try_damage_player()
			_tick_timed_state(delta, State.RECOVERY)
		State.RECOVERY:
			velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
			_tick_timed_state(delta, State.IDLE)
		State.HURT:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			_tick_timed_state(delta, State.IDLE)
		State.TURN:
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			_tick_timed_state(delta, State.IDLE)


func _change_state(next_state: State) -> void:
	_state = next_state
	_attack_visual.visible = false
	_set_parts_tint(Color.WHITE)
	match _state:
		State.WINDUP:
			_state_timer = attack_windup
			_attack_visual.visible = true
			_attack_visual.color = Color(1.0, 0.12, 0.06, 0.32)
			_attack_visual.scale = Vector2(1.35, 1.35)
			SFX.play_at("enemy_windup", global_position, 0.06)
			_set_parts_tint(Color(1.0, 0.78, 0.28, 1.0))
		State.LEAP:
			_state_timer = attack_duration
			_attack_has_hit = false
			_leap_direction = _target_direction()
			if is_zero_approx(_leap_direction):
				_leap_direction = _facing_direction
			velocity.x = _leap_direction * leap_speed * _movement_multiplier
			velocity.y = leap_lift
			_attack_visual.visible = true
			SFX.play_at("enemy_melee", global_position, 0.07)
			_try_damage_player()
		State.RECOVERY:
			_state_timer = attack_cooldown
			_set_parts_tint(Color(0.72, 0.72, 0.72, 1.0))
		State.HURT:
			_state_timer = hurt_duration
		State.DEAD:
			_state_timer = 0.0
		State.TURN:
			_state_timer = turn_duration
			_set_parts_tint(Color(0.65, 0.9, 1.0, 1.0))


func _tick_timed_state(delta: float, next_state: State) -> void:
	_state_timer = maxf(_state_timer - delta, 0.0)
	if _state_timer <= 0.0:
		if _state == State.TURN:
			_facing_direction = _queued_turn_direction
			_visual.scale.x = _facing_direction
		_change_state(next_state)


func _target_direction() -> float:
	var direction := signf(_target.global_position.x - global_position.x)
	return direction


func _needs_turn(direction: float) -> bool:
	return not is_zero_approx(direction) and signf(direction) != signf(_facing_direction)


func _start_turn(direction: float) -> void:
	_queued_turn_direction = signf(direction)
	_change_state(State.TURN)


func _can_attack() -> bool:
	return absf(global_position.x - _target.global_position.x) <= attack_range \
		and absf(global_position.y - _target.global_position.y) < 95.0


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
		if is_instance_valid(_target) and _target.is_network_attack_active():
			apply_combat_stun(0.45)
			velocity.x = signf(global_position.x - _target.global_position.x) * 260.0
			_target.apply_clash_recoil(signf(_target.global_position.x - global_position.x))
			_attack_has_hit = true
			return
		if closest_part.receive_damage(attack_damage, global_position):
			_attack_has_hit = true


func take_damage(amount: int, source_position: Vector2) -> void:
	if _state == State.DEAD:
		return
	var body: BodyPart = _parts.get("body")
	if is_instance_valid(body):
		body.receive_damage(amount, source_position)


func can_receive_part_damage() -> bool:
	return _state != State.DEAD


func get_movement_multiplier() -> float:
	return _movement_multiplier


func get_attack_multiplier() -> float:
	return 1.0


func apply_movement_stun(duration: float) -> void:
	_movement_stun_timer = maxf(_movement_stun_timer, duration)
	velocity.x = 0.0


func apply_combat_stun(duration: float) -> void:
	_movement_stun_timer = maxf(_movement_stun_timer, duration)
	_attack_stun_timer = maxf(_attack_stun_timer, duration)
	velocity.x = 0.0
	_attack_has_hit = true
	_change_state(State.RECOVERY)


func apply_clash_result(direction: float, hard_clash: bool) -> void:
	_attack_has_hit = true
	if hard_clash:
		apply_combat_stun(0.45)
	else:
		_change_state(State.RECOVERY)
	velocity.x = direction * 220.0


func get_attack_stun_time() -> float:
	return _attack_stun_timer


func is_melee_attack_active() -> bool:
	return _state == State.LEAP and _attack_stun_timer <= 0.0


func get_network_attack_kind() -> int:
	return Player.AttackKind.DASH


func get_attack_step() -> int:
	return 1


func get_movement_stun_time() -> float:
	return _movement_stun_timer


func on_body_part_damaged(part: BodyPart, _amount: int, source_position: Vector2) -> void:
	var knockback_direction := signf(global_position.x - source_position.x)
	if is_zero_approx(knockback_direction):
		knockback_direction = 1.0
	velocity.x = knockback_direction * knockback_speed
	velocity.y = -120.0
	_update_health_label()
	if part.health <= 0 and part.vital:
		_die()
	else:
		_change_state(State.HURT)


func _create_body_parts() -> void:
	var body_hp := maxi(max_health, 4)
	_add_body_part("head", "头部", maxi(body_hp - 2, 3), true, Vector2(20, 18), Vector2(30, -18), Color(0.88, 0.58, 0.28), 8)
	_add_body_part("body", "身体", body_hp, true, Vector2(52, 26), Vector2(0, 0), Color(0.58, 0.34, 0.18), 8)
	_add_body_part("front_legs", "前双腿", maxi(body_hp - 2, 3), false, Vector2(18, 22), Vector2(20, 20), Color(0.42, 0.24, 0.14), 8)
	_add_body_part("back_legs", "后双腿", maxi(body_hp - 2, 3), false, Vector2(18, 22), Vector2(-22, 20), Color(0.42, 0.24, 0.14), 8)


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
		"front_legs", "back_legs":
			_movement_multiplier *= 0.58
	_update_health_label()


func _update_health_label() -> void:
	var health := 0
	var total_max := 0
	for part in _parts.values():
		var body_part := part as BodyPart
		health += body_part.health
		total_max += body_part.max_health
	_health_label.text = "狗 %d/%d" % [health, total_max]


func _die() -> void:
	_change_state(State.DEAD)
	SFX.play_at("enemy_death", global_position, 0.07)
	collision_layer = 0
	collision_mask = 0
	_health_label.text = "击败！"
	defeated.emit()
	var death_tween := create_tween()
	death_tween.set_parallel(true)
	death_tween.tween_property(self, "modulate:a", 0.0, 0.35)
	death_tween.tween_property(self, "scale", Vector2(1.25, 0.18), 0.35)
	death_tween.set_parallel(false)
	death_tween.tween_callback(queue_free)


func _set_parts_tint(color: Color) -> void:
	for part in _parts.values():
		(part as BodyPart).set_tint(color)


func _animate_body_parts() -> void:
	var step := sin(_animation_time * 10.0)
	var crouch := 3.0 if _state == State.WINDUP else -2.0 if _state == State.LEAP else 0.0
	if _state == State.TURN:
		crouch = 1.0
	_animate_part("body", Vector2(0, crouch), deg_to_rad(-3.0 if _state == State.LEAP else 0.0))
	_animate_part("head", Vector2(2 if _state == State.LEAP else 0, crouch - 1), 0.0)
	_animate_part("front_legs", Vector2(step * 2.0, -absf(step) * 1.5 + crouch), 0.0)
	_animate_part("back_legs", Vector2(-step * 2.0, absf(step) * 1.2 + crouch), 0.0)


func _animate_part(id: StringName, offset: Vector2, angle: float) -> void:
	var part: BodyPart = _parts.get(id)
	if is_instance_valid(part):
		part.animate_transform(offset, angle)
