extends Node


func _ready() -> void:
	await get_tree().physics_frame
	var main := $Main
	var menu_visible: bool = main.get_node("UI/StartMenu").visible
	var port_available := int(main.get_node("UI/NetworkPanel/VBox/PortRow/PortInput").value) == 7000
	var world_hidden_before_start: bool = not main.get_node("Player").visible
	var no_world_on_menu: bool = main.get_node("BackgroundLayer").visible \
		and not main.get_node("HallMap").visible \
		and not main.get_node("PvPMap").visible \
		and main.get_node_or_null("TrainingDummy") == null
	main.call("_show_settings_menu")
	var settings_page_ready: bool = main.get_node("UI/SettingsPanel").visible \
		and not main.get_node("UI/StartMenu").visible \
		and main.get_node("UI/SettingsPanel/Margin/VBox/ResolutionRow/ResolutionSelect").item_count == 2 \
		and main.get_node("UI/SettingsPanel/Margin/VBox/RefreshRow/RefreshSelect").item_count == 3
	main.get_node("UI/SettingsPanel/Margin/VBox/RefreshRow/RefreshSelect").selected = 1
	main.call("_apply_display_settings")
	await get_tree().process_frame
	var refresh_setting_applied := Engine.max_fps == 120
	main.call("_show_start_menu")
	main.call("_show_multiplayer_menu")
	main.get_node("UI/NetworkPanel/VBox/NameInput").text = "测试主机"
	Input.action_press("move_right")
	main.call("_release_text_input")
	var text_input_clears_movement := not Input.is_action_pressed("move_right")
	var separate_network_page: bool = not main.get_node("UI/StartMenu").visible \
		and main.get_node("UI/NetworkPanel").visible \
		and not main.get_node("Player").visible
	main.call("_host_game")
	await get_tree().process_frame
	var peer_ready := multiplayer.has_multiplayer_peer() and multiplayer.is_server()
	var player_ready := main.has_node("Player_1")
	await get_tree().process_frame
	var ping_display_ready: bool = main.get_node("UI/PingLabel").visible \
		and "主机" in main.get_node("UI/PingLabel").text
	var pvp_map_ready: bool = main.get_node("PvPMap").visible \
		and main.get_node_or_null("TrainingDummy") == null
	var map_selector_ready: bool = main.get_node(
		"UI/NetworkPanel/VBox/MapRow/MapSelect"
	).item_count == 4
	var arena_is_large: bool = main.get_node("PvPMap/ArenaRightWall").position.x >= 2200.0
	var hall_hidden_in_arena: bool = not main.get_node("HallMap").visible
	var hall_collisions_disabled := true
	for node in main.get_node("HallMap").find_children("*", "CollisionShape2D", true, false):
		if not (node as CollisionShape2D).disabled:
			hall_collisions_disabled = false
	var arena_collisions_enabled := true
	for node in main.get_node("PvPMap").find_children("*", "CollisionShape2D", true, false):
		if (node as CollisionShape2D).disabled:
			arena_collisions_enabled = false
	main.call("_apply_multiplayer_map", "hall")
	await get_tree().process_frame
	var hall_switch_clean: bool = main.get_node("HallMap").visible \
		and not main.get_node("PvPMap").visible
	for node in main.get_node("HallMap").find_children("*", "CollisionShape2D", true, false):
		hall_switch_clean = hall_switch_clean and not (node as CollisionShape2D).disabled
	for node in main.get_node("PvPMap").find_children("*", "CollisionShape2D", true, false):
		hall_switch_clean = hall_switch_clean and (node as CollisionShape2D).disabled
	main.call("_apply_multiplayer_map", "arena")
	await get_tree().process_frame
	var traps_removed := main.get_node_or_null("PvPMap/LeftSpikes") == null \
		and main.get_node_or_null("PvPMap/RightSpikes") == null
	var body_health_at_top: bool = main.get_node("UI/BodyPartsPanel").position.y <= 10.0
	main.call("_spawn_network_player", 2)
	var remote_player := main.get_node("Player_2") as Player
	var host_player := main.get_node("Player_1") as Player
	main.call("_sync_player_names", {1: "测试主机", 2: "测试玩家"})
	var avatar_image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	avatar_image.fill(Color(0.2, 0.7, 1.0, 1.0))
	var avatar_base64 := Marshalls.raw_to_base64(avatar_image.save_png_to_buffer())
	main.call("_sync_player_avatars", {1: avatar_base64, 2: avatar_base64})
	var names_synced := host_player.get_player_display_name() == "测试主机" \
		and remote_player.get_player_display_name() == "测试玩家"
	var avatars_synced := host_player.get_node("Avatar").texture != null \
		and remote_player.get_node("Avatar").texture != null
	var overhead_health_ready: bool = "50/50" in host_player.get_node("PlayerHealthLabel").text \
		and "50/50" in remote_player.get_node("PlayerHealthLabel").text
	host_player.position = Vector2(500, 610)
	remote_player.position = Vector2(580, 610)
	host_player.get_node("Visual").scale.x = 1.0
	remote_player.get_node("Visual").scale.x = -1.0
	var remote_leg: BodyPart
	for node in remote_player.get_node("Visual/Parts").get_children():
		var part := node as BodyPart
		if part.part_id == "left_leg":
			remote_leg = part
			break
	var leg_before := remote_leg.health
	_set_active_attack(host_player)
	main.request_pvp_damage(1, 2, "left_leg", 1, "melee")
	await get_tree().process_frame
	var leg_after_first_hit := remote_leg.health
	var pvp_damage_synced := leg_after_first_hit < leg_before
	var host_torso: BodyPart
	for node in host_player.get_node("Visual/Parts").get_children():
		var host_part := node as BodyPart
		if host_part.part_id == "torso":
			host_torso = host_part
			break
	host_player.set("_invincibility_timer", 0.0)
	_set_active_attack(remote_player)
	var host_health_before := host_torso.health
	host_player.set("_attack_phase", 0)
	var reverse_damage_applied := host_player.server_apply_part_damage(
		&"torso", 1, remote_player.global_position, 2, "melee"
	)
	var mutual_damage_works := reverse_damage_applied \
		and host_torso.health < host_health_before \
		and remote_leg.health == leg_after_first_hit
	var independent_health_labels: bool = str(host_player.get_health()) in host_player.get_node(
		"PlayerHealthLabel"
	).text and str(remote_player.get_health()) in remote_player.get_node(
		"PlayerHealthLabel"
	).text
	var green_dot := remote_leg.get_status_color().g > remote_leg.get_status_color().r
	var remote_torso: BodyPart
	for node in remote_player.get_node("Visual/Parts").get_children():
		var part := node as BodyPart
		if part.part_id == "torso":
			remote_torso = part
			break
	remote_torso.apply_authoritative_state(1, remote_torso.max_health)
	var red_dot := remote_torso.get_status_color().r > remote_torso.get_status_color().g
	remote_torso.apply_authoritative_state(remote_torso.max_health, remote_torso.max_health)
	remote_player.set("_invincibility_timer", 0.0)
	remote_player.call("_start_block")
	var spell_guard_before := remote_torso.health
	main.request_pvp_damage(1, 2, "torso", host_player.get_spell_damage(), "spell")
	var guarding_blocks_magic := remote_torso.health == spell_guard_before
	remote_player.call("_stop_block", false)
	_set_active_attack(host_player)
	remote_player.call("_start_block")
	main.request_pvp_damage(1, 2, "torso", 1, "melee")
	var perfect_block_combat_lock := host_player.get_movement_stun_time() >= 0.9 \
		and host_player.get_attack_stun_time() >= 0.9
	remote_player.call("_stop_block", false)
	host_player.reset_for_pvp(Vector2(500, 610))
	remote_player.reset_for_pvp(Vector2(580, 610))
	host_player.get_node("Visual").scale.x = 1.0
	remote_player.get_node("Visual").scale.x = -1.0
	host_player.set("_movement_stun_timer", 0.0)
	host_player.set("_attack_stun_timer", 0.0)
	_set_active_attack(host_player)
	_set_active_attack(remote_player)
	var clash_health_before := remote_torso.health
	main.request_pvp_damage(1, 2, "torso", 1, "melee")
	var light_clash_no_stun := remote_torso.health == clash_health_before \
		and host_player.get_attack_stun_time() == 0.0 \
		and remote_player.get_attack_stun_time() == 0.0
	_set_active_attack(host_player, 3)
	remote_player.set("_combo_step", 3)
	remote_player.set("_attack_kind", 0)
	remote_player.set("_attack_phase", 2)
	main.set("_last_clash_time", {})
	main.request_pvp_damage(1, 2, "torso", 1, "melee")
	var heavy_clash_stuns := host_player.get_attack_stun_time() >= 0.4 \
		and remote_player.get_attack_stun_time() >= 0.4
	host_player.set("_attack_stun_timer", 0.0)
	host_player.set("_movement_stun_timer", 0.0)
	remote_player.set("_attack_stun_timer", 0.0)
	remote_player.set("_movement_stun_timer", 0.0)
	_set_active_attack(host_player, 1, Player.AttackKind.LOW)
	remote_player.call("_start_block")
	var low_before_guard := remote_torso.health
	main.request_pvp_damage(1, 2, "torso", 1, "melee")
	var low_ignores_guard := remote_torso.health < low_before_guard
	remote_player.call("_stop_block", false)
	_set_active_attack(host_player, 1, Player.AttackKind.LOW)
	remote_player.set("_attack_kind", 3)
	remote_player.set("_attack_phase", 2)
	main.set("_last_clash_time", {})
	var low_clash_before := remote_torso.health
	main.request_pvp_damage(1, 2, "torso", 1, "melee")
	var low_only_clashes_low := remote_torso.health == low_clash_before
	remote_player.set("_invincibility_timer", 0.0)
	var invalid_damage_before := remote_leg.health
	main.request_pvp_damage(1, 2, "left_leg", 99, "melee")
	var invalid_damage_rejected := remote_leg.health == invalid_damage_before
	var synchronized_state := remote_player.get_body_state()
	synchronized_state["left_arm"] = [0, 4]
	remote_player.apply_body_state(synchronized_state, 1)
	var destroyed_limb_synced := not (
		remote_player.get_node("Visual/Parts").get_child(2) as BodyPart
	).visible
	remote_player.call("_sync_combat_effect", "attack", 1, 0, 1.0)
	await get_tree().create_timer(0.2).timeout
	var attack_effect_synced: bool = remote_player.get_node(
		"Visual/SwordPivot/AttackArea/WhiteSlash"
	).visible
	var upgrades_before := host_player.get_applied_upgrade_count()
	main.call("_on_pvp_player_defeated", 2, 1)
	var upgrade_offer_ready: bool = (main.get("_offered_upgrades") as Array).size() == 3 \
		and main.get_node("UI/UpgradePanel").visible
	if upgrade_offer_ready:
		main.call("_choose_upgrade", 0)
	var kill_grants_upgrade: bool = main.get_pvp_kills(1) == 1 \
		and host_player.get_applied_upgrade_count() > upgrades_before
	var death_removes_upgrades := remote_player.attack_damage == 3
	main.set("_pvp_kills", {1: 7, 2: 0})
	main.call("_on_pvp_player_defeated", 2, 1)
	var eight_kills_wins: bool = main.is_pvp_round_ending() \
		and host_player.get_node("KingLabel").visible
	var world_visible_after_start: bool = main.get_node("Player_1").visible
	print("Network host test: menu=%s clean_menu=%s settings=%s port=%s hidden=%s page=%s peer=%s player=%s ping=%s names=%s overhead=%s mutual=%s map=%s selector=%s large=%s hall_off=%s arena_on=%s no_traps=%s top=%s visible=%s damage=%s green=%s red=%s magic_guard=%s perfect=%s clash=%s reject=%s limb=%s effect=%s upgrade=%s reset=%s win=%s" % [
		menu_visible,
		no_world_on_menu,
		settings_page_ready and refresh_setting_applied,
		port_available,
		world_hidden_before_start,
		separate_network_page,
		peer_ready,
		player_ready,
		ping_display_ready,
		names_synced and avatars_synced and text_input_clears_movement,
		overhead_health_ready and independent_health_labels,
		mutual_damage_works,
		pvp_map_ready,
		map_selector_ready,
		arena_is_large,
		hall_hidden_in_arena and hall_collisions_disabled,
		arena_collisions_enabled,
		traps_removed,
		body_health_at_top,
		world_visible_after_start,
		pvp_damage_synced,
		green_dot,
		red_dot,
		guarding_blocks_magic,
		perfect_block_combat_lock,
		light_clash_no_stun and heavy_clash_stuns \
			and low_ignores_guard and low_only_clashes_low,
		invalid_damage_rejected,
		destroyed_limb_synced,
		attack_effect_synced,
		kill_grants_upgrade,
		death_removes_upgrades,
		eight_kills_wins,
	])
	multiplayer.multiplayer_peer = null
	get_tree().quit(0 if menu_visible and no_world_on_menu \
		and settings_page_ready and refresh_setting_applied \
		and port_available and world_hidden_before_start \
		and separate_network_page and peer_ready and player_ready and pvp_map_ready \
		and ping_display_ready and names_synced and avatars_synced \
		and text_input_clears_movement and overhead_health_ready \
		and mutual_damage_works and independent_health_labels \
		and map_selector_ready and arena_is_large and hall_hidden_in_arena \
		and hall_collisions_disabled and arena_collisions_enabled \
		and hall_switch_clean and traps_removed \
		and body_health_at_top and world_visible_after_start \
		and pvp_damage_synced and green_dot and red_dot and attack_effect_synced \
		and guarding_blocks_magic and perfect_block_combat_lock \
		and light_clash_no_stun and heavy_clash_stuns \
		and low_ignores_guard and low_only_clashes_low \
		and invalid_damage_rejected and destroyed_limb_synced \
		and upgrade_offer_ready and kill_grants_upgrade \
		and death_removes_upgrades and eight_kills_wins else 1)


func _set_active_attack(
	player: Player,
	step: int = 1,
	kind: int = Player.AttackKind.NORMAL
) -> void:
	player.set("_combo_step", step)
	player.set("_attack_kind", kind)
	player.set("_attack_phase", Player.AttackPhase.ACTIVE)
