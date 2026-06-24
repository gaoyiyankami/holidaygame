extends Node2D

const ENEMY_SCENE := preload("res://scenes/enemies/training_dummy.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const MAX_CLIENTS := 7

var _wave: int = 1
var _current_enemy: TrainingDummy
var _upgrade_open: bool = false
var _network_players: Dictionary = {}
var _pvp_mode: bool = false

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
@onready var _port_input: SpinBox = $UI/NetworkPanel/VBox/PortRow/PortInput
@onready var _host_button: Button = $UI/NetworkPanel/VBox/Buttons/HostButton
@onready var _join_button: Button = $UI/NetworkPanel/VBox/Buttons/JoinButton
@onready var _network_status: Label = $UI/NetworkPanel/VBox/NetworkStatus
@onready var _start_menu: PanelContainer = $UI/StartMenu
@onready var _single_button: Button = $UI/StartMenu/Margin/VBox/SingleButton
@onready var _multi_button: Button = $UI/StartMenu/Margin/VBox/MultiButton
@onready var _back_button: Button = $UI/NetworkPanel/VBox/BackButton


func _ready() -> void:
	_player.health_changed.connect(_on_player_health_changed)
	_player.mana_changed.connect(_on_player_mana_changed)
	_player.body_parts_changed.connect(_on_player_body_parts_changed)
	_player.stats_changed.connect(_on_player_stats_changed)
	_player.died.connect(_on_player_died)
	_attack_button.pressed.connect(_choose_attack_upgrade)
	_speed_button.pressed.connect(_choose_speed_upgrade)
	_health_button.pressed.connect(_choose_health_upgrade)
	_single_button.pressed.connect(_start_single_player)
	_multi_button.pressed.connect(_show_multiplayer_menu)
	_back_button.pressed.connect(_show_start_menu)
	_host_button.pressed.connect(_host_game)
	_join_button.pressed.connect(_join_game)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	_on_player_health_changed(_player.get_health(), _player.max_health)
	_on_player_mana_changed(_player.get_mana(), _player.max_mana)
	_on_player_stats_changed(_player.attack_damage, _player.get_attack_speed_bonus())
	_update_wave_label()

	_current_enemy = $TrainingDummy as TrainingDummy
	_connect_enemy(_current_enemy)
	_player.set_controls_enabled(false)
	_network_panel.visible = false
	_set_game_active(false)
	if _is_dedicated_server():
		_port_input.value = _server_port_from_args()
		call_deferred("_host_game")


func _start_single_player() -> void:
	_set_pvp_mode(false)
	_start_menu.visible = false
	_network_panel.visible = false
	_set_game_active(true)


func _show_multiplayer_menu() -> void:
	_start_menu.visible = false
	_network_panel.visible = true
	_set_game_active(false)


func _show_start_menu() -> void:
	_network_panel.visible = false
	_start_menu.visible = true
	_set_game_active(false)


func _set_game_active(active: bool) -> void:
	for child in get_children():
		if child is CanvasItem and child != $UI:
			(child as CanvasItem).visible = active
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
	var peer := ENetMultiplayerPeer.new()
	var port := _selected_port()
	var error := peer.create_server(port, MAX_CLIENTS)
	if error != OK:
		_network_status.text = "创建主机失败：%s" % error_string(error)
		return
	multiplayer.multiplayer_peer = peer
	_prepare_existing_player_for_network()
	_network_players[1] = true
	_network_status.text = "主机已开启，端口 %d（最多 8 人）" % port
	_network_panel.visible = false
	_set_game_active(true)
	_set_pvp_mode(true)
	_host_button.disabled = true
	_join_button.disabled = true


func _join_game() -> void:
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


func _is_dedicated_server() -> bool:
	return "--server" in OS.get_cmdline_args() or "--server" in OS.get_cmdline_user_args()


func _server_port_from_args() -> int:
	for argument in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if argument.begins_with("--port="):
			return clampi(int(argument.trim_prefix("--port=")), 1024, 65535)
	return 7000


func _set_pvp_mode(enabled: bool) -> void:
	_pvp_mode = enabled
	$PvPMap.visible = enabled
	for collision in $PvPMap.get_children():
		if collision is StaticBody2D:
			var shape := collision.get_node_or_null("CollisionShape2D") as CollisionShape2D
			if is_instance_valid(shape):
				shape.disabled = not enabled
	$PlatformLeft.visible = not enabled
	$PlatformRight.visible = not enabled
	$PlatformLeft/CollisionShape2D.disabled = enabled
	$PlatformRight/CollisionShape2D.disabled = enabled
	if is_instance_valid(_current_enemy):
		_current_enemy.visible = not enabled
		_current_enemy.set_physics_process(not enabled)
	_wave_label.visible = not enabled
	if enabled:
		_room_title("PvP 竞技场")
	else:
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


func _on_peer_disconnected(peer_id: int) -> void:
	if multiplayer.is_server():
		_remove_network_player.rpc(peer_id)


@rpc("authority", "call_local", "reliable")
func _spawn_network_player(peer_id: int) -> void:
	if _network_players.has(peer_id):
		return
	var player := PLAYER_SCENE.instantiate() as Player
	player.name = "Player_%d" % peer_id
	player.position = Vector2(170 + (_network_players.size() % 4) * 54, 610)
	add_child(player)
	player.configure_network_authority(peer_id)
	_network_players[peer_id] = true
	if peer_id == multiplayer.get_unique_id():
		_bind_local_player(player)
	_network_status.text = "当前玩家：%d / 8" % _network_players.size()


@rpc("authority", "call_local", "reliable")
func _remove_network_player(peer_id: int) -> void:
	var player := get_node_or_null("Player_%d" % peer_id)
	if is_instance_valid(player):
		player.queue_free()
	_network_players.erase(peer_id)
	_network_status.text = "当前玩家：%d / 8" % _network_players.size()


func _bind_local_player(player: Player) -> void:
	_player = player
	_player.health_changed.connect(_on_player_health_changed)
	_player.mana_changed.connect(_on_player_mana_changed)
	_player.body_parts_changed.connect(_on_player_body_parts_changed)
	_player.stats_changed.connect(_on_player_stats_changed)
	_player.died.connect(_on_player_died)
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
	_attack_button.grab_focus()


func _choose_attack_upgrade() -> void:
	_player.apply_attack_upgrade()
	_finish_upgrade("攻击力 +1")


func _choose_speed_upgrade() -> void:
	_player.apply_attack_speed_upgrade()
	_finish_upgrade("攻击速度 +15%")


func _choose_health_upgrade() -> void:
	_player.apply_max_health_upgrade()
	_finish_upgrade("生命上限 +2，回复 2 点")


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
