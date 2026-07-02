class_name MapEditor
extends CanvasLayer

signal closed
signal play_requested

const SIDEBAR_WIDTH := 286.0
const SIDEBAR_MARGIN := 14.0
const PREVIEW_ALPHA := 0.45
const PREVIEW_BLOCKED_ALPHA := 0.22
const INVALID_GRID := Vector2i(-9999, -9999)

var _custom_map: CustomMap
var _selected_kind: String = "platform"
var _selected_variant: int = 0
var _selected_enemy_type: String = CustomMap.ENEMY_HUMAN
var _erase_mode: bool = false
var _selected_label: Label
var _status_label: Label
var _sidebar: PanelContainer
var _preview_sprite: Sprite2D
var _ui_built: bool = false
var _panning: bool = false
var _last_mouse_screen: Vector2 = Vector2.ZERO
var _last_applied_grid: Vector2i = INVALID_GRID
var _last_preview_grid: Vector2i = INVALID_GRID


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	set_editor_enabled(false)


func setup(custom_map: CustomMap) -> void:
	_custom_map = custom_map
	_ensure_preview_sprite()
	_update_labels("左键拖动地图视角；鼠标指到格子后按 E 放置，按 D 删除。")


func set_editor_enabled(enabled: bool) -> void:
	visible = enabled
	set_process_input(enabled)
	if is_instance_valid(_custom_map):
		_custom_map.set_editor_mode(enabled)
	_panning = false
	_last_applied_grid = INVALID_GRID
	if is_instance_valid(_preview_sprite):
		_preview_sprite.visible = false


func _input(event: InputEvent) -> void:
	if not visible or not is_instance_valid(_custom_map):
		return
	if event is InputEventMouseMotion:
		var mouse_event := event as InputEventMouseMotion
		_last_mouse_screen = mouse_event.position
		if _panning:
			_custom_map.position += mouse_event.relative
			_update_preview_from_screen(mouse_event.position)
			get_viewport().set_input_as_handled()
			return
		_update_preview_from_screen(mouse_event.position)
	elif event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		var over_sidebar := _screen_over_sidebar(mouse_button.position)
		_last_mouse_screen = mouse_button.position
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if over_sidebar:
				_panning = false
				_last_applied_grid = INVALID_GRID
				return
			_panning = mouse_button.pressed
			_last_applied_grid = INVALID_GRID
			get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo or _screen_over_sidebar(_last_mouse_screen):
			return
		if key_event.keycode == KEY_E:
			_apply_at_screen_position(_last_mouse_screen, false)
			get_viewport().set_input_as_handled()
		elif key_event.keycode == KEY_D:
			_apply_at_screen_position(_last_mouse_screen, true)
			get_viewport().set_input_as_handled()


func _build_ui() -> void:
	if _ui_built:
		return
	_ui_built = true

	var root := Control.new()
	root.name = "MapEditorUI"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(root)

	_sidebar = PanelContainer.new()
	_sidebar.name = "Sidebar"
	_sidebar.anchor_left = 0.0
	_sidebar.anchor_top = 0.0
	_sidebar.anchor_right = 0.0
	_sidebar.anchor_bottom = 1.0
	_sidebar.offset_left = SIDEBAR_MARGIN
	_sidebar.offset_top = SIDEBAR_MARGIN
	_sidebar.offset_right = SIDEBAR_MARGIN + SIDEBAR_WIDTH
	_sidebar.offset_bottom = -SIDEBAR_MARGIN
	_sidebar.mouse_filter = Control.MOUSE_FILTER_STOP
	_sidebar.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(_sidebar)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_sidebar.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "地图编辑器"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)

	_selected_label = Label.new()
	_selected_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_selected_label.custom_minimum_size = Vector2(0, 44)
	_selected_label.add_theme_font_size_override("font_size", 15)
	vbox.add_child(_selected_label)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(0, 70)
	vbox.add_child(_status_label)

	var scroll := ScrollContainer.new()
	scroll.name = "PaletteScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var palette := VBoxContainer.new()
	palette.name = "Palette"
	palette.add_theme_constant_override("separation", 8)
	scroll.add_child(palette)

	_add_section_label(palette, "平台（可从下方跳上）")
	for index in range(5):
		palette.add_child(_palette_button(
			"平台 %d" % (index + 1),
			CustomMap.PLATFORM_TEXTURES[index],
			_select_module.bind("platform", index)
		))
	_add_section_label(palette, "墙壁（有碰撞）")
	for index in range(3):
		palette.add_child(_palette_button(
			"墙壁 %d" % (index + 1),
			CustomMap.WALL_TEXTURES[index],
			_select_module.bind("wall", index)
		))
	_add_section_label(palette, "背景墙（无碰撞）")
	for index in range(3):
		palette.add_child(_palette_button(
			"背景 %d" % (index + 1),
			CustomMap.BACKGROUND_TEXTURES[index],
			_select_module.bind("background", index)
		))
	_add_section_label(palette, "怪物生成点")
	for enemy_type in CustomMap.EDITOR_ENEMY_TYPES:
		var enemy_button := _palette_button(
			"%s生成点" % CustomMap.get_enemy_name(enemy_type),
			CustomMap.ENEMY_MARKER_TEXTURE,
			_select_enemy_spawn.bind(enemy_type)
		)
		enemy_button.modulate = CustomMap.get_enemy_color(enemy_type)
		palette.add_child(enemy_button)
	palette.add_child(_palette_button("橡皮 / 删除", "", _select_eraser))

	var action_row_1 := HBoxContainer.new()
	action_row_1.add_theme_constant_override("separation", 6)
	vbox.add_child(action_row_1)
	action_row_1.add_child(_action_button("保存", _save_pressed))
	action_row_1.add_child(_action_button("读取", _load_pressed))
	action_row_1.add_child(_action_button("默认", _reset_pressed))

	var action_row_2 := VBoxContainer.new()
	action_row_2.add_theme_constant_override("separation", 6)
	vbox.add_child(action_row_2)
	action_row_2.add_child(_wide_action_button("试玩自定义地图", _play_pressed))
	action_row_2.add_child(_wide_action_button("返回主菜单", _close_pressed))

	_update_labels("准备好了。")


