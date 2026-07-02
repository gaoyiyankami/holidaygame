class_name BodyPart
extends Area2D

signal health_changed(part: BodyPart)
signal destroyed(part: BodyPart)
signal regenerated(part: BodyPart)

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


func receive_damage(amount: int, source_position: Vector2, damage_kind: String = "melee") -> bool:
	if health <= 0:
		return false
	if actor.has_method("can_receive_part_damage") and not actor.can_receive_part_damage():
		return false
	if actor.has_method("modify_part_incoming_damage"):
		amount = actor.modify_part_incoming_damage(self, amount, source_position, damage_kind)
	elif actor.has_method("modify_incoming_damage"):
		amount = actor.modify_incoming_damage(amount, source_position, damage_kind)
	if amount <= 0:
		return true

	var applied_damage := mini(amount, health)
	health = maxi(health - amount, 0)
	_update_status_dot()
	_flash()
	_present_damage_number(applied_damage, damage_kind)
	if damage_kind != "dot":
		Feedback.hit(global_position, get_impact_material(), clampf(float(applied_damage) / 4.0, 0.65, 1.6), damage_kind in ["melee", "low", "spell"])
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


func heal_one() -> bool:
	if health >= max_health:
		return false
	var was_destroyed := health <= 0
	health += 1
	if was_destroyed:
		visible = true
		_collision.set_deferred("disabled", false)
		_visual.modulate = Color.WHITE
		position = rest_position
		rotation = rest_rotation
		scale = Vector2.ONE
	_update_status_dot()
	health_changed.emit(self)
	if was_destroyed:
		regenerated.emit(self)
	return true


func reset_part() -> void:
	max_health = base_max_health
	health = max_health
	visible = true
	_collision.set_deferred("disabled", false)
	_visual.modulate = Color.WHITE
	position = rest_position
	rotation = rest_rotation
	scale = Vector2.ONE
	_update_status_dot()
	health_changed.emit(self)


func apply_authoritative_state(new_health: int, new_max_health: int) -> void:
	var was_destroyed := health <= 0
	max_health = maxi(new_max_health, 1)
	health = clampi(new_health, 0, max_health)
	var intact := health > 0
	visible = intact
	_collision.set_deferred("disabled", not intact)
	if intact:
		_visual.modulate = Color.WHITE
		if was_destroyed:
			position = rest_position
			rotation = rest_rotation
			scale = Vector2.ONE
	_update_status_dot()
	health_changed.emit(self)
	if was_destroyed and intact:
		regenerated.emit(self)


func set_tint(color: Color) -> void:
	if health > 0:
		_visual.modulate = color


func reset_tint() -> void:
	if health > 0:
		_visual.modulate = Color.WHITE


func set_art_visible(enabled: bool) -> void:
	if is_instance_valid(_visual):
		_visual.visible = enabled


func set_visual_polygon(points: PackedVector2Array) -> void:
	if is_instance_valid(_visual) and points.size() >= 3:
		_visual.polygon = points


func add_visual_detail(points: PackedVector2Array, color: Color, z_offset: int = 1) -> Polygon2D:
	var detail := Polygon2D.new()
	detail.polygon = points
	detail.color = color
	detail.z_index = z_offset
	add_child(detail)
	return detail


func get_visual_polygon() -> PackedVector2Array:
	return _visual.polygon if is_instance_valid(_visual) else PackedVector2Array()


func get_impact_material() -> String:
	var id := str(part_id)
	if id in ["shell", "shield", "weapon", "helmet"]:
		return "metal"
	var archetype_name := str(actor.get_archetype_name()) if is_instance_valid(actor) and actor.has_method("get_archetype_name") else ""
	if archetype_name in ["stone_bug", "dungeon_turret", "heavy_hammer_guard"]:
		return "stone" if id in ["body", "legs", "root"] else "metal"
	if archetype_name in ["dungeon_mage", "summoning_priest", "ghost_mage", "crystal_drone", "crimson_witch", "lightning_slime", "frost_slime"]:
		return "magic" if id in ["core", "wings", "weapon", "body"] else "flesh"
	return "flesh"


func animate_transform(offset: Vector2, angle: float, smoothness: float = 0.28) -> void:
	if health <= 0:
		return
	position = position.lerp(rest_position + offset, smoothness)
	rotation = lerp_angle(rotation, rest_rotation + angle, smoothness)


func animate_scale(target_scale: Vector2, smoothness: float = 0.28) -> void:
	if health <= 0:
		return
	scale = scale.lerp(target_scale, smoothness)


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


func _present_damage_number(amount: int, damage_kind: String) -> void:
	if amount <= 0 or get_tree() == null:
		return
	var host := get_tree().current_scene
	if host == null:
		return
	var peer := multiplayer.multiplayer_peer
	var network_active := multiplayer.has_multiplayer_peer() \
		and not (peer is OfflineMultiplayerPeer)
	if not network_active or multiplayer.is_server():
		spawn_damage_number(host, global_position, amount, damage_kind)
	if network_active and multiplayer.is_server():
		var controller := actor
		while is_instance_valid(controller) \
			and not controller.has_method("broadcast_damage_number"):
			controller = controller.get_parent()
		if is_instance_valid(controller):
			controller.broadcast_damage_number(global_position, amount, damage_kind)


static func spawn_damage_number(
	host: Node,
	world_position: Vector2,
	amount: int,
	damage_kind: String
) -> void:
	if not is_instance_valid(host) or amount <= 0:
		return
	var label := Label.new()
	label.name = "DamageNumber"
	label.add_to_group("damage_number")
	label.text = "-%d" % amount
	label.size = Vector2(72.0, 30.0)
	label.pivot_offset = label.size * 0.5
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 120
	label.add_theme_font_size_override("font_size", 18 if amount < 10 else 21)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.08, 0.95))
	var number_color := Color(1.0, 0.92, 0.52)
	match damage_kind:
		"projectile":
			number_color = Color(0.58, 0.9, 1.0)
		"magic", "spell":
			number_color = Color(0.82, 0.58, 1.0)
		"dot", "poison":
			number_color = Color(0.58, 1.0, 0.42)
	label.add_theme_color_override("font_color", number_color)
	host.add_child(label)
	label.global_position = world_position + Vector2(-36.0 + randf_range(-6.0, 6.0), -38.0)
	label.scale = Vector2(0.72, 0.72)
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "global_position", label.global_position + Vector2(randf_range(-10.0, 10.0), -42.0), 0.58).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.24).set_delay(0.38)
	tween.chain().tween_callback(label.queue_free)


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
