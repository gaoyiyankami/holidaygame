extends Node2D

const ENEMY_SCENE := preload("res://scenes/enemies/training_dummy.tscn")

var _wave: int = 1
var _current_enemy: TrainingDummy
var _upgrade_open: bool = false

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


func _ready() -> void:
	_player.health_changed.connect(_on_player_health_changed)
	_player.mana_changed.connect(_on_player_mana_changed)
	_player.body_parts_changed.connect(_on_player_body_parts_changed)
	_player.stats_changed.connect(_on_player_stats_changed)
	_player.died.connect(_on_player_died)
	_attack_button.pressed.connect(_choose_attack_upgrade)
	_speed_button.pressed.connect(_choose_speed_upgrade)
	_health_button.pressed.connect(_choose_health_upgrade)

	_on_player_health_changed(_player.get_health(), _player.max_health)
	_on_player_mana_changed(_player.get_mana(), _player.max_mana)
	_on_player_stats_changed(_player.attack_damage, _player.get_attack_speed_bonus())
	_update_wave_label()

	_current_enemy = $TrainingDummy as TrainingDummy
	_connect_enemy(_current_enemy)


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
