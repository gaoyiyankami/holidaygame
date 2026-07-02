extends Node


func _ready() -> void:
	var settings_path := "user://settings.cfg"
	var absolute_settings_path := ProjectSettings.globalize_path(settings_path)
	var had_settings := FileAccess.file_exists(settings_path)
	var original_settings := FileAccess.get_file_as_bytes(settings_path) if had_settings else PackedByteArray()
	var main_scene := load("res://scenes/main/main.tscn") as PackedScene
	var main := main_scene.instantiate()
	add_child(main)
	await get_tree().process_frame
	var master_slider := main.get_node("UI/SettingsPanel/Margin/VBox/MasterVolumeRow/Slider") as HSlider
	var sfx_slider := main.get_node("UI/SettingsPanel/Margin/VBox/SfxVolumeRow/Slider") as HSlider
	var mute_toggle := main.get_node("UI/SettingsPanel/Margin/VBox/MuteToggle") as CheckButton
	master_slider.value = 72.0
	sfx_slider.value = 64.0
	mute_toggle.button_pressed = true
	main.call("_save_settings")
	var config := ConfigFile.new()
	var settings_ok := config.load(settings_path) == OK \
		and is_equal_approx(float(config.get_value("audio", "master", 0.0)), 72.0) \
		and is_equal_approx(float(config.get_value("audio", "sfx", 0.0)), 64.0) \
		and bool(config.get_value("audio", "muted", false)) \
		and AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Master"))
	if had_settings:
		var restore_file := FileAccess.open(settings_path, FileAccess.WRITE)
		restore_file.store_buffer(original_settings)
	else:
		DirAccess.remove_absolute(absolute_settings_path)
	mute_toggle.button_pressed = false
	SFX.apply_audio_settings(85.0, 85.0, false)

	var player := main.get_node("Player") as Player
	for upgrade in ["fire_build", "frost_build", "lightning_build", "counter_build", "charge_build"]:
		player.apply_upgrade(upgrade)
	var levels := player.get_build_levels()
	var build_levels_ok := levels.values().all(func(level: int) -> bool: return level == 1)

	var enemy_scene := load("res://scenes/enemies/variant_enemy.tscn") as PackedScene
	var enemy_one := enemy_scene.instantiate() as VariantEnemy
	var enemy_two := enemy_scene.instantiate() as VariantEnemy
	enemy_one.archetype = "skeleton_shield"
	enemy_two.archetype = "skeleton"
	main.add_child(enemy_one)
	main.add_child(enemy_two)
	enemy_one.set_physics_process(false)
	enemy_two.set_physics_process(false)
	enemy_one.global_position = player.global_position + Vector2(70, 0)
	enemy_two.global_position = player.global_position + Vector2(130, 0)
	var target_part := _find_part(enemy_one, &"body")
	var shell_part := _find_part(enemy_one, &"shell")
	var second_before := _total_health(enemy_two)
	for index in 3:
		player.call("_trigger_build_effects", target_part, 6)
	var elemental_effects_ok := enemy_one.get_movement_stun_time() > 0.0 \
		and enemy_one.get_children().any(func(child: Node) -> bool: return child.get_script() != null and child.get_script().resource_path.ends_with("damage_over_time.gd")) \
		and _total_health(enemy_two) < second_before \
		and shell_part.get_impact_material() == "metal"
	var counter_before := _total_health(enemy_one) + _total_health(enemy_two)
	player.call("_trigger_counter_attack", enemy_one.global_position, true)
	var counter_ok := _total_health(enemy_one) + _total_health(enemy_two) < counter_before

	player.set("_mana", 100)
	player.set("_spell_cooldown_timer", 0.0)
	var charged_cast := player.cast_charged_spell(1.0)
	var mastery_bolt: MagicBolt
	for node in get_tree().get_nodes_in_group("magic_bolt"):
		if (node as MagicBolt).power_tier == 1:
			mastery_bolt = node as MagicBolt
			break
	var charge_build_ok := charged_cast and player.get_mana() == 25 \
		and is_instance_valid(mastery_bolt) \
		and mastery_bolt.damage == player.get_spell_damage() * 4 \
		and mastery_bolt.fire_level == 1 and mastery_bolt.frost_level == 1 \
		and mastery_bolt.lightning_level == 1

	print("Polish features test: settings=%s build_levels=%s elemental=%s counter=%s charge=%s" % [
		settings_ok, build_levels_ok, elemental_effects_ok, counter_ok, charge_build_ok,
	])
	get_tree().quit(0 if settings_ok and build_levels_ok and elemental_effects_ok and counter_ok and charge_build_ok else 1)


func _find_part(enemy: VariantEnemy, id: StringName) -> BodyPart:
	for node in enemy.get_node("Visual/Parts").get_children():
		var part := node as BodyPart
		if part.part_id == id:
			return part
	return null


func _total_health(enemy: VariantEnemy) -> int:
	var total := 0
	for node in enemy.get_node("Visual/Parts").get_children():
		total += (node as BodyPart).health
	return total