func _add_section_label(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.36, 1.0))
	parent.add_child(label)


func _palette_button(text: String, texture_path: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 58)
	button.clip_text = true
	if not texture_path.is_empty():
		button.icon = load(texture_path) as Texture2D
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(callback)
	return button


func _action_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 38)
	button.pressed.connect(callback)
	return button


func _wide_action_button(text: String, callback: Callable) -> Button:
	var button := _action_button(text, callback)
	button.custom_minimum_size = Vector2(0, 44)
	return button


func _select_module(kind: String, variant: int) -> void:
	_selected_kind = kind
	_selected_variant = variant
	_erase_mode = false
	_last_preview_grid = INVALID_GRID
	_update_labels("选择了 %s%d。移动到地图上会先显示半透明预览。" % [_kind_name(kind), variant + 1])
	_refresh_preview_texture()


func _select_enemy_spawn(enemy_type: String = CustomMap.ENEMY_HUMAN) -> void:
	_selected_kind = "enemy_spawn"
	_selected_variant = 0
	_selected_enemy_type = enemy_type
	_erase_mode = false
	_last_preview_grid = INVALID_GRID
	_update_labels("选择了%s生成点。" % CustomMap.get_enemy_name(_selected_enemy_type))
	_refresh_preview_texture()


func _select_eraser() -> void:
	_erase_mode = true
	_last_preview_grid = INVALID_GRID
	if is_instance_valid(_preview_sprite):
		_preview_sprite.visible = false
	_update_labels("删除模式：鼠标指向格子后按 D 删除。")


func _apply_tool(grid: Vector2i) -> void:
	if _erase_mode:
		_custom_map.erase_at(grid)
		_update_labels("已删除格子 %s。" % _grid_text(grid))
		return
	if _selected_kind == "enemy_spawn":
		_custom_map.add_enemy_spawn(grid, _selected_enemy_type)
		var enemy_name := CustomMap.get_enemy_name(_selected_enemy_type)
		_update_labels("已放置%s生成点 %s。" % [enemy_name, _grid_text(grid)])
	else:
		_custom_map.add_module(_selected_kind, _selected_variant, grid)
		_update_labels("已放置 %s%d %s。" % [_kind_name(_selected_kind), _selected_variant + 1, _grid_text(grid)])
	_refresh_preview_texture()
	_update_preview_at_grid(grid)


func _apply_at_screen_position(screen_position: Vector2, force_erase: bool) -> void:
	if _screen_over_sidebar(screen_position):
		return
	var grid := _grid_from_screen(screen_position)
	if not force_erase and not _erase_mode and _selected_kind != "enemy_spawn":
		grid = _custom_map.get_valid_anchor_grid(_selected_kind, grid)
	if grid == _last_applied_grid:
		return
	_last_applied_grid = grid
	if force_erase:
		_custom_map.erase_at(grid)
		_update_labels("已删除格子 %s。" % _grid_text(grid))
	else:
		_apply_tool(grid)


func _update_preview_from_screen(screen_position: Vector2) -> void:
	if _erase_mode or _screen_over_sidebar(screen_position):
		if is_instance_valid(_preview_sprite):
			_preview_sprite.visible = false
		return
	_update_preview_at_grid(_grid_from_screen(screen_position))


func _update_preview_at_grid(grid: Vector2i) -> void:
	_ensure_preview_sprite()
	if not is_instance_valid(_preview_sprite):
		return
	if _selected_kind != "enemy_spawn":
		grid = _custom_map.get_valid_anchor_grid(_selected_kind, grid)
	_last_preview_grid = grid
	_refresh_preview_texture()
	_preview_sprite.position = _custom_map.grid_to_world(grid) + Vector2(0, -18) \
		if _selected_kind == "enemy_spawn" else _custom_map.get_module_world_position(_selected_kind, grid)
	_preview_sprite.modulate = _preview_modulate()
	_preview_sprite.visible = visible and not _erase_mode


