class_name CustomMap
extends Node2D

const SAVE_PATH := "user://custom_map.json"
const GRID_SIZE := 64.0
const PLATFORM_SIZE := Vector2(128, 32)
const WALL_SIZE := Vector2(64, 64)
const BACKGROUND_SIZE := Vector2(128, 128)
const SOLID_COLLISION_LAYER := 1
const ONE_WAY_PLATFORM_LAYER := 1 << 5
const MAP_GRID_WIDTH := 24
const MAP_GRID_HEIGHT := 18
const EDITOR_WIDTH := int(MAP_GRID_WIDTH * GRID_SIZE)
const EDITOR_HEIGHT := int(MAP_GRID_HEIGHT * GRID_SIZE)
const ENEMY_HUMAN := "human"
const ENEMY_DOG := "dog"
const ENEMY_CRYPT_DOG := "crypt_dog"
const ENEMY_CORRUPTED_DOG := "corrupted_dog"
const ENEMY_POUNCE_DOG := "pounce_dog"
const ENEMY_VENOM_DOG := "venom_dog"
const ENEMY_BOMBER_DOG := "bomber_dog"
const ENEMY_STONE_BUG := "stone_bug"
const ENEMY_DIVE_BAT := "dive_bat"
const ENEMY_SKELETON := "skeleton"
const ENEMY_SKELETON_ARCHER := "skeleton_archer"
const ENEMY_FIRE_SLIME := "fire_slime"
const ENEMY_ABYSS_HOUND_KING := "abyss_hound_king"
const ENEMY_SKELETON_SHIELD := "skeleton_shield"
const ENEMY_SKELETON_SPEAR := "skeleton_spear"
const ENEMY_SKELETON_BOMBER := "skeleton_bomber"
const ENEMY_DUNGEON_MAGE := "dungeon_mage"
const ENEMY_SUMMONING_PRIEST := "summoning_priest"
const ENEMY_FROST_SLIME := "frost_slime"
const ENEMY_LIGHTNING_SLIME := "lightning_slime"
const ENEMY_SPLITTING_SLIME := "splitting_slime"
const ENEMY_SPIKE_VINE := "spike_vine"
const ENEMY_MAN_EATING_FLOWER := "man_eating_flower"
const ENEMY_SHADOW_ASSASSIN := "shadow_assassin"
const ENEMY_BERSERKER := "berserker"
const ENEMY_BOMB_GOBLIN := "bomb_goblin"
const ENEMY_CURSED_DOLL := "cursed_doll"
const ENEMY_GHOST_MAGE := "ghost_mage"
const ENEMY_DUNGEON_TURRET := "dungeon_turret"
const ENEMY_CRYSTAL_DRONE := "crystal_drone"
const ENEMY_FIRE_LIZARD := "fire_lizard"
const ENEMY_HEAVY_HAMMER_GUARD := "heavy_hammer_guard"
const ENEMY_DUAL_BLADE_HUNTER := "dual_blade_hunter"
const ENEMY_SKELETON_GENERAL := "skeleton_general"
const ENEMY_CRIMSON_WITCH := "crimson_witch"
const ENEMY_BLOOD_ARMOR_KNIGHT := "blood_armor_knight"
const ENEMY_BLACKFLAME_LANCER := "blackflame_lancer"
const ENEMY_ABYSS_EXECUTIONER := "abyss_executioner"
const EDITOR_ENEMY_TYPES := [
	ENEMY_CRYPT_DOG,
	ENEMY_CORRUPTED_DOG,
	ENEMY_POUNCE_DOG,
	ENEMY_VENOM_DOG,
	ENEMY_BOMBER_DOG,
	ENEMY_STONE_BUG,
	ENEMY_DIVE_BAT,
	ENEMY_SKELETON,
	ENEMY_SKELETON_ARCHER,
	ENEMY_FIRE_SLIME,
	ENEMY_ABYSS_HOUND_KING,
	ENEMY_SKELETON_SHIELD,
	ENEMY_SKELETON_SPEAR,
	ENEMY_SKELETON_BOMBER,
	ENEMY_DUNGEON_MAGE,
	ENEMY_SUMMONING_PRIEST,
	ENEMY_FROST_SLIME,
	ENEMY_LIGHTNING_SLIME,
	ENEMY_SPLITTING_SLIME,
	ENEMY_SPIKE_VINE,
	ENEMY_MAN_EATING_FLOWER,
	ENEMY_SHADOW_ASSASSIN,
	ENEMY_BERSERKER,
	ENEMY_BOMB_GOBLIN,
	ENEMY_CURSED_DOLL,
	ENEMY_GHOST_MAGE,
	ENEMY_DUNGEON_TURRET,
	ENEMY_CRYSTAL_DRONE,
	ENEMY_FIRE_LIZARD,
	ENEMY_HEAVY_HAMMER_GUARD,
	ENEMY_DUAL_BLADE_HUNTER,
	ENEMY_SKELETON_GENERAL,
	ENEMY_CRIMSON_WITCH,
	ENEMY_BLOOD_ARMOR_KNIGHT,
	ENEMY_BLACKFLAME_LANCER,
	ENEMY_ABYSS_EXECUTIONER,
]
const ENEMY_NAMES := {
	ENEMY_HUMAN: "旧人形怪",
	ENEMY_DOG: "旧犬类怪",
	ENEMY_CRYPT_DOG: "地穴犬",
	ENEMY_CORRUPTED_DOG: "腐化犬",
	ENEMY_POUNCE_DOG: "跳扑犬",
	ENEMY_VENOM_DOG: "毒牙犬",
	ENEMY_BOMBER_DOG: "自爆犬",
	ENEMY_STONE_BUG: "石壳虫",
	ENEMY_DIVE_BAT: "飞扑蝠",
	ENEMY_SKELETON: "骷髅兵",
	ENEMY_SKELETON_ARCHER: "骷髅弓手",
	ENEMY_FIRE_SLIME: "火焰史莱姆",
	ENEMY_ABYSS_HOUND_KING: "深渊猎犬王（Boss）",
	ENEMY_SKELETON_SHIELD: "骷髅盾兵",
	ENEMY_SKELETON_SPEAR: "骷髅枪兵",
	ENEMY_SKELETON_BOMBER: "骷髅投弹手",
	ENEMY_DUNGEON_MAGE: "地牢法师",
	ENEMY_SUMMONING_PRIEST: "召唤祭司",
	ENEMY_FROST_SLIME: "冰霜史莱姆",
	ENEMY_LIGHTNING_SLIME: "雷电史莱姆",
	ENEMY_SPLITTING_SLIME: "分裂史莱姆",
	ENEMY_SPIKE_VINE: "尖刺藤蔓",
	ENEMY_MAN_EATING_FLOWER: "食人花",
	ENEMY_SHADOW_ASSASSIN: "暗影刺客",
	ENEMY_BERSERKER: "狂战士",
	ENEMY_BOMB_GOBLIN: "炸弹哥布林",
	ENEMY_CURSED_DOLL: "诅咒人偶",
	ENEMY_GHOST_MAGE: "幽魂法师",
	ENEMY_DUNGEON_TURRET: "地牢炮台",
	ENEMY_CRYSTAL_DRONE: "魔晶浮游炮",
	ENEMY_FIRE_LIZARD: "火焰蜥蜴",
	ENEMY_HEAVY_HAMMER_GUARD: "重锤守卫",
	ENEMY_DUAL_BLADE_HUNTER: "双刀猎手",
	ENEMY_SKELETON_GENERAL: "骸骨将军（Boss）",
	ENEMY_CRIMSON_WITCH: "猩红女巫（Boss）",
	ENEMY_BLOOD_ARMOR_KNIGHT: "血甲骑士（精英）",
	ENEMY_BLACKFLAME_LANCER: "黑焰枪骑（精英）",
	ENEMY_ABYSS_EXECUTIONER: "深渊执行者（精英）",
}
const ENEMY_COLORS := {
	ENEMY_CRYPT_DOG: Color("9b795f"),
	ENEMY_CORRUPTED_DOG: Color("a94ec4"),
	ENEMY_POUNCE_DOG: Color("4fc3f7"),
	ENEMY_VENOM_DOG: Color("65d45b"),
	ENEMY_BOMBER_DOG: Color("ff5b45"),
	ENEMY_STONE_BUG: Color("b5a58b"),
	ENEMY_DIVE_BAT: Color("7c71d8"),
	ENEMY_SKELETON: Color("e4dcc5"),
	ENEMY_SKELETON_ARCHER: Color("d8b66b"),
	ENEMY_FIRE_SLIME: Color("ff8a32"),
	ENEMY_ABYSS_HOUND_KING: Color("e2385d"),
	ENEMY_SKELETON_SHIELD: Color("a8b7c8"),
	ENEMY_SKELETON_SPEAR: Color("d5c99d"),
	ENEMY_SKELETON_BOMBER: Color("d28a45"),
	ENEMY_DUNGEON_MAGE: Color("6e78d6"),
	ENEMY_SUMMONING_PRIEST: Color("ad6bd2"),
	ENEMY_FROST_SLIME: Color("65c7e8"),
	ENEMY_LIGHTNING_SLIME: Color("efd34b"),
	ENEMY_SPLITTING_SLIME: Color("70d59a"),
	ENEMY_SPIKE_VINE: Color("4f9c5b"),
	ENEMY_MAN_EATING_FLOWER: Color("d94f72"),
	ENEMY_SHADOW_ASSASSIN: Color("5c4a86"),
	ENEMY_BERSERKER: Color("b6463f"),
	ENEMY_BOMB_GOBLIN: Color("bd7b35"),
	ENEMY_CURSED_DOLL: Color("a97f91"),
	ENEMY_GHOST_MAGE: Color("77a5c9"),
	ENEMY_DUNGEON_TURRET: Color("77828d"),
	ENEMY_CRYSTAL_DRONE: Color("54c7c2"),
	ENEMY_FIRE_LIZARD: Color("db6636"),
	ENEMY_HEAVY_HAMMER_GUARD: Color("8b6d55"),
	ENEMY_DUAL_BLADE_HUNTER: Color("697985"),
	ENEMY_SKELETON_GENERAL: Color("d4c7a1"),
	ENEMY_CRIMSON_WITCH: Color("b31f52"),
	ENEMY_BLOOD_ARMOR_KNIGHT: Color("9d233e"),
	ENEMY_BLACKFLAME_LANCER: Color("6e3aa8"),
	ENEMY_ABYSS_EXECUTIONER: Color("421f55"),
}

