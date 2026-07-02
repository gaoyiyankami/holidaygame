extends Node

const PORT := 17124
const TEST_TIMEOUT := 16.0

var _role := ""
var _elapsed := 0.0
var _scenario_time := 0.0
var _scenario_started := false
var _effects_spawned := false
var _lethal_damage_sent := false
var _initial_sync_passed := false
var _client_saw_death := false
var _motion_enemy: VariantEnemy
var _last_enemy_x := NAN
var _minimum_enemy_x := INF
var _maximum_enemy_x := -INF
var _maximum_frame_step := 0.0
var _client_connected := false
var _client_repositioned := false
var _client_attack_sent := false
var _client_reposition_time := 0.0
var _client_projectile_seen := false
var _client_hazard_seen := false
var _client_damage_seen := false
var _client_damage_number_seen := false
var _client_status_seen := false
var _client_part_damage_seen := false

@onready var _main := $Main


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			_role = argument.trim_prefix("--role=")
	_main.get_node("UI/NetworkPanel/VBox/PortRow/PortInput").value = PORT
	if _role == "server":
		_main.get_node("UI/NetworkPanel/VBox/NameInput").text = "PvE Host"
		_main.get_node("UI/NetworkPanel/VBox/MapRow/MapSelect").selected = 3
		_main.call("_host_game")
		print("PVE E2E SERVER READY")
	elif _role == "client":
		_main.get_node("UI/NetworkPanel/VBox/NameInput").text = "PvE Client"
		_main.get_node("UI/NetworkPanel/VBox/AddressInput").text = "127.0.0.1"
		multiplayer.connected_to_server.connect(func() -> void: _client_connected = true)
		_main.call("_join_game")
	else:
		push_error("Missing --role")
		get_tree().quit(2)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= TEST_TIMEOUT:
		print("PVE E2E %s TIMEOUT wave=%s enemies=%s effects=%s" % [
			_role, _main.get("_wave"), (_main.get("_active_enemies") as Array).size(),
			get_tree().get_nodes_in_group("enemy_network_effect").size(),
		])
		if _role == "client":
			print("PVE E2E CLIENT FLAGS projectile=%s hazard=%s damage=%s numbers=%s status=%s parts=%s initial=%s death=%s range=%.1f max_step=%.1f" % [
				_client_projectile_seen, _client_hazard_seen, _client_damage_seen,
				_client_damage_number_seen, _client_status_seen,
				_client_part_damage_seen, _initial_sync_passed,
				_client_saw_death, _maximum_enemy_x - _minimum_enemy_x,
				_maximum_frame_step,
			])
		get_tree().quit(1)
		return
	if _role == "server":
		_update_server(delta)
	elif _role == "client":
		_update_client()


