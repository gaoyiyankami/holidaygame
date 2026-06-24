class_name Player
extends CharacterBody2D

enum AttackPhase {
	NONE,
	WINDUP,
	ACTIVE,
	RECOVERY,
}

signal health_changed(current_health: int, max_health: int)
signal body_parts_changed(summary: String)
signal stats_changed(attack_damage: int, attack_speed_bonus: int)
signal died

@export_category("Movement")
@export var move_speed: float = 320.0
@export var acceleration: float = 1800.0
@export var air_acceleration: float = 1100.0
@export var friction: float = 2200.0
@export var jump_velocity: float = -620.0

@export_category("Jump Feel")
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12
@export var jump_cut_multiplier: float = 0.45

@export_category("Combat")
@export var attack_damage: int = 1
@export var combo_reset_time: float = 0.5

@export_category("Dash")
@export var dash_speed: float = 760.0
@export var dash_duration: float = 0.16
@export var dash_cooldown: float = 0.65

@export_category("Health")
@export var max_health: int = 5
@export var invincibility_duration: float = 0.75
@export var hurt_lock_duration: float = 0.18
@export var knockback_speed: float = 460.0

var _gravity: float = 1600.0
var _health: int
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _attack_timer: float = 0.0
var _attack_phase: AttackPhase = AttackPhase.NONE
var _attack_cooldown_timer: float = 0.0
var _combo_reset_timer: float = 0.0
var _combo_step: int = 0
var _combo_queued: bool = false
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _dash_direction: float = 1.0
var _invincibility_timer: float = 0.0
var _hurt_lock_timer: float = 0.0
var _is_dead: bool = false
var _controls_enabled: bool = true
var _attack_speed_multiplier: float = 1.0
var _arm_attack_multiplier: float = 1.0
var _attack_damage_multiplier: float = 1.0
var _movement_multiplier: float = 1.0
var _jump_multiplier: float = 1.0
var _dash_multiplier: float = 1.0
var _animation_time: float = 0.0
var _hit_targets: Dictionary = {}
var _parts: Dictionary = {}
var _sword_tween: Tween

@onready var _visual: Node2D = $Visual
@onready var _parts_root: Node2D = $Visual/Parts
@onready var _sword_pivot: Node2D = $Visual/SwordPivot
@onready var _attack_area: Area2D = $Visual/SwordPivot/AttackArea
@onready var _slash_visual: Polygon2D = $Visual/SwordPivot/AttackArea/SlashVisual
@onready var _dash_visual: Polygon2D = $Visual/DashVisual


func _ready() -> void:
	add_to_group("player")
	_gravity = float(ProjectSettings.get_setting("physics/2d/default_gravity", 1600.0))
	_create_body_parts()
	_refresh_body_health()


func _physics_process(delta: float) -> void:
	_animation_time += delta
	_update_timers(delta)
	if _dash_timer > 0.0:
		_update_dash(delta)
	elif not _is_dead and _controls_enabled and _hurt_lock_timer <= 0.0:
		_apply_gravity(delta)
		_handle_horizontal_movement(delta)
		_handle_jump()
		_handle_attack(delta)
		_handle_dash()
	else:
		_apply_gravity(delta)
		if _is_dead:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	move_and_slide()
	_animate_body_parts()


func _update_timers(delta: float) -> void:
	_invincibility_timer = maxf(_invincibility_timer - delta, 0.0)
	_hurt_lock_timer = maxf(_hurt_lock_timer - delta, 0.0)
	_dash_cooldown_timer = maxf(_dash_cooldown_timer - delta, 0.0)
	_combo_reset_timer = maxf(_combo_reset_timer - delta, 0.0)
	if _combo_reset_timer <= 0.0 and _attack_phase == AttackPhase.NONE:
		_combo_step = 0

	if is_on_floor():
		_coyote_timer = coyote_time
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += _gravity * delta


func _handle_horizontal_movement(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	var target_speed := direction * move_speed * _movement_multiplier

	if not is_zero_approx(direction):
		var current_acceleration := acceleration if is_on_floor() else air_acceleration
		velocity.x = move_toward(velocity.x, target_speed, current_acceleration * delta)
		_visual.scale.x = signf(direction)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)


func _handle_jump() -> void:
	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = jump_velocity * _jump_multiplier
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0

	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier


func _handle_attack(delta: float) -> void:
	_attack_cooldown_timer = maxf(_attack_cooldown_timer - delta, 0.0)

	if Input.is_action_just_pressed("attack"):
		if _attack_phase != AttackPhase.NONE and _combo_step < 3:
			_combo_queued = true
		elif _attack_phase == AttackPhase.NONE and _attack_cooldown_timer <= 0.0:
			_start_attack((_combo_step % 3) + 1)

	if _attack_phase == AttackPhase.NONE:
		return

	_attack_timer = maxf(_attack_timer - delta, 0.0)
	match _attack_phase:
		AttackPhase.WINDUP:
			if _attack_timer <= 0.0:
				_begin_active_attack()
		AttackPhase.ACTIVE:
			_damage_overlapping_enemies()
			if _attack_timer <= 0.0:
				_begin_attack_recovery()
		AttackPhase.RECOVERY:
			if _attack_timer <= 0.0:
				_finish_attack()


func _start_attack(step: int) -> void:
	_combo_step = step
	_attack_phase = AttackPhase.WINDUP
	_attack_timer = _get_windup_duration(step) / _effective_attack_speed()
	_hit_targets.clear()
	_slash_visual.visible = false
	_slash_visual.scale = Vector2(0.9 + step * 0.12, 0.82 + step * 0.08)
	_slash_visual.color = Color(1.0, 0.82 - step * 0.08, 0.2, 0.78)
	_attack_area.position.x = 48.0 + step * 5.0
	_play_sword_windup(step)


func _begin_active_attack() -> void:
	_attack_phase = AttackPhase.ACTIVE
	_attack_timer = _get_active_duration(_combo_step) / _effective_attack_speed()
	_slash_visual.visible = true
	_play_sword_swing(_combo_step)
	_damage_overlapping_enemies()


func _begin_attack_recovery() -> void:
	_attack_phase = AttackPhase.RECOVERY
	_attack_timer = _get_recovery_duration(_combo_step) / _effective_attack_speed()
	_slash_visual.visible = false
	_play_sword_recovery()


func _finish_attack() -> void:
	_attack_phase = AttackPhase.NONE
	if _combo_queued and _combo_step < 3:
		_combo_queued = false
		_start_attack(_combo_step + 1)
	else:
		_combo_queued = false
		_attack_cooldown_timer = (0.1 if _combo_step < 3 else 0.24) / _effective_attack_speed()
		_combo_reset_timer = combo_reset_time


func _damage_overlapping_enemies() -> void:
	var closest_by_actor: Dictionary = {}
	for area in _attack_area.get_overlapping_areas():
		if not (area is BodyPart):
			continue
		var part := area as BodyPart
		var target_id := part.actor.get_instance_id()
		if _hit_targets.has(target_id):
			continue
		var distance := _attack_area.global_position.distance_squared_to(part.global_position)
		if not closest_by_actor.has(target_id) or distance < closest_by_actor[target_id]["distance"]:
			closest_by_actor[target_id] = {"part": part, "distance": distance}

	for target_id in closest_by_actor:
		var part: BodyPart = closest_by_actor[target_id]["part"]
		var base_damage := attack_damage * (2 if _combo_step == 3 else 1)
		var damage := maxi(1, roundi(base_damage * _attack_damage_multiplier))
		if part.receive_damage(damage, global_position):
			_hit_targets[target_id] = true


func _get_windup_duration(step: int) -> float:
	match step:
		1:
			return 0.12
		2:
			return 0.14
		_:
			return 0.2


func _get_active_duration(step: int) -> float:
	match step:
		1:
			return 0.11
		2:
			return 0.12
		_:
			return 0.16


func _get_recovery_duration(step: int) -> float:
	match step:
		1:
			return 0.14
		2:
			return 0.16
		_:
			return 0.23


func _handle_dash() -> void:
	if not Input.is_action_just_pressed("dash") or _dash_cooldown_timer > 0.0:
		return
	start_dash()


func start_dash() -> void:
	if _dash_cooldown_timer > 0.0 or _is_dead:
		return
	var input_direction := Input.get_axis("move_left", "move_right")
	_dash_direction = input_direction if not is_zero_approx(input_direction) else signf(_visual.scale.x)
	if is_zero_approx(_dash_direction):
		_dash_direction = 1.0
	_visual.scale.x = _dash_direction
	_dash_timer = dash_duration
	_dash_cooldown_timer = dash_cooldown
	_invincibility_timer = maxf(_invincibility_timer, dash_duration)
	_attack_timer = 0.0
	_attack_phase = AttackPhase.NONE
	_combo_queued = false
	_slash_visual.visible = false
	_dash_visual.visible = true
	_set_parts_tint(Color(0.35, 0.95, 1.0, 0.42))
	velocity = Vector2(_dash_direction * dash_speed * _dash_multiplier, 0.0)


