extends Node2D

const ENEMY_SCENE := preload("res://scenes/enemies/training_dummy.tscn")
const DOG_ENEMY_SCENE := preload("res://scenes/enemies/dog_enemy.tscn")
const VARIANT_ENEMY_SCENE := preload("res://scenes/enemies/variant_enemy.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const ENEMY_PROJECTILE_SCRIPT := preload("res://scripts/combat/enemy_projectile.gd")
const ENEMY_HAZARD_SCRIPT := preload("res://scripts/combat/enemy_hazard.gd")
const CUSTOM_MAP_SCRIPT := preload("res://scripts/main/custom_map.gd")
const MAP_EDITOR_SCRIPT := preload("res://scripts/main/map_editor.gd")
const MAX_CLIENTS := 7
const NETWORK_CHANNEL_COUNT := 5
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
const MAP_CUSTOM := "custom"
const MAP_CHALLENGE_ARENA := "challenge_arena"
const FALL_KILL_MARGIN := 240.0
const FALL_DAMAGE := 9999
const SOLID_COLLISION_LAYER := 1
const ONE_WAY_PLATFORM_LAYER := 1 << 5
const ENEMY_SYNC_INTERVAL := 1.0 / 30.0
const ARENA_MAX_WAVE := 30
const ARENA_HEALTH_GROWTH_PER_WAVE := 0.06
const ARENA_ATTACK_GROWTH_PER_WAVE := 0.035
const COOP_RESPAWN_DELAY := 2.5
const RUN_SINGLE := "single"
const RUN_CUSTOM := "custom"
const RUN_ARENA := "arena"
const RUN_MULTIPLAYER := "multiplayer"
const PENDING_RUN_META := &"holiday_adventure_pending_run"
const ARENA_ELITE_POOL := [
	CustomMap.ENEMY_BLOOD_ARMOR_KNIGHT,
	CustomMap.ENEMY_BLACKFLAME_LANCER,
	CustomMap.ENEMY_ABYSS_EXECUTIONER,
]
const CHALLENGE_ARENA_SIZE := Vector2i(3200, 900)
const CHALLENGE_PLAYER_SPAWNS := [
	Vector2(220, 610),
	Vector2(2980, 610),
	Vector2(520, 430),
	Vector2(2680, 430),
	Vector2(1040, 610),
	Vector2(2160, 610),
	Vector2(1360, 280),
	Vector2(1840, 280),
]
const CHALLENGE_ENEMY_SPAWNS := [
	Vector2(720, 610),
	Vector2(2480, 610),
	Vector2(1120, 610),
	Vector2(2080, 610),
	Vector2(1600, 410),
	Vector2(620, 360),
	Vector2(2580, 360),
]

var _wave: int = 1
var _current_enemy: Node
var _active_enemies: Array[Node] = []
var _upgrade_open: bool = false
var _network_players: Dictionary = {}
var _pvp_mode: bool = false
var _pvp_kills: Dictionary = {}
var _pvp_round_ending: bool = false
var _multiplayer_map: String = MAP_ARENA
var _using_custom_map: bool = false
var _arena_mode: bool = false
var _arena_upgrade_picks_remaining: int = 0
var _arena_gold: int = 0
var _arena_shop_open: bool = false
var _run_mode: String = ""
var _run_active: bool = false
var _run_elapsed: float = 0.0
var _run_defeated: int = 0
var _game_paused: bool = false
var _result_open: bool = false
var _settings_context: String = "menu"
var _challenge_arena_map: Node2D
var _offered_upgrades: Array[String] = []
var _last_clash_time: Dictionary = {}
var _last_melee_swing: Dictionary = {}
var _last_combat_effect: Dictionary = {}
var _player_position_history: Dictionary = {}
var _last_player_state_sequence: Dictionary = {}
var _last_regeneration_time: Dictionary = {}
var _player_names: Dictionary = {}
var _player_avatars: Dictionary = {}
var _player_appearance_seeds: Dictionary = {}
var _pending_pvp_upgrade_offers: Dictionary = {}
var _pvp_upgrade_selection_active: bool = false
var _selected_avatar_base64: String = ""
var _ping_timer: float = 0.0
var _enemy_sync_timer: float = 0.0
var _enemy_snapshot_sequence: int = 0
var _next_enemy_effect_id: int = 1
var _network_enemy_effects: Dictionary = {}
var _enemy_missing_snapshots: Dictionary = {}
var _effect_missing_snapshots: Dictionary = {}
var _coop_respawn_pending: Dictionary = {}
var _smoothed_latency_msec: float = 0.0
var _server_clock_offset_msec: float = 0.0
var _custom_map: CustomMap
var _map_editor: MapEditor
var _custom_map_button: Button
var _map_editor_button: Button
var _arena_button: Button
var _cheat_button: Button
const SETTINGS_PATH := "user://settings.cfg"
const POSITION_HISTORY_MSEC := 600
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
	{"id": "fire_build", "title": "余烬剑印", "detail": "攻击附加持续灼烧；与冰霜触发冷热冲击"},
	{"id": "frost_build", "title": "霜缚锋刃", "detail": "命中短暂冻结移动；强化寒冰光波"},
	{"id": "lightning_build", "title": "雷链核心", "detail": "每 3 次命中向附近敌人连锁闪电"},
	{"id": "counter_build", "title": "镜盾反击", "detail": "格挡自动反击；完美格挡造成双倍反击"},
	{"id": "charge_build", "title": "蓄能回路", "detail": "蓄力光波增伤并降低高阶魔力消耗"},
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
@onready var _shop_gold_label: Label = $UI/UpgradePanel/Margin/VBox/ShopGoldLabel
@onready var _shop_continue_button: Button = $UI/UpgradePanel/Margin/VBox/ShopContinueButton
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
@onready var _title_quit_button: Button = $UI/StartMenu/Margin/VBox/QuitButton
@onready var _settings_panel: PanelContainer = $UI/SettingsPanel
@onready var _resolution_select: OptionButton = $UI/SettingsPanel/Margin/VBox/ResolutionRow/ResolutionSelect
@onready var _refresh_select: OptionButton = $UI/SettingsPanel/Margin/VBox/RefreshRow/RefreshSelect
@onready var _apply_settings_button: Button = $UI/SettingsPanel/Margin/VBox/ApplyButton
@onready var _settings_back_button: Button = $UI/SettingsPanel/Margin/VBox/BackButton
@onready var _master_volume_slider: HSlider = $UI/SettingsPanel/Margin/VBox/MasterVolumeRow/Slider
@onready var _master_volume_value: Label = $UI/SettingsPanel/Margin/VBox/MasterVolumeRow/Value
@onready var _sfx_volume_slider: HSlider = $UI/SettingsPanel/Margin/VBox/SfxVolumeRow/Slider
@onready var _sfx_volume_value: Label = $UI/SettingsPanel/Margin/VBox/SfxVolumeRow/Value
@onready var _mute_toggle: CheckButton = $UI/SettingsPanel/Margin/VBox/MuteToggle
@onready var _ping_label: Label = $UI/PingLabel
@onready var _pause_overlay: Control = $UI/PauseOverlay
@onready var _pause_context: Label = $UI/PauseOverlay/Panel/Margin/VBox/Context
@onready var _pause_resume_button: Button = $UI/PauseOverlay/Panel/Margin/VBox/ResumeButton
@onready var _pause_settings_button: Button = $UI/PauseOverlay/Panel/Margin/VBox/SettingsButton
@onready var _pause_restart_button: Button = $UI/PauseOverlay/Panel/Margin/VBox/RestartButton
@onready var _pause_menu_button: Button = $UI/PauseOverlay/Panel/Margin/VBox/MenuButton
@onready var _pause_quit_button: Button = $UI/PauseOverlay/Panel/Margin/VBox/QuitButton
@onready var _result_overlay: Control = $UI/ResultOverlay
@onready var _result_title: Label = $UI/ResultOverlay/Panel/Margin/VBox/Title
@onready var _result_subtitle: Label = $UI/ResultOverlay/Panel/Margin/VBox/Subtitle
@onready var _result_summary: Label = $UI/ResultOverlay/Panel/Margin/VBox/Summary
@onready var _result_record: Label = $UI/ResultOverlay/Panel/Margin/VBox/Record
@onready var _result_retry_button: Button = $UI/ResultOverlay/Panel/Margin/VBox/RetryButton
@onready var _result_menu_button: Button = $UI/ResultOverlay/Panel/Margin/VBox/MenuButton
@onready var _result_quit_button: Button = $UI/ResultOverlay/Panel/Margin/VBox/QuitButton


func _process(delta: float) -> void:
	if _run_active and not _game_paused and not _result_open:
		_run_elapsed += delta
	_check_fall_kill()
	_update_enemy_network_sync(delta)
	if not _pvp_mode or not _has_active_network_session():
		return
	_ping_timer -= delta
	if _ping_timer > 0.0:
		return
	_ping_timer = 0.5
	if multiplayer.is_server():
		_ping_label.text = "延迟 0 ms（主机）· 怪物 30 Hz" if _arena_mode \
			else "延迟 0 ms（主机）· 玩家动态 12–60 Hz"
	else:
		_ping_server.rpc_id(1, Time.get_ticks_msec())


func _update_enemy_network_sync(delta: float) -> void:
	if not _arena_mode or not _has_active_network_session() or not multiplayer.is_server():
		return
	_enemy_sync_timer -= delta
	if _enemy_sync_timer > 0.0:
		return
	_enemy_sync_timer = ENEMY_SYNC_INTERVAL
	_broadcast_enemy_snapshot()


func _broadcast_enemy_snapshot(force_full_state: bool = false) -> void:
	_enemy_snapshot_sequence += 1
	var sequence := _enemy_snapshot_sequence
	var server_msec := Time.get_ticks_msec()
	var include_parts := force_full_state or sequence % 3 == 0
	var include_effect_config := force_full_state or sequence % 15 == 0
	var enemy_states := _collect_enemy_network_states(include_parts)
	var effect_states := _collect_enemy_network_effect_states(include_effect_config)
	var enemy_ids: Array[String] = []
	var effect_ids: Array[int] = []
	for state in enemy_states:
		enemy_ids.append(str(state.get("id", "")))
	for state in effect_states:
		effect_ids.append(int(state.get("id", 0)))
	_sync_enemy_snapshot_header.rpc(sequence, server_msec, enemy_ids, effect_ids)
	for state in enemy_states:
		_sync_single_enemy_state.rpc(sequence, server_msec, state)
	for state in effect_states:
		_sync_single_enemy_effect_state.rpc(sequence, server_msec, state)


func _collect_enemy_network_states(include_parts: bool = true) -> Array:
	var states: Array = []
	var living_enemies: Array[Node] = []
	for enemy in _active_enemies:
		if not is_instance_valid(enemy):
			continue
		living_enemies.append(enemy)
		var body := enemy as CharacterBody2D
		var node2d := enemy as Node2D
		if not is_instance_valid(node2d):
			continue
		var state: Dictionary
		if enemy.has_method("serialize_network_state"):
			state = enemy.serialize_network_state()
		else:
			state = {
				"position": node2d.global_position,
				"velocity": body.velocity if is_instance_valid(body) else Vector2.ZERO,
				"parts": enemy.get_part_health_state() if enemy.has_method("get_part_health_state") else {},
				"facing": enemy.get_network_facing() if enemy.has_method("get_network_facing") else 1.0,
				"state": enemy.get_network_state_id() if enemy.has_method("get_network_state_id") else 0,
			}
		state["id"] = str(enemy.name)
		state["archetype"] = str(enemy.get_archetype()) if enemy.has_method("get_archetype") else CustomMap.ENEMY_CRYPT_DOG
		if not include_parts:
			state.erase("parts")
		states.append(state)
	_active_enemies = living_enemies
	return states


func _collect_enemy_network_effect_states(include_config: bool = true) -> Array:
	var states: Array = []
	for node in get_tree().get_nodes_in_group("enemy_network_effect"):
		if not is_instance_valid(node) or not node.has_method("serialize_network_state"):
			continue
		var network_id := int(node.get_network_id()) if node.has_method("get_network_id") else 0
		if network_id <= 0 and node.has_method("set_network_id"):
			network_id = _next_enemy_effect_id
			_next_enemy_effect_id += 1
			node.set_network_id(network_id)
		var state: Dictionary = node.serialize_network_state() if include_config \
			or not node.has_method("serialize_network_motion_state") \
			else node.serialize_network_motion_state()
		state["id"] = network_id
		states.append(state)
	return states


@rpc("authority", "call_remote", "unreliable_ordered", 4)
func _sync_enemy_snapshot_header(
	snapshot_sequence: int,
	_server_msec: int,
	enemy_ids: Array[String],
	effect_ids: Array[int]
) -> void:
	if not _arena_mode or multiplayer.is_server() or snapshot_sequence < _enemy_snapshot_sequence:
		return
	_enemy_snapshot_sequence = snapshot_sequence
	var enemy_roster: Dictionary = {}
	for id in enemy_ids:
		enemy_roster[id] = true
		_enemy_missing_snapshots.erase(id)
	for enemy in _active_enemies.duplicate():
		if is_instance_valid(enemy) and not enemy_roster.has(str(enemy.name)):
			var id := str(enemy.name)
			var missed := int(_enemy_missing_snapshots.get(id, 0)) + 1
			_enemy_missing_snapshots[id] = missed
			if missed >= 6:
				_enemy_missing_snapshots.erase(id)
				_active_enemies.erase(enemy)
				enemy.queue_free()
	var effect_roster: Dictionary = {}
	for id in effect_ids:
		effect_roster[id] = true
		_effect_missing_snapshots.erase(id)
	for network_id in _network_enemy_effects.keys():
		var effect: Node = _network_enemy_effects.get(network_id)
		if not is_instance_valid(effect):
			_effect_missing_snapshots.erase(network_id)
			_network_enemy_effects.erase(network_id)
		elif not effect_roster.has(int(network_id)):
			var missed := int(_effect_missing_snapshots.get(network_id, 0)) + 1
			_effect_missing_snapshots[network_id] = missed
			if missed >= 6:
				_effect_missing_snapshots.erase(network_id)
				_network_enemy_effects.erase(network_id)
				effect.queue_free()


@rpc("authority", "call_remote", "unreliable_ordered", 4)
func _sync_single_enemy_state(
	snapshot_sequence: int,
	server_msec: int,
	state: Dictionary
) -> void:
	if not _arena_mode or multiplayer.is_server() or snapshot_sequence < _enemy_snapshot_sequence:
		return
	_apply_received_enemy_state(snapshot_sequence, server_msec, state)


@rpc("authority", "call_remote", "reliable", 3)
func _sync_single_enemy_state_reliable(
	snapshot_sequence: int,
	server_msec: int,
	state: Dictionary
) -> void:
	if not _arena_mode or multiplayer.is_server() or snapshot_sequence < _enemy_snapshot_sequence:
		return
	_apply_received_enemy_state(snapshot_sequence, server_msec, state)


func _apply_received_enemy_state(
	snapshot_sequence: int,
	server_msec: int,
	state: Dictionary
) -> void:
	_enemy_snapshot_sequence = maxi(_enemy_snapshot_sequence, snapshot_sequence)
	var id := str(state.get("id", ""))
	if id.is_empty():
		return
	_enemy_missing_snapshots.erase(id)
	var enemy := _find_active_enemy_by_id(id)
	if not is_instance_valid(enemy):
		enemy = _spawn_network_enemy_from_state(state)
	if is_instance_valid(enemy) and enemy.has_method("apply_network_state"):
		state["snapshot_sequence"] = snapshot_sequence
		state["server_msec"] = server_msec
		state["sync_interval"] = ENEMY_SYNC_INTERVAL
		enemy.apply_network_state(state)


@rpc("authority", "call_remote", "unreliable_ordered", 4)
func _sync_single_enemy_effect_state(
	snapshot_sequence: int,
	server_msec: int,
	state: Dictionary
) -> void:
	if not _arena_mode or multiplayer.is_server() or snapshot_sequence < _enemy_snapshot_sequence:
		return
	_enemy_snapshot_sequence = maxi(_enemy_snapshot_sequence, snapshot_sequence)
	var network_id := int(state.get("id", 0))
	if network_id <= 0:
		return
	_effect_missing_snapshots.erase(network_id)
	var effect: Node = _network_enemy_effects.get(network_id)
	if not is_instance_valid(effect):
		effect = _spawn_network_enemy_effect(state)
	if is_instance_valid(effect) and effect.has_method("apply_network_state"):
		state["snapshot_sequence"] = snapshot_sequence
		state["server_msec"] = server_msec
		effect.apply_network_state(state)


func register_enemy_network_effect(effect: Node) -> void:
	if not _has_active_network_session() or not multiplayer.is_server() or not _arena_mode:
		return
	if not is_instance_valid(effect) or not effect.has_method("serialize_network_state"):
		return
	var network_id := int(effect.get_network_id()) if effect.has_method("get_network_id") else 0
	if network_id <= 0 and effect.has_method("set_network_id"):
		network_id = _next_enemy_effect_id
		_next_enemy_effect_id += 1
		effect.set_network_id(network_id)
	var state: Dictionary = effect.serialize_network_state()
	state["id"] = network_id
	_spawn_enemy_effect_reliable.rpc(state, _enemy_snapshot_sequence, Time.get_ticks_msec())


func unregister_enemy_network_effect(network_id: int) -> void:
	if network_id <= 0 or not _has_active_network_session() \
		or not multiplayer.is_server() or not _arena_mode:
		return
	_remove_enemy_effect_reliable.rpc(network_id)


@rpc("authority", "call_remote", "reliable", 3)
func _spawn_enemy_effect_reliable(
	state: Dictionary,
	snapshot_sequence: int,
	server_msec: int
) -> void:
	if multiplayer.is_server():
		return
	var network_id := int(state.get("id", 0))
	if network_id <= 0:
		return
	_effect_missing_snapshots.erase(network_id)
	var effect: Node = _network_enemy_effects.get(network_id)
	if not is_instance_valid(effect):
		effect = _spawn_network_enemy_effect(state)
	if is_instance_valid(effect) and effect.has_method("apply_network_state"):
		state["snapshot_sequence"] = maxi(snapshot_sequence, 1)
		state["server_msec"] = server_msec
		effect.apply_network_state(state)


@rpc("authority", "call_remote", "reliable", 3)
func _remove_enemy_effect_reliable(network_id: int) -> void:
	if multiplayer.is_server():
		return
	var effect: Node = _network_enemy_effects.get(network_id)
	_effect_missing_snapshots.erase(network_id)
	_network_enemy_effects.erase(network_id)
	if is_instance_valid(effect):
		effect.queue_free()


func _spawn_network_enemy_effect(state: Dictionary) -> Node:
	var effect: Node
	if str(state.get("kind", "")) == "hazard":
		var hazard := ENEMY_HAZARD_SCRIPT.new() as EnemyHazard
		hazard.damage = int(state.get("damage", 1))
		hazard.radius = float(state.get("radius", 38.0))
		hazard.startup_delay = float(state.get("startup_delay", 0.0))
		hazard.lifetime = float(state.get("lifetime", 1.0))
		hazard.tick_interval = float(state.get("tick_interval", 0.7))
		hazard.visual_color = state.get("visual_color", Color(1.0, 0.28, 0.04, 0.48))
		hazard.slow_duration = float(state.get("slow_duration", 0.0))
		hazard.weakness_duration = float(state.get("weakness_duration", 0.0))
		effect = hazard
	else:
		var projectile := ENEMY_PROJECTILE_SCRIPT.new() as EnemyProjectile
		projectile.direction = state.get("direction", Vector2.RIGHT)
		projectile.speed = float(state.get("speed", 420.0))
		projectile.damage = int(state.get("damage", 1))
		projectile.source_position = state.get("source_position", Vector2.ZERO)
		projectile.poison_ticks = int(state.get("poison_ticks", 0))
		projectile.radius = float(state.get("radius", 7.0))
		projectile.visual_length = float(state.get("visual_length", 20.0))
		projectile.visual_color = state.get("visual_color", Color(1.0, 0.72, 0.24, 0.95))
		projectile.shape_style = str(state.get("shape_style", "bolt"))
		projectile.homing_strength = float(state.get("homing_strength", 0.0))
		projectile.slow_duration = float(state.get("slow_duration", 0.0))
		projectile.weakness_duration = float(state.get("weakness_duration", 0.0))
		effect = projectile
	if not is_instance_valid(effect):
		return null
	effect.set_network_id(int(state.get("id", 0)))
	effect.set_network_proxy(true)
	(effect as Node2D).global_position = state.get("position", Vector2.ZERO)
	add_child(effect)
	_network_enemy_effects[int(state.get("id", 0))] = effect
	return effect


func _find_active_enemy_by_id(id: String) -> Node:
	for enemy in _active_enemies:
		if is_instance_valid(enemy) and str(enemy.name) == id:
			return enemy
	return null


func _spawn_network_enemy_from_state(state: Dictionary) -> Node:
	var entry := {
		"position": state.get("position", Vector2.ZERO),
		"enemy": str(state.get("archetype", CustomMap.ENEMY_CRYPT_DOG)),
	}
	_spawn_enemy_from_entry(entry)
	var enemy: Node = _active_enemies.back() if not _active_enemies.is_empty() else null
	if is_instance_valid(enemy):
		enemy.name = str(state.get("id", enemy.name))
		_configure_enemy_network_proxy(enemy)
	return enemy


func _check_fall_kill() -> void:
	if not $BackgroundLayer.visible:
		return
	if is_instance_valid(_map_editor) and _map_editor.visible:
		return
	var kill_y := _fall_kill_y()
	if _pvp_mode and _has_active_network_session():
		if not multiplayer.is_server():
			return
		for node in get_tree().get_nodes_in_group("player"):
			var player := node as Player
			if is_instance_valid(player) and player.global_position.y > kill_y:
				var peer_id := player.get_multiplayer_authority()
				_pending_pvp_upgrade_offers.erase(peer_id)
				_respawn_pvp_player.rpc(peer_id, _spawn_for_peer(peer_id))
		return
	if is_instance_valid(_player) and _player.global_position.y > kill_y and _player.get_health() > 0:
		_player.take_damage(FALL_DAMAGE, _player.global_position + Vector2(0, -80))
	var kept_enemies: Array[Node] = []
	for enemy in _active_enemies:
		if not is_instance_valid(enemy):
			continue
		var enemy_body := enemy as Node2D
		if not is_instance_valid(enemy_body):
			continue
		if enemy_body.global_position.y <= kill_y:
			kept_enemies.append(enemy)
			continue
		if enemy_body.has_method("take_damage"):
			enemy_body.take_damage(FALL_DAMAGE, enemy_body.global_position + Vector2(0, -80))
	_active_enemies = kept_enemies


func _fall_kill_y() -> float:
	if _arena_mode or _multiplayer_map == MAP_CHALLENGE_ARENA:
		return float(CHALLENGE_ARENA_SIZE.y) + FALL_KILL_MARGIN
	if (_using_custom_map or (_pvp_mode and _multiplayer_map == MAP_CUSTOM)) and is_instance_valid(_custom_map):
		return float(_custom_map.get_world_height()) + FALL_KILL_MARGIN
	return 720.0 + FALL_KILL_MARGIN


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
		and event.keycode == KEY_O and $BackgroundLayer.visible and is_instance_valid(_player):
		_apply_cheat_upgrade()
		get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if _result_open:
		return
	if _settings_context == "pause" and _settings_panel.visible:
		_return_to_pause_from_settings()
		return
	if _game_paused:
		_resume_game()
		return
	if is_instance_valid(_map_editor) and _map_editor.visible:
		_close_map_editor()
	elif $BackgroundLayer.visible:
		_open_pause_menu()


func _return_to_main_menu() -> void:
	if _is_dedicated_server():
		return
	_player.clear_input_state()
	_player.set_controls_enabled(false)
	if _has_active_network_session():
		multiplayer.multiplayer_peer = null
	# Reloading guarantees that spawned players, score state, enemies and
	# network authority are all reset before the menu is shown again.
	get_tree().paused = false
	get_tree().reload_current_scene()


func _quit_game() -> void:
	get_tree().paused = false
	get_tree().quit()


func _open_pause_menu() -> void:
	if _result_open or not $BackgroundLayer.visible:
		return
	_game_paused = true
	_player.clear_input_state()
	_player.set_controls_enabled(false)
	var online := _has_active_network_session()
	_pause_context.text = "联机战斗仍在继续" if online else "当前战斗已暂停"
	_pause_restart_button.visible = not online
	_pause_restart_button.disabled = online
	_pause_menu_button.text = "断开并返回标题" if online else "返回标题画面"
	_pause_overlay.visible = true
	if not online:
		get_tree().paused = true
	_pause_resume_button.grab_focus()


func _resume_game() -> void:
	if not _game_paused:
		return
	_pause_overlay.visible = false
	_settings_panel.visible = false
	_settings_context = "menu"
	_game_paused = false
	get_tree().paused = false
	if _run_active and not _result_open and not _upgrade_open \
		and is_instance_valid(_player) and not _player.is_dead():
		_player.set_controls_enabled(true)


func _show_pause_settings() -> void:
	if not _game_paused:
		return
	_settings_context = "pause"
	_pause_overlay.visible = false
	_settings_panel.visible = true
	_settings_back_button.text = "返回暂停菜单"
	_apply_settings_button.grab_focus()


func _return_to_pause_from_settings() -> void:
	_settings_panel.visible = false
	_pause_overlay.visible = true
	_pause_resume_button.grab_focus()


func _on_settings_back() -> void:
	if _settings_context == "pause":
		_return_to_pause_from_settings()
	else:
		_show_start_menu()


func _begin_run(mode: String) -> void:
	_run_mode = mode
	_run_active = true
	_run_elapsed = 0.0
	_run_defeated = 0
	_result_open = false
	_game_paused = false
	_pause_overlay.visible = false
	_result_overlay.visible = false
	get_tree().paused = false


func _start_pending_run() -> void:
	if not get_tree().has_meta(PENDING_RUN_META):
		return
	var mode := str(get_tree().get_meta(PENDING_RUN_META, ""))
	get_tree().remove_meta(PENDING_RUN_META)
	match mode:
		RUN_ARENA:
			_start_single_arena_mode()
		RUN_CUSTOM:
			_start_custom_single_player()
		RUN_SINGLE:
			_start_single_player()


func _restart_current_run() -> void:
	if _has_active_network_session() or _run_mode not in [RUN_SINGLE, RUN_CUSTOM, RUN_ARENA]:
		return
	get_tree().set_meta(PENDING_RUN_META, _run_mode)
	get_tree().paused = false
	get_tree().reload_current_scene()


func _show_run_result(
	victory: bool,
	defeated_override: int = -1,
	elapsed_override: float = -1.0
) -> void:
	if _result_open:
		return
	if defeated_override >= 0:
		_run_defeated = defeated_override
	if elapsed_override >= 0.0:
		_run_elapsed = elapsed_override
	_run_active = false
	_result_open = true
	_game_paused = false
	_player.clear_input_state()
	_player.set_controls_enabled(false)
	_pause_overlay.visible = false
	_settings_panel.visible = false
	_upgrade_panel.visible = false
	_status_label.visible = false
	_result_title.text = "竞技场征服" if victory else "挑战结束"
	_result_subtitle.text = "猩红女巫已被击败" if victory else "整顿装备，再次出发"
	var mode_name := _run_mode_display_name()
	var wave_line := "完成波次  %d / %d" % [_wave, ARENA_MAX_WAVE] \
		if _arena_mode else "到达波次  %d" % _wave
	_result_summary.text = "模式  %s\n%s\n击败敌人  %d\n用时  %s" % [
		mode_name, wave_line, _run_defeated, _format_run_time(_run_elapsed),
	]
	var record := _save_run_record(victory)
	_result_record.text = "最高波次 %d  ·  最多击败 %d" % [
		int(record.get("best_wave", _wave)), int(record.get("best_defeated", _run_defeated)),
	]
	var can_retry := not _has_active_network_session() \
		and _run_mode in [RUN_SINGLE, RUN_CUSTOM, RUN_ARENA]
	_result_retry_button.visible = can_retry
	_result_menu_button.text = "断开并返回标题" if _has_active_network_session() else "返回标题画面"
	_result_overlay.visible = true
	if not _has_active_network_session():
		get_tree().paused = true
	(_result_retry_button if can_retry else _result_menu_button).grab_focus()


func _run_mode_display_name() -> String:
	if _run_mode == RUN_ARENA:
		return "单人竞技场"
	if _run_mode == RUN_CUSTOM:
		return "自定义地图"
	if _run_mode == RUN_MULTIPLAYER:
		return "合作竞技场" if _arena_mode else "多人对战"
	return "单人挑战"


func _format_run_time(seconds: float) -> String:
	var total_seconds := maxi(0, floori(seconds))
	return "%02d:%02d" % [floori(float(total_seconds) / 60.0), total_seconds % 60]


func _save_run_record(victory: bool) -> Dictionary:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	var best_wave := maxi(int(config.get_value("records", "best_wave", 0)), _wave)
	var best_defeated := maxi(int(config.get_value("records", "best_defeated", 0)), _run_defeated)
	var arena_clears := int(config.get_value("records", "arena_clears", 0))
	if victory and _arena_mode:
		arena_clears += 1
	config.set_value("records", "best_wave", best_wave)
	config.set_value("records", "best_defeated", best_defeated)
	config.set_value("records", "arena_clears", arena_clears)
	config.save(SETTINGS_PATH)
	return {
		"best_wave": best_wave,
		"best_defeated": best_defeated,
		"arena_clears": arena_clears,
	}


func _ready() -> void:
	_configure_builtin_one_way_platforms()
	_player.health_changed.connect(_on_player_health_changed)
	_player.mana_changed.connect(_on_player_mana_changed)
	_player.body_parts_changed.connect(_on_player_body_parts_changed)
	_player.stats_changed.connect(_on_player_stats_changed)
	_player.died.connect(_on_player_died)
	_player.pvp_defeated.connect(_on_pvp_player_defeated)
	_attack_button.pressed.connect(_choose_upgrade.bind(0))
	_speed_button.pressed.connect(_choose_upgrade.bind(1))
	_health_button.pressed.connect(_choose_upgrade.bind(2))
	_shop_continue_button.pressed.connect(_leave_arena_shop)
	_single_button.pressed.connect(_start_single_player)
	_multi_button.pressed.connect(_show_multiplayer_menu)
	_settings_button.pressed.connect(_show_settings_menu)
	_title_quit_button.pressed.connect(_quit_game)
	_apply_settings_button.pressed.connect(_apply_display_settings)
	_settings_back_button.pressed.connect(_on_settings_back)
	_master_volume_slider.value_changed.connect(_preview_audio_settings)
	_sfx_volume_slider.value_changed.connect(_preview_audio_settings)
	_mute_toggle.toggled.connect(_preview_mute_setting)
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
	_pause_resume_button.pressed.connect(_resume_game)
	_pause_settings_button.pressed.connect(_show_pause_settings)
	_pause_restart_button.pressed.connect(_restart_current_run)
	_pause_menu_button.pressed.connect(_return_to_main_menu)
	_pause_quit_button.pressed.connect(_quit_game)
	_result_retry_button.pressed.connect(_restart_current_run)
	_result_menu_button.pressed.connect(_return_to_main_menu)
	_result_quit_button.pressed.connect(_quit_game)
	_ensure_custom_map()
	_ensure_map_editor()
	_ensure_main_menu_map_buttons()
	_ensure_cheat_button()
	call_deferred("_wire_ui_sounds")
	_map_select.add_item("废弃大厅（小型）")
	_map_select.add_item("大型 PvP 竞技场")
	_map_select.add_item("自定义地图（主机保存）")
	_map_select.add_item("合作竞技场模式（30波）")
	_map_select.selected = 1
	_resolution_select.add_item("1920 × 1080（1080p）")
	_resolution_select.add_item("2560 × 1440（2K）")
	_refresh_select.add_item("60 Hz")
	_refresh_select.add_item("120 Hz")
	_refresh_select.add_item("240 Hz")
	_resolution_select.selected = 0
	_refresh_select.selected = 0
	_load_saved_settings()
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
	_pause_overlay.visible = false
	_result_overlay.visible = false
	_set_pvp_mode(false)
	_set_game_active(false)
	call_deferred("_start_pending_run")
	if _is_dedicated_server():
		_port_input.value = _server_port_from_args()
		call_deferred("_host_game")


func _wire_ui_sounds() -> void:
	for node in find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		if not is_instance_valid(button) or button.has_meta("sfx_connected"):
			continue
		button.set_meta("sfx_connected", true)
		button.pressed.connect(_play_ui_button_sound.bind(button))


func _play_ui_button_sound(button: BaseButton) -> void:
	var lowered_name := button.name.to_lower()
	SFX.play("ui_back" if "back" in lowered_name else "ui_confirm", 0.025)


func _ensure_custom_map() -> void:
	if is_instance_valid(_custom_map):
		return
	var existing := get_node_or_null("CustomMap") as CustomMap
	if is_instance_valid(existing):
		_custom_map = existing
	else:
		_custom_map = CUSTOM_MAP_SCRIPT.new() as CustomMap
		_custom_map.name = "CustomMap"
		add_child(_custom_map)
		if has_node("Player"):
			move_child(_custom_map, $Player.get_index())
	_custom_map.visible = false
	_custom_map.set_collision_enabled(false)


func _ensure_challenge_arena_map() -> void:
	if is_instance_valid(_challenge_arena_map):
		return
	_challenge_arena_map = Node2D.new()
	_challenge_arena_map.name = "ChallengeArenaMap"
	_challenge_arena_map.visible = false
	add_child(_challenge_arena_map)
	if has_node("Player"):
		move_child(_challenge_arena_map, $Player.get_index())
	_add_arena_backdrop()
	_add_arena_solid("ChallengeGround", Vector2(1600, 680), Vector2(3200, 80), Color(0.23, 0.075, 0.105, 1.0), false)
	_add_arena_solid("ChallengeLeftWall", Vector2(-20, 360), Vector2(40, 720), Color(0.18, 0.045, 0.07, 1.0), false)
	_add_arena_solid("ChallengeRightWall", Vector2(3220, 360), Vector2(40, 720), Color(0.18, 0.045, 0.07, 1.0), false)
	_add_arena_solid("LowerLeftPlatform", Vector2(620, 520), Vector2(460, 32), Color(0.44, 0.14, 0.18, 1.0), true)
	_add_arena_solid("LowerRightPlatform", Vector2(2580, 520), Vector2(460, 32), Color(0.44, 0.14, 0.18, 1.0), true)
	_add_arena_solid("MiddlePlatform", Vector2(1600, 440), Vector2(620, 32), Color(0.56, 0.18, 0.22, 1.0), true)
	_add_arena_solid("UpperLeftPlatform", Vector2(1040, 300), Vector2(360, 32), Color(0.62, 0.2, 0.26, 1.0), true)
	_add_arena_solid("UpperRightPlatform", Vector2(2160, 300), Vector2(360, 32), Color(0.62, 0.2, 0.26, 1.0), true)
	_add_arena_solid("TopPlatform", Vector2(1600, 210), Vector2(420, 30), Color(0.72, 0.25, 0.3, 1.0), true)


func _add_arena_backdrop() -> void:
	var backdrop := Polygon2D.new()
	backdrop.name = "Backdrop"
	backdrop.polygon = PackedVector2Array([
		Vector2(0, 70), Vector2(CHALLENGE_ARENA_SIZE.x, 70),
		Vector2(CHALLENGE_ARENA_SIZE.x, 720), Vector2(0, 720),
	])
	backdrop.color = Color(0.10, 0.02, 0.04, 0.86)
	backdrop.z_index = -20
	_challenge_arena_map.add_child(backdrop)
	var glow := Polygon2D.new()
	glow.name = "CenterGlow"
	glow.polygon = PackedVector2Array([
		Vector2(920, 650), Vector2(1220, 120), Vector2(1980, 120), Vector2(2280, 650),
	])
	glow.color = Color(1.0, 0.12, 0.18, 0.10)
	glow.z_index = -18
	_challenge_arena_map.add_child(glow)
	var title := Label.new()
	title.name = "ArenaTitle"
	title.text = "ABYSS ARENA"
	title.position = Vector2(1340, 95)
	title.size = Vector2(520, 52)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.55, 0.22, 0.92))
	title.add_theme_font_size_override("font_size", 38)
	_challenge_arena_map.add_child(title)


