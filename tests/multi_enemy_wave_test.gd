extends Node


func _ready() -> void:
	var had_original := FileAccess.file_exists(CustomMap.SAVE_PATH)
	var original_text := ""
	if had_original:
		var original_file := FileAccess.open(CustomMap.SAVE_PATH, FileAccess.READ)
		if original_file:
			original_text = original_file.get_as_text()

	var main := $Main
	var custom_map := main.get_node("CustomMap") as CustomMap
	var data := custom_map.default_map_data()
	data["enemy_spawns"] = [
		{"grid": [7, 9], "enemy": CustomMap.ENEMY_HUMAN},
		{"grid": [12, 9], "enemy": CustomMap.ENEMY_DOG},
	]
	custom_map.build_from_data(data, false)
	custom_map.save_to_user()

	main.call("_start_custom_single_player")
	await get_tree().physics_frame
	await get_tree().physics_frame

	var human := main.get_node_or_null("TrainingDummy") as TrainingDummy
	var dog := main.get_node_or_null("DogEnemy") as DogEnemy
	var two_spawned := is_instance_valid(human) and is_instance_valid(dog)
	var active_count_ok: bool = main.get("_active_enemies").size() == 2

	human.take_damage(999, Vector2.ZERO)
	await get_tree().process_frame
	var no_upgrade_after_one: bool = not main.get_node("UI/UpgradePanel").visible
	var one_left: bool = main.get("_active_enemies").size() == 1

	dog.take_damage(999, Vector2.ZERO)
	await get_tree().process_frame
	var upgrade_after_all: bool = main.get_node("UI/UpgradePanel").visible

	_restore_user_map(had_original, original_text)

	print("Multi enemy wave test: spawned=%s active=%s one_left=%s no_early_upgrade=%s final_upgrade=%s" % [
		two_spawned,
		active_count_ok,
		one_left,
		no_upgrade_after_one,
		upgrade_after_all,
	])
	get_tree().quit(0 if two_spawned and active_count_ok and one_left \
		and no_upgrade_after_one and upgrade_after_all else 1)


func _restore_user_map(had_original: bool, original_text: String) -> void:
	if had_original:
		var file := FileAccess.open(CustomMap.SAVE_PATH, FileAccess.WRITE)
		if file:
			file.store_string(original_text)
	else:
		var absolute_path := ProjectSettings.globalize_path(CustomMap.SAVE_PATH)
		if FileAccess.file_exists(CustomMap.SAVE_PATH):
			DirAccess.remove_absolute(absolute_path)
