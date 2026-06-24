extends Node


func _ready() -> void:
	$Main.call("_start_single_player")
	await get_tree().physics_frame
	await get_tree().physics_frame

	var player := $Main/Player as Player
	var enemy := $Main/TrainingDummy as TrainingDummy
	var enemy_start_x := enemy.global_position.x

	await get_tree().create_timer(1.0).timeout
	var enemy_moved := enemy.global_position.x < enemy_start_x - 40.0

	await get_tree().create_timer(3.0).timeout
	var player_was_attacked := player.get_health() < player.max_health
	enemy.take_damage(999, player.global_position)
	await get_tree().create_timer(0.1).timeout

	var upgrade_panel := $Main/UI/UpgradePanel as PanelContainer
	var upgrade_opened := upgrade_panel.visible
	var attack_button := $Main/UI/UpgradePanel/Margin/VBox/Choices/AttackButton as Button
	attack_button.pressed.emit()
	await get_tree().create_timer(0.8).timeout

	var attack_upgraded := player.attack_damage == 2
	var next_enemy: TrainingDummy
	for child in $Main.get_children():
		if child is TrainingDummy:
			next_enemy = child
			break
	var next_wave_spawned := is_instance_valid(next_enemy)

	print("Combat smoke test: moved=%s attacked=%s upgrade=%s attack_upgraded=%s next_wave=%s" % [
		enemy_moved,
		player_was_attacked,
		upgrade_opened,
		attack_upgraded,
		next_wave_spawned,
	])

	var passed := enemy_moved and player_was_attacked and upgrade_opened \
		and attack_upgraded and next_wave_spawned
	get_tree().quit(0 if passed else 1)
