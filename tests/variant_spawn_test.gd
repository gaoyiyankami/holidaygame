extends Node


func _ready() -> void:
	var had_original := FileAccess.file_exists(CustomMap.SAVE_PATH)
	var original_text := ""
	if had_original:
		var original := FileAccess.open(CustomMap.SAVE_PATH, FileAccess.READ)
		if original:
			original_text = original.get_as_text()

	var main := $Main
	var custom_map := main.get_node("CustomMap") as CustomMap
	var data := custom_map.default_map_data()
	var spawns: Array = []
	for index in range(CustomMap.EDITOR_ENEMY_TYPES.size()):
		spawns.append({
			"grid": [1 + index % 22, 7 + floori(float(index) / 22.0)],
			"enemy": CustomMap.EDITOR_ENEMY_TYPES[index],
		})
	data["enemy_spawns"] = spawns
	custom_map.build_from_data(data, false)
	custom_map.save_to_user()
	main.call("_start_custom_single_player")
	for frame in range(12):
		await get_tree().physics_frame

	var active: Array = main.get("_active_enemies")
	var spawned_types: Array[String] = []
	for enemy in active:
		spawned_types.append(str(enemy.get("archetype")))
	var passed := active.size() == CustomMap.EDITOR_ENEMY_TYPES.size()
	for enemy_type in CustomMap.EDITOR_ENEMY_TYPES:
		passed = passed and enemy_type in spawned_types

	_restore_user_map(had_original, original_text)
	print("Variant spawn test: count=%d all_types=%s" % [active.size(), passed])
	get_tree().quit(0 if passed else 1)


func _restore_user_map(had_original: bool, original_text: String) -> void:
	if had_original:
		var file := FileAccess.open(CustomMap.SAVE_PATH, FileAccess.WRITE)
		if file:
			file.store_string(original_text)
	elif FileAccess.file_exists(CustomMap.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CustomMap.SAVE_PATH))
