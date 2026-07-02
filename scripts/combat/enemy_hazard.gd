class_name EnemyHazard
extends Area2D

var damage: int = 1
var lifetime: float = 3.0
var tick_interval: float = 0.7
var radius: float = 38.0
var startup_delay: float = 0.0
var visual_color: Color = Color(1.0, 0.28, 0.04, 0.48)
var slow_duration: float = 0.0
var weakness_duration: float = 0.0
var _tick_timer: float = 0.0
var _visual: Polygon2D
var _network_id: int = 0
var _network_proxy: bool = false
var _network_last_sequence: int = -1
var _network_stale_time: float = 0.0


func _ready() -> void:
	add_to_group("enemy_network_effect")
	collision_layer = 0
	collision_mask = 0 if _network_proxy else 16
	monitoring = not _network_proxy
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	collision.shape = shape
	add_child(collision)
	_visual = Polygon2D.new()
	var points := PackedVector2Array()
	for index in range(16):
		var angle := TAU * float(index) / 16.0
		points.append(Vector2(cos(angle), sin(angle) * 0.38) * radius)
	_visual.polygon = points
	_visual.color = visual_color
	add_child(_visual)
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


func _physics_process(delta: float) -> void:
	lifetime -= delta
	if startup_delay > 0.0:
		startup_delay -= delta
		_visual.modulate.a = 0.28 + 0.22 * sin(Time.get_ticks_msec() * 0.018)
		if lifetime <= 0.0 and not _network_proxy:
			queue_free()
		return
	_visual.modulate.a = 1.0
	if _network_proxy:
		_network_stale_time += delta
		if _network_stale_time > 1.0:
			queue_free()
		return
	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer = tick_interval
		var damaged_actors: Array[Node] = []
		for area in get_overlapping_areas():
			if area is BodyPart:
				var part := area as BodyPart
				if part.actor not in damaged_actors and _apply_damage(part):
					damaged_actors.append(part.actor)
					if slow_duration > 0.0 and part.actor.has_method("apply_enemy_slow"):
						_apply_status(part.actor, "slow", slow_duration, 0.55)
					if weakness_duration > 0.0 and part.actor.has_method("apply_enemy_weakness"):
						_apply_status(part.actor, "weakness", weakness_duration, 0.68)
	if lifetime <= 0.0:
		queue_free()


func _apply_damage(part: BodyPart) -> bool:
	if multiplayer.has_multiplayer_peer():
		if not multiplayer.is_server():
			return false
		var main := get_tree().current_scene
		if is_instance_valid(main) and main.has_method("server_apply_enemy_player_damage"):
			return main.server_apply_enemy_player_damage(
				part.actor as Player, part.part_id, damage, global_position, "fire"
			)
	return part.receive_damage(damage, global_position, "fire")


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
		"kind": "hazard",
		"position": global_position,
		"damage": damage,
		"radius": radius,
		"startup_delay": startup_delay,
		"lifetime": lifetime,
		"tick_interval": tick_interval,
		"visual_color": visual_color,
		"slow_duration": slow_duration,
		"weakness_duration": weakness_duration,
		"tick_timer": _tick_timer,
	}


func serialize_network_motion_state() -> Dictionary:
	return {
		"kind": "hazard",
		"position": global_position,
		"startup_delay": startup_delay,
		"lifetime": lifetime,
		"tick_timer": _tick_timer,
	}


func apply_network_state(state: Dictionary) -> void:
	var sequence := int(state.get("snapshot_sequence", 0))
	if sequence <= _network_last_sequence:
		return
	_network_last_sequence = sequence
	_network_stale_time = 0.0
	global_position = state.get("position", global_position)
	startup_delay = float(state.get("startup_delay", startup_delay))
	lifetime = float(state.get("lifetime", lifetime))
	_tick_timer = float(state.get("tick_timer", _tick_timer))
