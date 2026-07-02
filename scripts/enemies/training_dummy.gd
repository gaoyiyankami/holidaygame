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
	TURN,
	JUMP_WINDUP,
	JUMP,
	JUMP_RECOVERY,
}

const ONE_WAY_PLATFORM_LAYER := 1 << 5

@export var max_health: int = 3
@export var knockback_speed: float = 340.0
@export_category("Movement")
@export var move_speed: float = 105.0
@export var chase_range: float = 520.0
@export var attack_range: float = 76.0
@export var turn_duration: float = 0.18
@export_category("Attack")
@export var attack_damage: int = 3
@export var attack_windup: float = 0.28
@export var attack_duration: float = 0.16
@export var attack_cooldown: float = 1.0
@export var variant_attack_windup: float = 0.42
@export var variant_attack_duration: float = 0.24
@export_category("Jump")
@export var jump_windup: float = 0.22
@export var jump_duration: float = 0.34
@export var jump_recovery: float = 0.22
@export var jump_speed: float = 230.0
@export var jump_lift: float = -740.0
@export var hurt_duration: float = 0.2

var _health: int
var _gravity: float = 1600.0
var _platform_nav := PlatformChaseAgent.new()
var _target: Player
var _state: State = State.IDLE
var _state_timer: float = 0.0
var _attack_has_hit: bool = false
var _parts: Dictionary = {}
var _movement_multiplier: float = 1.0
var _attack_multiplier: float = 1.0
var _attack_speed_multiplier: float = 1.0
var _animation_time: float = 0.0
var _movement_stun_timer: float = 0.0
var _attack_stun_timer: float = 0.0
var _facing_direction: float = 1.0
var _queued_turn_direction: float = 1.0
var _attack_variant: int = 0
var _jump_direction: float = 1.0

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


func _physics_process(delta: float) -> void:
	_platform_nav.tick(self, delta)
	_animation_time += delta
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
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if _needs_turn(direction):
				_start_turn(direction)
			elif _can_attack():
				_change_state(State.WINDUP)
			elif _can_jump():
				_change_state(State.JUMP_WINDUP)
			elif global_position.distance_to(_target.global_position) <= chase_range:
				_change_state(State.CHASE)
		State.CHASE:
			direction = _platform_nav.steer(self, _target, delta, direction, move_speed * _movement_multiplier)
			if _needs_turn(direction):
				_start_turn(direction)
			elif _can_attack():
				_change_state(State.WINDUP)
			elif _can_jump():
				_change_state(State.JUMP_WINDUP)
			elif global_position.distance_to(_target.global_position) > chase_range:
				_change_state(State.IDLE)
			else:
				velocity.x = direction * move_speed * _movement_multiplier \
					+ _platform_nav.separation(self) * move_speed * 0.45
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
		State.TURN:
			_stop_horizontal(delta)
			_tick_timed_state(delta, State.IDLE)
		State.JUMP_WINDUP:
			_stop_horizontal(delta)
			_tick_timed_state(delta, State.JUMP)
		State.JUMP:
			velocity.x = _jump_direction * jump_speed * _movement_multiplier
			_tick_timed_state(delta, State.JUMP_RECOVERY)
		State.JUMP_RECOVERY:
			_stop_horizontal(delta)
			_tick_timed_state(delta, State.IDLE)


