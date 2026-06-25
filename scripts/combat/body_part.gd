class_name BodyPart
extends Area2D

signal health_changed(part: BodyPart)
signal destroyed(part: BodyPart)

var part_id: StringName
var display_name: String
var max_health: int
var base_max_health: int
var health: int
var vital: bool
var actor: Node
var rest_position: Vector2
var rest_rotation: float = 0.0

var _visual: Polygon2D
var _status_dot: Polygon2D
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
	base_max_health = hp
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

	_status_dot = Polygon2D.new()
	_status_dot.position = Vector2.ZERO
	_status_dot.polygon = PackedVector2Array([
		Vector2(0, -3), Vector2(3, 0), Vector2(0, 3), Vector2(-3, 0),
	])
	add_child(_status_dot)
	_update_status_dot()


func receive_damage(amount: int, source_position: Vector2) -> bool:
	if health <= 0:
		return false
	if actor.has_method("can_receive_part_damage") and not actor.can_receive_part_damage():
		return false
	if actor.has_method("modify_incoming_damage"):
		amount = actor.modify_incoming_damage(amount, source_position)
		if amount <= 0:
			return true

	health = maxi(health - amount, 0)
	_update_status_dot()
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
	_update_status_dot()
	health_changed.emit(self)


func reset_part() -> void:
	max_health = base_max_health
	health = max_health
	visible = true
	_collision.set_deferred("disabled", false)
	_visual.modulate = Color.WHITE
	_update_status_dot()
	health_changed.emit(self)


func apply_authoritative_state(new_health: int, new_max_health: int) -> void:
	max_health = maxi(new_max_health, 1)
	health = clampi(new_health, 0, max_health)
	var intact := health > 0
	visible = intact
	_collision.set_deferred("disabled", not intact)
	if intact:
		_visual.modulate = Color.WHITE
	_update_status_dot()
	health_changed.emit(self)


func set_tint(color: Color) -> void:
	if health > 0:
		_visual.modulate = color


func reset_tint() -> void:
	if health > 0:
		_visual.modulate = Color.WHITE


func animate_transform(offset: Vector2, angle: float, smoothness: float = 0.28) -> void:
	if health <= 0:
		return
	position = position.lerp(rest_position + offset, smoothness)
	rotation = lerp_angle(rotation, rest_rotation + angle, smoothness)


func get_status_color() -> Color:
	return _status_dot.color


func get_status_dot_position() -> Vector2:
	return _status_dot.position


func _flash() -> void:
	if not is_instance_valid(_visual):
		return
	var tween := create_tween()
	_visual.modulate = Color(1.0, 0.2, 0.2, 1.0)
	tween.tween_property(_visual, "modulate", Color.WHITE, 0.14)


func _update_status_dot() -> void:
	if not is_instance_valid(_status_dot):
		return
	var ratio := float(health) / float(max_health)
	if ratio < 0.2:
		_status_dot.color = Color(1.0, 0.16, 0.12)
	elif ratio < 0.5:
		_status_dot.color = Color(1.0, 0.82, 0.12)
	else:
		_status_dot.color = Color(0.2, 1.0, 0.3)
