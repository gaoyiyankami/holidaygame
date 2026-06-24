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
	var world_visible_after_start: bool = main.get_node("Player_1").visible
	print("Network host test: menu=%s port=%s hidden=%s connection_page=%s peer=%s player=%s visible=%s pvp=%s" % [
		menu_visible,
		port_available,
		world_hidden_before_start,
		separate_network_page,
		peer_ready,
		player_ready,
		world_visible_after_start,
		pvp_damage_synced,
	])
	multiplayer.multiplayer_peer = null
	get_tree().quit(0 if menu_visible and port_available and world_hidden_before_start \
		and separate_network_page and peer_ready and player_ready \
		and world_visible_after_start and pvp_damage_synced else 1)
