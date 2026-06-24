class_name Player
extends CharacterBody2D

signal health_changed(current_health: int, max_health: int)
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
var _hit_targets: Dictionary = {}
var _hurt_tween: Tween

@onready var _visual: Node2D = $Visual
@onready var _body_visual: Polygon2D = $Visual/Body
@onready var _attack_area: Area2D = $Visual/AttackArea
@onready var _slash_visual: Polygon2D = $Visual/AttackArea/SlashVisual
@onready var _dash_visual: Polygon2D = $Visual/DashVisual


func _ready() -> void:
	add_to_group("player")
	_gravity = float(ProjectSettings.get_setting("physics/2d/default_gravity", 1600.0))
	_health = max_health
	health_changed.emit(_health, max_health)


func _physics_process(delta: float) -> void:
	_update_timers(delta)
	if _dash_timer > 0.0:
		_update_dash(delta)
	elif not _is_dead and _hurt_lock_timer <= 0.0:
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


func _update_timers(delta: float) -> void:
	_invincibility_timer = maxf(_invincibility_timer - delta, 0.0)
	_hurt_lock_timer = maxf(_hurt_lock_timer - delta, 0.0)
	_dash_cooldown_timer = maxf(_dash_cooldown_timer - delta, 0.0)
	_combo_reset_timer = maxf(_combo_reset_timer - delta, 0.0)
	if _combo_reset_timer <= 0.0 and _attack_timer <= 0.0:
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
	var target_speed := direction * move_speed

	if not is_zero_approx(direction):
		var current_acceleration := acceleration if is_on_floor() else air_acceleration
		velocity.x = move_toward(velocity.x, target_speed, current_acceleration * delta)
		_visual.scale.x = signf(direction)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)


func _handle_jump() -> void:
	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = jump_velocity
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0

	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier


func _handle_attack(delta: float) -> void:
	_attack_cooldown_timer = maxf(_attack_cooldown_timer - delta, 0.0)

	if Input.is_action_just_pressed("attack"):
		if _attack_timer > 0.0 and _combo_step < 3:
			_combo_queued = true
		elif _attack_timer <= 0.0 and _attack_cooldown_timer <= 0.0:
			_start_attack((_combo_step % 3) + 1)

	if _attack_timer <= 0.0:
		return

	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_damage_overlapping_enemies()

	if _attack_timer <= 0.0:
		_slash_visual.visible = false
		if _combo_queued and _combo_step < 3:
			_combo_queued = false
			_start_attack(_combo_step + 1)
		else:
			_combo_queued = false
			_attack_cooldown_timer = 0.12 if _combo_step < 3 else 0.26
			_combo_reset_timer = combo_reset_time


func _start_attack(step: int) -> void:
	_combo_step = step
	_attack_timer = _get_attack_duration(step)
	_hit_targets.clear()
	_slash_visual.visible = true
	_slash_visual.scale = Vector2(0.9 + step * 0.12, 0.82 + step * 0.08)
	_slash_visual.color = Color(1.0, 0.82 - step * 0.08, 0.2, 0.78)
	_attack_area.position.x = 48.0 + step * 5.0


func _damage_overlapping_enemies() -> void:
	for body in _attack_area.get_overlapping_bodies():
		var target_id := body.get_instance_id()
		if _hit_targets.has(target_id):
			continue
		if body.has_method("take_damage"):
			_hit_targets[target_id] = true
			var damage := attack_damage * (2 if _combo_step == 3 else 1)
			body.take_damage(damage, global_position)


func _get_attack_duration(step: int) -> float:
	match step:
		1:
			return 0.15
		2:
			return 0.17
		_:
			return 0.23


func _handle_dash() -> void:
	if not Input.is_action_just_pressed("dash") or _dash_cooldown_timer > 0.0:
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
	_combo_queued = false
	_slash_visual.visible = false
	_dash_visual.visible = true
	velocity = Vector2(_dash_direction * dash_speed, 0.0)


func _update_dash(delta: float) -> void:
	_dash_timer = maxf(_dash_timer - delta, 0.0)
	velocity = Vector2(_dash_direction * dash_speed, 0.0)
	if _dash_timer <= 0.0:
		_dash_visual.visible = false
		velocity.x *= 0.45


func take_damage(amount: int, source_position: Vector2) -> void:
	if _is_dead or _invincibility_timer > 0.0:
		return

	_health = maxi(_health - amount, 0)
	_invincibility_timer = invincibility_duration
	_hurt_lock_timer = hurt_lock_duration
	_attack_timer = 0.0
	_combo_queued = false
	_dash_timer = 0.0
	_slash_visual.visible = false
	_dash_visual.visible = false

	var knockback_direction := signf(global_position.x - source_position.x)
	if is_zero_approx(knockback_direction):
		knockback_direction = 1.0
	velocity = Vector2(knockback_direction * knockback_speed, -230.0)
	_flash_on_hit()
	health_changed.emit(_health, max_health)

	if _health <= 0:
		_die()


func get_health() -> int:
	return _health


func _flash_on_hit() -> void:
	if _hurt_tween and _hurt_tween.is_valid():
		_hurt_tween.kill()
	_body_visual.modulate = Color(1.0, 0.3, 0.3, 1.0)
	_hurt_tween = create_tween()
	_hurt_tween.set_loops(3)
	_hurt_tween.tween_property(_body_visual, "modulate:a", 0.25, 0.08)
	_hurt_tween.tween_property(_body_visual, "modulate:a", 1.0, 0.08)
	_hurt_tween.finished.connect(func() -> void: _body_visual.modulate = Color.WHITE)


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
