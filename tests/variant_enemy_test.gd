extends Node

const ENEMY_PROJECTILE_SCRIPT := preload("res://scripts/combat/enemy_projectile.gd")

class SummonTracker:
	extends Node
	var registered: Array[Node] = []

	func register_summoned_enemy(enemy: Node) -> void:
		registered.append(enemy)


const EXPECTED := {
	"crypt_dog": [4, 20],
	"corrupted_dog": [4, 24],
	"pounce_dog": [4, 24],
	"venom_dog": [5, 26],
	"bomber_dog": [5, 18],
	"stone_bug": [3, 28],
	"dive_bat": [3, 16],
	"skeleton": [5, 30],
	"skeleton_archer": [5, 24],
	"fire_slime": [2, 26],
	"abyss_hound_king": [8, 180],
}
const NEW_TYPES := [
	"skeleton_shield", "skeleton_spear", "skeleton_bomber", "dungeon_mage",
	"summoning_priest", "frost_slime", "lightning_slime", "splitting_slime",
	"spike_vine", "man_eating_flower", "shadow_assassin", "berserker",
	"bomb_goblin", "cursed_doll", "ghost_mage", "dungeon_turret",
	"crystal_drone", "fire_lizard", "heavy_hammer_guard", "dual_blade_hunter",
	"skeleton_general", "crimson_witch",
	"blood_armor_knight", "blackflame_lancer", "abyss_executioner",
]
const DOCUMENT_TOTALS := {
	"skeleton_shield": 48, "skeleton_spear": 38, "skeleton_bomber": 32,
	"dungeon_mage": 36, "summoning_priest": 44, "frost_slime": 30,
	"lightning_slime": 34, "splitting_slime": 40, "spike_vine": 35,
	"man_eating_flower": 42, "shadow_assassin": 48, "berserker": 60,
	"bomb_goblin": 36, "cursed_doll": 40, "ghost_mage": 46,
	"dungeon_turret": 50, "crystal_drone": 48, "fire_lizard": 56,
	"heavy_hammer_guard": 90, "dual_blade_hunter": 72,
	"skeleton_general": 320, "crimson_witch": 280,
	"blood_armor_knight": 80, "blackflame_lancer": 85, "abyss_executioner": 120,
}