func _update_dash(delta: float) -> void:
	_dash_timer = maxf(_dash_timer - delta, 0.0)
	velocity = Vector2(_dash_direction * dash_speed * _dash_multiplier, 0.0)
	if _dash_timer <= 0.0:
		_dash_visual.visible = false
		_set_parts_tint(Color.WHITE)
		velocity.x *= 0.45


func take_damage(amount: int, source_position: Vector2) -> void:
	if _is_dead or _invincibility_timer > 0.0:
		return
	var torso: BodyPart = _parts.get("torso")
	if is_instance_valid(torso):
		torso.receive_damage(amount, source_position)


func can_receive_part_damage() -> bool:
	return not _is_dead and _invincibility_timer <= 0.0


func is_dash_invulnerable() -> bool:
	return _dash_timer > 0.0 and _invincibility_timer > 0.0


func is_attack_recovering() -> bool:
	return _attack_phase == AttackPhase.RECOVERY


func on_body_part_damaged(part: BodyPart, _amount: int, source_position: Vector2) -> void:
	_invincibility_timer = invincibility_duration
	_hurt_lock_timer = hurt_lock_duration
	_attack_timer = 0.0
	_attack_phase = AttackPhase.NONE
	_combo_queued = false
	_dash_timer = 0.0
	_slash_visual.visible = false
	_dash_visual.visible = false

	var knockback_direction := signf(global_position.x - source_position.x)
	if is_zero_approx(knockback_direction):
		knockback_direction = 1.0
	velocity = Vector2(knockback_direction * knockback_speed, -230.0)
	_refresh_body_health()
	if part.health <= 0 and part.vital:
		_die()


func get_health() -> int:
	return _health


func set_controls_enabled(enabled: bool) -> void:
	_controls_enabled = enabled
	if not enabled:
		velocity.x = 0.0
		_attack_timer = 0.0
		_attack_phase = AttackPhase.NONE
		_combo_queued = false
		_slash_visual.visible = false
		_dash_visual.visible = false


func apply_attack_upgrade() -> void:
	attack_damage += 1
	stats_changed.emit(attack_damage, get_attack_speed_bonus())


func apply_attack_speed_upgrade() -> void:
	_attack_speed_multiplier += 0.15
	stats_changed.emit(attack_damage, get_attack_speed_bonus())


func apply_max_health_upgrade() -> void:
	var torso: BodyPart = _parts.get("torso")
	if is_instance_valid(torso):
		torso.increase_max_health(2, 2)
	_refresh_body_health()


func get_attack_speed_bonus() -> int:
	return roundi((_attack_speed_multiplier - 1.0) * 100.0)


func get_movement_multiplier() -> float:
	return _movement_multiplier


func get_attack_damage_multiplier() -> float:
	return _attack_damage_multiplier


func _create_body_parts() -> void:
	_add_body_part("head", "头部", 5, true, Vector2(22, 18), Vector2(0, -34), Color(0.45, 0.82, 1.0), 16)
	_add_body_part("torso", "身体", 8, true, Vector2(28, 32), Vector2(0, -7), Color(0.18, 0.62, 0.96), 16)
	_add_body_part("left_arm", "左臂", 4, false, Vector2(10, 28), Vector2(-21, -7), Color(0.28, 0.72, 1.0), 16)
	_add_body_part("right_arm", "右臂", 4, false, Vector2(10, 28), Vector2(21, -7), Color(0.28, 0.72, 1.0), 16)
	_add_body_part("left_leg", "左腿", 5, false, Vector2(11, 30), Vector2(-9, 24), Color(0.12, 0.45, 0.82), 16)
	_add_body_part("right_leg", "右腿", 5, false, Vector2(11, 30), Vector2(9, 24), Color(0.12, 0.45, 0.82), 16)


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
	_refresh_body_health()


func _on_part_destroyed(part: BodyPart) -> void:
	match part.part_id:
		"left_arm", "right_arm":
			_arm_attack_multiplier *= 0.72
			_attack_damage_multiplier *= 0.72
		"left_leg", "right_leg":
			_movement_multiplier *= 0.72
			_jump_multiplier *= 0.82
			_dash_multiplier *= 0.7
	_refresh_body_health()


