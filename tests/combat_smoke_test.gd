extends Node


func _ready() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame

	var player := $Main/Player as Player
	var enemy := $Main/TrainingDummy as TrainingDummy
	var enemy_start_x := enemy.global_position.x

	await get_tree().create_timer(1.0).timeout
	var enemy_moved := enemy.global_position.x < enemy_start_x - 40.0

	await get_tree().create_timer(3.0).timeout
	var player_was_attacked := player.get_health() < player.max_health

	print("Combat smoke test: moved=%s attacked=%s enemy_x=%.1f player_hp=%d" % [
		enemy_moved,
		player_was_attacked,
		enemy.global_position.x,
		player.get_health(),
	])
	print("Enemy diagnostics: physics=%s state=%s target=%s velocity=%s" % [
		enemy.is_physics_processing(),
		enemy.get("_state"),
		is_instance_valid(enemy.get("_target")),
		enemy.velocity,
	])
	print("Player group diagnostics: member=%s count=%d" % [
		player.is_in_group("player"),
		get_tree().get_nodes_in_group("player").size(),
	])

	get_tree().quit(0 if enemy_moved and player_was_attacked else 1)
