extends Node2D

const ENEMY_SCENE := preload("res://scenes/enemies/training_dummy.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const MAX_CLIENTS := 7
const PVP_KILLS_TO_WIN := 8
const PVP_SPAWNS := [
	Vector2(150, 610),
	Vector2(2050, 610),
	Vector2(420, 390),
	Vector2(1780, 390),
	Vector2(760, 610),
	Vector2(1440, 610),
	Vector2(850, 250),
	Vector2(1350, 250),
]
const HALL_SPAWNS := [
	Vector2(150, 610),
	Vector2(1130, 610),
	Vector2(300, 450),
	Vector2(900, 360),
	Vector2(480, 610),
	Vector2(800, 610),
	Vector2(360, 610),
	Vector2(980, 610),
]
const MAP_HALL := "hall"
const MAP_ARENA := "arena"

var _wave: int = 1
var _current_enemy: TrainingDummy
var _upgrade_open: bool = false
var _network_players: Dictionary = {}
var _pvp_mode: bool = false
var _pvp_kills: Dictionary = {}
var _pvp_round_ending: bool = false
var _multiplayer_map: String = MAP_ARENA
var _offered_upgrades: Array[String] = []
var _last_clash_time: Dictionary = {}
var _last_melee_swing: Dictionary = {}
var _last_regeneration_time: Dictionary = {}
var _player_names: Dictionary = {}
var _player_avatars: Dictionary = {}
var _selected_avatar_base64: String = ""
var _ping_timer: float = 0.0
const UPGRADE_POOL := [
	{"id": "attack", "title": "攻击力", "detail": "+1 伤害"},
	{"id": "attack_speed", "title": "攻击速度", "detail": "+20% 攻速"},
	{"id": "move_speed", "title": "移动速度", "detail": "+30% 移速"},
	{"id": "double_jump", "title": "二段跳", "detail": "获得空中追加跳跃"},
	{"id": "attack_range", "title": "攻击范围", "detail": "+20% 剑击范围"},
	{"id": "part_health", "title": "肢体强化", "detail": "每个部位生命 +2"},
	{"id": "magic_damage", "title": "魔法强化", "detail": "法术伤害 +1"},
	{"id": "max_mana", "title": "魔力扩容", "detail": "魔法上限 +20"},
	{"id": "mana_regen", "title": "魔力循环", "detail": "回魔速度 +50%"},
	{"id": "dash_cooldown", "title": "疾风步", "detail": "冲刺冷却 -15%"},
	{"id": "rapid_regeneration", "title": "快速再生", "detail": "一次性：回血间隔变为 3 秒"},
]

@onready var _player: Player = $Player
@onready var _enemy_spawn: Marker2D = $EnemySpawn
@onready var _health_label: Label = $UI/HealthPanel/HealthLabel
@onready var _mana_label: Label = $UI/ManaPanel/ManaLabel
@onready var _body_parts_label: Label = $UI/BodyPartsPanel/BodyPartsLabel
@onready var _stats_label: Label = $UI/StatsPanel/StatsLabel
@onready var _wave_label: Label = $UI/WaveLabel
@onready var _status_label: Label = $UI/StatusLabel
@onready var _upgrade_panel: PanelContainer = $UI/UpgradePanel
@onready var _attack_button: Button = $UI/UpgradePanel/Margin/VBox/Choices/AttackButton
@onready var _speed_button: Button = $UI/UpgradePanel/Margin/VBox/Choices/SpeedButton
@onready var _health_button: Button = $UI/UpgradePanel/Margin/VBox/Choices/HealthButton
@onready var _network_panel: PanelContainer = $UI/NetworkPanel
@onready var _address_input: LineEdit = $UI/NetworkPanel/VBox/AddressInput
@onready var _name_input: LineEdit = $UI/NetworkPanel/VBox/NameInput
@onready var _avatar_button: Button = $UI/NetworkPanel/VBox/AvatarRow/AvatarButton
@onready var _avatar_status: Label = $UI/NetworkPanel/VBox/AvatarRow/AvatarStatus
@onready var _avatar_file_dialog: FileDialog = $UI/AvatarFileDialog
@onready var _port_input: SpinBox = $UI/NetworkPanel/VBox/PortRow/PortInput
@onready var _host_button: Button = $UI/NetworkPanel/VBox/Buttons/HostButton
@onready var _join_button: Button = $UI/NetworkPanel/VBox/Buttons/JoinButton
@onready var _network_status: Label = $UI/NetworkPanel/VBox/NetworkStatus
@onready var _start_menu: PanelContainer = $UI/StartMenu
@onready var _single_button: Button = $UI/StartMenu/Margin/VBox/SingleButton
@onready var _multi_button: Button = $UI/StartMenu/Margin/VBox/MultiButton
@onready var _back_button: Button = $UI/NetworkPanel/VBox/BackButton
@onready var _pvp_score_label: Label = $UI/PvPScoreLabel
@onready var _map_select: OptionButton = $UI/NetworkPanel/VBox/MapRow/MapSelect
@onready var _settings_button: Button = $UI/StartMenu/Margin/VBox/SettingsButton
@onready var _settings_panel: PanelContainer = $UI/SettingsPanel
@onready var _resolution_select: OptionButton = $UI/SettingsPanel/Margin/VBox/ResolutionRow/ResolutionSelect
@onready var _refresh_select: OptionButton = $UI/SettingsPanel/Margin/VBox/RefreshRow/RefreshSelect
@onready var _apply_settings_button: Button = $UI/SettingsPanel/Margin/VBox/ApplyButton
@onready var _settings_back_button: Button = $UI/SettingsPanel/Margin/VBox/BackButton
@onready var _ping_label: Label = $UI/PingLabel


func _process(delta: float) -> void:
	if not _pvp_mode or not multiplayer.has_multiplayer_peer():
		return
	_ping_timer -= delta
	if _ping_timer > 0.0:
		return
	_ping_timer = 1.0
	if multiplayer.is_server():
		_ping_label.text = "延迟 0 ms（主机）"
	else:
		_ping_server.rpc_id(1, Time.get_ticks_msec())


func _ready() -> void:
	_player.health_changed.connect(_on_player_health_changed)
	_player.mana_changed.connect(_on_player_mana_changed)
	_player.body_parts_changed.connect(_on_player_body_parts_changed)
	_player.stats_changed.connect(_on_player_stats_changed)
	_player.died.connect(_on_player_died)
	_player.pvp_defeated.connect(_on_pvp_player_defeated)
	_attack_button.pressed.connect(_choose_upgrade.bind(0))
	_speed_button.pressed.connect(_choose_upgrade.bind(1))
	_health_button.pressed.connect(_choose_upgrade.bind(2))
	_single_button.pressed.connect(_start_single_player)
	_multi_button.pressed.connect(_show_multiplayer_menu)
	_settings_button.pressed.connect(_show_settings_menu)
	_apply_settings_button.pressed.connect(_apply_display_settings)
	_settings_back_button.pressed.connect(_show_start_menu)
	_back_button.pressed.connect(_show_start_menu)
	_host_button.pressed.connect(_host_game)
	_join_button.pressed.connect(_join_game)
	_avatar_button.pressed.connect(_avatar_file_dialog.popup_centered)
	_avatar_file_dialog.file_selected.connect(_on_avatar_file_selected)
	_address_input.focus_entered.connect(_on_text_input_focus_entered)
	_address_input.focus_exited.connect(_on_text_input_focus_exited)
	_name_input.focus_entered.connect(_on_text_input_focus_entered)
	_name_input.focus_exited.connect(_on_text_input_focus_exited)
	_address_input.text_submitted.connect(func(_text: String) -> void: _release_text_input())
	_name_input.text_submitted.connect(func(_text: String) -> void: _release_text_input())
	_map_select.add_item("废弃大厅（小型）")
	_map_select.add_item("大型 PvP 竞技场")
	_map_select.selected = 1
	_resolution_select.add_item("1920 × 1080（1080p）")
	_resolution_select.add_item("2560 × 1440（2K）")
	_refresh_select.add_item("60 Hz")
	_refresh_select.add_item("120 Hz")
	_refresh_select.add_item("240 Hz")
	_resolution_select.selected = 0
	_refresh_select.selected = 0
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	_on_player_health_changed(_player.get_health(), _player.max_health)
	_on_player_mana_changed(_player.get_mana(), _player.max_mana)
	_on_player_stats_changed(_player.attack_damage, _player.get_attack_speed_bonus())
	_update_wave_label()

	_player.set_controls_enabled(false)
	_network_panel.visible = false
	_settings_panel.visible = false
	_set_game_active(false)
	_set_pvp_mode(false)
	if _is_dedicated_server():
		_port_input.value = _server_port_from_args()
		call_deferred("_host_game")


func _start_single_player() -> void:
	_set_pvp_mode(false)
	_start_menu.visible = false
	_network_panel.visible = false
	_settings_panel.visible = false
	_set_game_active(true)
	if not is_instance_valid(_current_enemy):
		_spawn_next_enemy()


func _show_multiplayer_menu() -> void:
	_start_menu.visible = false
	_settings_panel.visible = false
	_network_panel.visible = true
	_set_game_active(false)


func _show_start_menu() -> void:
	_network_panel.visible = false
	_settings_panel.visible = false
	_start_menu.visible = true
	_set_game_active(false)


func _show_settings_menu() -> void:
	_start_menu.visible = false
	_network_panel.visible = false
	_settings_panel.visible = true
	_set_game_active(false)


func _apply_display_settings() -> void:
	var resolutions := [Vector2i(1920, 1080), Vector2i(2560, 1440)]
	var refresh_limits := [60, 120, 240]
	var resolution: Vector2i = resolutions[clampi(_resolution_select.selected, 0, 1)]
	var fps_limit: int = refresh_limits[clampi(_refresh_select.selected, 0, 2)]
	var window := get_window()
	window.mode = Window.MODE_WINDOWED
	window.borderless = false
	window.content_scale_size = Vector2i(1280, 720)
	window.size = resolution
	Engine.max_fps = fps_limit
	await get_tree().process_frame
	var actual_size := window.size
	var screen := window.current_screen
	var usable_rect := DisplayServer.screen_get_usable_rect(screen)
	window.position = usable_rect.position + Vector2i(
		maxi((usable_rect.size.x - actual_size.x) / 2, 0),
		maxi((usable_rect.size.y - actual_size.y) / 2, 0)
	)
	var message := "实际窗口：%d × %d，帧率上限 %d" % [
		actual_size.x,
		actual_size.y,
		fps_limit,
	]
	if actual_size != resolution:
		message += "\n系统或编辑器限制了所选分辨率"
	elif OS.has_feature("editor"):
		message += "\n若画面未变化，请关闭 Godot 的“嵌入游戏”"
	$UI/SettingsPanel/Margin/VBox/Status.text = message


func _set_game_active(active: bool) -> void:
	$BackgroundLayer.visible = active
	for child in get_children():
		if child is CanvasItem and child != $UI and child not in [$HallMap, $PvPMap]:
			(child as CanvasItem).visible = active
	if not active:
		$HallMap.visible = false
		$PvPMap.visible = false
	elif _pvp_mode:
		_apply_multiplayer_map(_multiplayer_map)
	else:
		_set_arena_enabled(false)
		_set_hall_enabled(true)
	for node_name in [
		"HelpPanel",
		"HealthPanel",
		"ManaPanel",
		"StatsPanel",
		"BodyPartsPanel",
		"WaveLabel",
		"StatusLabel",
		"UpgradePanel",
	]:
		var hud_node := $UI.get_node_or_null(node_name) as CanvasItem
		if is_instance_valid(hud_node):
			hud_node.visible = active and node_name not in ["StatusLabel", "UpgradePanel"]
	_player.set_controls_enabled(active)
	get_tree().paused = not active


func _selected_port() -> int:
	return int(_port_input.value)


func _host_game() -> void:
	_release_text_input()
	var peer := ENetMultiplayerPeer.new()
	var port := _selected_port()
	var error := peer.create_server(port, MAX_CLIENTS)
	if error != OK:
		_network_status.text = "创建主机失败：%s" % error_string(error)
		return
	multiplayer.multiplayer_peer = peer
	_prepare_existing_player_for_network()
	_player_names[1] = _selected_player_name()
	_player_avatars[1] = _selected_avatar_base64
	_player.set_player_display_name(_player_names[1])
	_player.set_avatar_base64(_selected_avatar_base64)
	_network_players[1] = true
	_pvp_kills[1] = 0
	_network_status.text = "主机已开启，端口 %d（最多 8 人）" % port
	_network_panel.visible = false
	_set_game_active(true)
	_set_pvp_mode(true)
	_multiplayer_map = MAP_HALL if _map_select.selected == 0 else MAP_ARENA
	_apply_multiplayer_map.rpc(_multiplayer_map)
	_host_button.disabled = true
	_join_button.disabled = true


func _join_game() -> void:
	_release_text_input()
	var address := _address_input.text.strip_edges()
	if address.is_empty():
		address = "127.0.0.1"
	var peer := ENetMultiplayerPeer.new()
	var port := _selected_port()
	var error := peer.create_client(address, port)
	if error != OK:
		_network_status.text = "连接失败：%s" % error_string(error)
		return
	multiplayer.multiplayer_peer = peer
	_prepare_existing_player_for_network()
	_network_status.text = "正在连接 %s:%d……" % [address, port]
	_host_button.disabled = true
	_join_button.disabled = true


func _prepare_existing_player_for_network() -> void:
	_player.name = "Player_1"
	_player.configure_network_authority(1)
	_network_players[1] = true


func _on_connected_to_server() -> void:
	_network_status.text = "连接成功，玩家编号 %d" % multiplayer.get_unique_id()
	_network_panel.visible = false
	_set_game_active(true)
	_set_pvp_mode(true)
	_submit_player_name.rpc_id(1, _selected_player_name())
	_submit_player_avatar.rpc_id(1, _selected_avatar_base64)


func _is_dedicated_server() -> bool:
	return "--server" in OS.get_cmdline_args() or "--server" in OS.get_cmdline_user_args()


func _server_port_from_args() -> int:
	for argument in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if argument.begins_with("--port="):
			return clampi(int(argument.trim_prefix("--port=")), 1024, 65535)
	return 7000


func _set_pvp_mode(enabled: bool) -> void:
	_pvp_mode = enabled
	if is_instance_valid(_current_enemy):
		_current_enemy.visible = not enabled
		_current_enemy.set_physics_process(not enabled)
	_wave_label.visible = not enabled
	_pvp_score_label.visible = enabled
	_ping_label.visible = enabled
	for node in get_tree().get_nodes_in_group("player"):
		(node as Player).set_pvp_enabled(enabled)
	if enabled:
		_apply_multiplayer_map(_multiplayer_map)
		_update_pvp_scoreboard()
	else:
		_set_arena_enabled(false)
		_set_hall_enabled(true)
		_room_title("第一战斗房间 · 废弃大厅")


func _room_title(title: String) -> void:
	$RoomTitle.text = title


func _on_connection_failed() -> void:
	_network_status.text = "连接主机失败"
	multiplayer.multiplayer_peer = null
	_host_button.disabled = false
	_join_button.disabled = false


func _on_server_disconnected() -> void:
	_network_status.text = "与主机断开连接"
	multiplayer.multiplayer_peer = null


func _on_peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	for existing_id in _network_players:
		_spawn_network_player.rpc_id(peer_id, existing_id)
	_spawn_network_player.rpc(peer_id)
	_apply_multiplayer_map.rpc_id(peer_id, _multiplayer_map)
	_sync_player_names.rpc_id(peer_id, _player_names)
	_sync_player_avatars.rpc_id(peer_id, _player_avatars)
	for existing_id in _network_players:
		var existing := get_node_or_null("Player_%d" % existing_id) as Player
		if is_instance_valid(existing):
			_sync_body_state.rpc_id(peer_id, existing_id, existing.get_body_state(), 0)


func _on_peer_disconnected(peer_id: int) -> void:
	if multiplayer.is_server():
		_remove_network_player.rpc(peer_id)


@rpc("authority", "call_local", "reliable")
func _spawn_network_player(peer_id: int) -> void:
	if _network_players.has(peer_id):
		return
	var player := PLAYER_SCENE.instantiate() as Player
	player.name = "Player_%d" % peer_id
	player.position = _spawn_for_peer(peer_id)
	add_child(player)
	player.configure_network_authority(peer_id)
	player.set_pvp_enabled(_pvp_mode)
	player.set_player_display_name(str(_player_names.get(peer_id, "玩家 %d" % peer_id)))
	player.set_avatar_base64(str(_player_avatars.get(peer_id, "")))
	player.pvp_defeated.connect(_on_pvp_player_defeated)
	_network_players[peer_id] = true
	_pvp_kills[peer_id] = 0
	if peer_id == multiplayer.get_unique_id():
		_bind_local_player(player)
	_network_status.text = "当前玩家：%d / 8" % _network_players.size()


func _selected_player_name() -> String:
	var chosen := _name_input.text.strip_edges()
	if chosen.is_empty():
		chosen = "玩家"
	return chosen.left(18)


func _on_text_input_focus_entered() -> void:
	_player.set_controls_enabled(false)
	_player.clear_input_state()


func _on_text_input_focus_exited() -> void:
	_player.clear_input_state()


func _release_text_input() -> void:
	_address_input.release_focus()
	_name_input.release_focus()
	_player.clear_input_state()


func _on_avatar_file_selected(path: String) -> void:
	var image := Image.new()
	var load_error := image.load(path)
	if load_error != OK:
		_avatar_status.text = "头像读取失败"
		return
	image.resize(48, 48, Image.INTERPOLATE_LANCZOS)
	var png_bytes := image.save_png_to_buffer()
	var encoded := Marshalls.raw_to_base64(png_bytes)
	if encoded.length() > 24576:
		_avatar_status.text = "头像数据过大"
		return
	_selected_avatar_base64 = encoded
	_avatar_status.text = "头像已选择"


@rpc("any_peer", "call_remote", "reliable")
func _submit_player_name(display_name: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	_player_names[peer_id] = display_name.strip_edges().left(18)
	if str(_player_names[peer_id]).is_empty():
		_player_names[peer_id] = "玩家 %d" % peer_id
	_sync_player_names.rpc(_player_names)


@rpc("authority", "call_local", "reliable")
func _sync_player_names(names: Dictionary) -> void:
	_player_names = names.duplicate()
	for peer_id in _player_names:
		var player := get_node_or_null("Player_%d" % peer_id) as Player
		if is_instance_valid(player):
			player.set_player_display_name(str(_player_names[peer_id]))


@rpc("any_peer", "call_remote", "reliable")
func _submit_player_avatar(encoded_avatar: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	_player_avatars[peer_id] = encoded_avatar if encoded_avatar.length() <= 24576 else ""
	_sync_player_avatars.rpc(_player_avatars)


@rpc("authority", "call_local", "reliable")
func _sync_player_avatars(avatars: Dictionary) -> void:
	_player_avatars = avatars.duplicate()
	for peer_id in _player_avatars:
		var player := get_node_or_null("Player_%d" % peer_id) as Player
		if is_instance_valid(player):
			player.set_avatar_base64(str(_player_avatars[peer_id]))


@rpc("any_peer", "call_remote", "unreliable")
func _ping_server(sent_msec: int) -> void:
	if multiplayer.is_server():
		_ping_reply.rpc_id(multiplayer.get_remote_sender_id(), sent_msec)


@rpc("authority", "call_remote", "unreliable")
func _ping_reply(sent_msec: int) -> void:
	var latency := maxi(Time.get_ticks_msec() - sent_msec, 0)
	_ping_label.text = "延迟 %d ms" % latency
	_ping_label.modulate = Color(0.4, 1.0, 0.5) if latency < 80 \
		else Color(1.0, 0.82, 0.25) if latency < 160 else Color(1.0, 0.3, 0.25)


func request_pvp_damage(
	attacker_peer_id: int,
	victim_peer_id: int,
	part_id: StringName,
	damage: int,
	damage_kind: String
) -> void:
	if not multiplayer.has_multiplayer_peer() or not _pvp_mode:
		return
	if multiplayer.is_server():
		_server_apply_pvp_damage(attacker_peer_id, victim_peer_id, part_id, damage, damage_kind)
	else:
		_request_pvp_damage.rpc_id(1, attacker_peer_id, victim_peer_id, part_id, damage, damage_kind)


func request_pvp_melee_swing(
	attacker_peer_id: int,
	attack_sequence: int,
	attack_kind: int,
	combo_step: int,
	facing: float
) -> void:
	if not multiplayer.has_multiplayer_peer() or not _pvp_mode:
		return
	if multiplayer.is_server():
		_server_resolve_pvp_melee_swing(
			attacker_peer_id, attack_sequence, attack_kind, combo_step, facing
		)
	else:
		_request_pvp_melee_swing.rpc_id(
			1, attacker_peer_id, attack_sequence, attack_kind, combo_step, facing
		)


@rpc("any_peer", "call_remote", "reliable")
func _request_pvp_melee_swing(
	attacker_peer_id: int,
	attack_sequence: int,
	attack_kind: int,
	combo_step: int,
	facing: float
) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != attacker_peer_id:
		return
	_server_resolve_pvp_melee_swing(
		attacker_peer_id, attack_sequence, attack_kind, combo_step, facing
	)


func _server_resolve_pvp_melee_swing(
	attacker_peer_id: int,
	attack_sequence: int,
	attack_kind: int,
	combo_step: int,
	facing: float
) -> void:
	if not _pvp_mode or _pvp_round_ending:
		return
	if attack_kind < Player.AttackKind.NORMAL or attack_kind > Player.AttackKind.LOW:
		return
	if combo_step < 1 or combo_step > 3 or is_zero_approx(facing):
		return
	var previous_sequence := int(_last_melee_swing.get(attacker_peer_id, -1))
	if attack_sequence <= previous_sequence:
		return
	_last_melee_swing[attacker_peer_id] = attack_sequence
	var attacker := get_node_or_null("Player_%d" % attacker_peer_id) as Player
	if not is_instance_valid(attacker):
		return
	attacker.server_confirm_melee_swing(attack_kind, combo_step, facing)
	var reach := 155.0
	var vertical_reach := 92.0
	match attack_kind:
		Player.AttackKind.AIR:
			reach = 170.0
			vertical_reach = 145.0
		Player.AttackKind.DASH:
			reach = 235.0
			vertical_reach = 105.0
		Player.AttackKind.LOW:
			reach = 175.0
			vertical_reach = 105.0
	var direction := signf(facing)
	var damage := attacker.get_melee_damage_for(attack_kind, combo_step)
	for victim_peer_id in _network_players:
		if int(victim_peer_id) == attacker_peer_id:
			continue
		var victim := get_node_or_null("Player_%d" % victim_peer_id) as Player
		if not is_instance_valid(victim):
			continue
		var offset := victim.global_position - attacker.global_position
		var forward_distance := offset.x * direction
		if forward_distance < -24.0 or forward_distance > reach \
			or absf(offset.y) > vertical_reach:
			continue
		var low_attack := attack_kind == Player.AttackKind.LOW
		var hit_position := attacker.global_position + Vector2(
			direction * minf(maxf(forward_distance, 35.0), reach * 0.72),
			30.0 if low_attack else clampf(offset.y, -35.0, 35.0)
		)
		var part_id := victim.get_best_pvp_hit_part(hit_position, low_attack)
		if part_id != &"":
			_server_apply_pvp_damage(
				attacker_peer_id, int(victim_peer_id), part_id, damage, "melee"
			)


func request_player_regeneration(peer_id: int) -> void:
	if multiplayer.is_server():
		_server_regenerate_player(peer_id)
	else:
		_request_player_regeneration.rpc_id(1, peer_id)


@rpc("any_peer", "call_remote", "reliable")
func _request_player_regeneration(peer_id: int) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != peer_id:
		return
	_server_regenerate_player(peer_id)


func _server_regenerate_player(peer_id: int) -> void:
	var player := get_node_or_null("Player_%d" % peer_id) as Player
	if not is_instance_valid(player):
		return
	var now := Time.get_ticks_msec()
	var minimum_interval := player.get_health_regen_interval_msec() - 150
	if now - int(_last_regeneration_time.get(peer_id, -10000)) < minimum_interval:
		return
	_last_regeneration_time[peer_id] = now
	if player.heal_next_body_part():
		_sync_body_state.rpc(peer_id, player.get_body_state(), 0)


func request_magic_bolt_destroy(attacker_peer_id: int, hit_position: Vector2) -> void:
	if multiplayer.is_server():
		_server_destroy_magic_bolt(attacker_peer_id, hit_position)
	else:
		_request_magic_bolt_destroy.rpc_id(1, attacker_peer_id, hit_position)


@rpc("any_peer", "call_remote", "reliable")
func _request_magic_bolt_destroy(attacker_peer_id: int, hit_position: Vector2) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == attacker_peer_id:
		_server_destroy_magic_bolt(attacker_peer_id, hit_position)


func _server_destroy_magic_bolt(attacker_peer_id: int, hit_position: Vector2) -> void:
	var attacker := get_node_or_null("Player_%d" % attacker_peer_id) as Player
	if is_instance_valid(attacker) and attacker.can_destroy_magic_bolt_at(hit_position):
		_destroy_magic_bolt_at.rpc(hit_position)


@rpc("authority", "call_local", "reliable")
func _destroy_magic_bolt_at(hit_position: Vector2) -> void:
	var nearest: MagicBolt
	var nearest_distance := 3600.0
	for node in get_tree().get_nodes_in_group("magic_bolt"):
		var bolt := node as MagicBolt
		var distance := bolt.global_position.distance_squared_to(hit_position)
		if distance < nearest_distance:
			nearest = bolt
			nearest_distance = distance
	if is_instance_valid(nearest):
		nearest.destroy_by_attack()


@rpc("any_peer", "call_remote", "reliable")
func _request_pvp_damage(
	attacker_peer_id: int,
	victim_peer_id: int,
	part_id: StringName,
	damage: int,
	damage_kind: String
) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != attacker_peer_id:
		return
	_server_apply_pvp_damage(attacker_peer_id, victim_peer_id, part_id, damage, damage_kind)


func _server_apply_pvp_damage(
	attacker_peer_id: int,
	victim_peer_id: int,
	part_id: StringName,
	damage: int,
	damage_kind: String
) -> void:
	if not _pvp_mode or _pvp_round_ending or damage <= 0 or damage > 20:
		return
	if damage_kind not in ["melee", "spell"]:
		return
	var attacker := get_node_or_null("Player_%d" % attacker_peer_id) as Player
	var victim := get_node_or_null("Player_%d" % victim_peer_id) as Player
	if not is_instance_valid(attacker) or not is_instance_valid(victim) or attacker == victim:
		return
	if damage_kind == "melee":
		if not attacker.is_network_attack_active():
			return
		damage = attacker.get_network_melee_damage()
		var attacker_kind := attacker.get_network_attack_kind()
		var is_low_attack := attacker_kind == Player.AttackKind.LOW
		if victim.is_perfect_block_active() and not is_low_attack:
			attacker.apply_combat_stun.rpc(1.0)
			_show_combat_message.rpc((attacker.global_position + victim.global_position) * 0.5, "格挡！")
			return
		if victim.is_network_attack_active() \
			and attacker.can_clash_with_player(victim) \
			and attacker.is_facing_position(victim.global_position.x) \
			and victim.is_facing_position(attacker.global_position.x) \
			and _can_trigger_clash(attacker_peer_id, victim_peer_id):
			var hard_clash := attacker.get_attack_step() == 3 and victim.get_attack_step() == 3
			attacker.apply_clash_result.rpc(
				signf(attacker.global_position.x - victim.global_position.x),
				hard_clash
			)
			victim.apply_clash_result.rpc(
				signf(victim.global_position.x - attacker.global_position.x),
				hard_clash
			)
			_show_combat_message.rpc((attacker.global_position + victim.global_position) * 0.5, "拼刀！")
			return
	else:
		if victim.is_guarding():
			_show_combat_message.rpc(victim.global_position + Vector2(0, -70), "魔法免疫")
			return
		damage = attacker.get_spell_damage()
	var allowed_distance := 950.0 if damage_kind == "spell" else 190.0
	if attacker.global_position.distance_to(victim.global_position) > allowed_distance:
		return
	var resolved_kind := "low" if damage_kind == "melee" \
		and attacker.get_network_attack_kind() == Player.AttackKind.LOW else damage_kind
	if victim.server_apply_part_damage(part_id, damage, attacker.global_position, attacker_peer_id, resolved_kind):
		_sync_body_state.rpc(victim_peer_id, victim.get_body_state(), attacker_peer_id)


func _can_trigger_clash(first_peer_id: int, second_peer_id: int) -> bool:
	var low := mini(first_peer_id, second_peer_id)
	var high := maxi(first_peer_id, second_peer_id)
	var key := "%d:%d" % [low, high]
	var now := Time.get_ticks_msec()
	if now - int(_last_clash_time.get(key, -1000)) < 500:
		return false
	_last_clash_time[key] = now
	return true


@rpc("authority", "call_local", "reliable")
func _show_combat_message(world_position: Vector2, message: String) -> void:
	show_local_combat_message(world_position, message)


func show_local_combat_message(world_position: Vector2, message: String) -> void:
	var label := Label.new()
	label.text = message
	label.position = world_position - Vector2(90, 85)
	label.size = Vector2(180, 45)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.22))
	add_child(label)
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 35.0, 0.55)
	tween.tween_property(label, "modulate:a", 0.0, 0.55)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)