const PLATFORM_TEXTURES := [
	"res://assets/maps/generated/platform_0.png",
	"res://assets/maps/generated/platform_1.png",
	"res://assets/maps/generated/platform_2.png",
	"res://assets/maps/generated/platform_3.png",
	"res://assets/maps/generated/platform_4.png",
]
const WALL_TEXTURES := [
	"res://assets/maps/generated/wall_0.png",
	"res://assets/maps/generated/wall_1.png",
	"res://assets/maps/generated/wall_2.png",
]
const BACKGROUND_TEXTURES := [
	"res://assets/maps/generated/background_0.png",
	"res://assets/maps/generated/background_1.png",
	"res://assets/maps/generated/background_2.png",
]
const ENEMY_MARKER_TEXTURE := "res://assets/maps/generated/enemy_spawn_marker.png"

var _map_data: Dictionary = {}
var _module_root: Node2D
var _spawn_root: Node2D
var _editor_mode: bool = false
var _collisions_enabled: bool = true


func _ready() -> void:
	if not is_instance_valid(_module_root):
		_create_roots()
	if _map_data.is_empty():
		build_from_data(default_map_data(), false)


func _draw() -> void:
	if not _editor_mode:
		return
	var grid_color := Color(0.32, 0.68, 0.95, 0.18)
	var major_color := Color(0.32, 0.68, 0.95, 0.32)
	for x in range(0, EDITOR_WIDTH + 1, int(GRID_SIZE)):
		draw_line(Vector2(x, 0), Vector2(x, EDITOR_HEIGHT), major_color if x % 256 == 0 else grid_color, 1.0)
	for y in range(0, EDITOR_HEIGHT + 1, int(GRID_SIZE)):
		draw_line(Vector2(0, y), Vector2(EDITOR_WIDTH, y), major_color if y % 256 == 0 else grid_color, 1.0)
	for spawn in _map_data.get("enemy_spawns", []):
		var enemy_type := _spawn_enemy_type(spawn)
		var world := grid_to_world(_spawn_grid(spawn))
		var color := get_enemy_color(enemy_type)
		var fill := Color(color.r, color.g, color.b, 0.34)
		var line := Color(color.r, color.g, color.b, 0.9)
		draw_circle(world, 13.0, fill)
		draw_arc(world, 17.0, 0.0, TAU, 32, line, 2.0)


