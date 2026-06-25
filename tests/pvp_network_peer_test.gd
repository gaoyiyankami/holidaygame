extends Node

const PORT := 17123
const TEST_TIMEOUT := 18.0

var _role := ""
var _elapsed := 0.0
var _attack_timer := 0.0
var _attacks_sent := 0
var _initial_attack_damage := 0
var _initial_upgrade_count := 0
var _connected := false
var _choice_submitted := false
var _choice_wait := 0.0
var _knockback_seen := false

@onready var _main := $Main


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			_role = argument.trim_prefix("--role=")
	_main.get_node("UI/NetworkPanel/VBox/PortRow/PortInput").value = PORT
	if _role == "server":
		_main.get_node("UI/NetworkPanel/VBox/NameInput").text = "E2E Server"
		_main.call("_host_game")
		print("E2E SERVER READY")
	elif _role in ["attacker", "victim"]:
		_main.get_node("UI/NetworkPanel/VBox/NameInput").text = _role
		_main.get_node("UI/NetworkPanel/VBox/AddressInput").text = "127.0.0.1"
		multiplayer.connected_to_server.connect(_on_connected)
		_main.call("_join_game")
	else:
		push_error("Missing --role")
		get_tree().quit(2)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= TEST_TIMEOUT:
		print("E2E %s TIMEOUT players=%s" % [_role, _main.get("_network_players")])
		get_tree().quit(1)
		return
	if _role == "server":
		return
	if not _connected:
		return
	var local_id := multiplayer.get_unique_id()
	var local_player := _main.get_node_or_null("Player_%d" % local_id) as Player
	if not is_instance_valid(local_player):
		return
	if _role == "victim":
		if not _knockback_seen and absf(local_player.velocity.x) > 100.0:
			_knockback_seen = true
			print("E2E VICTIM KNOCKBACK velocity=%s" % local_player.velocity)
		local_player.global_position = Vector2(780, 610)
		local_player.get_node("Visual").scale.x = -1.0
		return
	if _main.get("_network_players").size() < 3:
		return
	local_player.global_position = Vector2(700, 610)
	local_player.get_node("Visual").scale.x = 1.0
	if _initial_attack_damage == 0:
		_initial_attack_damage = local_player.attack_damage
		_initial_upgrade_count = local_player.get_applied_upgrade_count()
	_attack_timer -= delta
	if _attack_timer <= 0.0 and _attacks_sent < 12:
		_attack_timer = 0.9
		_attacks_sent += 1
		local_player.call("_start_attack", 1)
		local_player.call("_begin_active_attack")
		_main.request_pvp_melee_swing(
			local_id, _attacks_sent, Player.AttackKind.NORMAL, 1, 1.0
		)
	var kills: int = _main.get_pvp_kills(local_id)
	if kills > 0:
		if not _choice_submitted:
			var choices: Array = _main.get("_offered_upgrades")
			var panel_visible: bool = _main.get_node("UI/UpgradePanel").visible
			print("E2E UPGRADE OFFER choices=%s panel=%s" % [choices, panel_visible])
			if choices.size() != 3 or not panel_visible:
				get_tree().quit(1)
				return
			_choice_submitted = true
			_main.call("_choose_upgrade", 0)
			return
		_choice_wait += delta
		var upgraded: bool = local_player.get_applied_upgrade_count() > _initial_upgrade_count
		if not upgraded and _choice_wait < 3.0:
			return
		print("E2E ATTACKER RESULT kills=%d upgraded=%s count=%d damage=%d" % [
			kills,
			upgraded,
			local_player.get_applied_upgrade_count(),
			local_player.attack_damage,
		])
		get_tree().quit(0 if upgraded else 1)


func _on_connected() -> void:
	_connected = true
	print("E2E %s CONNECTED id=%d" % [_role, multiplayer.get_unique_id()])
