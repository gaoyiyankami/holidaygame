extends Node


func _ready() -> void:
	$Main.call("_start_single_player")
	await get_tree().physics_frame
	await get_tree().physics_frame

	var player := $Main/Player as Player
	var torso := _find_part(player, "torso")
	var source := player.global_position + Vector2(100, 0)
	player.set("_invincibility_timer", 0.0)
	torso.receive_damage(1, source)
	var normal_before := torso.health
	await get_tree().create_timer(6.25).timeout
	var normal_regeneration := torso.health == normal_before + 1

	player.apply_upgrade("rapid_regeneration")
	player.set("_invincibility_timer", 0.0)
	torso.receive_damage(1, source)
	var rapid_before := torso.health
	await get_tree().create_timer(3.25).timeout
	var rapid_regeneration := torso.health == rapid_before + 1

	print("Real regeneration test: normal=%s rapid=%s" % [
		normal_regeneration,
		rapid_regeneration,
	])
	get_tree().quit(0 if normal_regeneration and rapid_regeneration else 1)


func _find_part(player: Player, id: StringName) -> BodyPart:
	for node in player.get_node("Visual/Parts").get_children():
		var part := node as BodyPart
		if part.part_id == id:
			return part
	return null
