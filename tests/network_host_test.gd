extends Node


func _ready() -> void:
	await get_tree().physics_frame
	var main := $Main
	main.call("_host_game")
	await get_tree().process_frame
	var peer_ready := multiplayer.has_multiplayer_peer() and multiplayer.is_server()
	var player_ready := main.has_node("Player_1")
	print("Network host test: peer=%s player=%s" % [peer_ready, player_ready])
	multiplayer.multiplayer_peer = null
	get_tree().quit(0 if peer_ready and player_ready else 1)
