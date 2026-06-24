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
@export var attack_duration: float = 0.16
@export var attack_cooldown: float = 0.32

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
var _invincibility_timer: float = 0.0
var _hurt_lock_timer: float = 0.0
var _is_dead: bool = false
var _hit_targets: Dictionary = {}
var _hurt_tween: Tween

@onready var _visual: Node2D = $Visual
@onready var _body_visual: Polygon2D = $Visual/Body
@onready var _attack_area: Area2D = $Visual/AttackArea
@onready var _slash_visual: Polygon2D = $Visual/AttackArea/SlashVisual


func _ready() -> void:
	_gravity = float(ProjectSettings.get_setting("physics/2d/default_gravity", 1600.0))
	_health = max_health
	health_changed.emit(_health, max_health)


func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_apply_gravity(delta)
	if not _is_dead and _hurt_lock_timer <= 0.0:
		_handle_horizontal_movement(delta)
		_handle_jump()
		_handle_attack(delta)
	elif _is_dead:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	move_and_slide()


func _update_timers(delta: float) -> void:
	_invincibility_timer = maxf(_invincibility_timer - delta, 0.0)
	_hurt_lock_timer = maxf(_hurt_lock_timer - delta, 0.0)

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

	if Input.is_action_just_pressed("attack") and _attack_cooldown_timer <= 0.0:
		_start_attack()

	if _attack_timer <= 0.0:
		return

	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_damage_overlapping_enemies()

	if _attack_timer <= 0.0:
		_slash_visual.visible = false


func _start_attack() -> void:
	_attack_timer = attack_duration
	_attack_cooldown_timer = attack_cooldown
	_hit_targets.clear()
	_slash_visual.visible = true


func _damage_overlapping_enemies() -> void:
	for body in _attack_area.get_overlapping_bodies():
		var target_id := body.get_instance_id()
		if _hit_targets.has(target_id):
			continue
		if body.has_method("take_damage"):
			_hit_targets[target_id] = true
			body.take_damage(attack_damage, global_position)


func take_damage(amount: int, source_position: Vector2) -> void:
	if _is_dead or _invincibility_timer > 0.0:
		return

	_health = maxi(_health - amount, 0)
	_invincibility_timer = invincibility_duration
	_hurt_lock_timer = hurt_lock_duration
	_attack_timer = 0.0
	_slash_visual.visible = false

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
