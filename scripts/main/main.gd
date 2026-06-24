extends Node2D

@onready var _player: Player = $Player
@onready var _health_label: Label = $UI/HealthPanel/HealthLabel
@onready var _status_label: Label = $UI/StatusLabel


func _ready() -> void:
	_player.health_changed.connect(_on_player_health_changed)
	_player.died.connect(_on_player_died)
	_on_player_health_changed(_player.get_health(), _player.max_health)


func _on_player_health_changed(current_health: int, max_health: int) -> void:
	_health_label.text = "玩家生命  %d / %d" % [current_health, max_health]


func _on_player_died() -> void:
	_status_label.text = "挑战失败，即将重新开始……"
	_status_label.visible = true
	await get_tree().create_timer(1.2).timeout
	get_tree().reload_current_scene()