func default_map_data() -> Dictionary:
	var modules: Array = []
	for gx in range(0, MAP_GRID_WIDTH, 2):
		modules.append({"kind": "platform", "variant": gx / 2 % PLATFORM_TEXTURES.size(), "grid": [gx, 10]})
	for gx in range(4, 8, 2):
		modules.append({"kind": "platform", "variant": 1, "grid": [gx, 7]})
	for gx in range(12, 16, 2):
		modules.append({"kind": "platform", "variant": 3, "grid": [gx, 6]})
	for gx in range(0, MAP_GRID_WIDTH, 2):
		modules.append({"kind": "background", "variant": (gx / 2) % BACKGROUND_TEXTURES.size(), "grid": [gx, 2]})
	for gx in range(0, MAP_GRID_WIDTH, 2):
		modules.append({"kind": "background", "variant": (gx / 2 + 1) % BACKGROUND_TEXTURES.size(), "grid": [gx, 4]})
	modules.append({"kind": "wall", "variant": 0, "grid": [0, 7]})
	modules.append({"kind": "wall", "variant": 2, "grid": [MAP_GRID_WIDTH - 1, 7]})
	modules.append({"kind": "platform", "variant": 4, "grid": [9, 4]})
	return {
		"version": 1,
		"modules": modules,
		"enemy_spawns": [
			{"grid": [8, 9], "enemy": ENEMY_HUMAN},
			{"grid": [14, 8], "enemy": ENEMY_DOG},
			{"grid": [5, 6], "enemy": ENEMY_HUMAN},
		],
	}


