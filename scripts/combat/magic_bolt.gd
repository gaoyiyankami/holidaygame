class_name MagicBolt
extends Area2D

@export var speed: float = 720.0
@export var damage: int = 2
@export var lifetime: float = 1.4

var direction: float = 1.0
var caster: Node


func _ready() -> void:
	add_to_group("magic_bolt")
	area_entered.connect(_on_area_entered)


func destroy_by_attack() -> void:
	set_deferred("monitoring", false)
	collision_layer = 0
	collision_mask = 0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.6, 0.15), 0.12)
	tween.tween_property(self, "modulate:a", 0.0, 0.12)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	position.x += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if area is BodyPart:
		var part := area as BodyPart
		if part.actor == caster:
			return
		if part.actor is Player and multiplayer.has_multiplayer_peer():
			if is_instance_valid(caster) and caster is Player:
				(caster as Player).request_network_damage(part.actor as Player, part.part_id, damage, "spell")
			queue_free()
		elif part.receive_damage(damage, global_position, "spell"):
			queue_free()