@rpc("authority", "call_remote", "reliable")
func _sync_body_state(peer_id: int, state: Dictionary, attacker_peer_id: int) -> void:
	var player := get_node_or_null("Player_%d" % peer_id) as Player
	if is_instance_valid(player):
		player.apply_body_state(state, attacker_peer_id)


@rpc("authority", "call_local", "reliable")
func _apply_multiplayer_map(map_id: String) -> void:
	_multiplayer_map = MAP_HALL if map_id == MAP_HALL else MAP_ARENA
	var arena_enabled := _pvp_mode and _multiplayer_map == MAP_ARENA
	_set_arena_enabled(arena_enabled)
	_set_hall_enabled(not arena_enabled)
	$BackgroundLayer/Background.color = Color(0.11, 0.025, 0.045, 1.0) \
		if arena_enabled else Color(0.055, 0.075, 0.12, 1.0)
	_room_title("大型 PvP 竞技场" if arena_enabled else "PvP · 废弃大厅")
	for node in get_tree().get_nodes_in_group("player"):
		var player := node as Player
		player.set_camera_world_width(2200 if arena_enabled else 1280)


func _set_arena_enabled(enabled: bool) -> void:
	$PvPMap.visible = enabled
	_set_map_collisions($PvPMap, enabled)


func _set_hall_enabled(enabled: bool) -> void:
	$HallMap.visible = enabled
	_set_map_collisions($HallMap, enabled)


