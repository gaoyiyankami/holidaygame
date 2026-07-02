class_name PlatformChaseAgent
extends RefCounted

const ONE_WAY_PLATFORM_LAYER := 1 << 5
const WORLD_COLLISION_MASK := 1 | ONE_WAY_PLATFORM_LAYER

var jump_velocity: float = -740.0
var jump_cooldown: float = 0.0
var drop_timer: float = 0.0
var stuck_timer: float = 0.45
var stuck_jumps: int = 0
var last_position: Vector2 = Vector2.INF


func tick(body: CharacterBody2D, delta: float) -> void:
	jump_cooldown = maxf(0.0, jump_cooldown - delta)
	if drop_timer > 0.0:
		drop_timer = maxf(0.0, drop_timer - delta)
		body.collision_mask &= ~ONE_WAY_PLATFORM_LAYER
		if drop_timer <= 0.0:
			body.collision_mask |= ONE_WAY_PLATFORM_LAYER
	else:
		body.collision_mask |= ONE_WAY_PLATFORM_LAYER


func steer(body: CharacterBody2D, target: Node2D, delta: float, direction: float, move_speed: float) -> float:
	if not is_instance_valid(target):
		return direction
	var offset := target.global_position - body.global_position
	var steering := direction if not is_zero_approx(direction) else 1.0
	_update_stuck_state(body, offset, delta)
	if not body.is_on_floor() or drop_timer > 0.0:
		return steering

	if offset.y > 80.0:
		if _standing_on_one_way(body):
			drop_timer = 0.34
			body.position.y += 7.0
			body.velocity.y = 150.0
			return steering
		if absf(offset.x) < 110.0:
			steering = _nearest_edge_direction(body, steering)

	var obstacle_ahead := _ray_hit(body, Vector2(0, -24), Vector2(steering * 48.0, -24), WORLD_COLLISION_MASK)
	var floor_ahead := _ray_hit(body, Vector2(steering * 42.0, -4), Vector2(steering * 42.0, 88.0), WORLD_COLLISION_MASK)
	var target_above := offset.y < -48.0
	var gap_ahead := not floor_ahead and absf(offset.x) > 72.0
	var stuck := stuck_jumps > 0
	if jump_cooldown <= 0.0 and (target_above or obstacle_ahead or gap_ahead or stuck):
		var height_bonus := clampf(maxf(0.0, -offset.y - 70.0) * 0.12, 0.0, 45.0)
		body.velocity.y = jump_velocity - height_bonus
		body.velocity.x = steering * maxf(move_speed, 230.0)
		jump_cooldown = 0.62
		stuck_jumps = maxi(0, stuck_jumps - 1)
	return steering


func has_line_of_sight(body: CharacterBody2D, target: Node2D) -> bool:
	if not is_instance_valid(target) or body.get_world_2d() == null:
		return false
	var query := PhysicsRayQueryParameters2D.create(
		body.global_position + Vector2(0, -24),
		target.global_position + Vector2(0, -18),
		WORLD_COLLISION_MASK,
		[body.get_rid()]
	)
	return body.get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func separation(body: CharacterBody2D) -> float:
	var force := 0.0
	for node in body.get_tree().get_nodes_in_group("enemy"):
		if node == body or not (node is Node2D):
			continue
		var other := node as Node2D
		var distance := body.global_position.distance_to(other.global_position)
		if distance > 0.0 and distance < 72.0 and absf(body.global_position.y - other.global_position.y) < 55.0:
			force += signf(body.global_position.x - other.global_position.x) * (1.0 - distance / 72.0)
	return clampf(force, -1.0, 1.0)


func _update_stuck_state(body: CharacterBody2D, target_offset: Vector2, delta: float) -> void:
	stuck_timer -= delta
	if stuck_timer > 0.0:
		return
	if last_position.is_finite() and body.global_position.distance_to(last_position) < 7.0 \
		and target_offset.length() > 90.0:
		stuck_jumps = mini(stuck_jumps + 1, 2)
	else:
		stuck_jumps = 0
	last_position = body.global_position
	stuck_timer = 0.45


func _standing_on_one_way(body: CharacterBody2D) -> bool:
	return _ray_hit(body, Vector2(0, 8), Vector2(0, 72), ONE_WAY_PLATFORM_LAYER)


func _nearest_edge_direction(body: CharacterBody2D, fallback: float) -> float:
	for distance in [48.0, 86.0, 128.0, 172.0]:
		var left_floor := _ray_hit(body, Vector2(-distance, -4), Vector2(-distance, 100), WORLD_COLLISION_MASK)
		var right_floor := _ray_hit(body, Vector2(distance, -4), Vector2(distance, 100), WORLD_COLLISION_MASK)
		if not left_floor:
			return -1.0
		if not right_floor:
			return 1.0
	return fallback


func _ray_hit(body: CharacterBody2D, from_offset: Vector2, to_offset: Vector2, mask: int) -> bool:
	if body.get_world_2d() == null:
		return false
	var query := PhysicsRayQueryParameters2D.create(
		body.global_position + from_offset,
		body.global_position + to_offset,
		mask,
		[body.get_rid()]
	)
	return not body.get_world_2d().direct_space_state.intersect_ray(query).is_empty()
