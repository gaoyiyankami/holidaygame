class_name Player
extends CharacterBody2D

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

var _gravity: float = 1600.0
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _attack_timer: float = 0.0
var _attack_cooldown_timer: float = 0.0
var _hit_targets: Dictionary = {}

@onready var _visual: Node2D = $Visual
@onready var _attack_area: Area2D = $Visual/AttackArea
@onready var _slash_visual: Polygon2D = $Visual/AttackArea/SlashVisual


func _ready() -> void:
	_gravity = float(ProjectSettings.get_setting("physics/2d/default_gravity", 1600.0))


func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_apply_gravity(delta)
	_handle_horizontal_movement(delta)
	_handle_jump()
	_handle_attack(delta)
	move_and_slide()


func _update_timers(delta: float) -> void:
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
