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

	enemy.position = player.position + Vector2(70, 0)
	var enemy_total_before := _total_health(enemy_parts)
	var sword_pivot := player.get_node("Visual/SwordPivot") as Node2D
	var sword_rest_angle := sword_pivot.rotation
	Input.action_press("attack")
	await get_tree().physics_frame
	Input.action_release("attack")
	await get_tree().create_timer(0.04).timeout
	var sword_animated := absf(sword_pivot.rotation - sword_rest_angle) > 0.1
	await get_tree().create_timer(0.12).timeout
	var sword_hit_part := _total_health(enemy_parts) < enemy_total_before

	var player_torso := _find_part(player_parts, "torso")
	var player_torso_before := player_torso.health
	player.start_dash()
	var damage_accepted: bool = player_torso.receive_damage(1, enemy.global_position)
	var dash_iframe_worked := player.is_dash_invulnerable() \
		and not damage_accepted and player_torso.health == player_torso_before

	print("Body parts test: six=%s independent=%s sword_hit=%s sword_animation=%s dash_iframe=%s" % [
		six_parts_created,
		independent_health,
		sword_hit_part,
		sword_animated,
		dash_iframe_worked,
	])

	var passed := six_parts_created and independent_health and sword_hit_part \
		and sword_animated and dash_iframe_worked
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
