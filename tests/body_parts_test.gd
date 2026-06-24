extends Node


func _ready() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame

	var player := $Main/Player as Player
	var enemy := $Main/TrainingDummy as TrainingDummy
	enemy.set_physics_process(false)

	var player_parts := player.get_node("Visual/Parts").get_children()
	var enemy_parts := enemy.get_node("Visual/Parts").get_children()
	var six_parts_created := player_parts.size() == 6 and enemy_parts.size() == 6

	var enemy_arm := _find_part(enemy_parts, "left_arm")
	var enemy_torso := _find_part(enemy_parts, "torso")
	var torso_before := enemy_torso.health
	var arm_before := enemy_arm.health
	enemy_arm.receive_damage(1, player.global_position)
	var independent_health := enemy_arm.health == arm_before - 1 \
		and enemy_torso.health == torso_before
	enemy_arm.receive_damage(999, player.global_position)
	var destroyed_part_hidden := not enemy_arm.visible
	var arm_debuff_applied := enemy.get_attack_multiplier() < 1.0

	enemy.position = player.position + Vector2(70, 0)
	var enemy_total_before := _total_health(enemy_parts)
	var sword_pivot := player.get_node("Visual/SwordPivot") as Node2D
	var sword_rest_angle := sword_pivot.rotation
	player.call("_start_attack", 1)
	await get_tree().create_timer(0.06).timeout
	var no_damage_during_windup := _total_health(enemy_parts) == enemy_total_before
	await get_tree().create_timer(0.12).timeout
	var sword_animated := absf(sword_pivot.rotation - sword_rest_angle) > 0.03
	var sword_hit_part := _total_health(enemy_parts) < enemy_total_before
	await get_tree().create_timer(0.1).timeout
	var attack_has_recovery := player.is_attack_recovering()

	player.velocity.x = 180.0
	player.set("_animation_time", 0.7)
	player.call("_animate_body_parts")
	var animated_part_count := 0
	for node in player_parts:
		var part := node as BodyPart
		if part.health > 0 and (absf(part.rotation) > 0.03 or part.position.distance_to(part.rest_position) > 0.5):
			animated_part_count += 1
	var parts_animated := animated_part_count >= 4

	var player_torso := _find_part(player_parts, "torso")
	var player_torso_before := player_torso.health
	player.start_dash()
	var damage_accepted: bool = player_torso.receive_damage(1, enemy.global_position)
	var dash_iframe_worked := player.is_dash_invulnerable() \
		and not damage_accepted and player_torso.health == player_torso_before

	var left_wall_shape := $Main/LeftWall/CollisionShape2D.shape as RectangleShape2D
	var right_wall_shape := $Main/RightWall/CollisionShape2D.shape as RectangleShape2D
	var room_walls_cover_height := left_wall_shape.size.y >= 720.0 \
		and right_wall_shape.size.y >= 720.0

	print("Body parts test: six=%s independent=%s hidden=%s debuff=%s parts_animated=%s windup_safe=%s sword_hit=%s sword_animation=%s recovery=%s dash_iframe=%s walls=%s" % [
		six_parts_created,
		independent_health,
		destroyed_part_hidden,
		arm_debuff_applied,
		parts_animated,
		no_damage_during_windup,
		sword_hit_part,
		sword_animated,
		attack_has_recovery,
		dash_iframe_worked,
		room_walls_cover_height,
	])

	var passed := six_parts_created and independent_health and destroyed_part_hidden \
		and arm_debuff_applied and parts_animated and no_damage_during_windup \
		and sword_hit_part and sword_animated and attack_has_recovery \
		and dash_iframe_worked and room_walls_cover_height
	get_tree().quit(0 if passed else 1)


func _find_part(parts: Array[Node], id: StringName) -> BodyPart:
	for node in parts:
		var part := node as BodyPart
		if part.part_id == id:
			return part
	return null


func _total_health(parts: Array[Node]) -> int:
	var total := 0
	for node in parts:
		total += (node as BodyPart).health
	return total
