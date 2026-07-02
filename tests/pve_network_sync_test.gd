extends Node


func _ready() -> void:
	var main_scene := load("res://scenes/main/main.tscn") as PackedScene
	var main := main_scene.instantiate()
	add_child(main)
	await get_tree().process_frame
	main.call("_start_single_arena_mode")
	await get_tree().physics_frame

	var enemies: Array = main.get("_active_enemies")
	var enemy := enemies[0] as VariantEnemy
	var state := enemy.serialize_network_state()
	var complete_state := true
	for key in [
		"position", "velocity", "facing", "state", "state_timer", "animation_time",
		"parts", "scale", "attack_visual_scale", "boss_attack", "special_timer",
		"ability_counter", "enraged", "stealthed", "charged",
	]:
		complete_state = complete_state and state.has(key)
	var boss_scene := load("res://scenes/enemies/variant_enemy.tscn") as PackedScene
	var boss := boss_scene.instantiate() as VariantEnemy
	boss.archetype = CustomMap.ENEMY_CRIMSON_WITCH
	main.add_child(boss)
	boss.set_physics_process(false)
	var boss_packet_bytes := var_to_bytes(boss.serialize_network_state()).size()

	var start_position := enemy.global_position
	enemy.set_network_proxy(true)
	state["snapshot_sequence"] = 1
	state["server_msec"] = main.get_estimated_server_msec()
	state["position"] = start_position
	enemy.apply_network_state(state)
	state["snapshot_sequence"] = 2
	state["position"] = start_position + Vector2(120, 0)
	state["velocity"] = Vector2(150, 0)
	state["state"] = VariantEnemy.State.WINDUP
	state["state_timer"] = 0.4
	state["charged"] = true
	enemy.apply_network_state(state)
	var did_not_hard_snap := enemy.global_position.distance_to(start_position) < 5.0
	for _frame in 8:
		await get_tree().physics_frame
	var moved_smoothly := enemy.global_position.x > start_position.x + 30.0 \
		and enemy.global_position.x < start_position.x + 155.0
	var combat_visual_synced: bool = enemy.get_node("Visual/AttackTelegraph").visible \
		and int(enemy.get("_state")) == VariantEnemy.State.WINDUP

	var projectile_state := {
		"id": 101,
		"kind": "projectile",
		"position": Vector2(420, 300),
		"direction": Vector2.RIGHT,
		"speed": 520.0,
		"damage": 4,
		"source_position": Vector2(380, 300),
		"poison_ticks": 2,
		"radius": 9.0,
		"visual_length": 42.0,
		"visual_color": Color(0.3, 0.8, 1.0),
		"shape_style": "arrow",
		"homing_strength": 0.0,
		"slow_duration": 0.0,
		"weakness_duration": 0.0,
		"lifetime": 2.0,
	}
	var projectile := main.call("_spawn_network_enemy_effect", projectile_state) as EnemyProjectile
	projectile_state["snapshot_sequence"] = 3
	projectile.apply_network_state(projectile_state)
	var projectile_start := projectile.global_position.x
	await get_tree().create_timer(0.08).timeout
	var projectile_synced: bool = projectile.get("_network_proxy") \
		and projectile.global_position.x > projectile_start
	var projectile_packet_bytes := var_to_bytes(projectile_state).size()

	var hazard_state := {
		"id": 102,
		"kind": "hazard",
		"position": Vector2(560, 620),
		"damage": 3,
		"radius": 64.0,
		"startup_delay": 0.45,
		"lifetime": 1.2,
		"tick_interval": 0.7,
		"visual_color": Color(1.0, 0.2, 0.1, 0.5),
		"slow_duration": 1.0,
		"weakness_duration": 0.0,
		"tick_timer": 0.3,
	}
	var hazard := main.call("_spawn_network_enemy_effect", hazard_state) as EnemyHazard
	hazard_state["snapshot_sequence"] = 3
	hazard.apply_network_state(hazard_state)
	var hazard_synced: bool = hazard.get("_network_proxy") \
		and is_equal_approx(hazard.radius, 64.0) \
		and is_equal_approx(hazard.startup_delay, 0.45)
	var hazard_packet_bytes := var_to_bytes(hazard_state).size()
	var packet_sizes_ok: bool = boss_packet_bytes < 1100 \
		and projectile_packet_bytes < 900 and hazard_packet_bytes < 900

	var player := main.get_node("Player") as Player
	player.apply_upgrade("attack")
	var upgraded_damage := player.attack_damage
	player.revive_for_coop(Vector2(240, 610))
	var revive_preserves_build := player.attack_damage == upgraded_damage \
		and player.get_health() == player.max_health \
		and player.global_position == Vector2(240, 610)

	print("PvE network sync test: state=%s smooth=%s visual=%s projectile=%s hazard=%s revive=%s packets=%s boss_bytes=%d projectile_bytes=%d hazard_bytes=%d" % [
		complete_state, did_not_hard_snap and moved_smoothly, combat_visual_synced,
		projectile_synced, hazard_synced, revive_preserves_build,
		packet_sizes_ok, boss_packet_bytes, projectile_packet_bytes, hazard_packet_bytes,
	])
	get_tree().quit(0 if complete_state and did_not_hard_snap and moved_smoothly \
		and combat_visual_synced and projectile_synced and hazard_synced \
		and revive_preserves_build and packet_sizes_ok else 1)