func _set_map_collisions(map_root: Node, enabled: bool) -> void:
	for node in map_root.find_children("*", "CollisionShape2D", true, false):
		(node as CollisionShape2D).set_deferred("disabled", not enabled)


@rpc("authority", "call_local", "reliable")
func _remove_network_player(peer_id: int) -> void:
	var player := get_node_or_null("Player_%d" % peer_id)
	if is_instance_valid(player):
		player.queue_free()
	_network_players.erase(peer_id)
	_player_names.erase(peer_id)
	_player_avatars.erase(peer_id)
	_pvp_kills.erase(peer_id)
	_last_melee_swing.erase(peer_id)
	_update_pvp_scoreboard()
	_network_status.text = "当前玩家：%d / 8" % _network_players.size()


func _bind_local_player(player: Player) -> void:
	_player = player
	_player.health_changed.connect(_on_player_health_changed)
	_player.mana_changed.connect(_on_player_mana_changed)
	_player.body_parts_changed.connect(_on_player_body_parts_changed)
	_player.stats_changed.connect(_on_player_stats_changed)
	_player.died.connect(_on_player_died)
	if not _player.pvp_defeated.is_connected(_on_pvp_player_defeated):
		_player.pvp_defeated.connect(_on_pvp_player_defeated)
	_on_player_health_changed(_player.get_health(), _player.max_health)
	_on_player_mana_changed(_player.get_mana(), _player.max_mana)


