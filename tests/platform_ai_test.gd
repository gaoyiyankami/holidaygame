extends Node


func _ready() -> void:
	var main_scene := load("res://scenes/main/main.tscn") as PackedScene
	var main := main_scene.instantiate()
	add_child(main)
	await get_tree().process_frame
	main.call("_start_single_arena_mode")
	await get_tree().physics_frame
	var player := main.get_node("Player") as Player
	var enemies: Array = main.get("_active_enemies")
	var enemy := enemies[0] as VariantEnemy
	for index in range(1, enemies.size()):
		(enemies[index] as Node).set_physics_process(false)

	enemy.global_position = Vector2(1600, 625)
	enemy.velocity = Vector2.ZERO
	enemy.set("_state", 1)
	player.global_position = Vector2(1600, 185)
	var jumped_high := false
	var minimum_y := enemy.global_position.y
	for frame in 50:
		await get_tree().physics_frame
		minimum_y = minf(minimum_y, enemy.global_position.y)
		jumped_high = jumped_high or enemy.velocity.y < -680.0
	var upward_path_ok := jumped_high and minimum_y < 500.0

	enemy.global_position = Vector2(1600, 390)
	enemy.velocity = Vector2.ZERO
	enemy.set("_state", 1)
	player.global_position = Vector2(1600, 625)
	for frame in 12:
		await get_tree().physics_frame
	var dropped_through := false
	for frame in 45:
		await get_tree().physics_frame
		var navigator: PlatformChaseAgent = enemy.get("_platform_nav")
		dropped_through = dropped_through or navigator.drop_timer > 0.0 or enemy.global_position.y > 470.0
	var downward_path_ok := dropped_through

	var navigator: PlatformChaseAgent = enemy.get("_platform_nav")
	var navigation_config_ok := navigator.jump_velocity <= -700.0 \
		and navigator.jump_velocity >= -800.0 \
		and enemy.collision_mask & (1 << 5) != 0
	print("Platform AI test: upward=%s downward=%s config=%s" % [
		upward_path_ok, downward_path_ok, navigation_config_ok,
	])
	get_tree().quit(0 if upward_path_ok and downward_path_ok and navigation_config_ok else 1)
