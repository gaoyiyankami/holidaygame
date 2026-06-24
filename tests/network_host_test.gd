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
	var traps_active := true
	for node in main.get_node("PvPMap").get_children():
		if node is PvPTrap and not (node as Area2D).monitoring:
			traps_active = false
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
	remote_player.receive_network_part_damage.rpc(
		"left_leg",
		1,
		Vector2.ZERO
	)
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
	remote_torso.receive_damage(remote_torso.health - 1, Vector2.ZERO)
	var red_dot := remote_torso.get_status_color().r > remote_torso.get_status_color().g
	remote_player.call("_sync_combat_effect", "attack", 1, 0, 1.0)
	var attack_effect_synced: bool = remote_player.get_node(
		"Visual/SwordPivot/AttackArea/SlashVisual"
	).visible
	var host_player := main.get_node("Player_1") as Player
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
	print("Network host test: menu=%s port=%s hidden=%s page=%s peer=%s player=%s map=%s traps=%s top=%s visible=%s damage=%s green=%s red=%s effect=%s upgrade=%s reset=%s win=%s" % [
		menu_visible,
		port_available,
		world_hidden_before_start,
		separate_network_page,
		peer_ready,
		player_ready,
		pvp_map_ready,
		traps_active,
		body_health_at_top,
		world_visible_after_start,
		pvp_damage_synced,
		green_dot,
		red_dot,
		attack_effect_synced,
		kill_grants_upgrade,
		death_removes_upgrades,
		eight_kills_wins,
	])
	multiplayer.multiplayer_peer = null
	get_tree().quit(0 if menu_visible and port_available and world_hidden_before_start \
		and separate_network_page and peer_ready and player_ready and pvp_map_ready \
		and traps_active and body_health_at_top and world_visible_after_start \
		and pvp_damage_synced and green_dot and red_dot and attack_effect_synced \
		and kill_grants_upgrade and death_removes_upgrades and eight_kills_wins else 1)
