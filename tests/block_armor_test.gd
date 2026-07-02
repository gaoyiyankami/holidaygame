extends Node


func _ready() -> void:
	var scene := load("res://scenes/player/player.tscn") as PackedScene
	var player := scene.instantiate() as Player
	add_child(player)
	await get_tree().process_frame
	var torso := _find_part(player, &"torso")
	var before := torso.health
	player.call("_start_block")
	player.set("_block_timer", 0.35)
	torso.receive_damage(4, player.global_position + Vector2(80, 0), "melee")
	var reduced_damage_ok: bool = torso.health == before - 2
	var armor_ok: bool = player.is_blocking() \
		and player.get_movement_stun_time() == 0.0 \
		and player.get_attack_stun_time() == 0.0 \
		and absf(player.velocity.x) < 0.01
	print("Block armor test: reduced=%s armor=%s" % [reduced_damage_ok, armor_ok])
	get_tree().quit(0 if reduced_damage_ok and armor_ok else 1)


func _find_part(player: Player, id: StringName) -> BodyPart:
	for node in player.get_node("Visual/Parts").get_children():
		var part := node as BodyPart
		if part.part_id == id:
			return part
	return null
