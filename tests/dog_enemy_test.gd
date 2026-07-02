extends Node


func _ready() -> void:
	$Main.call("_start_single_player")
	await get_tree().physics_frame
	await get_tree().physics_frame

	var player := $Main/Player as Player
	var old_enemy := $Main.get_node_or_null("TrainingDummy")
	if is_instance_valid(old_enemy):
		old_enemy.queue_free()

	var dog_scene := load("res://scenes/enemies/dog_enemy.tscn") as PackedScene
	var dog := dog_scene.instantiate() as DogEnemy
	$Main.add_child(dog)
	dog.position = player.position + Vector2(70, 0)
	await get_tree().physics_frame

	var parts := dog.get_node("Visual/Parts").get_children()
	var four_parts := parts.size() == 4 \
		and _find_part(parts, "head") != null \
		and _find_part(parts, "body") != null \
		and _find_part(parts, "front_legs") != null \
		and _find_part(parts, "back_legs") != null

	var speed_before := dog.get_movement_multiplier()
	var front_legs := _find_part(parts, "front_legs")
	front_legs.receive_damage(999, player.global_position)
	var leg_debuff := dog.get_movement_multiplier() < speed_before

	dog.get_node("Visual").scale.x = 1.0
	dog.call("_change_state", DogEnemy.State.TURN)
	dog.set("_queued_turn_direction", -1.0)
	var turn_not_instant: bool = dog.get_node("Visual").scale.x > 0.0
	dog.call("_tick_timed_state", dog.turn_duration + 0.01, DogEnemy.State.IDLE)
	var turn_finished: bool = dog.get_node("Visual").scale.x < 0.0

	var torso := _find_part(player.get_node("Visual/Parts").get_children(), "torso")
	var health_before := torso.health
	dog.position = player.position + Vector2(54, 0)
	dog.get_node("Visual").scale.x = -1.0
	dog.call("_change_state", 3)
	await get_tree().create_timer(0.12, true).timeout
	var pounce_started := absf(dog.velocity.x) > 40.0
	await get_tree().create_timer(0.28, true).timeout
	var pounce_hit := torso.health < health_before

	print("Dog enemy test: parts=%s leg_debuff=%s turn_delay=%s turn_done=%s pounce=%s hit=%s" % [
		four_parts,
		leg_debuff,
		turn_not_instant,
		turn_finished,
		pounce_started,
		pounce_hit,
	])
	get_tree().quit(0 if four_parts and leg_debuff and turn_not_instant \
		and turn_finished and pounce_started and pounce_hit else 1)


func _find_part(parts: Array[Node], id: StringName) -> BodyPart:
	for node in parts:
		var part := node as BodyPart
		if part.part_id == id:
			return part
	return null