func _connect_enemy(enemy: TrainingDummy) -> void:
	enemy.defeated.connect(_on_enemy_defeated)


func _on_enemy_defeated() -> void:
	if _upgrade_open:
		return
	_upgrade_open = true
	_player.set_controls_enabled(false)
	_status_label.text = "第 %d 波完成！选择一项强化" % _wave
	_status_label.visible = true
	_upgrade_panel.visible = true
	_roll_upgrade_choices()
	_attack_button.grab_focus()


func _roll_upgrade_choices() -> void:
	var pool := UPGRADE_POOL.duplicate()
	if _player.has_double_jump_upgrade():
		pool = pool.filter(func(choice: Dictionary) -> bool: return choice.id != "double_jump")
	if _player.has_rapid_regeneration():
		pool = pool.filter(func(choice: Dictionary) -> bool: return choice.id != "rapid_regeneration")
	pool.shuffle()
	_offered_upgrades.clear()
	var buttons := [_attack_button, _speed_button, _health_button]
	for index in 3:
		var choice: Dictionary = pool[index]
		_offered_upgrades.append(choice.id)
		buttons[index].text = "%s\n\n%s" % [choice.title, choice.detail]


func _choose_upgrade(index: int) -> void:
	if index < 0 or index >= _offered_upgrades.size():
		return
	var upgrade_id := _offered_upgrades[index]
	var description := ""
	for choice in UPGRADE_POOL:
		if choice.id == upgrade_id:
			description = "%s：%s" % [choice.title, choice.detail]
			break
	_player.apply_upgrade(upgrade_id)
	_finish_upgrade(description)