func _add_arena_solid(node_name: String, center: Vector2, size: Vector2, color: Color, one_way: bool) -> void:
	var body := StaticBody2D.new()
	body.name = node_name
	body.position = center
	body.collision_layer = ONE_WAY_PLATFORM_LAYER if one_way else SOLID_COLLISION_LAYER
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	collision.one_way_collision = one_way
	collision.one_way_collision_margin = 10.0 if one_way else 1.0
	body.add_child(collision)
	var visual := Polygon2D.new()
	visual.name = "Visual"
	var half := size * 0.5
	visual.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	])
	visual.color = color
	body.add_child(visual)
	_challenge_arena_map.add_child(body)


func _configure_builtin_one_way_platforms() -> void:
	for root in [$HallMap, $PvPMap]:
		for child in root.get_children():
			var body := child as StaticBody2D
			if not is_instance_valid(body):
				continue
			if not body.name.contains("Platform"):
				body.collision_layer = SOLID_COLLISION_LAYER
				continue
			body.collision_layer = ONE_WAY_PLATFORM_LAYER
			for shape_node in body.find_children("*", "CollisionShape2D", true, false):
				var shape := shape_node as CollisionShape2D
				shape.one_way_collision = true
				shape.one_way_collision_margin = 10.0


func _ensure_map_editor() -> void:
	if is_instance_valid(_map_editor):
		return
	_ensure_custom_map()
	_map_editor = MAP_EDITOR_SCRIPT.new() as MapEditor
	_map_editor.name = "MapEditor"
	add_child(_map_editor)
	_map_editor.setup(_custom_map)
	_map_editor.closed.connect(_close_map_editor)
	_map_editor.play_requested.connect(_start_custom_single_player)