func build_from_data(data: Dictionary, editor_mode: bool = false) -> void:
	_create_roots()
	_clear_children(_module_root)
	_clear_children(_spawn_root)
	_map_data = _sanitize_data(data)
	_editor_mode = editor_mode
	for module in _map_data.get("modules", []):
		_add_module_node(module)
	for spawn in _map_data.get("enemy_spawns", []):
		_add_spawn_marker(_spawn_grid(spawn), _spawn_enemy_type(spawn))
	set_collision_enabled(_collisions_enabled)
	queue_redraw()


func load_from_user_or_default(editor_mode: bool = false) -> bool:
	var loaded_data := default_map_data()
	var loaded_from_file := false
	if FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var parsed = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				loaded_data = parsed
				loaded_from_file = true
	build_from_data(loaded_data, editor_mode)
	return loaded_from_file


func save_to_user() -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		return false
	file.store_string(JSON.stringify(_map_data, "\t"))
	return true


func reset_to_default(editor_mode: bool = true) -> void:
	build_from_data(default_map_data(), editor_mode)


func get_map_data() -> Dictionary:
	return _map_data.duplicate(true)


func set_editor_mode(enabled: bool) -> void:
	_editor_mode = enabled
	for child in _spawn_root.get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = enabled
	queue_redraw()


func set_collision_enabled(enabled: bool) -> void:
	_collisions_enabled = enabled
	if not is_instance_valid(_module_root):
		return
	for node in _module_root.find_children("*", "CollisionShape2D", true, false):
		(node as CollisionShape2D).set_deferred("disabled", not enabled)


func add_module(kind: String, variant: int, grid: Vector2i) -> void:
	if kind not in ["platform", "wall", "background"]:
		return
	grid = get_valid_anchor_grid(kind, grid)
	_remove_overlapping_modules(grid, kind, kind != "background")
	var module := {
		"kind": kind,
		"variant": _clamp_variant(kind, variant),
		"grid": [grid.x, grid.y],
	}
	var modules: Array = _map_data.get("modules", [])
	modules.append(module)
	_map_data["modules"] = modules
	build_from_data(_map_data, _editor_mode)


func add_enemy_spawn(grid: Vector2i, enemy_type: String = ENEMY_HUMAN) -> void:
	grid = _clamp_grid(grid)
	enemy_type = _normalize_enemy_type(enemy_type)
	var spawns: Array = _map_data.get("enemy_spawns", [])
	var kept: Array = []
	for spawn in spawns:
		if _spawn_grid(spawn) != grid:
			kept.append(spawn)
	kept.append({"grid": [grid.x, grid.y], "enemy": enemy_type})
	spawns = kept
	_map_data["enemy_spawns"] = spawns
	build_from_data(_map_data, _editor_mode)