func _refresh_body_health() -> void:
	_health = 0
	max_health = 0
	var lines: Array[String] = []
	for id in ["head", "torso", "left_arm", "right_arm", "left_leg", "right_leg"]:
		var part: BodyPart = _parts.get(id)
		if not is_instance_valid(part):
			continue
		_health += part.health
		max_health += part.max_health
		lines.append("%s %d/%d" % [part.display_name, part.health, part.max_health])
	health_changed.emit(_health, max_health)
	body_parts_changed.emit("  ".join(lines))


func _play_sword_windup(step: int) -> void:
	if _sword_tween and _sword_tween.is_valid():
		_sword_tween.kill()
	var start_angle := deg_to_rad(-72.0 if step != 2 else 58.0)
	if step == 3:
		start_angle = deg_to_rad(-105.0)
	_sword_tween = create_tween()
	_sword_tween.tween_property(
		_sword_pivot,
		"rotation",
		start_angle,
		_get_windup_duration(step) / _effective_attack_speed()
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _play_sword_swing(step: int) -> void:
	if _sword_tween and _sword_tween.is_valid():
		_sword_tween.kill()
	var end_angle := deg_to_rad(68.0 if step != 2 else -66.0)
	if step == 3:
		end_angle = deg_to_rad(105.0)
	_sword_tween = create_tween()
	_sword_tween.tween_property(
		_sword_pivot,
		"rotation",
		end_angle,
		_get_active_duration(step) / _effective_attack_speed()
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _play_sword_recovery() -> void:
	if _sword_tween and _sword_tween.is_valid():
		_sword_tween.kill()
	_sword_tween = create_tween()
	_sword_tween.tween_property(
		_sword_pivot,
		"rotation",
		deg_to_rad(25.0),
		_get_recovery_duration(_combo_step) / _effective_attack_speed()
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _effective_attack_speed() -> float:
	return maxf(0.35, _attack_speed_multiplier * _arm_attack_multiplier)


func _animate_body_parts() -> void:
	var moving := absf(velocity.x) > 20.0 and is_on_floor()
	var airborne := not is_on_floor()
	var walk_phase := _animation_time * (9.0 + absf(velocity.x) * 0.012)
	var idle_bob := sin(_animation_time * 2.4) * 1.2
	var swing := sin(walk_phase)

	_animate_part("torso", Vector2(0, idle_bob), swing * 0.025 if moving else 0.0)
	_animate_part("head", Vector2(0, idle_bob * 1.25), -swing * 0.035 if moving else sin(_animation_time * 1.7) * 0.025)

	if airborne:
		_animate_part("left_arm", Vector2(0, -2), deg_to_rad(-25.0))
		_animate_part("right_arm", Vector2(0, -2), deg_to_rad(25.0))
		_animate_part("left_leg", Vector2(0, -2), deg_to_rad(18.0))
		_animate_part("right_leg", Vector2(0, 1), deg_to_rad(-14.0))
	elif moving:
		_animate_part("left_arm", Vector2(0, idle_bob), swing * 0.55)
		_animate_part("right_arm", Vector2(0, idle_bob), -swing * 0.55)
		_animate_part("left_leg", Vector2(0, 0), -swing * 0.48)
		_animate_part("right_leg", Vector2(0, 0), swing * 0.48)
	else:
		_animate_part("left_arm", Vector2(0, idle_bob), sin(_animation_time * 2.0) * 0.06)
		_animate_part("right_arm", Vector2(0, idle_bob), -sin(_animation_time * 2.0) * 0.06)
		_animate_part("left_leg", Vector2.ZERO, 0.0)
		_animate_part("right_leg", Vector2.ZERO, 0.0)

	if _attack_phase != AttackPhase.NONE:
		var attack_arm: BodyPart = _parts.get("right_arm")
		if is_instance_valid(attack_arm) and attack_arm.health > 0:
			attack_arm.animate_transform(Vector2(3, -4), _sword_pivot.rotation * 0.45)


func _animate_part(id: StringName, offset: Vector2, angle: float) -> void:
	var part: BodyPart = _parts.get(id)
	if is_instance_valid(part):
		part.animate_transform(offset, angle)


func _set_parts_tint(color: Color) -> void:
	for part in _parts.values():
		(part as BodyPart).set_tint(color)


func _die() -> void:
	_is_dead = true
	collision_layer = 0
	collision_mask = 1
	var death_tween := create_tween()
	death_tween.set_parallel(true)
	death_tween.tween_property(self, "modulate:a", 0.0, 0.55)
	death_tween.tween_property(self, "rotation", deg_to_rad(90.0), 0.55)
	death_tween.set_parallel(false)
	death_tween.tween_callback(died.emit)
