extends SceneTree

const TYPES := [
	"skeleton_spear", "skeleton_bomber", "dungeon_mage",
	"frost_slime", "heavy_hammer_guard", "dual_blade_hunter",
]
const PROJECTILE_STYLES := ["arrow", "orb", "skull", "laser", "shard", "flame", "needle", "poison"]


func _initialize() -> void:
	var stage := Node2D.new()
	root.add_child(stage)
	current_scene = stage
	var background := Polygon2D.new()
	background.polygon = PackedVector2Array([Vector2.ZERO, Vector2(1280, 0), Vector2(1280, 720), Vector2(0, 720)])
	background.color = Color("171820")
	background.z_index = -20
	stage.add_child(background)
	var enemy_scene := load("res://scenes/enemies/variant_enemy.tscn") as PackedScene
	for type_index in TYPES.size():
		for phase_index in 4:
			var enemy := enemy_scene.instantiate()
			enemy.set("archetype", TYPES[type_index])
			enemy.set("_network_proxy", true)
			enemy.set_physics_process(false)
			stage.add_child(enemy)
			enemy.position = Vector2(66 + phase_index * 92 + (type_index % 3) * 410, 150 + floori(float(type_index) / 3.0) * 235)
			enemy.scale = Vector2(0.84, 0.84)
			if phase_index == 1:
				enemy.set("velocity", Vector2(140.0, 0.0))
				enemy.set("_animation_time", 0.16)
				for iteration in 10:
					enemy.call("_animate_parts")
			elif phase_index > 1:
				enemy.set("_state", 3 if phase_index == 2 else 4)
				var profile: Dictionary = enemy.get("_profile")
				enemy.set("_state_timer", float(profile.get("windup" if phase_index == 2 else "duration", 0.3)) * 0.5)
				for iteration in 10:
					enemy.call("_animate_parts")
			if phase_index == 2:
				var parts := enemy.get_node("Visual/Parts").get_children()
				if not parts.is_empty():
					(parts[0] as BodyPart).receive_damage(2, enemy.global_position - Vector2(40, 0), "projectile")
	var projectile_script := load("res://scripts/combat/enemy_projectile.gd")
	for index in PROJECTILE_STYLES.size():
		var projectile: Node = projectile_script.new()
		projectile.shape_style = PROJECTILE_STYLES[index]
		projectile.speed = 0.0
		projectile.radius = 12.0
		projectile.visual_length = 44.0
		projectile.visual_color = Color.from_hsv(float(index) / PROJECTILE_STYLES.size(), 0.72, 1.0)
		stage.add_child(projectile)
		projectile.position = Vector2(130 + index * 145, 650)
	var bolt_scene := load("res://scenes/combat/magic_bolt.tscn") as PackedScene
	for tier in [1, 2]:
		var wave := bolt_scene.instantiate() as MagicBolt
		wave.power_tier = tier
		stage.add_child(wave)
		wave.set_physics_process(false)
		wave.position = Vector2(1030 + (tier - 1) * 165, 560)
	RenderingServer.frame_post_draw.connect(_capture, CONNECT_ONE_SHOT)


func _capture() -> void:
	var image := root.get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("res://tmp_enemy_attack_qa.png"))
	quit()