func erase_at(grid: Vector2i, erase_solid_only: bool = false) -> void:
	grid = _clamp_grid(grid)
	var modules: Array = _map_data.get("modules", [])
	var kept: Array = []
	var has_solid_at_grid := false
	if not erase_solid_only:
		for module in modules:
			var module_kind := str(module.get("kind", ""))
			if module_kind != "background" and _module_contains_grid(module, grid):
				has_solid_at_grid = true
				break
	for module in modules:
		var module_kind := str(module.get("kind", ""))
		var erase_module := _module_contains_grid(module, grid) \
			and (module_kind != "background" if erase_solid_only or has_solid_at_grid else true)
		if erase_module:
			continue
		kept.append(module)
	_map_data["modules"] = kept

	var spawns: Array = _map_data.get("enemy_spawns", [])
	var kept_spawns: Array = []
	for spawn in spawns:
		if _spawn_grid(spawn) != grid:
			kept_spawns.append(spawn)
	_map_data["enemy_spawns"] = kept_spawns
	build_from_data(_map_data, _editor_mode)


func world_to_grid(world_position: Vector2) -> Vector2i:
	return _clamp_grid(Vector2i(floori(world_position.x / GRID_SIZE), floori(world_position.y / GRID_SIZE)))


func grid_to_world(grid: Vector2i) -> Vector2:
	return Vector2(float(grid.x) * GRID_SIZE + GRID_SIZE * 0.5, float(grid.y) * GRID_SIZE + GRID_SIZE * 0.5)


func get_module_world_position(kind: String, grid: Vector2i) -> Vector2:
	grid = get_valid_anchor_grid(kind, grid)
	var module_size := get_module_size(kind)
	return Vector2(float(grid.x) * GRID_SIZE, float(grid.y) * GRID_SIZE) + module_size * 0.5


func get_module_size(kind: String) -> Vector2:
	match kind:
		"platform":
			return PLATFORM_SIZE
		"wall":
			return WALL_SIZE
		"background":
			return BACKGROUND_SIZE
	return Vector2(32, 32)


func get_module_footprint(kind: String) -> Vector2i:
	var module_size := get_module_size(kind)
	return Vector2i(
		maxi(1, ceili(module_size.x / GRID_SIZE)),
		maxi(1, ceili(module_size.y / GRID_SIZE))
	)


func get_valid_anchor_grid(kind: String, grid: Vector2i) -> Vector2i:
	var footprint := get_module_footprint(kind)
	var snapped_x := floori(float(grid.x) / float(footprint.x)) * footprint.x
	var snapped_y := floori(float(grid.y) / float(footprint.y)) * footprint.y
	return Vector2i(
		clampi(snapped_x, 0, MAP_GRID_WIDTH - footprint.x),
		clampi(snapped_y, 0, MAP_GRID_HEIGHT - footprint.y)
	)


func get_enemy_spawn_positions() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for spawn in _map_data.get("enemy_spawns", []):
		result.append(grid_to_world(_spawn_grid(spawn)))
	if result.is_empty():
		result.append(Vector2(560, 602))
	return result


func get_enemy_spawn_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for spawn in _map_data.get("enemy_spawns", []):
		var grid := _spawn_grid(spawn)
		result.append({
			"position": grid_to_world(grid),
			"grid": grid,
			"enemy": _spawn_enemy_type(spawn),
		})
	if result.is_empty():
		result.append({
			"position": Vector2(560, 602),
			"grid": Vector2i(8, 9),
			"enemy": ENEMY_HUMAN,
		})
	return result


func get_player_spawn_positions() -> Array[Vector2]:
	var result := get_enemy_spawn_positions()
	if result.size() < 2:
		result.append(Vector2(170, 610))
		result.append(Vector2(1080, 610))
	return result


func get_world_width() -> int:
	var max_x := EDITOR_WIDTH
	for module in _map_data.get("modules", []):
		var kind := str(module.get("kind", "platform"))
		var grid := _array_to_grid(module.get("grid", [0, 0]))
		var module_size := get_module_size(kind)
		max_x = maxi(max_x, int(get_module_world_position(kind, grid).x + module_size.x * 0.5 + 96.0))
	return max_x


