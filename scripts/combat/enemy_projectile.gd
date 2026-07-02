class_name EnemyProjectile
extends Area2D

const DAMAGE_OVER_TIME_SCRIPT := preload("res://scripts/combat/damage_over_time.gd")

var direction: Vector2 = Vector2.RIGHT
var speed: float = 420.0
var damage: int = 2
var source_position: Vector2
var poison_ticks: int = 0
var radius: float = 7.0
var visual_length: float = 20.0
var visual_color: Color = Color(1.0, 0.72, 0.24, 0.95)
var shape_style: String = "bolt"
var target: Node2D
var homing_strength: float = 0.0
var slow_duration: float = 0.0
var weakness_duration: float = 0.0
var _life: float = 3.0
var _visual_root: Node2D
var _network_id: int = 0
var _network_proxy: bool = false
var _network_target_position: Vector2
var _network_target_direction: Vector2 = Vector2.RIGHT
var _network_last_sequence: int = -1
var _network_stale_time: float = 0.0


func _ready() -> void:
	add_to_group("enemy_network_effect")
	collision_layer = 0
	collision_mask = 0 if _network_proxy else 16
	monitoring = not _network_proxy
	var shape_node := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	shape_node.shape = shape
	add_child(shape_node)
	_visual_root = Node2D.new()
	_visual_root.rotation = direction.angle()
	add_child(_visual_root)
	_network_target_position = global_position
	_network_target_direction = direction
	var half_length := visual_length * 0.5
	var half_height := maxf(4.0, radius * 0.55)
	match shape_style:
		"arrow":
			_add_visual(PackedVector2Array([Vector2(-half_length, -2), Vector2(half_length * 0.45, -2), Vector2(half_length * 0.45, -half_height), Vector2(half_length, 0), Vector2(half_length * 0.45, half_height), Vector2(half_length * 0.45, 2), Vector2(-half_length, 2)]), visual_color)
		"orb", "blood_orb", "skull":
			var points := PackedVector2Array()
			for index in range(12):
				var angle := TAU * float(index) / 12.0
				points.append(Vector2(cos(angle), sin(angle)) * radius)
			_add_visual(points, visual_color)
			_add_visual(PackedVector2Array([Vector2(0, -radius * 0.62), Vector2(radius * 0.62, 0), Vector2(0, radius * 0.62), Vector2(-radius * 0.62, 0)]), visual_color.lightened(0.4), 1)
			if shape_style == "skull":
				_add_visual(PackedVector2Array([Vector2(-radius * 0.52, -radius * 0.18), Vector2(-radius * 0.12, -radius * 0.28), Vector2(-radius * 0.18, radius * 0.12), Vector2(-radius * 0.55, radius * 0.08)]), Color(0.04, 0.1, 0.18, 0.9), 2)
				_add_visual(PackedVector2Array([Vector2(radius * 0.12, -radius * 0.28), Vector2(radius * 0.52, -radius * 0.18), Vector2(radius * 0.55, radius * 0.08), Vector2(radius * 0.18, radius * 0.12)]), Color(0.04, 0.1, 0.18, 0.9), 2)
		"laser":
			_add_visual(PackedVector2Array([Vector2(-half_length, -half_height * 0.45), Vector2(half_length * 0.82, -half_height), Vector2(half_length, 0), Vector2(half_length * 0.82, half_height), Vector2(-half_length, half_height * 0.45)]), visual_color)
			_add_visual(PackedVector2Array([Vector2(-half_length, -1.5), Vector2(half_length, -1.5), Vector2(half_length, 1.5), Vector2(-half_length, 1.5)]), Color.WHITE, 1)
		"shard":
			_add_visual(PackedVector2Array([Vector2(-half_length, 0), Vector2(0, -half_height), Vector2(half_length, 0), Vector2(0, half_height)]), visual_color)
		"flame":
			_add_visual(PackedVector2Array([Vector2(-half_length, 0), Vector2(-half_length * 0.55, -half_height), Vector2(-half_length * 0.1, -half_height * 0.35), Vector2(half_length * 0.42, -half_height * 0.8), Vector2(half_length, 0), Vector2(half_length * 0.38, half_height * 0.78), Vector2(-half_length * 0.15, half_height * 0.32), Vector2(-half_length * 0.62, half_height)]), visual_color)
		"needle":
			_add_visual(PackedVector2Array([Vector2(-half_length, -1.5), Vector2(half_length * 0.72, -2.5), Vector2(half_length, 0), Vector2(half_length * 0.72, 2.5), Vector2(-half_length, 1.5)]), visual_color)
		"poison":
			_add_visual(PackedVector2Array([Vector2(-half_length * 0.75, -half_height * 0.7), Vector2(half_length * 0.3, -half_height), Vector2(half_length, -half_height * 0.1), Vector2(half_length * 0.55, half_height), Vector2(-half_length * 0.55, half_height * 0.72), Vector2(-half_length, 0)]), visual_color)
		_:
			_add_visual(PackedVector2Array([Vector2(-half_length, -half_height), Vector2(half_length * 0.68, -half_height * 0.9), Vector2(half_length, 0), Vector2(half_length * 0.68, half_height * 0.9), Vector2(-half_length, half_height), Vector2(-half_length * 0.45, 0)]), visual_color)
	if not _network_proxy:
		var main := get_tree().current_scene
		if is_instance_valid(main) and main.has_method("register_enemy_network_effect"):
			main.register_enemy_network_effect(self)