func _update_server(delta: float) -> void:
	if not _scenario_started and (_main.get("_network_players") as Dictionary).size() < 2:
		return
	_scenario_time += delta
	if not _scenario_started and _scenario_time >= 0.65:
		_scenario_started = true
		var entries := [
			{"position": Vector2(760, 610), "enemy": CustomMap.ENEMY_SHADOW_ASSASSIN},
			{"position": Vector2(1040, 610), "enemy": CustomMap.ENEMY_HEAVY_HAMMER_GUARD},
			{"position": Vector2(1320, 610), "enemy": CustomMap.ENEMY_DUAL_BLADE_HUNTER},
			{"position": Vector2(1600, 410), "enemy": CustomMap.ENEMY_CRYSTAL_DRONE},
			{"position": Vector2(1880, 610), "enemy": CustomMap.ENEMY_DUNGEON_MAGE},
			{"position": Vector2(2160, 610), "enemy": CustomMap.ENEMY_SUMMONING_PRIEST},
		]
		_main.rpc("_sync_arena_wave", 29, entries)
	if _scenario_started:
		var enemies: Array = _main.get("_active_enemies")
		if not is_instance_valid(_motion_enemy):
			for enemy in enemies:
				if is_instance_valid(enemy) and enemy is VariantEnemy \
					and (enemy as VariantEnemy).archetype == CustomMap.ENEMY_DUNGEON_MAGE:
					_motion_enemy = enemy as VariantEnemy
					break
		if is_instance_valid(_motion_enemy):
			var phase := _scenario_time * 2.2
			_motion_enemy.global_position.x = 1880.0 + sin(phase) * 150.0
			_motion_enemy.velocity.x = cos(phase) * 330.0
	if _scenario_started and not _effects_spawned and _scenario_time >= 1.25:
		_spawn_server_scenario_effects()
	if _effects_spawned and not _lethal_damage_sent and _scenario_time >= 3.6:
		_lethal_damage_sent = true
		var remote_player := _remote_test_player()
		if is_instance_valid(remote_player):
			_main.server_apply_enemy_player_damage(
				remote_player, &"torso", 99, Vector2(900, 610), "projectile"
			)
	if _effects_spawned and _scenario_time >= 8.0:
		var snapshot_count := int(_main.get("_enemy_snapshot_sequence"))
		var passed: bool = snapshot_count >= 120 and int(_main.get("_next_enemy_effect_id")) >= 3
		var body_state: Variant = _motion_enemy.get_part_health_state().get("body", []) \
			if is_instance_valid(_motion_enemy) else []
		print("PVE E2E SERVER RESULT snapshots=%d effects=%d passed=%s body=%s" % [
			snapshot_count, int(_main.get("_next_enemy_effect_id")) - 1, passed, body_state,
		])
		multiplayer.multiplayer_peer = null
		get_tree().quit(0 if passed else 1)


func _spawn_server_scenario_effects() -> void:
	_effects_spawned = true
	var projectile := EnemyProjectile.new()
	projectile.global_position = Vector2(680, 320)
	projectile.direction = Vector2.RIGHT
	projectile.speed = 95.0
	projectile.damage = 3
	projectile.radius = 9.0
	projectile.visual_length = 46.0
	projectile.shape_style = "arrow"
	projectile.visual_color = Color(0.3, 0.82, 1.0)
	projectile.set("_life", 5.5)
	_main.add_child(projectile)

	var hazard := EnemyHazard.new()
	hazard.global_position = Vector2(1520, 615)
	hazard.damage = 2
	hazard.radius = 72.0
	hazard.startup_delay = 1.2
	hazard.lifetime = 5.5
	hazard.visual_color = Color(1.0, 0.2, 0.12, 0.52)
	_main.add_child(hazard)

	var remote_player := _remote_test_player()
	if is_instance_valid(remote_player):
		_main.server_apply_enemy_player_damage(
			remote_player, &"torso", 3, Vector2(900, 610), "projectile"
		)
		_main.server_apply_enemy_player_status(remote_player, "slow", 5.0, 0.55)


func _remote_test_player() -> Player:
	for peer_id in (_main.get("_network_players") as Dictionary):
		if int(peer_id) != 1:
			return _main.get_node_or_null("Player_%d" % int(peer_id)) as Player
	return null