func _change_state(next_state: State) -> void:
	_state = next_state
	_attack_visual.visible = false
	if _state != State.ATTACK:
		_attack_area.scale = Vector2.ONE
		_attack_area.position = Vector2(44, 0)
	_set_parts_tint(Color.WHITE)

	match _state:
		State.WINDUP:
			_attack_variant = _choose_attack_variant()
			_attack_visual.visible = true
			_attack_visual.color = Color(1.0, 0.12, 0.06, 0.32)
			_attack_visual.scale = Vector2(1.4, 1.3)
			SFX.play_at("enemy_windup", global_position, 0.06)
			_state_timer = (variant_attack_windup if _attack_variant == 1 else attack_windup) / _attack_speed_multiplier
			_set_parts_tint(Color(1.0, 0.72, 0.25, 1.0))
		State.ATTACK:
			_state_timer = (variant_attack_duration if _attack_variant == 1 else attack_duration) / _attack_speed_multiplier
			_attack_has_hit = false
			_attack_area.scale = Vector2(1.35, 1.15) if _attack_variant == 1 else Vector2.ONE
			_attack_area.position = Vector2(52, -4) if _attack_variant == 1 else Vector2(44, 0)
			_attack_visual.visible = true
			SFX.play_at("enemy_melee", global_position, 0.07)
			_attack_visual.color = Color(1.0, 0.62, 0.12, 0.72) if _attack_variant == 1 else Color(1.0, 0.28, 0.16, 0.75)
			_try_damage_player()
		State.RECOVERY:
			_attack_area.scale = Vector2.ONE
			_attack_area.position = Vector2(44, 0)
			_state_timer = attack_cooldown / _attack_speed_multiplier
			_set_parts_tint(Color(0.72, 0.72, 0.72, 1.0))
		State.HURT:
			_state_timer = hurt_duration
		State.DEAD:
			_state_timer = 0.0
		State.TURN:
			_state_timer = turn_duration
			_set_parts_tint(Color(0.72, 0.82, 1.0, 1.0))
		State.JUMP_WINDUP:
			_state_timer = jump_windup
			_jump_direction = _target_direction()
			if is_zero_approx(_jump_direction):
				_jump_direction = _facing_direction
			_set_parts_tint(Color(0.55, 0.95, 1.0, 1.0))
		State.JUMP:
			_state_timer = jump_duration
			velocity.x = _jump_direction * jump_speed * _movement_multiplier
			velocity.y = jump_lift
		State.JUMP_RECOVERY:
			_state_timer = jump_recovery
			_set_parts_tint(Color(0.65, 0.75, 0.82, 1.0))


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


func _choose_attack_variant() -> int:
	return 1 if absf(global_position.x - _target.global_position.x) > attack_range * 0.62 and randi() % 3 == 0 else 0


func _can_attack() -> bool:
	return absf(global_position.x - _target.global_position.x) <= attack_range \
		and absf(global_position.y - _target.global_position.y) < 80.0


func _can_jump() -> bool:
	return is_on_floor() \
		and _target.global_position.y < global_position.y - 54.0 \
		and absf(_target.global_position.x - global_position.x) <= 280.0 \
		and global_position.distance_to(_target.global_position) <= chase_range


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
		if is_instance_valid(_target) and _target.is_network_attack_active():
			apply_combat_stun(0.45)
			velocity.x = signf(global_position.x - _target.global_position.x) * 260.0
			_target.apply_clash_recoil(signf(_target.global_position.x - global_position.x))
			var main := get_tree().current_scene
			if is_instance_valid(main) and main.has_method("show_local_combat_message"):
				main.show_local_combat_message((global_position + _target.global_position) * 0.5, "拼刀！")
			_attack_has_hit = true
			return
		var damage := maxi(1, roundi(attack_damage * _attack_multiplier))
		if _attack_variant == 1:
			damage = maxi(1, roundi(float(damage) * 1.25))
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
	return _state == State.ATTACK and _attack_stun_timer <= 0.0


func get_network_attack_kind() -> int:
	return Player.AttackKind.NORMAL


func get_attack_step() -> int:
	return 1


func get_movement_stun_time() -> float:
	return _movement_stun_timer


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
	SFX.play_at("enemy_death", global_position, 0.07)
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
		_animate_part("right_arm", Vector2(-6 if _attack_variant == 1 else -4, -6), -0.25)
	elif _state == State.ATTACK:
		_animate_part("right_arm", Vector2(10 if _attack_variant == 1 else 6, 1), 0.22 if _attack_variant == 1 else 0.0)
	elif _state == State.RECOVERY:
		_animate_part("right_arm", Vector2(2, 0), 0.0)
	elif _state == State.TURN:
		_animate_part("torso", Vector2(0, 0), 0.18 * _queued_turn_direction)
	elif _state == State.JUMP_WINDUP:
		_animate_part("torso", Vector2(0, 4), -0.12)
	elif _state == State.JUMP:
		_animate_part("torso", Vector2(0, -3), 0.12 * _jump_direction)


func _animate_part(id: StringName, offset: Vector2, angle: float) -> void:
	var part: BodyPart = _parts.get(id)
	if is_instance_valid(part):
		part.animate_transform(offset, angle)