func _exit_tree() -> void:
	if _network_proxy or _network_id <= 0 or not is_inside_tree():
		return
	var main := get_tree().current_scene
	if is_instance_valid(main) and main.has_method("unregister_enemy_network_effect"):
		main.unregister_enemy_network_effect(_network_id)


func _add_visual(points: PackedVector2Array, color: Color, z_index: int = 0) -> void:
	var visual := Polygon2D.new()
	visual.polygon = points
	visual.color = color
	visual.z_index = z_index
	_visual_root.add_child(visual)


func _physics_process(delta: float) -> void:
	if _network_proxy:
		_update_network_proxy(delta)
		return
	if homing_strength > 0.0 and is_instance_valid(target):
		var desired := (target.global_position - global_position).normalized()
		direction = direction.normalized().lerp(desired, clampf(homing_strength * delta, 0.0, 1.0)).normalized()
		_visual_root.rotation = direction.angle()
	position += direction.normalized() * speed * delta
	_life -= delta
	for area in get_overlapping_areas():
		if area is BodyPart:
			var part := area as BodyPart
			if _apply_damage(part):
				if slow_duration > 0.0 and part.actor.has_method("apply_enemy_slow"):
					_apply_status(part.actor, "slow", slow_duration, 0.58)
				if weakness_duration > 0.0 and part.actor.has_method("apply_enemy_weakness"):
					_apply_status(part.actor, "weakness", weakness_duration, 0.68)
				if poison_ticks > 0 and is_instance_valid(part.actor):
					_apply_poison(part.actor)
				queue_free()
				return
	if _life <= 0.0:
		queue_free()


func _apply_damage(part: BodyPart) -> bool:
	if multiplayer.has_multiplayer_peer():
		if not multiplayer.is_server():
			return false
		var main := get_tree().current_scene
		if is_instance_valid(main) and main.has_method("server_apply_enemy_player_damage"):
			return main.server_apply_enemy_player_damage(
				part.actor as Player, part.part_id, damage, source_position, "projectile"
			)
	return part.receive_damage(damage, source_position, "projectile")


func _apply_status(actor: Node, effect: String, duration: float, strength: float) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		var main := get_tree().current_scene
		if is_instance_valid(main) and main.has_method("server_apply_enemy_player_status"):
			main.server_apply_enemy_player_status(actor as Player, effect, duration, strength)
			return
	if effect == "slow":
		actor.apply_enemy_slow(duration, strength)
	elif effect == "weakness":
		actor.apply_enemy_weakness(duration, strength)


func _apply_poison(actor: Node) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		var main := get_tree().current_scene
		if is_instance_valid(main) and main.has_method("server_apply_enemy_player_poison"):
			main.server_apply_enemy_player_poison(actor as Player, source_position, poison_ticks, 0.8)
			return
	var effect := DAMAGE_OVER_TIME_SCRIPT.new()
	effect.configure(actor, source_position, 1, poison_ticks, 0.8)
	actor.add_child(effect)


func set_network_id(value: int) -> void:
	_network_id = value


func get_network_id() -> int:
	return _network_id


func set_network_proxy(enabled: bool) -> void:
	_network_proxy = enabled
	if is_inside_tree():
		collision_mask = 0 if enabled else 16
		monitoring = not enabled


func serialize_network_state() -> Dictionary:
	return {
		"kind": "projectile",
		"position": global_position,
		"direction": direction,
		"speed": speed,
		"damage": damage,
		"source_position": source_position,
		"poison_ticks": poison_ticks,
		"radius": radius,
		"visual_length": visual_length,
		"visual_color": visual_color,
		"shape_style": shape_style,
		"homing_strength": homing_strength,
		"slow_duration": slow_duration,
		"weakness_duration": weakness_duration,
		"lifetime": _life,
	}


func serialize_network_motion_state() -> Dictionary:
	return {
		"kind": "projectile",
		"position": global_position,
		"direction": direction,
		"lifetime": _life,
	}


func apply_network_state(state: Dictionary) -> void:
	var sequence := int(state.get("snapshot_sequence", 0))
	if sequence <= _network_last_sequence:
		return
	_network_last_sequence = sequence
	_network_stale_time = 0.0
	_network_target_position = state.get("position", global_position)
	_network_target_direction = (state.get("direction", direction) as Vector2).normalized()
	direction = _network_target_direction
	_life = float(state.get("lifetime", _life))
	if global_position.distance_to(_network_target_position) > 120.0:
		global_position = _network_target_position


func _update_network_proxy(delta: float) -> void:
	_network_stale_time += delta
	var predicted := _network_target_position + _network_target_direction * speed * minf(_network_stale_time, 0.08)
	var blend := 1.0 - exp(-34.0 * delta)
	global_position = global_position.lerp(predicted, blend)
	direction = direction.lerp(_network_target_direction, blend).normalized()
	if is_instance_valid(_visual_root):
		_visual_root.rotation = direction.angle()
	if _network_stale_time > 1.0:
		queue_free()
