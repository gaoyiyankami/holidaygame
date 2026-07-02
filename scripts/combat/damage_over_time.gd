class_name DamageOverTime
extends Node

var _actor: Node
var _source_position: Vector2
var _damage: int = 1
var _ticks_left: int = 0
var _interval: float = 1.0


func configure(actor: Node, source_position: Vector2, damage: int, ticks: int, interval: float) -> void:
	_actor = actor
	_source_position = source_position
	_damage = damage
	_ticks_left = ticks
	_interval = interval


func _ready() -> void:
	_tick_loop()


func _tick_loop() -> void:
	while _ticks_left > 0 and is_instance_valid(_actor):
		await get_tree().create_timer(_interval, false).timeout
		if not is_instance_valid(_actor):
			break
		var part := _first_living_part(_actor)
		if is_instance_valid(part):
			part.receive_damage(_damage, _source_position, "poison")
		_ticks_left -= 1
	queue_free()


func _first_living_part(actor: Node) -> BodyPart:
	var parts_root := actor.get_node_or_null("Visual/Parts")
	if not is_instance_valid(parts_root):
		return null
	for node in parts_root.get_children():
		if node is BodyPart and (node as BodyPart).health > 0:
			return node as BodyPart
	return null