func _finish_upgrade(message: String) -> void:
	if not _upgrade_open:
		return
	_upgrade_open = false
	_upgrade_panel.visible = false
	_status_label.text = message
	_wave += 1
	_update_wave_label()
	await get_tree().create_timer(0.65).timeout
	_status_label.visible = false
	_spawn_next_enemy()
	_player.set_controls_enabled(true)


func _spawn_next_enemy() -> void:
	var enemy := ENEMY_SCENE.instantiate() as TrainingDummy
	enemy.name = "TrainingDummy"
	enemy.max_health = 5 + _wave
	enemy.move_speed = 105.0 + (_wave - 1) * 7.0
	enemy.attack_cooldown = maxf(0.55, 1.0 - (_wave - 1) * 0.04)
	enemy.position = _enemy_spawn.position
	add_child(enemy)
	_current_enemy = enemy
	_connect_enemy(enemy)


func _on_player_health_changed(current_health: int, max_health: int) -> void:
	_health_label.text = "玩家生命  %d / %d" % [current_health, max_health]


func _on_player_mana_changed(current_mana: int, max_mana: int) -> void:
	_mana_label.text = "魔法  %d / %d" % [current_mana, max_mana]


func _on_player_body_parts_changed(summary: String) -> void:
	_body_parts_label.text = summary