func get_world_height() -> int:
	var max_y := EDITOR_HEIGHT
	for module in _map_data.get("modules", []):
		var kind := str(module.get("kind", "platform"))
		var grid := _array_to_grid(module.get("grid", [0, 0]))
		var module_size := get_module_size(kind)
		max_y = maxi(max_y, int(get_module_world_position(kind, grid).y + module_size.y * 0.5 + 96.0))
	return max_y


func _create_roots() -> void:
	if not is_instance_valid(_module_root):
		_module_root = Node2D.new()
		_module_root.name = "Modules"
		add_child(_module_root)
	if not is_instance_valid(_spawn_root):
		_spawn_root = Node2D.new()
		_spawn_root.name = "EnemySpawns"
		add_child(_spawn_root)


func _clear_children(root: Node) -> void:
	for child in root.get_children():
		root.remove_child(child)
		child.queue_free()


func _add_module_node(module: Dictionary) -> void:
	var kind := str(module.get("kind", "platform"))
	var variant := _clamp_variant(kind, int(module.get("variant", 0)))
	var grid := _array_to_grid(module.get("grid", [0, 0]))
	var texture := _texture_for(kind, variant)
	if texture == null:
		return

	if kind == "background":
		var sprite := Sprite2D.new()
		sprite.name = "Background_%d_%d" % [grid.x, grid.y]
		sprite.texture = texture
		sprite.position = get_module_world_position(kind, grid)
		sprite.scale = _texture_scale_for(kind, texture)
		sprite.z_index = -30
		sprite.modulate = Color(0.78, 0.82, 0.92, 0.82)
		_module_root.add_child(sprite)
		return

	var body := StaticBody2D.new()
	body.name = "%s_%d_%d" % [kind.capitalize(), grid.x, grid.y]
	body.position = get_module_world_position(kind, grid)
	body.collision_layer = ONE_WAY_PLATFORM_LAYER if kind == "platform" else SOLID_COLLISION_LAYER
	body.collision_mask = 0
	body.set_meta("grid", grid)
	body.set_meta("kind", kind)

	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = PLATFORM_SIZE if kind == "platform" else WALL_SIZE
	shape.shape = rectangle
	shape.one_way_collision = kind == "platform"
	shape.one_way_collision_margin = 10.0 if kind == "platform" else 1.0
	body.add_child(shape)

	var sprite := Sprite2D.new()
	sprite.name = "Visual"
	sprite.texture = texture
	sprite.scale = _texture_scale_for(kind, texture)
	sprite.z_index = -3 if kind == "platform" else -6
	body.add_child(sprite)

	_module_root.add_child(body)


func _add_spawn_marker(grid: Vector2i, enemy_type: String = ENEMY_HUMAN) -> void:
	var marker := Sprite2D.new()
	marker.name = "EnemySpawn_%s_%d_%d" % [enemy_type, grid.x, grid.y]
	marker.texture = load(ENEMY_MARKER_TEXTURE)
	marker.position = grid_to_world(grid) + Vector2(0, -18)
	marker.z_index = 10
	marker.modulate = get_enemy_color(enemy_type)
	marker.visible = _editor_mode
	_spawn_root.add_child(marker)
	var label := Label.new()
	label.name = "TypeLabel"
	label.text = get_enemy_name(enemy_type)
	label.position = marker.position + Vector2(-36, -30)
	label.z_index = 11
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", marker.modulate)
	label.visible = _editor_mode
	_spawn_root.add_child(label)


func _texture_for(kind: String, variant: int) -> Texture2D:
	var path := ""
	match kind:
		"platform":
			path = PLATFORM_TEXTURES[clampi(variant, 0, PLATFORM_TEXTURES.size() - 1)]
		"wall":
			path = WALL_TEXTURES[clampi(variant, 0, WALL_TEXTURES.size() - 1)]
		"background":
			path = BACKGROUND_TEXTURES[clampi(variant, 0, BACKGROUND_TEXTURES.size() - 1)]
		_:
			return null
	return load(path) as Texture2D


func _texture_scale_for(kind: String, texture: Texture2D) -> Vector2:
	if texture == null:
		return Vector2.ONE
	var size := texture.get_size()
	if size.x <= 0.0 or size.y <= 0.0:
		return Vector2.ONE
	var target := get_module_size(kind)
	return Vector2(target.x / size.x, target.y / size.y)