func _ensure_main_menu_map_buttons() -> void:
	if is_instance_valid(_custom_map_button) and is_instance_valid(_map_editor_button):
		if is_instance_valid(_arena_button):
			return
	var vbox := $UI/StartMenu/Margin/VBox as VBoxContainer
	vbox.add_theme_constant_override("separation", 8)
	_start_menu.offset_top = 20.0
	_start_menu.offset_bottom = 700.0
	for button in [_single_button, _multi_button, _settings_button, _title_quit_button]:
		button.custom_minimum_size = Vector2(0, 50)
		button.add_theme_font_size_override("font_size", 20)
	if not is_instance_valid(_custom_map_button):
		_custom_map_button = Button.new()
		_custom_map_button.name = "CustomMapButton"
		_custom_map_button.text = "自定义地图游戏"
		_custom_map_button.custom_minimum_size = Vector2(0, 50)
		_custom_map_button.add_theme_font_size_override("font_size", 20)
		_custom_map_button.pressed.connect(_start_custom_single_player)
		vbox.add_child(_custom_map_button)
		vbox.move_child(_custom_map_button, _settings_button.get_index())
	if not is_instance_valid(_arena_button):
		_arena_button = Button.new()
		_arena_button.name = "ArenaChallengeButton"
		_arena_button.text = "单人竞技场模式"
		_arena_button.custom_minimum_size = Vector2(0, 50)
		_arena_button.add_theme_font_size_override("font_size", 20)
		_arena_button.pressed.connect(_start_single_arena_mode)
		vbox.add_child(_arena_button)
		vbox.move_child(_arena_button, _settings_button.get_index())
	if not is_instance_valid(_map_editor_button):
		_map_editor_button = Button.new()
		_map_editor_button.name = "MapEditorButton"
		_map_editor_button.text = "地图编辑器"
		_map_editor_button.custom_minimum_size = Vector2(0, 50)
		_map_editor_button.add_theme_font_size_override("font_size", 20)
		_map_editor_button.pressed.connect(_open_map_editor)
		vbox.add_child(_map_editor_button)
		vbox.move_child(_map_editor_button, _settings_button.get_index())