func _ready() -> void:
	var scene := load("res://scenes/enemies/variant_enemy.tscn") as PackedScene
	var profiles_ok := true
	var effects_ok := true
	var telegraphs_ok := true
	for enemy_type in EXPECTED:
		var enemy: Node = scene.instantiate()
		enemy.set("archetype", enemy_type)
		add_child(enemy)
		var parts: Array[Node] = []
		for child in enemy.get_node("Visual/Parts").get_children():
			parts.append(child)
		var total := 0
		for node in parts:
			total += (node as BodyPart).max_health
		var expected: Array = EXPECTED[enemy_type]
		profiles_ok = profiles_ok and parts.size() == expected[0] and total == expected[1]
		if enemy_type == "pounce_dog":
			var legs := _find_part(parts, &"back_legs")
			var before: float = enemy.call("get_movement_multiplier")
			legs.receive_damage(999, Vector2.ZERO)
			effects_ok = effects_ok and float(enemy.call("get_movement_multiplier")) < before
		if enemy_type == "venom_dog":
			var fangs := _find_part(parts, &"fangs")
			var before_attack: float = enemy.call("get_attack_multiplier")
			fangs.receive_damage(999, Vector2.ZERO)
			effects_ok = effects_ok and float(enemy.call("get_attack_multiplier")) < before_attack
		if enemy_type == "abyss_hound_king":
			var core := _find_part(parts, &"core")
			var core_before := core.health
			core.receive_damage(5, Vector2.ZERO)
			var core_locked := core.health == core_before
			var head := _find_part(parts, &"head")
			head.receive_damage(4, Vector2.ZERO)
			var head_damaged := head.health
			enemy.call("_update_boss_timers", 4.1)
			var regenerates := head.health == head_damaged + 2
			for limb_id in [&"left_front_paw", &"right_front_paw", &"left_hind_leg", &"right_hind_leg"]:
				_find_part(parts, limb_id).receive_damage(999, Vector2.ZERO)
			core.receive_damage(5, Vector2.ZERO)
			var core_unlocked := core.health == core_before - 5
			effects_ok = effects_ok and core_locked and regenerates and core_unlocked
		enemy.queue_free()
	for enemy_type in NEW_TYPES:
		var enemy: Node = scene.instantiate()
		enemy.set("archetype", enemy_type)
		add_child(enemy)
		var parts := enemy.get_node("Visual/Parts").get_children()
		var telegraph := enemy.get_node_or_null("Visual/AttackTelegraph") as Polygon2D
		enemy.call("_change_state", 3)
		telegraphs_ok = telegraphs_ok and is_instance_valid(telegraph) \
			and telegraph.polygon.size() >= 5 and telegraph.visible
		var total_health := 0
		var polygonal_visual := false
		for node in parts:
			total_health += (node as BodyPart).max_health
			polygonal_visual = polygonal_visual \
				or (node as BodyPart).get_visual_polygon().size() > 4 \
				or node.get_child_count() > 3
		profiles_ok = profiles_ok and parts.size() >= 2 \
			and total_health == int(DOCUMENT_TOTALS.get(enemy_type, total_health)) \
			and polygonal_visual
		enemy.queue_free()

	var scaled_enemy: Node = scene.instantiate()
	scaled_enemy.set("archetype", "crypt_dog")
	scaled_enemy.set("health_scale", 2.0)
	scaled_enemy.set("attack_scale", 1.5)
	add_child(scaled_enemy)
	var scaled_total := 0
	for node in scaled_enemy.get_node("Visual/Parts").get_children():
		scaled_total += (node as BodyPart).max_health
	var scaled_profile: Dictionary = scaled_enemy.get("_profile")
	var scaling_ok := scaled_total == 40 and int(scaled_profile.get("damage", 0)) == 3
	scaled_enemy.queue_free()

	var custom_map := CustomMap.new()
	add_child(custom_map)
	var map_data := custom_map.default_map_data()
	var spawns: Array = []
	for index in range(CustomMap.EDITOR_ENEMY_TYPES.size()):
		spawns.append({
			"grid": [1 + index % 22, 7 + floori(float(index) / 22.0)],
			"enemy": CustomMap.EDITOR_ENEMY_TYPES[index],
		})
	map_data["enemy_spawns"] = spawns
	custom_map.build_from_data(map_data, true)
	var loaded_types: Array = []
	for entry in custom_map.get_enemy_spawn_entries():
		loaded_types.append(str(entry["enemy"]))
	var editor_data_ok := loaded_types.size() == CustomMap.EDITOR_ENEMY_TYPES.size()
	for enemy_type in CustomMap.EDITOR_ENEMY_TYPES:
		editor_data_ok = editor_data_ok and enemy_type in loaded_types

	var summon_tracker := SummonTracker.new()
	add_child(summon_tracker)
	var boss: Node = scene.instantiate()
	boss.set("archetype", "abyss_hound_king")
	summon_tracker.add_child(boss)
	boss.call("_summon_boss_dogs")
	boss.call("_summon_boss_dogs")
	boss.call("_summon_boss_dogs")
	boss.call("_summon_boss_dogs")
	var summon_ok := summon_tracker.registered.size() == 3
	summon_tracker.queue_free()

	var behavior_tracker := SummonTracker.new()
	add_child(behavior_tracker)
	var priest: Node = scene.instantiate()
	priest.set("archetype", "summoning_priest")
	behavior_tracker.add_child(priest)
	priest.call("_summon_priest_minion")
	var priest_summon_ok := behavior_tracker.registered.size() == 1
	for enemy in behavior_tracker.registered:
		if is_instance_valid(enemy):
			enemy.queue_free()
	behavior_tracker.registered.clear()
	var splitting_slime: Node = scene.instantiate()
	splitting_slime.set("archetype", "splitting_slime")
	behavior_tracker.add_child(splitting_slime)
	splitting_slime.call("take_damage", 999, Vector2.ZERO)
	var split_ok := behavior_tracker.registered.size() == 2
	for enemy in behavior_tracker.registered:
		if is_instance_valid(enemy):
			enemy.queue_free()
	behavior_tracker.registered.clear()
	var disabled_split_slime: Node = scene.instantiate()
	disabled_split_slime.set("archetype", "splitting_slime")
	behavior_tracker.add_child(disabled_split_slime)
	_find_part(disabled_split_slime.get_node("Visual/Parts").get_children(), &"core").receive_damage(999, Vector2.ZERO)
	disabled_split_slime.call("take_damage", 999, Vector2.ZERO)
	var split_core_ok := behavior_tracker.registered.is_empty()
	var disabled_priest: Node = scene.instantiate()
	disabled_priest.set("archetype", "summoning_priest")
	behavior_tracker.add_child(disabled_priest)
	_find_part(disabled_priest.get_node("Visual/Parts").get_children(), &"weapon").receive_damage(999, Vector2.ZERO)
	disabled_priest.set("_special_timer", 0.0)
	disabled_priest.call("_summon_priest_minion")
	var priest_relic_ok := behavior_tracker.registered.is_empty()
	behavior_tracker.queue_free()
	var special_behavior_ok := priest_summon_ok and split_ok and split_core_ok and priest_relic_ok

	var damage_numbers_ok := not get_tree().get_nodes_in_group("damage_number").is_empty()
	var projectile_shapes_ok := true
	var projectile_signatures := {}
	for style in ["arrow", "orb", "skull", "laser", "shard", "flame", "needle", "poison", "bolt"]:
		var projectile := ENEMY_PROJECTILE_SCRIPT.new()
		projectile.shape_style = style
		projectile.speed = 0.0
		add_child(projectile)
		var visual_root := projectile.get_child(1)
		projectile_shapes_ok = projectile_shapes_ok and visual_root.get_child_count() > 0
		var polygon := (visual_root.get_child(0) as Polygon2D).polygon
		var signature := "%d:%d:%s" % [polygon.size(), visual_root.get_child_count(), str(polygon[0])]
		projectile_signatures[signature] = true
		projectile.queue_free()
	projectile_shapes_ok = projectile_shapes_ok and projectile_signatures.size() >= 8

	var attack_animation_ok := true
	for pose_check in [["skeleton_spear", "weapon"], ["heavy_hammer_guard", "weapon"], ["dungeon_mage", "weapon"]]:
		var animated_enemy: Node = scene.instantiate()
		animated_enemy.set("archetype", pose_check[0])
		add_child(animated_enemy)
		animated_enemy.set("_state", 3)
		var profile: Dictionary = animated_enemy.get("_profile")
		animated_enemy.set("_state_timer", float(profile.get("windup", 0.4)) * 0.5)
		var pose: Dictionary = animated_enemy.call("_attack_part_pose", pose_check[1])
		attack_animation_ok = attack_animation_ok \
			and (pose.get("offset", Vector2.ZERO) as Vector2).length() > 4.0 \
			and absf(float(pose.get("angle", 0.0))) > 0.1
		animated_enemy.queue_free()
	var walking_enemy: Node = scene.instantiate()
	walking_enemy.set("archetype", "blackflame_lancer")
	add_child(walking_enemy)
	walking_enemy.set_physics_process(false)
	walking_enemy.set("_animation_time", 0.16)
	walking_enemy.set("velocity", Vector2(140.0, 0.0))
	var walking_parts := walking_enemy.get_node("Visual/Parts").get_children()
	var walking_leg := _find_part(walking_parts, &"left_leg")
	var walking_weapon := _find_part(walking_parts, &"weapon")
	for iteration in 10:
		walking_enemy.call("_animate_parts")
	var walking_animation_ok := walking_leg.position.distance_to(walking_leg.rest_position) > 1.5 \
		and absf(walking_weapon.rotation - walking_weapon.rest_rotation) > 0.04
	walking_enemy.queue_free()
	await get_tree().create_timer(0.75).timeout
	damage_numbers_ok = damage_numbers_ok and get_tree().get_nodes_in_group("damage_number").is_empty()

	print("Variant enemy test: profiles=%s effects=%s telegraphs=%s editor_types=%s summon=%s special=%s scaling=%s damage_numbers=%s projectile_shapes=%s attack_animation=%s walking_animation=%s" % [profiles_ok, effects_ok, telegraphs_ok, editor_data_ok, summon_ok, special_behavior_ok, scaling_ok, damage_numbers_ok, projectile_shapes_ok, attack_animation_ok, walking_animation_ok])
	get_tree().quit(0 if profiles_ok and effects_ok and editor_data_ok and summon_ok \
		and special_behavior_ok and scaling_ok and damage_numbers_ok \
		and projectile_shapes_ok and attack_animation_ok and walking_animation_ok \
		and telegraphs_ok else 1)


func _find_part(parts: Array[Node], id: StringName) -> BodyPart:
	for node in parts:
		var part := node as BodyPart
		if part.part_id == id:
			return part
	return null
