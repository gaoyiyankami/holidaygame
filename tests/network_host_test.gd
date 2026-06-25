extends Node


func _ready() -> void:
	await get_tree().physics_frame
	var main := $Main
	var menu_visible: bool = main.get_node("UI/StartMenu").visible
	var port_available := int(main.get_node("UI/NetworkPanel/VBox/PortRow/PortInput").value) == 7000
	var world_hidden_before_start: bool = not main.get_node("Player").visible
	main.call("_show_multiplayer_menu")
	var separate_network_page: bool = not main.get_node("UI/StartMenu").visible \
		and main.get_node("UI/NetworkPanel").visible \
		and not main.get_node("Player").visible
	main.call("_host_game")
	await get_tree().process_frame
	var peer_ready := multiplayer.has_multiplayer_peer() and multiplayer.is_server()
	var player_ready := main.has_node("Player_1")
	var pvp_map_ready: bool = main.get_node("PvPMap").visible \
		and not main.get_node("TrainingDummy").visible
	var map_selector_ready: bool = main.get_node(
		"UI/NetworkPanel/VBox/MapRow/MapSelect"
	).item_count == 2
	var arena_is_large: bool = main.get_node("PvPMap/ArenaRightWall").position.x >= 2200.0
	var traps_removed := main.get_node_or_null("PvPMap/LeftSpikes") == null \
		and main.get_node_or_null("PvPMap/RightSpikes") == null
	var body_health_at_top: bool = main.get_node("UI/BodyPartsPanel").position.y <= 10.0
	main.call("_spawn_network_player", 2)
	var remote_player := main.get_node("Player_2") as Player
	var remote_leg: BodyPart
	for node in remote_player.get_node("Visual/Parts").get_children():
		var part := node as BodyPart
		if part.part_id == "left_leg":
			remote_leg = part
			break
	var leg_before := remote_leg.health
	var host_player := main.get_node("Player_1") as Player
	host_player.call("_start_attack", 1)
	host_player.call("_begin_active_attack")
	main.request_pvp_damage(1, 2, "left_leg", 1, "melee")
	await get_tree().process_frame
	var pvp_damage_synced := remote_leg.health == leg_before - 1
	var green_dot := remote_leg.get_status_color().g > remote_leg.get_status_color().r
	var remote_torso: BodyPart
	for node in remote_player.get_node("Visual/Parts").get_children():
		var part := node as BodyPart
		if part.part_id == "torso":
			remote_torso = part
			break
	remote_player.set("_invincibility_timer", 0.0)
	main.request_pvp_damage(1, 2, "torso", remote_torso.health - 1, "spell")
	var red_dot := remote_torso.get_status_color().r > remote_torso.get_status_color().g
	remote_player.set("_invincibility_timer", 0.0)
	main.request_pvp_damage(1, 2, "left_leg", 99, "melee")
	var invalid_damage_rejected := remote_leg.health == leg_before - 1
	var synchronized_state := remote_player.get_body_state()
	synchronized_state["left_arm"] = [0, 4]
	remote_player.apply_body_state(synchronized_state, 1)
	var destroyed_limb_synced := not (
		remote_player.get_node("Visual/Parts").get_child(2) as BodyPart
	).visible
	remote_player.call("_sync_combat_effect", "attack", 1, 0, 1.0)
	await get_tree().create_timer(0.11).timeout
	var attack_effect_synced: bool = remote_player.get_node(
		"Visual/SwordPivot/AttackArea/SlashVisual"
	).visible
	var attack_before := host_player.attack_damage
	main.call("_on_pvp_player_defeated", 2, 1)
	var kill_grants_upgrade := main.get_pvp_kills(1) == 1 \
		and host_player.attack_damage > attack_before
	var death_removes_upgrades := remote_player.attack_damage == 1
	main.set("_pvp_kills", {1: 7, 2: 0})
	main.call("_on_pvp_player_defeated", 2, 1)
	var eight_kills_wins := main.is_pvp_round_ending() \
		and host_player.get_node("KingLabel").visible
	var world_visible_after_start: bool = main.get_node("Player_1").visible
	print("Network host test: menu=%s port=%s hidden=%s page=%s peer=%s player=%s map=%s selector=%s large=%s no_traps=%s top=%s visible=%s damage=%s green=%s red=%s reject=%s limb=%s effect=%s upgrade=%s reset=%s win=%s" % [
		menu_visible,
		port_available,
		world_hidden_before_start,
		separate_network_page,
		peer_ready,
		player_ready,
		pvp_map_ready,
		map_selector_ready,
		arena_is_large,
		traps_removed,
		body_health_at_top,
		world_visible_after_start,
		pvp_damage_synced,
		green_dot,
		red_dot,
		invalid_damage_rejected,
		destroyed_limb_synced,
		attack_effect_synced,
		kill_grants_upgrade,
		death_removes_upgrades,
		eight_kills_wins,
	])
	multiplayer.multiplayer_peer = null
	get_tree().quit(0 if menu_visible and port_available and world_hidden_before_start \
		and separate_network_page and peer_ready and player_ready and pvp_map_ready \
		and map_selector_ready and arena_is_large and traps_removed \
		and body_health_at_top and world_visible_after_start \
		and pvp_damage_synced and green_dot and red_dot and attack_effect_synced \
		and invalid_damage_rejected and destroyed_limb_synced \
		and kill_grants_upgrade and death_removes_upgrades and eight_kills_wins else 1)