func _start_single_player() -> void:
	_arena_mode = false
	_arena_upgrade_picks_remaining = 0
	_arena_gold = 0
	_arena_shop_open = false
	_using_custom_map = false
	_begin_run(RUN_SINGLE)
	_set_custom_map_enabled(false)
	_player.set_camera_world_width(1280, 720)
	_set_pvp_mode(false)
	_start_menu.visible = false
	_network_panel.visible = false
	_settings_panel.visible = false
	_set_game_active(true)
	if not is_instance_valid(_current_enemy):
		_spawn_next_enemy()


func _start_single_arena_mode() -> void:
	_arena_mode = true
	_arena_upgrade_picks_remaining = 0
	_arena_gold = 0
	_arena_shop_open = false
	_using_custom_map = false
	_begin_run(RUN_ARENA)
	_multiplayer_map = MAP_CHALLENGE_ARENA
	_wave = 1
	_active_enemies.clear()
	_current_enemy = null
	_ensure_challenge_arena_map()
	_set_custom_map_enabled(false)
	_set_pvp_mode(false)
	_start_menu.visible = false
	_network_panel.visible = false
	_settings_panel.visible = false
	_set_game_active(true)
	_player.position = CHALLENGE_PLAYER_SPAWNS[0]
	_player.set_camera_world_width(CHALLENGE_ARENA_SIZE.x, CHALLENGE_ARENA_SIZE.y)
	_player.restore_for_arena_wave()
	_update_wave_label()
	_spawn_arena_wave()


func _start_custom_single_player() -> void:
	_ensure_custom_map()
	_arena_mode = false
	_arena_upgrade_picks_remaining = 0
	if is_instance_valid(_map_editor):
		_map_editor.set_editor_enabled(false)
	_custom_map.position = Vector2.ZERO
	_custom_map.load_from_user_or_default(false)
	_using_custom_map = true
	_begin_run(RUN_CUSTOM)
	_set_pvp_mode(false)
	_start_menu.visible = false
	_network_panel.visible = false
	_settings_panel.visible = false
	_set_game_active(true)
	_set_hall_enabled(false)
	_set_arena_enabled(false)
	_set_custom_map_enabled(true)
	_room_title("自定义地图")
	_player.position = Vector2(170, 610)
	_player.set_camera_world_width(_custom_map.get_world_width(), _custom_map.get_world_height())
	if not is_instance_valid(_current_enemy):
		_spawn_next_enemy()


func _open_map_editor() -> void:
	_ensure_custom_map()
	_ensure_map_editor()
	_using_custom_map = false
	_set_pvp_mode(false)
	_start_menu.visible = false
	_network_panel.visible = false
	_settings_panel.visible = false
	_set_game_active(false)
	$BackgroundLayer.visible = true
	$BackgroundLayer/Background.color = Color(0.035, 0.047, 0.072, 1.0)
	$RoomTitle.visible = true
	_room_title("地图编辑器")
	_custom_map.position = Vector2.ZERO
	_custom_map.load_from_user_or_default(true)
	_custom_map.visible = true
	_custom_map.set_collision_enabled(false)
	_map_editor.set_editor_enabled(true)


func _close_map_editor() -> void:
	if is_instance_valid(_map_editor):
		_map_editor.set_editor_enabled(false)
	if is_instance_valid(_custom_map):
		_custom_map.set_editor_mode(false)
		_custom_map.visible = false
		_custom_map.set_collision_enabled(false)
		_custom_map.position = Vector2.ZERO
	_show_start_menu()


func _show_multiplayer_menu() -> void:
	_using_custom_map = false
	_start_menu.visible = false
	_settings_panel.visible = false
	_network_panel.visible = true
	_set_game_active(false)


func _show_start_menu() -> void:
	if is_instance_valid(_map_editor):
		_map_editor.set_editor_enabled(false)
	if is_instance_valid(_custom_map):
		_custom_map.set_editor_mode(false)
		_custom_map.visible = false
		_custom_map.set_collision_enabled(false)
	_network_panel.visible = false
	_settings_panel.visible = false
	_pause_overlay.visible = false
	_result_overlay.visible = false
	_start_menu.visible = true
	_run_active = false
	_result_open = false
	_game_paused = false
	_settings_context = "menu"
	_arena_mode = false
	_arena_upgrade_picks_remaining = 0
	_set_game_active(false)


func _show_settings_menu() -> void:
	_settings_context = "menu"
	_settings_back_button.text = "返回主菜单"
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
	_apply_audio_settings()
	_save_settings()
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


func _preview_audio_settings(_value: float) -> void:
	_apply_audio_settings()


func _preview_mute_setting(_enabled: bool) -> void:
	_apply_audio_settings()


func _apply_audio_settings() -> void:
	_master_volume_value.text = "%d%%" % roundi(_master_volume_slider.value)
	_sfx_volume_value.text = "%d%%" % roundi(_sfx_volume_slider.value)
	SFX.apply_audio_settings(_master_volume_slider.value, _sfx_volume_slider.value, _mute_toggle.button_pressed)


func _load_saved_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		_master_volume_slider.value = float(config.get_value("audio", "master", 85.0))
		_sfx_volume_slider.value = float(config.get_value("audio", "sfx", 85.0))
		_mute_toggle.button_pressed = bool(config.get_value("audio", "muted", false))
		_resolution_select.selected = clampi(int(config.get_value("display", "resolution", 0)), 0, 1)
		_refresh_select.selected = clampi(int(config.get_value("display", "refresh", 0)), 0, 2)
	_apply_audio_settings()


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("audio", "master", _master_volume_slider.value)
	config.set_value("audio", "sfx", _sfx_volume_slider.value)
	config.set_value("audio", "muted", _mute_toggle.button_pressed)
	config.set_value("display", "resolution", _resolution_select.selected)
	config.set_value("display", "refresh", _refresh_select.selected)
	config.save(SETTINGS_PATH)


func _set_game_active(active: bool) -> void:
	$BackgroundLayer.visible = active or _start_menu.visible \
		or _network_panel.visible or _settings_panel.visible
	for child in get_children():
		var is_map_node := child == $HallMap or child == $PvPMap or child == _custom_map or child == _challenge_arena_map
		if child is CanvasItem and child != $UI and not is_map_node:
			(child as CanvasItem).visible = active
	if not active:
		$HallMap.visible = false
		$PvPMap.visible = false
		_set_challenge_arena_enabled(false)
		_set_custom_map_enabled(false)
	elif _arena_mode:
		_set_arena_enabled(false)
		_set_hall_enabled(false)
		_set_custom_map_enabled(false)
		_set_challenge_arena_enabled(true)
	elif _pvp_mode:
		_apply_multiplayer_map(_multiplayer_map)
	elif _using_custom_map:
		_set_arena_enabled(false)
		_set_hall_enabled(false)
		_set_custom_map_enabled(true)
	else:
		_set_challenge_arena_enabled(false)
		_set_arena_enabled(false)
		_set_hall_enabled(true)
		_set_custom_map_enabled(false)
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
	if is_instance_valid(_cheat_button):
		_cheat_button.visible = active
	get_tree().paused = not active


func _ensure_cheat_button() -> void:
	if is_instance_valid(_cheat_button):
		return
	_cheat_button = Button.new()
	_cheat_button.name = "CheatUpgradeButton"
	_cheat_button.text = "测试强化  O"
	_cheat_button.position = Vector2(18, 660)
	_cheat_button.size = Vector2(138, 42)
	_cheat_button.tooltip_text = "全属性提升 1 级"
	_cheat_button.visible = false
	_cheat_button.pressed.connect(_apply_cheat_upgrade)
	$UI.add_child(_cheat_button)


func _apply_cheat_upgrade() -> void:
	if not is_instance_valid(_player) or not $BackgroundLayer.visible:
		return
	_player.apply_all_attribute_upgrade()
	_status_label.text = "测试强化：全属性提升 1 级"
	_status_label.visible = true


func _selected_port() -> int:
	return int(_port_input.value)


func _host_game() -> void:
	_release_text_input()
	var peer := ENetMultiplayerPeer.new()
	var port := _selected_port()
	var error := peer.create_server(port, MAX_CLIENTS, NETWORK_CHANNEL_COUNT)
	if error != OK:
		_network_status.text = "创建主机失败：%s" % error_string(error)
		return
	multiplayer.multiplayer_peer = peer
	_prepare_existing_player_for_network()
	_player_appearance_seeds[1] = randi()
	_player.set_character_appearance_seed(int(_player_appearance_seeds[1]))
	_player_names[1] = _selected_player_name()
	_player_avatars[1] = _selected_avatar_base64
	_player.set_player_display_name(_player_names[1])
	_player.set_avatar_base64(_selected_avatar_base64)
	_network_players[1] = true
	_pvp_kills[1] = 0
	_network_status.text = "主机已开启，端口 %d（最多 8 人）" % port
	_network_panel.visible = false
	_multiplayer_map = _selected_multiplayer_map_id()
	_arena_mode = _multiplayer_map == MAP_CHALLENGE_ARENA
	_begin_run(RUN_MULTIPLAYER)
	if _arena_mode:
		_wave = 1
		_active_enemies.clear()
		_current_enemy = null
	_set_game_active(true)
	_set_pvp_mode(not _arena_mode)
	if _multiplayer_map == MAP_CUSTOM:
		_ensure_custom_map()
		_custom_map.load_from_user_or_default(false)
		_sync_custom_map.rpc(_custom_map.get_map_data())
	_apply_multiplayer_map.rpc(_multiplayer_map)
	if _arena_mode:
		_start_multiplayer_arena_run()
	_host_button.disabled = true
	_join_button.disabled = true


func _join_game() -> void:
	_release_text_input()
	var address := _address_input.text.strip_edges()
	if address.is_empty():
		address = "127.0.0.1"
	var peer := ENetMultiplayerPeer.new()
	var port := _selected_port()
	var error := peer.create_client(address, port, NETWORK_CHANNEL_COUNT)
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
	_begin_run(RUN_MULTIPLAYER)
	_set_game_active(true)
	_set_pvp_mode(true)
	_submit_player_name.rpc_id(1, _selected_player_name())
	_submit_player_avatar.rpc_id(1, _selected_avatar_base64)


func _is_dedicated_server() -> bool:
	return "--server" in OS.get_cmdline_args() or "--server" in OS.get_cmdline_user_args()


func _has_active_network_session() -> bool:
	var peer := multiplayer.multiplayer_peer
	return peer != null and not (peer is OfflineMultiplayerPeer)


func _server_port_from_args() -> int:
	for argument in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if argument.begins_with("--port="):
			return clampi(int(argument.trim_prefix("--port=")), 1024, 65535)
	return 7000


func _set_pvp_mode(enabled: bool) -> void:
	_pvp_mode = enabled
	for enemy in _active_enemies:
		if is_instance_valid(enemy):
			if enemy is CanvasItem:
				(enemy as CanvasItem).visible = not enabled
			enemy.set_physics_process(not enabled)
	_wave_label.visible = not enabled
	_pvp_score_label.visible = enabled
	_ping_label.visible = enabled
	for node in get_tree().get_nodes_in_group("player"):
		(node as Player).set_pvp_enabled(enabled)
	if enabled:
		_apply_multiplayer_map(_multiplayer_map)
		_update_pvp_scoreboard()
	elif _arena_mode:
		_set_arena_enabled(false)
		_set_hall_enabled(false)
		_set_custom_map_enabled(false)
		_set_challenge_arena_enabled(true)
		_room_title("合作竞技场 · 第 %d / %d 波" % [_wave, ARENA_MAX_WAVE])
	else:
		_set_challenge_arena_enabled(false)
		_set_arena_enabled(false)
		if _using_custom_map:
			_set_hall_enabled(false)
			_set_custom_map_enabled(true)
			_room_title("自定义地图")
		else:
			_set_hall_enabled(true)
			_set_custom_map_enabled(false)
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
	if not _player_appearance_seeds.has(peer_id):
		_player_appearance_seeds[peer_id] = randi()
	for existing_id in _network_players:
		_spawn_network_player.rpc_id(
			peer_id,
			existing_id,
			int(_player_appearance_seeds.get(existing_id, existing_id))
		)
	_spawn_network_player.rpc(peer_id, int(_player_appearance_seeds[peer_id]))
	if _multiplayer_map == MAP_CUSTOM:
		_ensure_custom_map()
		_sync_custom_map.rpc_id(peer_id, _custom_map.get_map_data())
	_apply_multiplayer_map.rpc_id(peer_id, _multiplayer_map)
	if _multiplayer_map == MAP_CHALLENGE_ARENA:
		_sync_arena_wave.rpc_id(peer_id, _wave, _arena_wave_entries(_wave))
		var server_msec := Time.get_ticks_msec()
		for effect_state in _collect_enemy_network_effect_states(true):
			_spawn_enemy_effect_reliable.rpc_id(
				peer_id, effect_state, _enemy_snapshot_sequence, server_msec
			)
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
func _spawn_network_player(peer_id: int, appearance_seed: int = 0) -> void:
	if _network_players.has(peer_id):
		var existing := get_node_or_null("Player_%d" % peer_id) as Player
		if is_instance_valid(existing):
			existing.set_character_appearance_seed(
				appearance_seed if appearance_seed != 0 else peer_id
			)
		_player_appearance_seeds[peer_id] = appearance_seed
		return
	var player := PLAYER_SCENE.instantiate() as Player
	player.name = "Player_%d" % peer_id
	player.position = _spawn_for_peer(peer_id)
	add_child(player)
	player.configure_network_authority(peer_id)
	player.set_character_appearance_seed(appearance_seed if appearance_seed != 0 else peer_id)
	player.set_pvp_enabled(_pvp_mode)
	player.set_player_display_name(str(_player_names.get(peer_id, "玩家 %d" % peer_id)))
	player.set_avatar_base64(str(_player_avatars.get(peer_id, "")))
	player.pvp_defeated.connect(_on_pvp_player_defeated)
	_network_players[peer_id] = true
	_player_appearance_seeds[peer_id] = appearance_seed
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
		_ping_reply.rpc_id(
			multiplayer.get_remote_sender_id(), sent_msec, Time.get_ticks_msec()
		)


