extends SceneTree

const TYPES := [
	"skeleton_shield", "skeleton_spear", "skeleton_bomber", "dungeon_mage", "summoning_priest",
	"frost_slime", "lightning_slime", "splitting_slime", "spike_vine", "man_eating_flower",
	"shadow_assassin", "berserker", "bomb_goblin", "cursed_doll", "ghost_mage",
	"dungeon_turret", "crystal_drone", "fire_lizard", "heavy_hammer_guard", "dual_blade_hunter",
	"blood_armor_knight", "blackflame_lancer", "abyss_executioner", "skeleton_general", "crimson_witch",
]


func _initialize() -> void:
	_render()


func _render() -> void:
	var stage := Node2D.new()
	root.add_child(stage)
	var background := Polygon2D.new()
	background.polygon = PackedVector2Array([
		Vector2.ZERO, Vector2(1280, 0), Vector2(1280, 720), Vector2(0, 720),
	])
	background.color = Color("171820")
	background.z_index = -20
	stage.add_child(background)
	var scene := load("res://scenes/enemies/variant_enemy.tscn") as PackedScene
	for index in TYPES.size():
		var enemy := scene.instantiate()
		enemy.set("archetype", TYPES[index])
		enemy.set("_network_proxy", true)
		enemy.set_physics_process(false)
		stage.add_child(enemy)
		enemy.position = Vector2(125 + (index % 5) * 255, 105 + floori(float(index) / 5.0) * 142)
		enemy.scale = Vector2(0.78, 0.78) if index < 20 else Vector2(0.56, 0.56)
	RenderingServer.frame_post_draw.connect(_capture, CONNECT_ONE_SHOT)


func _capture() -> void:
	var image := root.get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("res://tmp_enemy_roster.png"))
	quit()
