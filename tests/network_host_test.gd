extends Node


func _ready() -> void:
	await get_tree().physics_frame
	var main := $Main
	var menu_visible := main.get_node("UI/StartMenu").visible
	var port_available := int(main.get_node("UI/NetworkPanel/VBox/PortRow/PortInput").value) == 7000
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
	print("Network host test: menu=%s port=%s peer=%s player=%s" % [
		menu_visible,
		port_available,
		peer_ready,
		player_ready,
	])
	multiplayer.multiplayer_peer = null
	get_tree().quit(0 if menu_visible and port_available and peer_ready \
		and player_ready and pvp_damage_synced else 1)