func _on_player_stats_changed(attack_damage: int, attack_speed_bonus: int) -> void:
	_stats_label.text = "攻击 %d    攻速 +%d%%" % [attack_damage, attack_speed_bonus]


func _update_wave_label() -> void:
	_wave_label.text = "第 %d 波" % _wave


func _on_player_died() -> void:
	_status_label.text = "挑战失败，即将重新开始……"
	_status_label.visible = true
	await get_tree().create_timer(1.2).timeout
	get_tree().reload_current_scene()


func _on_pvp_player_defeated(victim_peer_id: int, killer_peer_id: int) -> void:
	if not _pvp_mode or not multiplayer.is_server() or _pvp_round_ending:
		return
	if killer_peer_id > 0 and killer_peer_id != victim_peer_id and _network_players.has(killer_peer_id):
		_pvp_kills[killer_peer_id] = int(_pvp_kills.get(killer_peer_id, 0)) + 1
		_sync_pvp_upgrade.rpc(killer_peer_id, int(_pvp_kills[killer_peer_id]) - 1)
	_sync_pvp_scores.rpc(_pvp_kills)
	_respawn_pvp_player.rpc(victim_peer_id, _spawn_for_peer(victim_peer_id))
	if int(_pvp_kills.get(killer_peer_id, 0)) >= PVP_KILLS_TO_WIN:
		_finish_pvp_round(killer_peer_id)