func _refresh_preview_texture() -> void:
	_ensure_preview_sprite()
	if not is_instance_valid(_preview_sprite):
		return
	var texture := _selected_texture()
	_preview_sprite.texture = texture
	_preview_sprite.scale = _preview_scale_for(texture)
	_preview_sprite.z_index = 60
	_preview_sprite.centered = true
	_preview_sprite.visible = visible and texture != null and not _erase_mode and _last_preview_grid != INVALID_GRID
	_preview_sprite.modulate = _preview_modulate()


func _preview_modulate() -> Color:
	if _selected_kind == "enemy_spawn":
		var color := CustomMap.get_enemy_color(_selected_enemy_type)
		return Color(color.r, color.g, color.b, PREVIEW_ALPHA)
	if _selected_kind == "background":
		return Color(0.78, 0.82, 0.92, PREVIEW_BLOCKED_ALPHA)
	return Color(1.0, 1.0, 1.0, PREVIEW_ALPHA)


func _selected_texture() -> Texture2D:
	match _selected_kind:
		"platform":
			return load(CustomMap.PLATFORM_TEXTURES[clampi(_selected_variant, 0, CustomMap.PLATFORM_TEXTURES.size() - 1)]) as Texture2D
		"wall":
			return load(CustomMap.WALL_TEXTURES[clampi(_selected_variant, 0, CustomMap.WALL_TEXTURES.size() - 1)]) as Texture2D
		"background":
			return load(CustomMap.BACKGROUND_TEXTURES[clampi(_selected_variant, 0, CustomMap.BACKGROUND_TEXTURES.size() - 1)]) as Texture2D
		"enemy_spawn":
			return load(CustomMap.ENEMY_MARKER_TEXTURE) as Texture2D
	return null


func _preview_scale_for(texture: Texture2D) -> Vector2:
	if texture == null or _selected_kind == "enemy_spawn":
		return Vector2.ONE
	var size := texture.get_size()
	if size.x <= 0.0 or size.y <= 0.0:
		return Vector2.ONE
	var target := _custom_map.get_module_size(_selected_kind)
	return Vector2(target.x / size.x, target.y / size.y)


func _ensure_preview_sprite() -> void:
	if is_instance_valid(_preview_sprite) or not is_instance_valid(_custom_map):
		return
	_preview_sprite = Sprite2D.new()
	_preview_sprite.name = "PlacementPreview"
	_preview_sprite.visible = false
	_preview_sprite.z_index = 60
	_preview_sprite.modulate = Color(1.0, 1.0, 1.0, PREVIEW_ALPHA)
	_custom_map.add_child(_preview_sprite)


func _grid_from_screen(screen_position: Vector2) -> Vector2i:
	var world_position := get_viewport().get_canvas_transform().affine_inverse() * screen_position
	return _custom_map.world_to_grid(_custom_map.to_local(world_position))


func _screen_over_sidebar(screen_position: Vector2) -> bool:
	return is_instance_valid(_sidebar) and _sidebar.get_global_rect().has_point(screen_position)


func _save_pressed() -> void:
	if is_instance_valid(_custom_map) and _custom_map.save_to_user():
		_update_labels("已保存到本机自定义地图。")
	else:
		_update_labels("保存失败。")


func _load_pressed() -> void:
	if is_instance_valid(_custom_map):
		var loaded := _custom_map.load_from_user_or_default(true)
		_ensure_preview_sprite()
		_update_labels("已读取保存地图。" if loaded else "没有保存文件，已载入默认模板。")


func _reset_pressed() -> void:
	if is_instance_valid(_custom_map):
		_custom_map.reset_to_default(true)
		_ensure_preview_sprite()
		_update_labels("已恢复默认模板。")


func _play_pressed() -> void:
	if is_instance_valid(_custom_map):
		_custom_map.save_to_user()
	play_requested.emit()


func _close_pressed() -> void:
	closed.emit()


func _update_labels(status: String = "") -> void:
	if is_instance_valid(_selected_label):
		var selected := "橡皮 / 删除" if _erase_mode else (
			("%s生成点" % CustomMap.get_enemy_name(_selected_enemy_type)) if _selected_kind == "enemy_spawn" else "%s%d" % [_kind_name(_selected_kind), _selected_variant + 1]
		)
		_selected_label.text = "当前：%s\nE 放置，D 删除，左键拖动视角" % selected
	if is_instance_valid(_status_label) and not status.is_empty():
		_status_label.text = status


func _kind_name(kind: String) -> String:
	match kind:
		"platform":
			return "平台"
		"wall":
			return "墙"
		"background":
			return "背景"
	return "模块"


func _grid_text(grid: Vector2i) -> String:
	return "(%d, %d)" % [grid.x, grid.y]
