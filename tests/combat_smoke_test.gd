extends Node


func _ready() -> void:
	$Main.call("_start_single_player")
	await get_tree().physics_frame
	await get_tree().physics_frame

	var player := $Main/Player as Player
	var enemy := $Main/TrainingDummy as TrainingDummy
	var base_stats_ready := player.get_health() == 50 and player.max_health == 50 \
		and player.attack_damage == 3 and player.get_spell_damage() == 2
	var enemy_start_x := enemy.global_position.x

	await get_tree().create_timer(1.0).timeout
	var enemy_moved := enemy.global_position.x < enemy_start_x - 40.0

	await get_tree().create_timer(3.0).timeout
	var player_was_attacked := player.get_health() < player.max_health
	enemy.take_damage(999, player.global_position)
	await get_tree().create_timer(0.1).timeout

	var upgrade_panel := $Main/UI/UpgradePanel as PanelContainer
	var upgrade_opened := upgrade_panel.visible
	var random_three_choices: bool = $Main.get("_offered_upgrades").size() == 3
	player.apply_upgrade("double_jump")
	player.apply_upgrade("rapid_regeneration")
	$Main.call("_roll_upgrade_choices")
	var double_jump_only_once: bool = not "double_jump" in $Main.get("_offered_upgrades")
	var rapid_regen_only_once: bool = not "rapid_regeneration" in $Main.get("_offered_upgrades")
	var attack_button := $Main/UI/UpgradePanel/Margin/VBox/Choices/AttackButton as Button
	$Main.set("_offered_upgrades", ["attack", "attack_speed", "part_health"])
	attack_button.text = "攻击力\n\n+1 伤害"
	attack_button.pressed.emit()
	await get_tree().create_timer(0.8).timeout

	var attack_upgraded := player.attack_damage == 4
	var next_enemy: TrainingDummy
	for child in $Main.get_children():
		if child is TrainingDummy:
			next_enemy = child
			break
	var next_wave_spawned := is_instance_valid(next_enemy)

	print("Combat smoke test: base=%s moved=%s attacked=%s upgrade=%s choices=%s double_once=%s rapid_once=%s attack_upgraded=%s next_wave=%s" % [
		base_stats_ready,
		enemy_moved,
		player_was_attacked,
		upgrade_opened,
		random_three_choices,
		double_jump_only_once,
		rapid_regen_only_once,
		attack_upgraded,
		next_wave_spawned,
	])

	var passed := base_stats_ready and enemy_moved and player_was_attacked \
		and upgrade_opened and random_three_choices and double_jump_only_once \
		and rapid_regen_only_once \
		and attack_upgraded \
		and next_wave_spawned
	get_tree().quit(0 if passed else 1)
