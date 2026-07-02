extends Node

const ROOT := "res://assets/audio/sfx/"
const SETTINGS := {
	"ui_confirm": ["ui_confirm.wav", -7.0, 55],
	"ui_back": ["ui_back.wav", -8.0, 55],
	"ui_upgrade": ["ui_upgrade.wav", -5.0, 120],
	"footstep_1": ["footstep_1.wav", -13.0, 90],
	"footstep_2": ["footstep_2.wav", -13.0, 90],
	"jump": ["jump.wav", -8.0, 80],
	"land": ["land.wav", -9.0, 100],
	"dash": ["dash.wav", -6.0, 100],
	"sword_swing_1": ["sword_swing_1.wav", -7.0, 45],
	"sword_swing_2": ["sword_swing_2.wav", -7.0, 45],
	"sword_swing_3": ["sword_swing_3.wav", -5.0, 70],
	"sword_hit": ["sword_hit.wav", -5.0, 45],
	"hit_flesh": ["hit_flesh.wav", -6.0, 45],
	"hit_metal": ["hit_metal.wav", -5.0, 55],
	"hit_stone": ["hit_stone.wav", -5.0, 55],
	"hit_magic": ["hit_magic.wav", -6.0, 55],
	"player_hurt": ["player_hurt.wav", -4.0, 100],
	"block": ["block.wav", -4.0, 70],
	"perfect_block": ["perfect_block.wav", -2.0, 120],
	"spell_charge": ["spell_charge.wav", -8.0, 180],
	"charge_ready": ["charge_ready.wav", -4.0, 180],
	"super_ready": ["super_ready.wav", -2.0, 240],
	"spell_cast": ["spell_cast.wav", -5.0, 80],
	"charged_wave": ["charged_wave.wav", -3.0, 180],
	"super_wave": ["super_wave.wav", -1.0, 260],
	"enemy_windup": ["enemy_windup.wav", -13.0, 90],
	"enemy_melee": ["enemy_melee.wav", -11.0, 55],
	"enemy_ranged": ["enemy_ranged.wav", -11.0, 70],
	"enemy_hit": ["enemy_hit.wav", -12.0, 45],
	"enemy_death": ["enemy_death.wav", -8.0, 70],
	"enemy_spawn": ["enemy_spawn.wav", -13.0, 65],
	"bomb_warning": ["bomb_warning.wav", -7.0, 180],
	"explosion": ["explosion.wav", -3.0, 130],
	"summon": ["summon.wav", -6.0, 220],
	"frost": ["frost.wav", -8.0, 110],
	"lightning": ["lightning.wav", -6.0, 110],
	"poison": ["poison.wav", -9.0, 120],
	"wave_start": ["wave_start.wav", -5.0, 300],
	"wave_clear": ["wave_clear.wav", -4.0, 300],
	"boss_intro": ["boss_intro.wav", -2.0, 500],
}

var enabled: bool = true
var volume_offset_db: float = 0.0
var _streams: Dictionary = {}
var _last_played_msec: Dictionary = {}
var _active_count: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_sfx_bus()
	if DisplayServer.get_name() == "headless":
		enabled = false
	for key in SETTINGS:
		var file_stem := str(SETTINGS[key][0]).get_basename()
		_streams[key] = load(ROOT + file_stem + ".ogg")


func _ensure_sfx_bus() -> void:
	if AudioServer.get_bus_index(&"SFX") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, &"SFX")
		AudioServer.set_bus_send(AudioServer.bus_count - 1, &"Master")


func apply_audio_settings(master_percent: float, sfx_percent: float, muted: bool) -> void:
	var master_index := AudioServer.get_bus_index(&"Master")
	var sfx_index := AudioServer.get_bus_index(&"SFX")
	AudioServer.set_bus_volume_db(master_index, linear_to_db(clampf(master_percent / 100.0, 0.001, 1.0)))
	AudioServer.set_bus_mute(master_index, muted)
	if sfx_index >= 0:
		AudioServer.set_bus_volume_db(sfx_index, linear_to_db(clampf(sfx_percent / 100.0, 0.001, 1.0)))


func _exit_tree() -> void:
	for child in get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer2D:
			child.stop()
			child.stream = null
	_streams.clear()
	_active_count = 0


func play(key: String, pitch_variation: float = 0.0, volume_db_offset: float = 0.0) -> void:
	if not _can_play(key):
		return
	var player := AudioStreamPlayer.new()
	player.stream = _streams[key]
	_configure_player(player, key, pitch_variation, volume_db_offset)
	add_child(player)
	player.finished.connect(_release_player.bind(player))
	player.play()


func play_at(key: String, world_position: Vector2, pitch_variation: float = 0.0, volume_db_offset: float = 0.0) -> void:
	if not _can_play(key):
		return
	var player := AudioStreamPlayer2D.new()
	player.stream = _streams[key]
	player.global_position = world_position
	player.max_distance = 1250.0
	player.attenuation = 1.15
	_configure_player(player, key, pitch_variation, volume_db_offset)
	add_child(player)
	player.finished.connect(_release_player.bind(player))
	player.play()


func _can_play(key: String) -> bool:
	if not enabled or not SETTINGS.has(key) or not _streams.has(key) or _streams[key] == null:
		return false
	if _active_count >= 32:
		return false
	var now := Time.get_ticks_msec()
	var cooldown := int(SETTINGS[key][2])
	if now - int(_last_played_msec.get(key, -100000)) < cooldown:
		return false
	_last_played_msec[key] = now
	_active_count += 1
	return true


func _configure_player(player: Node, key: String, pitch_variation: float, extra_volume: float) -> void:
	player.volume_db = float(SETTINGS[key][1]) + volume_offset_db + extra_volume
	player.pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
	player.bus = &"SFX"


func _release_player(player: Node) -> void:
	_active_count = maxi(0, _active_count - 1)
	if is_instance_valid(player):
		player.queue_free()


func reset_limiter() -> void:
	_last_played_msec.clear()