@rpc("authority", "call_remote", "unreliable")
func _ping_reply(sent_msec: int, server_msec: int) -> void:
	var receive_msec := Time.get_ticks_msec()
	var latency := maxi(receive_msec - sent_msec, 0)
	_smoothed_latency_msec = float(latency) if _smoothed_latency_msec <= 0.0 \
		else lerpf(_smoothed_latency_msec, float(latency), 0.4)
	var estimated_server_now := float(server_msec) + float(latency) * 0.5
	var measured_offset := estimated_server_now - float(receive_msec)
	_server_clock_offset_msec = measured_offset if is_zero_approx(
		_server_clock_offset_msec
	) else lerpf(_server_clock_offset_msec, measured_offset, 0.25)
	_ping_label.text = (
		"延迟 %d ms · 怪物 30 Hz" if _arena_mode \
		else "延迟 %d ms · 玩家动态 12–60 Hz"
	) % roundi(_smoothed_latency_msec)
	_ping_label.modulate = Color(0.4, 1.0, 0.5) if latency < 80 \
		else Color(1.0, 0.82, 0.25) if latency < 160 else Color(1.0, 0.3, 0.25)


func get_estimated_server_msec() -> int:
	if _has_active_network_session() and multiplayer.is_server():
		return Time.get_ticks_msec()
	return roundi(float(Time.get_ticks_msec()) + _server_clock_offset_msec)


func submit_player_network_state(
	peer_id: int,
	state_sequence: int,
	network_position: Vector2,
	network_velocity: Vector2,
	facing: float,
	sample_server_msec: int,
	reliable_keyframe: bool = false,
	grounded: bool = true
) -> void:
	if not _has_active_network_session() or not (_pvp_mode or _arena_mode):
		return
	if multiplayer.is_server():
		_server_accept_player_network_state(
			peer_id, state_sequence, network_position, network_velocity, facing,
			sample_server_msec, reliable_keyframe, grounded
		)
	elif reliable_keyframe:
		_submit_player_network_keyframe.rpc_id(
			1, peer_id, state_sequence, network_position, network_velocity, facing,
			sample_server_msec, grounded
		)
	else:
		_submit_player_network_state.rpc_id(
			1, peer_id, state_sequence, network_position, network_velocity, facing,
			sample_server_msec, grounded
		)


@rpc("any_peer", "call_remote", "unreliable", 4)
func _submit_player_network_state(
	peer_id: int,
	state_sequence: int,
	network_position: Vector2,
	network_velocity: Vector2,
	facing: float,
	sample_server_msec: int,
	grounded: bool
) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != peer_id:
		return
	_server_accept_player_network_state(
		peer_id, state_sequence, network_position, network_velocity, facing,
		sample_server_msec, false, grounded
	)


@rpc("any_peer", "call_remote", "reliable", 0)
func _submit_player_network_keyframe(
	peer_id: int,
	state_sequence: int,
	network_position: Vector2,
	network_velocity: Vector2,
	facing: float,
	sample_server_msec: int,
	grounded: bool
) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != peer_id:
		return
	_server_accept_player_network_state(
		peer_id, state_sequence, network_position, network_velocity, facing,
		sample_server_msec, true, grounded
	)


func _server_accept_player_network_state(
	peer_id: int,
	state_sequence: int,
	network_position: Vector2,
	network_velocity: Vector2,
	facing: float,
	sample_server_msec: int,
	reliable_keyframe: bool = false,
	grounded: bool = true
) -> void:
	var player := get_node_or_null("Player_%d" % peer_id) as Player
	if not is_instance_valid(player):
		return
	var last_sequence := int(_last_player_state_sequence.get(peer_id, -1))
	if state_sequence <= last_sequence:
		return
	_last_player_state_sequence[peer_id] = state_sequence
	_record_player_position(peer_id, sample_server_msec, network_position)
	if peer_id != multiplayer.get_unique_id():
		player.receive_network_state(
			state_sequence, network_position, network_velocity, facing, 0.0, true,
			grounded
		)
	for target_peer_id in multiplayer.get_peers():
		if target_peer_id == peer_id:
			continue
		if reliable_keyframe:
			_receive_player_network_keyframe.rpc_id(
				target_peer_id, peer_id, state_sequence, network_position,
				network_velocity, facing, grounded
			)
		else:
			_receive_player_network_state.rpc_id(
				target_peer_id, peer_id, state_sequence, network_position,
				network_velocity, facing, grounded
			)


@rpc("authority", "call_remote", "unreliable", 4)
func _receive_player_network_state(
	peer_id: int,
	state_sequence: int,
	network_position: Vector2,
	network_velocity: Vector2,
	facing: float,
	grounded: bool
) -> void:
	_apply_received_player_network_state(
		peer_id, state_sequence, network_position, network_velocity, facing, grounded
	)


@rpc("authority", "call_remote", "reliable", 0)
func _receive_player_network_keyframe(
	peer_id: int,
	state_sequence: int,
	network_position: Vector2,
	network_velocity: Vector2,
	facing: float,
	grounded: bool
) -> void:
	_apply_received_player_network_state(
		peer_id, state_sequence, network_position, network_velocity, facing, grounded
	)


func _apply_received_player_network_state(
	peer_id: int,
	state_sequence: int,
	network_position: Vector2,
	network_velocity: Vector2,
	facing: float,
	grounded: bool
) -> void:
	if peer_id == multiplayer.get_unique_id():
		return
	var player := get_node_or_null("Player_%d" % peer_id) as Player
	if not is_instance_valid(player):
		return
	var prediction_seconds := clampf(
		maxf(_smoothed_latency_msec * 0.5 / 1000.0 + 1.0 / 60.0, 1.0 / 60.0),
		1.0 / 60.0,
		0.08
	)
	player.receive_network_state(
		state_sequence, network_position, network_velocity, facing, prediction_seconds,
		false, grounded
	)


func _record_player_position(peer_id: int, sample_msec: int, position: Vector2) -> void:
	var server_now := Time.get_ticks_msec()
	var safe_time := clampi(sample_msec, server_now - POSITION_HISTORY_MSEC, server_now + 80)
	var history: Array = _player_position_history.get(peer_id, [])
	history.append({"time": safe_time, "position": position})
	var cutoff := server_now - POSITION_HISTORY_MSEC
	while history.size() > 2 and int(history[0].time) < cutoff:
		history.pop_front()
	_player_position_history[peer_id] = history


func _historical_player_position(peer_id: int, target_msec: int, fallback: Vector2) -> Vector2:
	var history: Array = _player_position_history.get(peer_id, [])
	if history.is_empty():
		return fallback
	var best_position := fallback
	var best_delta := 1000000
	for sample in history:
		var delta := absi(int(sample.time) - target_msec)
		if delta < best_delta:
			best_delta = delta
			best_position = sample.position
	return best_position


func _matches_recent_player_position(
	peer_id: int,
	position: Vector2,
	current_position: Vector2,
	tolerance: float
) -> bool:
	if position.distance_to(current_position) <= tolerance:
		return true
	var now := Time.get_ticks_msec()
	var history: Array = _player_position_history.get(peer_id, [])
	for sample in history:
		if now - int(sample.time) <= POSITION_HISTORY_MSEC \
			and position.distance_to(sample.position) <= tolerance:
			return true
	return false


func request_player_combat_effect(
	peer_id: int,
	effect_sequence: int,
	action: String,
	step: int,
	kind: int,
	facing: float
) -> void:
	if multiplayer.is_server():
		_server_relay_player_combat_effect(
			peer_id, effect_sequence, action, step, kind, facing
		)
	else:
		_request_player_combat_effect.rpc_id(
			1, peer_id, effect_sequence, action, step, kind, facing
		)


@rpc("any_peer", "call_remote", "reliable", 1)
func _request_player_combat_effect(
	peer_id: int,
	effect_sequence: int,
	action: String,
	step: int,
	kind: int,
	facing: float
) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != peer_id:
		return
	_server_relay_player_combat_effect(
		peer_id, effect_sequence, action, step, kind, facing
	)


func _server_relay_player_combat_effect(
	peer_id: int,
	effect_sequence: int,
	action: String,
	step: int,
	kind: int,
	facing: float
) -> void:
	if effect_sequence <= int(_last_combat_effect.get(peer_id, -1)):
		return
	_last_combat_effect[peer_id] = effect_sequence
	var player := get_node_or_null("Player_%d" % peer_id) as Player
	if not is_instance_valid(player):
		return
	if peer_id != multiplayer.get_unique_id():
		player.apply_network_combat_effect(action, step, kind, facing)
	for target_peer_id in multiplayer.get_peers():
		if target_peer_id != peer_id:
			_receive_player_combat_effect.rpc_id(
				target_peer_id, peer_id, effect_sequence, action, step, kind, facing
			)


@rpc("authority", "call_remote", "reliable", 1)
func _receive_player_combat_effect(
	peer_id: int,
	_effect_sequence: int,
	action: String,
	step: int,
	kind: int,
	facing: float
) -> void:
	var player := get_node_or_null("Player_%d" % peer_id) as Player
	if is_instance_valid(player) and peer_id != multiplayer.get_unique_id():
		player.apply_network_combat_effect(action, step, kind, facing)


func request_pvp_damage(
	attacker_peer_id: int,
	victim_peer_id: int,
	part_id: StringName,
	damage: int,
	damage_kind: String
) -> void:
	if not _has_active_network_session() or not _pvp_mode:
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
	facing: float,
	attack_position: Vector2 = Vector2.INF,
	attack_server_msec: int = 0
) -> void:
	if not _has_active_network_session() or not _pvp_mode:
		return
	if multiplayer.is_server():
		_server_resolve_pvp_melee_swing(
			attacker_peer_id, attack_sequence, attack_kind, combo_step, facing,
			attack_position, attack_server_msec
		)
	else:
		_request_pvp_melee_swing.rpc_id(
			1, attacker_peer_id, attack_sequence, attack_kind, combo_step, facing,
			attack_position, attack_server_msec
		)


@rpc("any_peer", "call_remote", "reliable", 2)
func _request_pvp_melee_swing(
	attacker_peer_id: int,
	attack_sequence: int,
	attack_kind: int,
	combo_step: int,
	facing: float,
	attack_position: Vector2,
	attack_server_msec: int
) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != attacker_peer_id:
		return
	_server_resolve_pvp_melee_swing(
		attacker_peer_id, attack_sequence, attack_kind, combo_step, facing,
		attack_position, attack_server_msec
	)


func _server_resolve_pvp_melee_swing(
	attacker_peer_id: int,
	attack_sequence: int,
	attack_kind: int,
	combo_step: int,
	facing: float,
	attack_position: Vector2 = Vector2.INF,
	attack_server_msec: int = 0
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
	if attack_position.is_finite() \
		and attacker.global_position.distance_to(attack_position) <= 320.0:
		attacker.global_position = attack_position
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
	var resolved_attack_msec := attack_server_msec if attack_server_msec > 0 \
		else Time.get_ticks_msec()
	for victim_peer_id in _network_players:
		if int(victim_peer_id) == attacker_peer_id:
			continue
		var victim := get_node_or_null("Player_%d" % victim_peer_id) as Player
		if not is_instance_valid(victim):
			continue
		var victim_hit_position := _historical_player_position(
			int(victim_peer_id), resolved_attack_msec, victim.global_position
		)
		var offset := victim_hit_position - attacker.global_position
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
				attacker_peer_id, int(victim_peer_id), part_id, damage, "melee", true
			)


func request_player_regeneration(peer_id: int) -> void:
	if multiplayer.is_server():
		_server_regenerate_player(peer_id)
	else:
		_request_player_regeneration.rpc_id(1, peer_id)


