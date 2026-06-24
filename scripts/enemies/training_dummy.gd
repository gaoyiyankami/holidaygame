class_name TrainingDummy
extends CharacterBody2D

@export var max_health: int = 3
@export var knockback_speed: float = 340.0

var _health: int
var _gravity: float = 1600.0
var _is_dead: bool = false
var _flash_tween: Tween

@onready var _body_visual: Polygon2D = $BodyVisual
@onready var _health_label: Label = $HealthLabel


func _ready() -> void:
	_health = max_health
	_gravity = float(ProjectSettings.get_setting("physics/2d/default_gravity", 1600.0))
	_update_health_label()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += _gravity * delta

	velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
	move_and_slide()


func take_damage(amount: int, source_position: Vector2) -> void:
	if _is_dead:
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
	_is_dead = true
	collision_layer = 0
	collision_mask = 0
	_health_label.text = "击败！"
	var death_tween := create_tween()
	death_tween.set_parallel(true)
	death_tween.tween_property(self, "modulate:a", 0.0, 0.35)
	death_tween.tween_property(self, "scale", Vector2(1.3, 0.2), 0.35)
	death_tween.set_parallel(false)
	death_tween.tween_callback(queue_free)