func _update_client() -> void:
	if not _client_connected or not multiplayer.has_multiplayer_peer() \
		or not bool(_main.get("_arena_mode")):
		return
	var enemies: Array = _main.get("_active_enemies")
	var synced_enemy: VariantEnemy
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy is VariantEnemy \
			and (enemy as VariantEnemy).archetype == CustomMap.ENEMY_DUNGEON_MAGE:
			synced_enemy = enemy as VariantEnemy
			break
	if not is_instance_valid(synced_enemy):
		return
	var sequence := int(synced_enemy.get("_network_last_sequence"))
	if sequence >= 12:
		var current_x := synced_enemy.global_position.x
		_minimum_enemy_x = minf(_minimum_enemy_x, current_x)
		_maximum_enemy_x = maxf(_maximum_enemy_x, current_x)
		if not is_nan(_last_enemy_x):
			_maximum_frame_step = maxf(_maximum_frame_step, absf(current_x - _last_enemy_x))
		_last_enemy_x = current_x

	var projectile_seen := false
	var hazard_seen := false
	for effect in get_tree().get_nodes_in_group("enemy_network_effect"):
		if effect is EnemyProjectile and bool(effect.get("_network_proxy")):
			projectile_seen = true
		elif effect is EnemyHazard and bool(effect.get("_network_proxy")):
			hazard_seen = true
	_client_projectile_seen = _client_projectile_seen or projectile_seen
	_client_hazard_seen = _client_hazard_seen or hazard_seen
	_client_damage_number_seen = _client_damage_number_seen \
		or not get_tree().get_nodes_in_group("damage_number").is_empty()
	var local_player := _main.get_node_or_null("Player_%d" % multiplayer.get_unique_id()) as Player
	if not is_instance_valid(local_player):
		return
	if sequence >= 24 and not _client_repositioned:
		_client_repositioned = true
		_client_reposition_time = _elapsed
		local_player.global_position = synced_enemy.global_position + Vector2(-72, 0)
		var state_sequence := int(local_player.get("_network_state_sequence")) + 1
		local_player.set("_network_state_sequence", state_sequence)
		_main.submit_player_network_state(
			local_player.get_multiplayer_authority(), state_sequence,
			local_player.global_position, Vector2.ZERO, 1.0,
			_main.get_estimated_server_msec(), true, true
		)
	if _client_repositioned and not _client_attack_sent \
		and _elapsed - _client_reposition_time >= 0.35:
		_client_attack_sent = true
		local_player.call("_start_attack", 1)
		local_player.call("_begin_active_attack")
		_main.request_enemy_part_damage(
			synced_enemy, &"body", 1, "melee", local_player.global_position
		)
		print("PVE E2E CLIENT ATTACK id=%s player=%s enemy=%s" % [
			synced_enemy.name, local_player.global_position, synced_enemy.global_position,
		])
	if _client_attack_sent and _elapsed - _client_reposition_time >= 0.65 \
		and not local_player.is_dead():
		local_player.global_position = Vector2(420, 610)
	var damage_seen := local_player.get_health() < local_player.max_health
	var status_seen := float(local_player.get("_enemy_slow_timer")) > 0.0
	_client_damage_seen = _client_damage_seen or damage_seen
	_client_status_seen = _client_status_seen or status_seen
	var part_damage_seen := false
	var part_state := synced_enemy.get_part_health_state()
	for values in part_state.values():
		if values is Array and values.size() >= 2 and int(values[0]) < int(values[1]):
			part_damage_seen = true
			break
	_client_part_damage_seen = _client_part_damage_seen or part_damage_seen
	var motion_range := _maximum_enemy_x - _minimum_enemy_x
	var smooth_motion := motion_range > 45.0 and _maximum_frame_step < 42.0
	var fast_snapshots := sequence >= 45
	if _client_projectile_seen and _client_hazard_seen and _client_damage_seen \
		and _client_damage_number_seen and _client_status_seen \
		and _client_part_damage_seen \
		and smooth_motion and fast_snapshots:
		_initial_sync_passed = true
	if local_player.is_dead():
		_client_saw_death = true
	var respawn_seen := _client_saw_death and not local_player.is_dead() \
		and local_player.get_health() == local_player.max_health \
		and local_player.rotation == 0.0
	if _initial_sync_passed and respawn_seen:
		print("PVE E2E CLIENT RESULT seq=%d range=%.1f max_step=%.1f projectile=%s hazard=%s damage=%s numbers=%s status=%s parts=%s respawn=%s" % [
			sequence, motion_range, _maximum_frame_step, _client_projectile_seen,
			_client_hazard_seen, _client_damage_seen, _client_damage_number_seen,
			_client_status_seen,
			_client_part_damage_seen, respawn_seen,
		])
		multiplayer.multiplayer_peer = null
		get_tree().quit(0)