@rpc("authority", "call_local", "reliable")
func _sync_pvp_upgrade(peer_id: int, upgrade_index: int) -> void:
	var player := get_node_or_null("Player_%d" % peer_id) as Player
	if is_instance_valid(player):
		player.apply_pvp_upgrade(upgrade_index)


func _finish_pvp_round(winner_peer_id: int) -> void:
	if _pvp_round_ending:
		return
	_pvp_round_ending = true
	_show_pvp_winner.rpc(winner_peer_id)
	await get_tree().create_timer(3.0).timeout
	_pvp_kills.clear()
	for peer_id in _network_players:
		_pvp_kills[peer_id] = 0
	_reset_pvp_round.rpc()
	_pvp_round_ending = false


@rpc("authority", "call_local", "reliable")
func _respawn_pvp_player(peer_id: int, spawn_position: Vector2) -> void:
	var player := get_node_or_null("Player_%d" % peer_id) as Player
	if is_instance_valid(player):
		player.reset_for_pvp(spawn_position)
		player.set_pvp_enabled(true)


@rpc("authority", "call_local", "reliable")
func _show_pvp_winner(winner_peer_id: int) -> void:
	for node in get_tree().get_nodes_in_group("player"):
		var player := node as Player
		player.set_king(player.get_multiplayer_authority() == winner_peer_id)
		player.set_controls_enabled(false)
	_status_label.text = "玩家 %d 获胜！3 秒后重置" % winner_peer_id
	_status_label.visible = true


