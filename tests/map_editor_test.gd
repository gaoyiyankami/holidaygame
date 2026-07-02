extends Node


func _ready() -> void:
	var had_original := FileAccess.file_exists(CustomMap.SAVE_PATH)
	var original_text := ""
	if had_original:
		var original_file := FileAccess.open(CustomMap.SAVE_PATH, FileAccess.READ)
		if original_file:
			original_text = original_file.get_as_text()

	var main := $Main
	main.call("_open_map_editor")
	await get_tree().process_frame

	var custom_map := main.get_node("CustomMap") as CustomMap
	var map_editor := main.get_node("MapEditor") as MapEditor
	var editor_visible := map_editor.visible and custom_map.visible
	var sidebar_visible: bool = map_editor.get_node("MapEditorUI/Sidebar").visible
	var texture_count_ok := CustomMap.PLATFORM_TEXTURES.size() >= 5 \
		and CustomMap.WALL_TEXTURES.size() >= 3 \
		and CustomMap.BACKGROUND_TEXTURES.size() >= 3

	custom_map.reset_to_default(true)
	map_editor.call("_select_module", "platform", 3)
	var preview_grid := Vector2i(11, 8)
	var preview_anchor := custom_map.get_valid_anchor_grid("platform", preview_grid)
	var preview_screen := get_viewport().get_canvas_transform() * custom_map.grid_to_world(preview_grid)
	var before_sidebar_data := custom_map.get_map_data()
	var sidebar_click := InputEventMouseButton.new()
	sidebar_click.position = Vector2(40, 40)
	sidebar_click.button_index = MOUSE_BUTTON_LEFT
	sidebar_click.pressed = true
	map_editor.call("_input", sidebar_click)
	var sidebar_does_not_place := custom_map.get_map_data() == before_sidebar_data
	var pan_start := custom_map.position
	var pan_press := InputEventMouseButton.new()
	pan_press.position = Vector2(720, 360)
	pan_press.button_index = MOUSE_BUTTON_LEFT
	pan_press.pressed = true
	map_editor.call("_input", pan_press)
	var pan_motion := InputEventMouseMotion.new()
	pan_motion.position = Vector2(760, 382)
	pan_motion.relative = Vector2(40, 22)
	map_editor.call("_input", pan_motion)
	pan_press.pressed = false
	pan_press.position = pan_motion.position
	map_editor.call("_input", pan_press)
	var left_drag_pans: bool = custom_map.position == pan_start + Vector2(40, 22)
	custom_map.position = Vector2.ZERO
	var motion := InputEventMouseMotion.new()
	motion.position = preview_screen
	map_editor.call("_input", motion)
	var preview := custom_map.get_node_or_null("PlacementPreview") as Sprite2D
	var preview_worked: bool = is_instance_valid(preview) \
		and preview.visible \
		and preview.modulate.a < 0.6 \
		and preview.position.is_equal_approx(custom_map.get_module_world_position("platform", preview_anchor))
	var click := InputEventMouseButton.new()
	click.position = preview_screen
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	map_editor.call("_input", click)
	click.pressed = false
	map_editor.call("_input", click)
	var click_does_not_place: bool = not _has_module(custom_map.get_map_data(), "platform", 3, preview_anchor)
	var place_key := InputEventKey.new()
	place_key.keycode = KEY_E
	place_key.pressed = true
	map_editor.call("_input", place_key)
	var drag_place_worked: bool = _has_module(custom_map.get_map_data(), "platform", 3, preview_anchor)
	var delete_key := InputEventKey.new()
	delete_key.keycode = KEY_D
	delete_key.pressed = true
	map_editor.call("_input", delete_key)
	var footprint_erase_worked: bool = not _has_module(custom_map.get_map_data(), "platform", 3, preview_anchor)

	custom_map.add_module("platform", 4, Vector2i(6, 8))
	custom_map.add_module("wall", 2, Vector2i(1, 7))
	custom_map.add_module("background", 1, Vector2i(3, 4))
	custom_map.add_enemy_spawn(Vector2i(10, 9), CustomMap.ENEMY_DOG)
	var saved := custom_map.save_to_user()
	custom_map.reset_to_default(true)
	var loaded := custom_map.load_from_user_or_default(true)
	var data := custom_map.get_map_data()

	var platform_saved := _has_module(data, "platform", 4, custom_map.get_valid_anchor_grid("platform", Vector2i(6, 8)))
	var wall_saved := _has_module(data, "wall", 2, custom_map.get_valid_anchor_grid("wall", Vector2i(1, 7)))
	var background_saved := _has_module(data, "background", 1, custom_map.get_valid_anchor_grid("background", Vector2i(3, 4)))
	var enemy_spawn_saved := _has_spawn(data, Vector2i(10, 9), CustomMap.ENEMY_DOG)

	var dog_spawn_map := custom_map.default_map_data()
	dog_spawn_map["enemy_spawns"] = [{"grid": [10, 9], "enemy": CustomMap.ENEMY_DOG}]
	custom_map.build_from_data(dog_spawn_map, true)
	custom_map.save_to_user()
	main.call("_start_custom_single_player")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var enemy := main.get_node_or_null("DogEnemy") as DogEnemy
	var custom_game_running: bool = custom_map.visible \
		and not main.get_node("HallMap").visible \
		and not main.get_node("PvPMap").visible \
		and is_instance_valid(enemy)

	_restore_user_map(had_original, original_text)

	print("Map editor test: editor=%s sidebar=%s sidebar_safe=%s pan=%s preview=%s click_safe=%s key_place=%s key_delete=%s textures=%s save=%s load=%s platform=%s wall=%s background=%s dog_spawn=%s game=%s" % [
		editor_visible,
		sidebar_visible,
		sidebar_does_not_place,
		left_drag_pans,
		preview_worked,
		click_does_not_place,
		drag_place_worked,
		footprint_erase_worked,
		texture_count_ok,
		saved,
		loaded,
		platform_saved,
		wall_saved,
		background_saved,
		enemy_spawn_saved,
		custom_game_running,
	])

	var passed: bool = editor_visible and sidebar_visible and sidebar_does_not_place \
		and left_drag_pans and preview_worked and click_does_not_place \
		and drag_place_worked and footprint_erase_worked \
		and texture_count_ok and saved and loaded \
		and platform_saved and wall_saved and background_saved \
		and enemy_spawn_saved and custom_game_running
	get_tree().quit(0 if passed else 1)


