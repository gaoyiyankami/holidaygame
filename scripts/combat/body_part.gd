class_name BodyPart
extends Area2D

signal health_changed(part: BodyPart)
signal destroyed(part: BodyPart)

var part_id: StringName
var display_name: String
var max_health: int
var health: int
var vital: bool
var actor: Node
var rest_position: Vector2
var rest_rotation: float = 0.0

var _visual: Polygon2D
var _collision: CollisionShape2D
var _base_color: Color


func configure(
	actor_node: Node,
	id: StringName,
	label: String,
	hp: int,
	is_vital: bool,
	part_size: Vector2,
	part_position: Vector2,
	color: Color,
	hurtbox_layer: int
) -> void:
	actor = actor_node
	part_id = id
	display_name = label
	max_health = hp
	health = hp
	vital = is_vital
	position = part_position
	rest_position = part_position
	collision_layer = hurtbox_layer
	collision_mask = 0
	monitorable = true
	_base_color = color

	_collision = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = part_size
	_collision.shape = shape
	add_child(_collision)

	_visual = Polygon2D.new()
	var half := part_size * 0.5
	_visual.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	])
	_visual.color = color
	add_child(_visual)


func receive_damage(amount: int, source_position: Vector2) -> bool:
	if health <= 0:
		return false
	if actor.has_method("can_receive_part_damage") and not actor.can_receive_part_damage():
		return false

	health = maxi(health - amount, 0)
	_flash()
	health_changed.emit(self)
	if actor.has_method("on_body_part_damaged"):
		actor.on_body_part_damaged(self, amount, source_position)

	if health <= 0:
		_collision.set_deferred("disabled", true)
		visible = false
		destroyed.emit(self)
	return true


func increase_max_health(amount: int, heal_amount: int) -> void:
	max_health += amount
	health = mini(health + heal_amount, max_health)
	health_changed.emit(self)


func set_tint(color: Color) -> void:
	if health > 0:
		_visual.modulate = color


func reset_tint() -> void:
	if health > 0:
		_visual.modulate = Color.WHITE


func animate_transform(offset: Vector2, angle: float) -> void:
	if health <= 0:
		return
	position = rest_position + offset
	rotation = rest_rotation + angle


func _flash() -> void:
	if not is_instance_valid(_visual):
		return
	var tween := create_tween()
	_visual.modulate = Color(1.0, 0.2, 0.2, 1.0)
	tween.tween_property(_visual, "modulate", Color.WHITE, 0.14)
