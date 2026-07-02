class_name MagicBolt
extends Area2D

@export var speed: float = 720.0
@export var damage: int = 2
@export var lifetime: float = 1.4

var direction: float = 1.0
var caster: Node
var power_tier: int = 0
var fire_level: int = 0
var frost_level: int = 0
var lightning_level: int = 0
var _pierce_remaining: int = 0
var _hit_actors: Dictionary = {}


func _ready() -> void:
	add_to_group("magic_bolt")
	_configure_power_visual()
	area_entered.connect(_on_area_entered)


func _configure_power_visual() -> void:
	var glow := get_node_or_null("Glow") as Polygon2D
	var core := get_node_or_null("Core") as Polygon2D
	var facing := 1.0 if direction >= 0.0 else -1.0
	if power_tier == 1:
		speed = 610.0
		lifetime = 1.8
		_pierce_remaining = 4
		scale = Vector2(2.35 * facing, 1.55)
		if is_instance_valid(glow):
			glow.color = Color(0.12, 0.7, 1.0, 0.58)
		if is_instance_valid(core):
			core.color = Color(0.72, 0.96, 1.0, 1.0)
		_add_wave_fin(Color(0.35, 0.86, 1.0, 0.72), 1)
	elif power_tier >= 2:
		speed = 540.0
		lifetime = 2.1
		_pierce_remaining = 9
		scale = Vector2(3.65 * facing, 2.25)
		if is_instance_valid(glow):
			glow.color = Color(0.18, 0.62, 1.0, 0.7)
		if is_instance_valid(core):
			core.color = Color(0.94, 1.0, 1.0, 1.0)
		_add_wave_fin(Color(0.48, 0.9, 1.0, 0.88), 1)
		_add_wave_fin(Color.WHITE, 2, 0.52)
	else:
		scale.x = absf(scale.x) * facing


func _add_wave_fin(color: Color, layer: int, size_multiplier: float = 1.0) -> void:
	var fin := Polygon2D.new()
	fin.polygon = PackedVector2Array([
		Vector2(-18, 0), Vector2(-8, -10), Vector2(12, -7), Vector2(27, 0),
		Vector2(12, 7), Vector2(-8, 10),
	])
	fin.color = color
	fin.scale = Vector2(size_multiplier, size_multiplier)
	fin.z_index = layer
	add_child(fin)


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
		var actor_id := part.actor.get_instance_id() if is_instance_valid(part.actor) else part.get_instance_id()
		if power_tier > 0 and _hit_actors.has(actor_id):
			return
		var applied := false
		if part.actor is Player and multiplayer.has_multiplayer_peer():
			if is_instance_valid(caster) and caster is Player:
				(caster as Player).request_network_damage(part.actor as Player, part.part_id, damage, "spell")
			applied = true
		else:
			applied = part.receive_damage(damage, global_position, "spell")
		if not applied:
			return
		if fire_level > 0 and is_instance_valid(part.actor):
			var burn := preload("res://scripts/combat/damage_over_time.gd").new()
			burn.configure(part.actor, global_position, fire_level, 2 + fire_level, 0.65)
			part.actor.add_child(burn)
		if frost_level > 0 and part.actor.has_method("apply_movement_stun"):
			part.actor.apply_movement_stun(0.16 + frost_level * 0.1)
		if lightning_level > 0 and part.actor.has_method("apply_combat_stun"):
			part.actor.apply_combat_stun(0.08 + lightning_level * 0.04)
		if power_tier <= 0:
			queue_free()
			return
		_hit_actors[actor_id] = true
		_pierce_remaining -= 1
		if _pierce_remaining <= 0:
			queue_free()
