extends Node


func _ready() -> void:
	$Main.call("_start_single_player")
	await get_tree().physics_frame
	await get_tree().physics_frame

	var player := $Main/Player as Player
	var enemy := $Main/TrainingDummy as TrainingDummy
	var single_map_clean := $Main/HallMap.visible and not $Main/PvPMap.visible
	for node in $Main/HallMap.find_children("*", "CollisionShape2D", true, false):
		single_map_clean = single_map_clean and not (node as CollisionShape2D).disabled
	for node in $Main/PvPMap.find_children("*", "CollisionShape2D", true, false):
		single_map_clean = single_map_clean and (node as CollisionShape2D).disabled
	enemy.set_physics_process(false)

	var player_parts := player.get_node("Visual/Parts").get_children()
	var enemy_parts := enemy.get_node("Visual/Parts").get_children()
	var six_parts_created := player_parts.size() == 6 and enemy_parts.size() == 6
	var dots_centered := true
	for node in player_parts:
		if not (node as BodyPart).get_status_dot_position().is_zero_approx():
			dots_centered = false

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
	for index in range(8):
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

	var left_wall_shape := $Main/HallMap/LeftWall/CollisionShape2D.shape as RectangleShape2D
	var right_wall_shape := $Main/HallMap/RightWall/CollisionShape2D.shape as RectangleShape2D
	var room_walls_cover_height := left_wall_shape.size.y >= 720.0 \
		and right_wall_shape.size.y >= 720.0

	enemy.position = Vector2(1100, 602)
	await get_tree().create_timer(0.3).timeout
	var special_enemy_scene := load("res://scenes/enemies/training_dummy.tscn") as PackedScene
	var air_enemy := special_enemy_scene.instantiate() as TrainingDummy
	$Main.add_child(air_enemy)
	air_enemy.set_physics_process(false)
	air_enemy.position = player.position + Vector2(58, 18)
	await get_tree().physics_frame
	var air_before := _total_health(air_enemy.get_node("Visual/Parts").get_children())
	player.call("_start_attack", 1, 1)
	await get_tree().create_timer(0.22).timeout
	var air_attack_worked := player.get_attack_kind() == 1 \
		and _total_health(air_enemy.get_node("Visual/Parts").get_children()) < air_before

	await get_tree().create_timer(0.35).timeout
	air_enemy.position = Vector2(1100, 602)
	var dash_enemy := special_enemy_scene.instantiate() as TrainingDummy
	$Main.add_child(dash_enemy)
	dash_enemy.set_physics_process(false)
	dash_enemy.position = player.position + Vector2(82, 0)
	await get_tree().physics_frame
	var dash_before := _total_health(dash_enemy.get_node("Visual/Parts").get_children())
	player.set("_dash_cooldown_timer", 0.0)
	player.start_dash()
	player.call("_start_attack", 1, 2)
	await get_tree().create_timer(0.16).timeout
	var dash_attack_worked := player.get_attack_kind() == 2 \
		and _total_health(dash_enemy.get_node("Visual/Parts").get_children()) < dash_before

	await get_tree().create_timer(0.35).timeout
	dash_enemy.position = Vector2(1100, 602)
	var low_enemy := special_enemy_scene.instantiate() as TrainingDummy
	$Main.add_child(low_enemy)
	low_enemy.set_physics_process(false)
	low_enemy.position = player.position + Vector2(62, 18)
	await get_tree().physics_frame
	var low_parts := low_enemy.get_node("Visual/Parts").get_children()
	var low_before := _total_health(low_parts)
	var left_foot := _find_part(low_parts, "left_leg")
	var right_foot := _find_part(low_parts, "right_leg")
	var feet_before := left_foot.health + right_foot.health
	player.call("_start_attack", 1, 3)
	await get_tree().create_timer(0.22).timeout
	var low_attack_worked := player.get_attack_kind() == 3 \
		and _total_health(low_parts) < low_before \
		and left_foot.health + right_foot.health < feet_before

	await get_tree().create_timer(0.35).timeout
	low_enemy.position = Vector2(1100, 602)
	var spell_enemy := special_enemy_scene.instantiate() as TrainingDummy
	$Main.add_child(spell_enemy)
	spell_enemy.set_physics_process(false)
	spell_enemy.position = player.position + Vector2(150, 0)
	await get_tree().physics_frame
	var spell_before := _total_health(spell_enemy.get_node("Visual/Parts").get_children())
	var mana_before := player.get_mana()
	var spell_cast := player.cast_spell()
	await get_tree().create_timer(0.35).timeout
	var spell_worked := spell_cast and player.get_mana() == mana_before - player.spell_cost \
		and _total_health(spell_enemy.get_node("Visual/Parts").get_children()) < spell_before
	var mana_after_spell := player.get_mana()
	await get_tree().create_timer(0.3).timeout
	var mana_regenerated := player.get_mana() > mana_after_spell

	var block_enemy := special_enemy_scene.instantiate() as TrainingDummy
	$Main.add_child(block_enemy)
	block_enemy.set_physics_process(false)
	block_enemy.position = player.position + Vector2(45, 0)
	player.set("_invincibility_timer", 0.0)
	var block_torso := _find_part(player_parts, "torso")
	var perfect_before := block_torso.health
	player.call("_start_block")
	var perfect_connected := block_torso.receive_damage(2, block_enemy.global_position)
	var perfect_blocked := perfect_connected and block_torso.health == perfect_before \
		and block_enemy.get_movement_stun_time() >= 0.9 \
		and block_enemy.get_attack_stun_time() >= 0.9
	block_enemy.set("_movement_stun_timer", 0.0)
	block_enemy.set("_attack_stun_timer", 0.0)
	var magic_before := block_torso.health
	player.set("_invincibility_timer", 0.0)
	var magic_connected := block_torso.receive_damage(5, block_enemy.global_position, "spell")
	var blocking_immune_to_magic := magic_connected and block_torso.health == magic_before \
		and block_enemy.get_movement_stun_time() == 0.0 \
		and block_enemy.get_attack_stun_time() == 0.0
	player.set("_block_timer", 0.3)
	player.set("_invincibility_timer", 0.0)
	var reduced_before := block_torso.health
	block_torso.receive_damage(2, block_enemy.global_position)
	var half_damage := block_torso.health == reduced_before - 1
	player.call("_stop_block")
	var block_cooldown_started := player.get_block_cooldown_time() >= 0.95

	var shield := player.get_node("Visual/Shield") as Node2D
	var player_arm := _find_part(player_parts, "left_arm")
	player.set("_invincibility_timer", 0.0)
	player_arm.receive_damage(999, block_enemy.global_position)
	var arm_break_disables_block := not shield.visible and not player.can_block()
	var torso_regen_before := block_torso.health
	player.call("heal_next_body_part")
	var normal_heal_order := block_torso.health == torso_regen_before + 1 \
		and player_arm.health == 0
	block_torso.health = block_torso.max_health
	var head_part := _find_part(player_parts, "head")
	head_part.health = head_part.max_health
	player.call("_refresh_body_health")
	player.call("heal_next_body_part")
	var limb_regenerated_after_priority := player_arm.health == 1 \
		and player_arm.visible and player.can_block() and shield.visible
	var regenerated_at_rest := player_arm.position.is_equal_approx(player_arm.rest_position) \
		and is_zero_approx(player_arm.rotation)
	player.set("health_regen_interval_msec", 50)
	var regen_timer := player.get_node("HealthRegenerationTimer") as Timer
	regen_timer.wait_time = 0.05
	regen_timer.stop()
	var timed_regen_before := block_torso.health
	block_torso.health = maxi(block_torso.health - 1, 0)
	player.call("_refresh_body_health")
	player.call("_on_part_health_changed", block_torso)
	await get_tree().create_timer(0.07).timeout
	var six_second_logic_works := block_torso.health == timed_regen_before
	player.apply_upgrade("rapid_regeneration")
	var rapid_regen_once := player.get_health_regen_interval_msec() == 3000 \
		and player.has_rapid_regeneration()
	player.apply_upgrade("rapid_regeneration")
	var rapid_regen_not_stacked := player.get_health_regen_interval_msec() == 3000

	var bolt_scene := load("res://scenes/combat/magic_bolt.tscn") as PackedScene
	var attackable_bolt := bolt_scene.instantiate() as MagicBolt
	attackable_bolt.caster = block_enemy
	$Main.add_child(attackable_bolt)
	attackable_bolt.global_position = player.global_position + Vector2(62, -8)
	await get_tree().physics_frame
	player.call("_start_attack", 1)
	player.call("_begin_active_attack")
	await get_tree().physics_frame
	player.call("_damage_overlapping_enemies")
	await get_tree().create_timer(0.15).timeout
	var bolt_destroyed_by_attack := not is_instance_valid(attackable_bolt)

	print("Body parts test: map=%s base=%s dots=%s animation=%s timing=%s iframe=%s walls=%s air=%s dash=%s low=%s spell=%s regen=%s perfect=%s magic_guard=%s half=%s cooldown=%s arm_break=%s heal_order=%s regrow=%s timed=%s rapid=%s bolt_cut=%s" % [
		single_map_clean,
		six_parts_created,
		dots_centered,
		parts_animated,
		no_damage_during_windup and sword_hit_part and sword_animated and attack_has_recovery,
		dash_iframe_worked,
		room_walls_cover_height,
		air_attack_worked,
		dash_attack_worked,
		low_attack_worked,
		spell_worked,
		mana_regenerated,
		perfect_blocked,
		blocking_immune_to_magic,
		half_damage,
		block_cooldown_started,
		arm_break_disables_block,
		normal_heal_order,
		limb_regenerated_after_priority and regenerated_at_rest,
		six_second_logic_works,
		rapid_regen_once and rapid_regen_not_stacked,
		bolt_destroyed_by_attack,
	])

	var passed := single_map_clean and six_parts_created and dots_centered \
		and independent_health and destroyed_part_hidden \
		and arm_debuff_applied and parts_animated and no_damage_during_windup \
		and sword_hit_part and sword_animated and attack_has_recovery \
		and dash_iframe_worked and room_walls_cover_height \
		and air_attack_worked and dash_attack_worked \
		and low_attack_worked and spell_worked and mana_regenerated \
		and perfect_blocked and blocking_immune_to_magic \
		and half_damage and block_cooldown_started \
		and arm_break_disables_block and normal_heal_order \
		and limb_regenerated_after_priority and regenerated_at_rest \
		and six_second_logic_works \
		and rapid_regen_once and rapid_regen_not_stacked \
		and bolt_destroyed_by_attack
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