func request_enemy_part_damage(
	enemy: Node,
	part_id: StringName,
	damage: int,
	damage_kind: String,
	source_position: Vector2
) -> bool:
	if not _has_active_network_session() or not _arena_mode or not is_instance_valid(enemy):
		return false
	var enemy_id := str(enemy.name)
	if multiplayer.is_server():
		_server_apply_enemy_part_damage(enemy_id, part_id, damage, damage_kind, source_position)
	else:
		_request_enemy_part_damage.rpc_id(1, enemy_id, String(part_id), damage, damage_kind, source_position)
	return true


@rpc("any_peer", "call_remote", "reliable")
func _request_enemy_part_damage(
	enemy_id: String,
	part_id: String,
	damage: int,
	damage_kind: String,
	source_position: Vector2
) -> void:
	if not multiplayer.is_server() or not _arena_mode:
		return
	if damage_kind not in ["melee", "low", "spell"]:
		return
	var sender_id := multiplayer.get_remote_sender_id()
	var attacker := get_node_or_null("Player_%d" % sender_id) as Player
	var enemy := _find_active_enemy_by_id(enemy_id) as Node2D
	if not is_instance_valid(attacker) or not is_instance_valid(enemy):
		return
	var recent_position_ok := _matches_recent_player_position(
		sender_id, source_position, attacker.global_position, 190.0
	)
	var enemy_distance := source_position.distance_to(enemy.global_position)
	if not recent_position_ok or enemy_distance > 440.0:
		return
	var expected_damage := attacker.get_spell_damage() if damage_kind == "spell" \
		else attacker.get_network_melee_damage()
	_server_apply_enemy_part_damage(
		enemy_id,
		StringName(part_id),
		clampi(damage, 1, maxi(1, expected_damage)),
		damage_kind,
		source_position
	)


func _server_apply_enemy_part_damage(
	enemy_id: String,
	part_id: StringName,
	damage: int,
	damage_kind: String,
	source_position: Vector2
) -> void:
	var enemy := _find_active_enemy_by_id(enemy_id)
	if not is_instance_valid(enemy):
		return
	if enemy.has_method("receive_part_damage_by_id"):
		enemy.receive_part_damage_by_id(part_id, damage, source_position, damage_kind)
	elif enemy.has_method("take_damage"):
		enemy.take_damage(damage, source_position)
	if enemy not in _active_enemies:
		return
	_enemy_snapshot_sequence += 1
	var state: Dictionary = enemy.serialize_network_state() if enemy.has_method("serialize_network_state") else {}
	state["id"] = enemy_id
	state["archetype"] = str(enemy.get_archetype()) if enemy.has_method("get_archetype") else CustomMap.ENEMY_CRYPT_DOG
	_sync_single_enemy_state_reliable.rpc(
		_enemy_snapshot_sequence, Time.get_ticks_msec(), state
	)


func server_apply_enemy_player_damage(
	victim: Player,
	part_id: StringName,
	damage: int,
	source_position: Vector2,
	damage_kind: String = "melee"
) -> bool:
	if not is_instance_valid(victim):
		return false
	if _has_active_network_session() and not multiplayer.is_server():
		return false
	var applied := victim.server_apply_part_damage(part_id, damage, source_position, 0, damage_kind)
	if applied:
		_sync_body_state.rpc(victim.get_multiplayer_authority(), victim.get_body_state(), 0)
		if _arena_mode and _has_active_network_session() and multiplayer.is_server() \
			and victim.is_dead():
			_schedule_coop_respawn(victim.get_multiplayer_authority())
	return applied


func server_apply_enemy_player_status(
	victim: Player,
	effect: String,
	duration: float,
	strength: float = 1.0
) -> void:
	if not is_instance_valid(victim):
		return
	if _has_active_network_session():
		if not multiplayer.is_server():
			return
		_sync_enemy_player_status.rpc(
			victim.get_multiplayer_authority(), effect, duration, strength
		)
	else:
		_apply_enemy_player_status(victim, effect, duration, strength)


@rpc("authority", "call_local", "reliable", 3)
func _sync_enemy_player_status(
	peer_id: int,
	effect: String,
	duration: float,
	strength: float
) -> void:
	var victim := get_node_or_null("Player_%d" % peer_id) as Player
	if not is_instance_valid(victim) and peer_id == 1:
		victim = get_node_or_null("Player") as Player
	if is_instance_valid(victim):
		_apply_enemy_player_status(victim, effect, duration, strength)


func _apply_enemy_player_status(
	victim: Player,
	effect: String,
	duration: float,
	strength: float
) -> void:
	match effect:
		"slow":
			victim.apply_enemy_slow(duration, strength)
		"weakness":
			victim.apply_enemy_weakness(duration, strength)
		"stun":
			victim.apply_combat_stun(duration)


func server_apply_enemy_player_poison(
	victim: Player,
	source_position: Vector2,
	ticks: int,
	interval: float
) -> void:
	if not is_instance_valid(victim):
		return
	if _has_active_network_session() and not multiplayer.is_server():
		return
	_apply_server_poison_ticks(
		victim.get_multiplayer_authority(), source_position, clampi(ticks, 1, 8), maxf(interval, 0.2)
	)


func _apply_server_poison_ticks(
	peer_id: int,
	source_position: Vector2,
	ticks: int,
	interval: float
) -> void:
	for _tick in ticks:
		await get_tree().create_timer(interval, false).timeout
		var victim := get_node_or_null("Player_%d" % peer_id) as Player
		if not is_instance_valid(victim) and peer_id == 1:
			victim = get_node_or_null("Player") as Player
		if not is_instance_valid(victim) or victim.get_health() <= 0:
			return
		var part := _first_living_player_part(victim)
		if is_instance_valid(part):
			server_apply_enemy_player_damage(
				victim, part.part_id, 1, source_position, "poison"
			)


func _first_living_player_part(player: Player) -> BodyPart:
	var parts_root := player.get_node_or_null("Visual/Parts")
	if not is_instance_valid(parts_root):
		return null
	for node in parts_root.get_children():
		var part := node as BodyPart
		if is_instance_valid(part) and part.health > 0:
			return part
	return null


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
	damage_kind: String,
	melee_position_validated: bool = false
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
	var allowed_distance := 950.0 if damage_kind == "spell" else 270.0
	if not melee_position_validated \
		and attacker.global_position.distance_to(victim.global_position) > allowed_distance:
		return
	var resolved_kind := "low" if damage_kind == "melee" \
		and attacker.get_network_attack_kind() == Player.AttackKind.LOW else damage_kind
	var health_before := victim.get_health()
	if victim.server_apply_part_damage(part_id, damage, attacker.global_position, attacker_peer_id, resolved_kind):
		_sync_body_state.rpc(victim_peer_id, victim.get_body_state(), attacker_peer_id)
		if victim.get_health() < health_before:
			if victim.is_guarding() and resolved_kind != "low":
				return
			var knockback_direction := signf(victim.global_position.x - attacker.global_position.x)
			if is_zero_approx(knockback_direction):
				knockback_direction = 1.0
			_apply_pvp_knockback.rpc(
				victim_peer_id,
				Vector2(knockback_direction * victim.knockback_speed, -230.0)
			)


@rpc("authority", "call_local", "reliable", 3)
func _apply_pvp_knockback(peer_id: int, knockback_velocity: Vector2) -> void:
	var player := get_node_or_null("Player_%d" % peer_id) as Player
	if is_instance_valid(player):
		player.apply_network_knockback(knockback_velocity)


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


func broadcast_damage_number(
	world_position: Vector2,
	amount: int,
	damage_kind: String
) -> void:
	if not _has_active_network_session() or not multiplayer.is_server() or amount <= 0:
		return
	_sync_damage_number.rpc(world_position, amount, damage_kind)


@rpc("authority", "call_remote", "reliable", 3)
func _sync_damage_number(
	world_position: Vector2,
	amount: int,
	damage_kind: String
) -> void:
	BodyPart.spawn_damage_number(self, world_position, amount, damage_kind)


@rpc("authority", "call_remote", "reliable", 3)
func _sync_body_state(peer_id: int, state: Dictionary, attacker_peer_id: int) -> void:
	var player := get_node_or_null("Player_%d" % peer_id) as Player
	if is_instance_valid(player):
		player.apply_body_state(state, attacker_peer_id)


@rpc("authority", "call_local", "reliable")
func _sync_custom_map(map_data: Dictionary) -> void:
	_ensure_custom_map()
	_custom_map.build_from_data(map_data, false)
	if _multiplayer_map == MAP_CUSTOM:
		_set_custom_map_enabled(_pvp_mode)


@rpc("authority", "call_local", "reliable")
func _apply_multiplayer_map(map_id: String) -> void:
	_multiplayer_map = _normalize_map_id(map_id)
	_arena_mode = _multiplayer_map == MAP_CHALLENGE_ARENA
	if _arena_mode:
		_pvp_mode = false
	var arena_enabled := _pvp_mode and _multiplayer_map == MAP_ARENA
	var hall_enabled := _pvp_mode and _multiplayer_map == MAP_HALL
	var custom_enabled := _pvp_mode and _multiplayer_map == MAP_CUSTOM
	var challenge_enabled := _arena_mode
	_set_arena_enabled(arena_enabled)
	_set_hall_enabled(hall_enabled)
	_set_custom_map_enabled(custom_enabled)
	_set_challenge_arena_enabled(challenge_enabled)
	$BackgroundLayer/Background.color = Color(0.11, 0.025, 0.045, 1.0) \
		if arena_enabled or challenge_enabled else Color(0.035, 0.047, 0.072, 1.0) \
		if custom_enabled else Color(0.055, 0.075, 0.12, 1.0)
	_room_title(
		"合作竞技场 · 第 %d / %d 波" % [_wave, ARENA_MAX_WAVE] if challenge_enabled else
		"大型 PvP 竞技场" if arena_enabled else
		"PvP · 自定义地图" if custom_enabled else
		"PvP · 废弃大厅"
	)
	_pvp_score_label.visible = _pvp_mode
	_ping_label.visible = _has_active_network_session()
	for node in get_tree().get_nodes_in_group("player"):
		var player := node as Player
		player.set_pvp_enabled(_pvp_mode)
		var world_width := CHALLENGE_ARENA_SIZE.x if challenge_enabled else 2200 if arena_enabled else _custom_map.get_world_width() if custom_enabled else 1280
		var world_height := CHALLENGE_ARENA_SIZE.y if challenge_enabled else _custom_map.get_world_height() if custom_enabled else 720
		player.set_camera_world_width(world_width, world_height)


func _set_arena_enabled(enabled: bool) -> void:
	$PvPMap.visible = enabled
	_set_map_collisions($PvPMap, enabled)


func _set_hall_enabled(enabled: bool) -> void:
	$HallMap.visible = enabled
	_set_map_collisions($HallMap, enabled)


func _set_custom_map_enabled(enabled: bool) -> void:
	_ensure_custom_map()
	if enabled:
		_custom_map.position = Vector2.ZERO
	_custom_map.visible = enabled
	_custom_map.set_editor_mode(false)
	_custom_map.set_collision_enabled(enabled)


func _set_challenge_arena_enabled(enabled: bool) -> void:
	_ensure_challenge_arena_map()
	_challenge_arena_map.visible = enabled
	_set_map_collisions(_challenge_arena_map, enabled)


func _set_map_collisions(map_root: Node, enabled: bool) -> void:
	for node in map_root.find_children("*", "CollisionShape2D", true, false):
		(node as CollisionShape2D).set_deferred("disabled", not enabled)


func _normalize_map_id(map_id: String) -> String:
	if map_id == MAP_HALL or map_id == MAP_CUSTOM or map_id == MAP_CHALLENGE_ARENA:
		return map_id
	return MAP_ARENA


func _selected_multiplayer_map_id() -> String:
	match _map_select.selected:
		0:
			return MAP_HALL
		2:
			return MAP_CUSTOM
		3:
			return MAP_CHALLENGE_ARENA
	return MAP_ARENA


@rpc("authority", "call_local", "reliable")
func _remove_network_player(peer_id: int) -> void:
	var player := get_node_or_null("Player_%d" % peer_id)
	if is_instance_valid(player):
		player.queue_free()
	_network_players.erase(peer_id)
	_player_names.erase(peer_id)
	_player_avatars.erase(peer_id)
	_player_appearance_seeds.erase(peer_id)
	_pvp_kills.erase(peer_id)
	_last_melee_swing.erase(peer_id)
	_last_combat_effect.erase(peer_id)
	_player_position_history.erase(peer_id)
	_last_player_state_sequence.erase(peer_id)
	_pending_pvp_upgrade_offers.erase(peer_id)
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


func _connect_enemy(enemy: Node) -> void:
	if enemy.has_signal("defeated"):
		enemy.defeated.connect(_on_enemy_defeated.bind(enemy))


func register_summoned_enemy(enemy: Node) -> void:
	if not is_instance_valid(enemy) or enemy in _active_enemies:
		return
	_active_enemies.append(enemy)
	_connect_enemy(enemy)


func unregister_summoned_enemy(enemy: Node) -> void:
	_active_enemies.erase(enemy)


