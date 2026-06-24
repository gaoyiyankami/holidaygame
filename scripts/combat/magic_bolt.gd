class_name MagicBolt
extends Area2D

@export var speed: float = 720.0
@export var damage: int = 2
@export var lifetime: float = 1.4

var direction: float = 1.0
var caster: Node


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	position.x += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if area is BodyPart:
		var part := area as BodyPart
		if part.actor == caster:
			return
		if part.actor is Player and multiplayer.has_multiplayer_peer():
			(part.actor as Player).receive_network_part_damage.rpc(
				part.part_id,
				damage,
				global_position
			)
			queue_free()
		elif part.receive_damage(damage, global_position):
			queue_free()
