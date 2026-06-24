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
var _flash_tween: Tween

@onready var _visual: Node2D = $Visual
@onready var _body_visual: Polygon2D = $Visual/BodyVisual
@onready var _attack_area: Area2D = $Visual/AttackArea
@onready var _attack_visual: Polygon2D = $Visual/AttackArea/AttackVisual
@onready var _health_label: Label = $HealthLabel


func _ready() -> void:
	_health = max_health
	_gravity = float(ProjectSettings.get_setting("physics/2d/default_gravity", 1600.0))
	_target = get_tree().get_first_node_in_group("player") as Player
	_update_health_label()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += _gravity * delta

	_update_state(delta)
	move_and_slide()


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
				velocity.x = direction * move_speed
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
	_body_visual.modulate = Color.WHITE

	match _state:
		State.WINDUP:
			_state_timer = attack_windup
			_body_visual.modulate = Color(1.0, 0.72, 0.25, 1.0)
		State.ATTACK:
			_state_timer = attack_duration
			_attack_has_hit = false
			_attack_visual.visible = true
			_try_damage_player()
		State.RECOVERY:
			_state_timer = attack_cooldown
			_body_visual.modulate = Color(0.72, 0.72, 0.72, 1.0)
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
	for body in _attack_area.get_overlapping_bodies():
		if body.has_method("take_damage"):
			_attack_has_hit = true
			body.take_damage(attack_damage, global_position)
			return


func take_damage(amount: int, source_position: Vector2) -> void:
	if _state == State.DEAD:
		return

	_health = maxi(_health - amount, 0)
	var knockback_direction := signf(global_position.x - source_position.x)
	if is_zero_approx(knockback_direction):
		knockback_direction = 1.0
	velocity.x = knockback_direction * knockback_speed
	velocity.y = -140.0
	_flash_on_hit()
	_update_health_label()

	if _health <= 0:
		_die()
	else:
		_change_state(State.HURT)


func _flash_on_hit() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_body_visual.modulate = Color.WHITE
	_flash_tween = create_tween()
	_flash_tween.tween_property(_body_visual, "modulate", Color(1, 0.3, 0.3), 0.07)
	_flash_tween.tween_property(_body_visual, "modulate", Color.WHITE, 0.11)


func _update_health_label() -> void:
	_health_label.text = "HP %d / %d" % [_health, max_health]


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