func _has_module(data: Dictionary, kind: String, variant: int, grid: Vector2i) -> bool:
	for module in data.get("modules", []):
		if str(module.get("kind", "")) == kind \
			and int(module.get("variant", -1)) == variant \
			and _array_to_grid(module.get("grid", [])) == grid:
			return true
	return false


func _has_spawn(data: Dictionary, grid: Vector2i, enemy_type: String) -> bool:
	for spawn in data.get("enemy_spawns", []):
		if _spawn_grid(spawn) == grid and _spawn_enemy_type(spawn) == enemy_type:
			return true
	return false


func _array_to_grid(value) -> Vector2i:
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i.ZERO


func _spawn_grid(value) -> Vector2i:
	if value is Dictionary:
		return _array_to_grid(value.get("grid", []))
	return _array_to_grid(value)


func _spawn_enemy_type(value) -> String:
	if value is Dictionary:
		return str(value.get("enemy", CustomMap.ENEMY_HUMAN))
	return CustomMap.ENEMY_HUMAN


func _restore_user_map(had_original: bool, original_text: String) -> void:
	if had_original:
		var file := FileAccess.open(CustomMap.SAVE_PATH, FileAccess.WRITE)
		if file:
			file.store_string(original_text)
	else:
		var absolute_path := ProjectSettings.globalize_path(CustomMap.SAVE_PATH)
		if FileAccess.file_exists(CustomMap.SAVE_PATH):
			DirAccess.remove_absolute(absolute_path)
