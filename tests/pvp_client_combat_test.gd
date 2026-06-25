extends Node


func _ready() -> void:
	await get_tree().physics_frame
	var main := $Main
	main.call("_show_multiplayer_menu")
	main.get_node("UI/NetworkPanel/VBox/PortRow/PortInput").value = 17092
	main.call("_host_game")
	await get_tree().process_frame
	main.call("_spawn_network_player", 2)
	main.call("_spawn_network_player", 3)
	var attacker := main.get_node("Player_2") as Player
	var victim := main.get_node("Player_3") as Player
	attacker.position = Vector2(700, 610)
	victim.position = Vector2(780, 610)
	attacker.get_node("Visual").scale.x = 1.0
	victim.get_node("Visual").scale.x = -1.0

	var victim_state := victim.get_body_state()
	victim_state["torso"] = [1, 14]
	victim.apply_body_state(victim_state, 0)
	victim.set("_invincibility_timer", 0.0)
	var upgrades_before := attacker.get_applied_upgrade_count()
	main.call("_server_resolve_pvp_melee_swing", 2, 1, 0, 1, 1.0)
	await get_tree().process_frame

	var client_hit_client: bool = main.get_pvp_kills(2) == 1
	var offered: Array = main.get("_pending_pvp_upgrade_offers").get(2, [])
	var three_upgrade_choices: bool = offered.size() == 3
	if three_upgrade_choices:
		main.call("_server_choose_pvp_upgrade", 2, offered[0])
	await get_tree().process_frame
	var kill_granted_upgrade: bool = attacker.get_applied_upgrade_count() > upgrades_before
	var victim_respawned: bool = victim.get_health() == victim.max_health
	print("PvP client combat test: hit=%s choices=%s upgrade=%s respawn=%s" % [
		client_hit_client,
		three_upgrade_choices,
		kill_granted_upgrade,
		victim_respawned,
	])
	multiplayer.multiplayer_peer = null
	get_tree().quit(0 if client_hit_client and three_upgrade_choices \
		and kill_granted_upgrade and victim_respawned else 1)
