class_name PvPTrap
extends Area2D

@export var damage: int = 2
@export var cooldown: float = 0.8

var _cooldowns: Dictionary = {}


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	for id in _cooldowns.keys():
		_cooldowns[id] = maxf(_cooldowns[id] - delta, 0.0)


func _on_body_entered(body: Node2D) -> void:
	if not body is Player:
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	var id := body.get_instance_id()
	if _cooldowns.get(id, 0.0) > 0.0:
		return
	_cooldowns[id] = cooldown
	var player := body as Player
	player.receive_network_part_damage.rpc("left_leg", damage, global_position, 0)