func _sanitize_data(data: Dictionary) -> Dictionary:
	var modules: Array = []
	for raw_module in data.get("modules", []):
		if not (raw_module is Dictionary):
			continue
		var kind := str(raw_module.get("kind", "platform"))
		if kind not in ["platform", "wall", "background"]:
			continue
		var grid := get_valid_anchor_grid(kind, _array_to_grid(raw_module.get("grid", [0, 0])))
		modules.append({
			"kind": kind,
			"variant": _clamp_variant(kind, int(raw_module.get("variant", 0))),
			"grid": [grid.x, grid.y],
		})

	var spawns: Array = []
	for raw_spawn in data.get("enemy_spawns", []):
		var grid := _clamp_grid(_spawn_grid(raw_spawn))
		var enemy_type := _spawn_enemy_type(raw_spawn)
		var entry := {"grid": [grid.x, grid.y], "enemy": enemy_type}
		if not _has_spawn_at(spawns, grid):
			spawns.append(entry)
	if spawns.is_empty():
		spawns.append({"grid": [8, 9], "enemy": ENEMY_HUMAN})

	return {
		"version": 1,
		"modules": modules,
		"enemy_spawns": spawns,
	}


func _remove_overlapping_modules(anchor_grid: Vector2i, kind: String, solid_only: bool) -> void:
	var modules: Array = _map_data.get("modules", [])
	var kept: Array = []
	var footprint := get_module_footprint(kind)
	var new_rect := Rect2i(anchor_grid, footprint)
	for module in modules:
		var module_kind := str(module.get("kind", ""))
		if solid_only and module_kind == "background":
			kept.append(module)
			continue
		if not solid_only and module_kind != kind:
			kept.append(module)
			continue
		var module_grid := _array_to_grid(module.get("grid", [0, 0]))
		var module_rect := Rect2i(module_grid, get_module_footprint(module_kind))
		if module_rect.intersects(new_rect):
			continue
		kept.append(module)
	_map_data["modules"] = kept


func _module_contains_grid(module: Dictionary, grid: Vector2i) -> bool:
	var kind := str(module.get("kind", ""))
	var module_grid := _array_to_grid(module.get("grid", [0, 0]))
	var rect := Rect2i(module_grid, get_module_footprint(kind))
	return rect.has_point(grid)


func _array_to_grid(value) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(roundi(value.x), roundi(value.y))
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i.ZERO


func _spawn_grid(spawn) -> Vector2i:
	if spawn is Dictionary:
		return _array_to_grid(spawn.get("grid", [8, 9]))
	return _array_to_grid(spawn)


func _spawn_enemy_type(spawn) -> String:
	if spawn is Dictionary:
		return _normalize_enemy_type(str(spawn.get("enemy", ENEMY_HUMAN)))
	return ENEMY_HUMAN


func _normalize_enemy_type(enemy_type: String) -> String:
	if enemy_type == ENEMY_HUMAN or enemy_type == ENEMY_DOG or enemy_type in EDITOR_ENEMY_TYPES:
		return enemy_type
	return ENEMY_CRYPT_DOG


static func get_enemy_name(enemy_type: String) -> String:
	return str(ENEMY_NAMES.get(enemy_type, "地穴犬"))


static func get_enemy_color(enemy_type: String) -> Color:
	if enemy_type == ENEMY_HUMAN:
		return Color(1.0, 0.9, 0.35, 1.0)
	if enemy_type == ENEMY_DOG:
		return Color(0.45, 1.0, 1.0, 1.0)
	return ENEMY_COLORS.get(enemy_type, Color.WHITE) as Color


func _has_spawn_at(spawns: Array, grid: Vector2i) -> bool:
	for spawn in spawns:
		if _spawn_grid(spawn) == grid:
			return true
	return false


func _clamp_grid(grid: Vector2i) -> Vector2i:
	return Vector2i(
		clampi(grid.x, 0, MAP_GRID_WIDTH - 1),
		clampi(grid.y, 0, MAP_GRID_HEIGHT - 1)
	)


func _clamp_variant(kind: String, variant: int) -> int:
	match kind:
		"platform":
			return clampi(variant, 0, PLATFORM_TEXTURES.size() - 1)
		"wall":
			return clampi(variant, 0, WALL_TEXTURES.size() - 1)
		"background":
			return clampi(variant, 0, BACKGROUND_TEXTURES.size() - 1)
	return 0