@rpc("authority", "call_local", "reliable")
func _reset_pvp_round() -> void:
	for node in get_tree().get_nodes_in_group("player"):
		var player := node as Player
		player.set_king(false)
		player.reset_for_pvp(_spawn_for_peer(player.get_multiplayer_authority()))
	_status_label.visible = false
	_update_pvp_scoreboard()


@rpc("authority", "call_local", "reliable")
func _sync_pvp_scores(kills: Dictionary) -> void:
	_pvp_kills = kills.duplicate()
	_update_pvp_scoreboard()


func _update_pvp_scoreboard() -> void:
	var lines: Array[String] = ["击杀榜（先到 %d 胜利）" % PVP_KILLS_TO_WIN]
	var ids := _pvp_kills.keys()
	ids.sort()
	for peer_id in ids:
		var display_name := str(_player_names.get(peer_id, "玩家 %d" % peer_id))
		lines.append("%s：%d" % [display_name, int(_pvp_kills[peer_id])])
	_pvp_score_label.text = "\n".join(lines)


func _spawn_for_peer(peer_id: int) -> Vector2:
	var spawns := HALL_SPAWNS if _multiplayer_map == MAP_HALL else PVP_SPAWNS
	return spawns[(peer_id - 1) % spawns.size()]


func get_pvp_kills(peer_id: int) -> int:
	return int(_pvp_kills.get(peer_id, 0))


func is_pvp_round_ending() -> bool:
	return _pvp_round_ending