func _on_enemy_defeated(enemy: Node = null) -> void:
	if _run_active and (not _has_active_network_session() or multiplayer.is_server()):
		_run_defeated += 1
	if is_instance_valid(enemy):
		if _arena_mode and _has_active_network_session() and multiplayer.is_server():
			_play_enemy_death_reliable.rpc(str(enemy.name))
		_active_enemies.erase(enemy)
	var living_enemies: Array[Node] = []
	for active in _active_enemies:
		if is_instance_valid(active):
			living_enemies.append(active)
	_active_enemies = living_enemies
	if not _active_enemies.is_empty():
		return
	SFX.play("wave_clear", 0.015)
	if _arena_mode:
		_on_arena_wave_cleared()
		return
	if _upgrade_open:
		return
	_upgrade_open = true
	_player.set_controls_enabled(false)
	_status_label.text = "第 %d 波完成！选择一项强化" % _wave
	_status_label.visible = true
	_upgrade_panel.visible = true
	_roll_upgrade_choices()
	_attack_button.grab_focus()


@rpc("authority", "call_remote", "reliable", 3)
func _play_enemy_death_reliable(enemy_id: String) -> void:
	if multiplayer.is_server():
		return
	var enemy := _find_active_enemy_by_id(enemy_id)
	if not is_instance_valid(enemy):
		return
	_enemy_missing_snapshots.erase(enemy_id)
	_active_enemies.erase(enemy)
	if enemy.has_method("play_network_death"):
		enemy.play_network_death()
	else:
		enemy.queue_free()


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
		var price := _upgrade_price(str(choice.id))
		buttons[index].text = "%s\n\n%s%s" % [
			choice.title, choice.detail,
			("\n\n%d 金币" % price) if _arena_shop_open else "",
		]
		buttons[index].disabled = _arena_shop_open and _arena_gold < price
	_refresh_shop_labels()


func _choose_upgrade(index: int) -> void:
	if index < 0 or index >= _offered_upgrades.size():
		return
	var upgrade_id := _offered_upgrades[index]
	if _arena_shop_open:
		var price := _upgrade_price(upgrade_id)
		if _arena_gold < price:
			return
		_arena_gold -= price
		_player.apply_upgrade(upgrade_id)
		SFX.play("ui_upgrade", 0.015)
		_status_label.text = "购买成功：%s" % _upgrade_title(upgrade_id)
		_roll_upgrade_choices()
		return
	if _pvp_upgrade_selection_active:
		_submit_pvp_upgrade_choice(upgrade_id)
		_close_pvp_upgrade_selection()
		return
	var description := ""
	for choice in UPGRADE_POOL:
		if choice.id == upgrade_id:
			description = "%s：%s" % [choice.title, choice.detail]
			break
	_player.apply_upgrade(upgrade_id)
	SFX.play("ui_upgrade", 0.015)
	_finish_upgrade(description)


func _upgrade_price(upgrade_id: String) -> int:
	if upgrade_id in ["fire_build", "frost_build", "lightning_build", "counter_build", "charge_build"]:
		return 60
	if upgrade_id in ["part_health", "rapid_regeneration", "double_jump"]:
		return 50
	return 35


func _upgrade_title(upgrade_id: String) -> String:
	for choice in UPGRADE_POOL:
		if str(choice.id) == upgrade_id:
			return str(choice.title)
	return upgrade_id


func _refresh_shop_labels() -> void:
	_shop_gold_label.visible = _arena_shop_open
	_shop_continue_button.visible = _arena_shop_open
	if _arena_shop_open:
		_shop_gold_label.text = "竞技场金币  %d" % _arena_gold
		$UI/UpgradePanel/Margin/VBox/Title.text = "第 %d 波休整商店" % _wave
	else:
		$UI/UpgradePanel/Margin/VBox/Title.text = "选择一项强化"


func _finish_upgrade(message: String) -> void:
	if not _upgrade_open:
		return
	if _arena_mode:
		_arena_upgrade_picks_remaining -= 1
		if _arena_upgrade_picks_remaining > 0:
			_status_label.text = "%s\n还可再选择 %d 次强化" % [message, _arena_upgrade_picks_remaining]
			_roll_upgrade_choices()
			return
		_upgrade_open = false
		_upgrade_panel.visible = false
		_status_label.text = message
		await get_tree().create_timer(0.65).timeout
		_status_label.visible = false
		_wave += 1
		_update_wave_label()
		_spawn_arena_wave()
		_player.set_controls_enabled(true)
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


func _submit_pvp_upgrade_choice(upgrade_id: String) -> void:
	var peer_id := multiplayer.get_unique_id()
	if multiplayer.is_server():
		_server_choose_pvp_upgrade(peer_id, upgrade_id)
	else:
		_request_pvp_upgrade_choice.rpc_id(1, upgrade_id)


@rpc("any_peer", "call_remote", "reliable")
func _request_pvp_upgrade_choice(upgrade_id: String) -> void:
	if multiplayer.is_server():
		_server_choose_pvp_upgrade(multiplayer.get_remote_sender_id(), upgrade_id)


func _server_choose_pvp_upgrade(peer_id: int, upgrade_id: String) -> void:
	var offered: Array = _pending_pvp_upgrade_offers.get(peer_id, [])
	if upgrade_id not in offered:
		return
	_pending_pvp_upgrade_offers.erase(peer_id)
	_sync_pvp_upgrade.rpc(peer_id, upgrade_id)


func _close_pvp_upgrade_selection() -> void:
	_pvp_upgrade_selection_active = false
	_upgrade_open = false
	_upgrade_panel.visible = false
	_status_label.visible = false
	_offered_upgrades.clear()
	if is_instance_valid(_player):
		_player.set_controls_enabled(true)


func _spawn_next_enemy() -> void:
	if _arena_mode:
		_spawn_arena_wave()
		return
	_active_enemies.clear()
	SFX.play("wave_start", 0.015)
	var spawn_entries: Array[Dictionary] = [{
		"position": _enemy_spawn.position,
		"enemy": CustomMap.ENEMY_HUMAN,
	}]
	if _using_custom_map and is_instance_valid(_custom_map):
		spawn_entries = _custom_map.get_enemy_spawn_entries()
	for spawn_entry in spawn_entries:
		_spawn_enemy_from_entry(spawn_entry)


func _spawn_enemy_from_entry(spawn_entry: Dictionary) -> void:
	var enemy_type := str(spawn_entry.get("enemy", CustomMap.ENEMY_HUMAN))
	var spawn_position: Vector2 = spawn_entry.get("position", _enemy_spawn.position)
	var enemy := _enemy_scene_for_type(enemy_type).instantiate()
	var is_variant := enemy_type in CustomMap.EDITOR_ENEMY_TYPES
	if is_variant:
		enemy.set("archetype", enemy_type)
		if _arena_mode:
			var arena_scaling := _arena_enemy_scaling(_wave)
			enemy.set("health_scale", arena_scaling.x)
			enemy.set("attack_scale", arena_scaling.y)
		enemy.name = "Enemy_%s_%d" % [enemy_type, _active_enemies.size()]
	elif enemy_type == CustomMap.ENEMY_DOG:
		enemy.name = "DogEnemy"
	else:
		enemy.name = "TrainingDummy"
	if not is_variant:
		enemy.set("max_health", 5 + _wave)
	if enemy_type == CustomMap.ENEMY_DOG:
		enemy.set("move_speed", 150.0 + (_wave - 1) * 8.0)
		enemy.set("attack_cooldown", maxf(0.62, 1.05 - (_wave - 1) * 0.035))
	elif not is_variant:
		enemy.set("move_speed", 105.0 + (_wave - 1) * 7.0)
		enemy.set("attack_cooldown", maxf(0.55, 1.0 - (_wave - 1) * 0.04))
	(enemy as Node2D).position = spawn_position
	if enemy.has_method("get_spawn_offset"):
		(enemy as Node2D).position += enemy.get_spawn_offset()
	add_child(enemy)
	_current_enemy = enemy
	_active_enemies.append(enemy)
	_configure_enemy_network_proxy(enemy)
	_connect_enemy(enemy)


func _configure_enemy_network_proxy(enemy: Node) -> void:
	if not _has_active_network_session() or not _arena_mode or multiplayer.is_server():
		return
	if enemy.has_method("set_network_proxy"):
		enemy.set_network_proxy(true)
	else:
		enemy.set_physics_process(false)


func _start_multiplayer_arena_run() -> void:
	_arena_mode = true
	_arena_upgrade_picks_remaining = 0
	_wave = 1
	_player.position = _spawn_for_peer(multiplayer.get_unique_id())
	_player.restore_for_arena_wave()
	_update_wave_label()
	_spawn_arena_wave()


func _spawn_arena_wave() -> void:
	if _has_active_network_session() and not multiplayer.is_server():
		return
	var entries := _arena_wave_entries(_wave)
	if _has_active_network_session():
		_sync_arena_wave.rpc(_wave, entries)
	else:
		_apply_arena_wave(_wave, entries)


@rpc("authority", "call_local", "reliable")
func _sync_arena_wave(wave: int, entries: Array) -> void:
	_apply_arena_wave(wave, entries)


func _apply_arena_wave(wave: int, entries: Array) -> void:
	_arena_mode = true
	_pvp_mode = false
	_wave = wave
	_ensure_challenge_arena_map()
	_set_game_active(true)
	_set_challenge_arena_enabled(true)
	_room_title("合作竞技场 · 第 %d / %d 波" % [_wave, ARENA_MAX_WAVE])
	_update_wave_label()
	SFX.play("wave_start", 0.015)
	_clear_active_enemies()
	for entry in entries:
		if entry is Dictionary:
			_spawn_enemy_from_entry(entry)


func _arena_wave_entries(wave: int) -> Array:
	var plan := _arena_wave_plan(clampi(wave, 1, ARENA_MAX_WAVE))
	var entries: Array = []
	for index in range(plan.size()):
		entries.append({
			"position": CHALLENGE_ENEMY_SPAWNS[index % CHALLENGE_ENEMY_SPAWNS.size()],
			"enemy": str(plan[index]),
		})
	return entries


