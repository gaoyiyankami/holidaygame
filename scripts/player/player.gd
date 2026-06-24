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

var _gravity: float = 1600.0
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0


func _ready() -> void:
	_gravity = float(ProjectSettings.get_setting("physics/2d/default_gravity", 1600.0))


func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_apply_gravity(delta)
	_handle_horizontal_movement(delta)
	_handle_jump()
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
		$Visual.scale.x = signf(direction)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)


func _handle_jump() -> void:
	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = jump_velocity
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0

	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier

