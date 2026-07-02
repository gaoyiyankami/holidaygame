extends Node


func _ready() -> void:
	var scene := load("res://scenes/main/main.tscn") as PackedScene
	var main := scene.instantiate()
	add_child(main)
	await get_tree().process_frame
	main.call("_start_single_arena_mode")
	await get_tree().process_frame
	var enemies: Array = main.get("_active_enemies")
	var platform := main.get_node("ChallengeArenaMap/MiddlePlatform") as StaticBody2D
	var platform_shape := platform.find_children("*", "CollisionShape2D", true, false)[0] as CollisionShape2D
	var one_way_ok: bool = platform.collision_layer == (1 << 5) and platform_shape.one_way_collision
	var first_wave_ok: bool = bool(main.get("_arena_mode")) \
		and enemies.size() == 2 \
		and main.get_node("ChallengeArenaMap").visible
	var player := main.get_node("Player") as Player
	var attack_before_cheat := player.attack_damage
	var health_before_cheat := player.max_health
	var cheat_event := InputEventKey.new()
	cheat_event.keycode = KEY_O
	cheat_event.pressed = true
	main.call("_unhandled_input", cheat_event)
	var spell_keeps_l := false
	for input_event in InputMap.action_get_events("spell"):
		if input_event is InputEventKey and (input_event as InputEventKey).physical_keycode == KEY_L:
			spell_keeps_l = true
	var cheat_ok: bool = player.attack_damage == attack_before_cheat + 1 \
		and player.max_health > health_before_cheat \
		and main.get_node("UI/CheatUpgradeButton").visible and spell_keeps_l
	var wave_ten: Array = main.call("_arena_wave_plan", 10)
	var boss_wave_ok: bool = wave_ten.size() == 1 and str(wave_ten[0]) == CustomMap.ENEMY_ABYSS_HOUND_KING
	var wave_twenty: Array = main.call("_arena_wave_plan", 20)
	var wave_thirty: Array = main.call("_arena_wave_plan", 30)
	boss_wave_ok = boss_wave_ok \
		and wave_twenty == [CustomMap.ENEMY_SKELETON_GENERAL] \
		and wave_thirty == [CustomMap.ENEMY_CRIMSON_WITCH]
	var elite_pool := [
		CustomMap.ENEMY_BLOOD_ARMOR_KNIGHT,
		CustomMap.ENEMY_BLACKFLAME_LANCER,
		CustomMap.ENEMY_ABYSS_EXECUTIONER,
	]
	var wave_fifteen: Array = main.call("_arena_wave_plan", 15)
	var wave_twenty_five: Array = main.call("_arena_wave_plan", 25)
	var elite_waves_ok := wave_fifteen.any(func(type: String) -> bool: return type in elite_pool) \
		and wave_twenty_five.any(func(type: String) -> bool: return type in elite_pool)
	var required_new_types := [
		CustomMap.ENEMY_SKELETON_SHIELD, CustomMap.ENEMY_SKELETON_SPEAR,
		CustomMap.ENEMY_SKELETON_BOMBER, CustomMap.ENEMY_DUNGEON_MAGE,
		CustomMap.ENEMY_SUMMONING_PRIEST, CustomMap.ENEMY_FROST_SLIME,
		CustomMap.ENEMY_LIGHTNING_SLIME, CustomMap.ENEMY_SPLITTING_SLIME,
		CustomMap.ENEMY_SPIKE_VINE, CustomMap.ENEMY_MAN_EATING_FLOWER,
		CustomMap.ENEMY_SHADOW_ASSASSIN, CustomMap.ENEMY_BERSERKER,
		CustomMap.ENEMY_BOMB_GOBLIN, CustomMap.ENEMY_CURSED_DOLL,
		CustomMap.ENEMY_GHOST_MAGE, CustomMap.ENEMY_DUNGEON_TURRET,
		CustomMap.ENEMY_CRYSTAL_DRONE, CustomMap.ENEMY_FIRE_LIZARD,
		CustomMap.ENEMY_HEAVY_HAMMER_GUARD, CustomMap.ENEMY_DUAL_BLADE_HUNTER,
	]
	var late_wave_types: Array = []
	for wave in range(11, 30):
		for enemy_type in main.call("_arena_wave_plan", wave):
			if enemy_type not in late_wave_types:
				late_wave_types.append(enemy_type)
	var roster_ok := true
	for enemy_type in required_new_types:
		roster_ok = roster_ok and enemy_type in late_wave_types

	main.call("_apply_arena_wave", 11, main.call("_arena_wave_entries", 11))
	await get_tree().process_frame
	var scaled_enemies: Array = main.get("_active_enemies")
	var scaling_ok := scaled_enemies.size() == 4
	for enemy in scaled_enemies:
		scaling_ok = scaling_ok \
			and is_equal_approx(float(enemy.call("get_health_scale")), 1.6) \
			and is_equal_approx(float(enemy.call("get_attack_scale")), 1.35)

	main.call("_clear_active_enemies")
	main.set("_wave", 5)
	var torso: BodyPart
	for node in player.get_node("Visual/Parts").get_children():
		if (node as BodyPart).part_id == &"torso":
			torso = node as BodyPart
			break
	var shop_health := torso.health - 1
	torso.health = shop_health
	var upgrades_before_shop := player.get_applied_upgrade_count()
	main.call("_begin_arena_shop", 5)
	var shop_started: bool = bool(main.get("_arena_shop_open")) \
		and main.get_node("UI/UpgradePanel").visible \
		and int(main.get("_arena_gold")) == 85 \
		and torso.health == shop_health
	var gold_before_purchase := int(main.get("_arena_gold"))
	main.call("_choose_upgrade", 0)
	var shop_purchase_ok := int(main.get("_arena_gold")) < gold_before_purchase \
		and player.get_applied_upgrade_count() == upgrades_before_shop + 1
	main.call("_resume_arena_after_shop", 6)
	var shop_resume_ok := not bool(main.get("_arena_shop_open")) \
		and int(main.get("_wave")) == 6 \
		and not (main.get("_active_enemies") as Array).is_empty()
	var shop_ok: bool = shop_started and shop_purchase_ok and shop_resume_ok

	main.call("_apply_arena_wave", 13, [{
		"position": Vector2(1200, 610),
		"enemy": CustomMap.ENEMY_SUMMONING_PRIEST,
	}])
	await get_tree().process_frame
	var priest: Node = main.get("_active_enemies")[0]
	priest.set("_special_timer", 0.0)
	priest.call("_summon_priest_minion")
	var summon_registered: bool = main.get("_active_enemies").size() == 2
	priest.call("take_damage", 999, Vector2.ZERO)
	await get_tree().process_frame
	var summon_cleanup_ok: bool = summon_registered and main.get("_active_enemies").is_empty()
	print("Arena mode test: first_wave=%s bosses=%s elites=%s roster=%s scaling=%s shop=%s summon_cleanup=%s cheat=%s one_way=%s" % [first_wave_ok, boss_wave_ok, elite_waves_ok, roster_ok, scaling_ok, shop_ok, summon_cleanup_ok, cheat_ok, one_way_ok])
	get_tree().quit(0 if first_wave_ok and boss_wave_ok and elite_waves_ok and roster_ok \
		and scaling_ok and shop_ok and summon_cleanup_ok and cheat_ok and one_way_ok else 1)