func _arena_wave_plan(wave: int) -> Array:
	match wave:
		1:
			return [CustomMap.ENEMY_CRYPT_DOG, CustomMap.ENEMY_CRYPT_DOG]
		2:
			return [CustomMap.ENEMY_CRYPT_DOG, CustomMap.ENEMY_CORRUPTED_DOG, CustomMap.ENEMY_VENOM_DOG]
		3:
			return [CustomMap.ENEMY_POUNCE_DOG, CustomMap.ENEMY_STONE_BUG, CustomMap.ENEMY_CRYPT_DOG]
		4:
			return [CustomMap.ENEMY_SKELETON, CustomMap.ENEMY_SKELETON, CustomMap.ENEMY_DIVE_BAT]
		5:
			return [CustomMap.ENEMY_CORRUPTED_DOG, CustomMap.ENEMY_POUNCE_DOG, CustomMap.ENEMY_BOMBER_DOG, CustomMap.ENEMY_VENOM_DOG]
		6:
			return [CustomMap.ENEMY_SKELETON_ARCHER, CustomMap.ENEMY_STONE_BUG, CustomMap.ENEMY_DIVE_BAT, CustomMap.ENEMY_CRYPT_DOG]
		7:
			return [CustomMap.ENEMY_FIRE_SLIME, CustomMap.ENEMY_FIRE_SLIME, CustomMap.ENEMY_CORRUPTED_DOG, CustomMap.ENEMY_POUNCE_DOG]
		8:
			return [CustomMap.ENEMY_SKELETON, CustomMap.ENEMY_SKELETON_ARCHER, CustomMap.ENEMY_DIVE_BAT, CustomMap.ENEMY_VENOM_DOG, CustomMap.ENEMY_STONE_BUG]
		9:
			return [CustomMap.ENEMY_CORRUPTED_DOG, CustomMap.ENEMY_POUNCE_DOG, CustomMap.ENEMY_BOMBER_DOG, CustomMap.ENEMY_FIRE_SLIME, CustomMap.ENEMY_SKELETON_ARCHER]
		10:
			return [CustomMap.ENEMY_ABYSS_HOUND_KING]
		11:
			return [CustomMap.ENEMY_SKELETON_SHIELD, CustomMap.ENEMY_SKELETON_SHIELD, CustomMap.ENEMY_SKELETON_SPEAR, CustomMap.ENEMY_FROST_SLIME]
		12:
			return [CustomMap.ENEMY_SKELETON_BOMBER, CustomMap.ENEMY_DUNGEON_MAGE, CustomMap.ENEMY_LIGHTNING_SLIME]
		13:
			return [CustomMap.ENEMY_SUMMONING_PRIEST, CustomMap.ENEMY_SPLITTING_SLIME, CustomMap.ENEMY_CRYPT_DOG]
		14:
			return [CustomMap.ENEMY_SPIKE_VINE, CustomMap.ENEMY_MAN_EATING_FLOWER, CustomMap.ENEMY_SKELETON_ARCHER]
		15:
			return [CustomMap.ENEMY_SHADOW_ASSASSIN, CustomMap.ENEMY_BERSERKER, CustomMap.ENEMY_FROST_SLIME, _random_arena_elite()]
		16:
			return [CustomMap.ENEMY_BOMB_GOBLIN, CustomMap.ENEMY_CURSED_DOLL, CustomMap.ENEMY_DIVE_BAT, CustomMap.ENEMY_LIGHTNING_SLIME]
		17:
			return [CustomMap.ENEMY_GHOST_MAGE, CustomMap.ENEMY_DUNGEON_TURRET, CustomMap.ENEMY_SKELETON_SHIELD]
		18:
			return [CustomMap.ENEMY_CRYSTAL_DRONE, CustomMap.ENEMY_FIRE_LIZARD, CustomMap.ENEMY_SKELETON_SPEAR, CustomMap.ENEMY_SPLITTING_SLIME]
		19:
			return [CustomMap.ENEMY_HEAVY_HAMMER_GUARD, CustomMap.ENEMY_DUAL_BLADE_HUNTER, CustomMap.ENEMY_SUMMONING_PRIEST, CustomMap.ENEMY_MAN_EATING_FLOWER]
		20:
			return [CustomMap.ENEMY_SKELETON_GENERAL]
		21:
			return [CustomMap.ENEMY_SKELETON_SHIELD, CustomMap.ENEMY_SKELETON_SPEAR, CustomMap.ENEMY_SKELETON_BOMBER, CustomMap.ENEMY_DUNGEON_MAGE, CustomMap.ENEMY_FROST_SLIME]
		22:
			return [CustomMap.ENEMY_SPIKE_VINE, CustomMap.ENEMY_MAN_EATING_FLOWER, CustomMap.ENEMY_SHADOW_ASSASSIN, CustomMap.ENEMY_BOMB_GOBLIN, CustomMap.ENEMY_FIRE_LIZARD]
		23:
			return [CustomMap.ENEMY_DUNGEON_TURRET, CustomMap.ENEMY_CRYSTAL_DRONE, CustomMap.ENEMY_GHOST_MAGE, CustomMap.ENEMY_CURSED_DOLL, CustomMap.ENEMY_LIGHTNING_SLIME]
		24:
			return [CustomMap.ENEMY_BERSERKER, CustomMap.ENEMY_DUAL_BLADE_HUNTER, CustomMap.ENEMY_HEAVY_HAMMER_GUARD, CustomMap.ENEMY_SKELETON_SHIELD]
		25:
			return [CustomMap.ENEMY_SUMMONING_PRIEST, CustomMap.ENEMY_SPLITTING_SLIME, CustomMap.ENEMY_DUNGEON_MAGE, CustomMap.ENEMY_SHADOW_ASSASSIN, CustomMap.ENEMY_SKELETON_SPEAR, _random_arena_elite()]
		26:
			return [CustomMap.ENEMY_SPIKE_VINE, CustomMap.ENEMY_DUNGEON_TURRET, CustomMap.ENEMY_CRYSTAL_DRONE, CustomMap.ENEMY_FIRE_LIZARD, CustomMap.ENEMY_SKELETON_BOMBER]
		27:
			return [CustomMap.ENEMY_HEAVY_HAMMER_GUARD, CustomMap.ENEMY_DUAL_BLADE_HUNTER, CustomMap.ENEMY_BERSERKER, CustomMap.ENEMY_GHOST_MAGE, CustomMap.ENEMY_BOMB_GOBLIN]
		28:
			return [CustomMap.ENEMY_SKELETON_SHIELD, CustomMap.ENEMY_SKELETON_SPEAR, CustomMap.ENEMY_MAN_EATING_FLOWER, CustomMap.ENEMY_CURSED_DOLL, CustomMap.ENEMY_FROST_SLIME, CustomMap.ENEMY_LIGHTNING_SLIME]
		29:
			return [CustomMap.ENEMY_SHADOW_ASSASSIN, CustomMap.ENEMY_HEAVY_HAMMER_GUARD, CustomMap.ENEMY_DUAL_BLADE_HUNTER, CustomMap.ENEMY_CRYSTAL_DRONE, CustomMap.ENEMY_DUNGEON_MAGE, CustomMap.ENEMY_SUMMONING_PRIEST]
		_:
			return [CustomMap.ENEMY_CRIMSON_WITCH]


func _random_arena_elite() -> String:
	return str(ARENA_ELITE_POOL.pick_random())


func _arena_enemy_scaling(wave: int) -> Vector2:
	var completed_waves := maxf(0.0, float(wave - 1))
	return Vector2(
		1.0 + completed_waves * ARENA_HEALTH_GROWTH_PER_WAVE,
		1.0 + completed_waves * ARENA_ATTACK_GROWTH_PER_WAVE
	)


func _clear_active_enemies() -> void:
	for enemy in _active_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_active_enemies.clear()
	_current_enemy = null


func _on_arena_wave_cleared() -> void:
	if _has_active_network_session() and not multiplayer.is_server():
		return
	if _upgrade_open:
		return
	if _wave >= ARENA_MAX_WAVE:
		if _has_active_network_session():
			_show_arena_clear.rpc(_run_defeated, _run_elapsed)
		else:
			_show_arena_clear(_run_defeated, _run_elapsed)
		return
	if _wave % 5 == 0:
		if _has_active_network_session():
			_begin_arena_shop.rpc(_wave)
		else:
			_begin_arena_shop(_wave)
	else:
		if _has_active_network_session():
			_begin_arena_rest.rpc(_wave)
		else:
			_begin_arena_rest(_wave)


@rpc("authority", "call_local", "reliable")
func _begin_arena_rest(cleared_wave: int) -> void:
	_upgrade_open = true
	_player.set_controls_enabled(false)
	_status_label.text = "第 %d 波完成，短暂休整……" % cleared_wave
	_status_label.visible = true
	await get_tree().create_timer(1.4).timeout
	if _arena_shop_open:
		return
	_upgrade_open = false
	_status_label.visible = false
	_wave = cleared_wave + 1
	_update_wave_label()
	if not _has_active_network_session() or multiplayer.is_server():
		_spawn_arena_wave()
	_player.set_controls_enabled(true)


@rpc("authority", "call_local", "reliable")
func _begin_arena_shop(cleared_wave: int) -> void:
	_arena_shop_open = true
	_upgrade_open = true
	_arena_upgrade_picks_remaining = 0
	_arena_gold += 70 + cleared_wave * 3
	_player.set_controls_enabled(false)
	_status_label.text = "第 %d 波完成：没有自动回血，利用休整购买强化" % cleared_wave
	_status_label.visible = false
	_upgrade_panel.visible = true
	_roll_upgrade_choices()
	_attack_button.grab_focus()


func _leave_arena_shop() -> void:
	if not _arena_shop_open:
		return
	if _has_active_network_session():
		if multiplayer.is_server():
			_resume_arena_after_shop.rpc(_wave + 1)
		else:
			_upgrade_panel.visible = false
			_status_label.text = "等待主机结束休整……"
	else:
		_resume_arena_after_shop(_wave + 1)


@rpc("authority", "call_local", "reliable")
func _resume_arena_after_shop(next_wave: int) -> void:
	_arena_shop_open = false
	_upgrade_open = false
	_upgrade_panel.visible = false
	_shop_gold_label.visible = false
	_shop_continue_button.visible = false
	_status_label.visible = false
	_wave = next_wave
	_update_wave_label()
	if not _has_active_network_session() or multiplayer.is_server():
		_spawn_arena_wave()
	_player.set_controls_enabled(true)


@rpc("authority", "call_local", "reliable")
func _show_arena_clear(defeated_count: int = -1, elapsed_seconds: float = -1.0) -> void:
	_upgrade_open = false
	_upgrade_panel.visible = false
	SFX.play("wave_clear", 0.0, 2.0)
	_show_run_result(true, defeated_count, elapsed_seconds)


@rpc("authority", "call_local", "reliable")
func _restore_arena_players() -> void:
	for node in get_tree().get_nodes_in_group("player"):
		var player := node as Player
		if is_instance_valid(player):
			player.restore_for_arena_wave()


func _enemy_scene_for_type(enemy_type: String) -> PackedScene:
	if enemy_type in CustomMap.EDITOR_ENEMY_TYPES:
		return VARIANT_ENEMY_SCENE
	return DOG_ENEMY_SCENE if enemy_type == CustomMap.ENEMY_DOG else ENEMY_SCENE


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
	if _arena_mode and _has_active_network_session():
		var peer_id := _player.get_multiplayer_authority()
		_player.set_controls_enabled(false)
		_status_label.text = "倒下了，%0.1f 秒后重新加入战斗……" % COOP_RESPAWN_DELAY
		_status_label.visible = true
		if multiplayer.is_server():
			_schedule_coop_respawn(peer_id)
		else:
			_request_coop_respawn.rpc_id(1, peer_id)
		return
	_show_run_result(false)


@rpc("any_peer", "call_remote", "reliable", 3)
func _request_coop_respawn(peer_id: int) -> void:
	if not multiplayer.is_server() or not _arena_mode:
		return
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	_schedule_coop_respawn(peer_id)


func _schedule_coop_respawn(peer_id: int) -> void:
	if _coop_respawn_pending.has(peer_id):
		return
	_coop_respawn_pending[peer_id] = true
	await get_tree().create_timer(COOP_RESPAWN_DELAY, false).timeout
	if not _arena_mode or not _has_active_network_session():
		_coop_respawn_pending.erase(peer_id)
		return
	_respawn_coop_player.rpc(peer_id, _spawn_for_peer(peer_id))
	_coop_respawn_pending.erase(peer_id)


@rpc("authority", "call_local", "reliable", 3)
func _respawn_coop_player(peer_id: int, spawn_position: Vector2) -> void:
	var player := get_node_or_null("Player_%d" % peer_id) as Player
	if not is_instance_valid(player):
		return
	player.revive_for_coop(spawn_position)
	if peer_id == multiplayer.get_unique_id():
		_status_label.visible = false
		if _game_paused:
			player.set_controls_enabled(false)


func _on_pvp_player_defeated(victim_peer_id: int, killer_peer_id: int) -> void:
	if not _pvp_mode or not multiplayer.is_server() or _pvp_round_ending:
		return
	_pending_pvp_upgrade_offers.erase(victim_peer_id)
	if killer_peer_id > 0 and killer_peer_id != victim_peer_id and _network_players.has(killer_peer_id):
		_pvp_kills[killer_peer_id] = int(_pvp_kills.get(killer_peer_id, 0)) + 1
		if int(_pvp_kills[killer_peer_id]) < PVP_KILLS_TO_WIN:
			_offer_pvp_upgrade_to_player(killer_peer_id)
	_sync_pvp_scores.rpc(_pvp_kills)
	_respawn_pvp_player.rpc(victim_peer_id, _spawn_for_peer(victim_peer_id))
	if int(_pvp_kills.get(killer_peer_id, 0)) >= PVP_KILLS_TO_WIN:
		_finish_pvp_round(killer_peer_id)


func _offer_pvp_upgrade_to_player(peer_id: int) -> void:
	var player := get_node_or_null("Player_%d" % peer_id) as Player
	if not is_instance_valid(player):
		return
	var pool := UPGRADE_POOL.duplicate()
	if player.has_double_jump_upgrade():
		pool = pool.filter(func(choice: Dictionary) -> bool: return choice.id != "double_jump")
	if player.has_rapid_regeneration():
		pool = pool.filter(func(choice: Dictionary) -> bool: return choice.id != "rapid_regeneration")
	pool.shuffle()
	var choices: Array[String] = []
	for index in mini(3, pool.size()):
		choices.append(str(pool[index].id))
	_pending_pvp_upgrade_offers[peer_id] = choices.duplicate()
	if peer_id == multiplayer.get_unique_id():
		_show_pvp_upgrade_offer(choices)
	elif peer_id in multiplayer.get_peers():
		_show_pvp_upgrade_offer.rpc_id(peer_id, choices)


@rpc("authority", "call_remote", "reliable")
func _show_pvp_upgrade_offer(choices: Array[String]) -> void:
	if choices.size() != 3:
		return
	_pvp_upgrade_selection_active = true
	_upgrade_open = true
	_offered_upgrades = choices.duplicate()
	_player.set_controls_enabled(false)
	_status_label.text = "击杀奖励：选择一项强化"
	_status_label.visible = true
	_upgrade_panel.visible = true
	var buttons := [_attack_button, _speed_button, _health_button]
	for index in 3:
		for choice in UPGRADE_POOL:
			if choice.id == choices[index]:
				buttons[index].text = "%s\n\n%s" % [choice.title, choice.detail]
				break
	_attack_button.grab_focus()


@rpc("authority", "call_local", "reliable")
func _sync_pvp_upgrade(peer_id: int, upgrade_id: String) -> void:
	var player := get_node_or_null("Player_%d" % peer_id) as Player
	if is_instance_valid(player):
		player.apply_upgrade(upgrade_id)


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
	_pvp_upgrade_selection_active = false
	_upgrade_open = false
	_upgrade_panel.visible = false
	_offered_upgrades.clear()
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
	if _multiplayer_map == MAP_CHALLENGE_ARENA:
		return CHALLENGE_PLAYER_SPAWNS[(peer_id - 1) % CHALLENGE_PLAYER_SPAWNS.size()]
	if _multiplayer_map == MAP_CUSTOM and is_instance_valid(_custom_map):
		var custom_spawns := _custom_map.get_player_spawn_positions()
		return custom_spawns[(peer_id - 1) % custom_spawns.size()]
	var spawns := HALL_SPAWNS if _multiplayer_map == MAP_HALL else PVP_SPAWNS
	return spawns[(peer_id - 1) % spawns.size()]


func get_pvp_kills(peer_id: int) -> int:
	return int(_pvp_kills.get(peer_id, 0))


func is_pvp_round_ending() -> bool:
	return _pvp_round_ending
