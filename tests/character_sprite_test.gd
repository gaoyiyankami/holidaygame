extends Node


func _ready() -> void:
	await get_tree().process_frame
	var main := $Main
	main.call("_start_single_player")
	await get_tree().process_frame
	var player := main.get_node("Player") as Player
	var pixel_character := player.get_node("Visual/PixelCharacter") as Node2D
	var textured_layers := 0
	for child in pixel_character.get_children():
		if child is Sprite2D and (child as Sprite2D).texture != null:
			textured_layers += 1
	var idle_region := (pixel_character.get_child(0) as Sprite2D).region_rect
	player.velocity = Vector2(300, 0)
	player.call("_animate_body_parts")
	await get_tree().process_frame
	var moving_region := (pixel_character.get_child(0) as Sprite2D).region_rect
	var same_seed := player.get_character_appearance_seed()
	player.set_character_appearance_seed(same_seed)
	var seed_stable := player.get_character_appearance_seed() == same_seed
	var male_seen := false
	var female_seen := false
	var all_variants_loaded := true
	for seed in range(1, 25):
		player.set_character_appearance_seed(seed)
		var loaded := 0
		for child in pixel_character.get_children():
			if child is Sprite2D and (child as Sprite2D).texture != null:
				loaded += 1
		all_variants_loaded = all_variants_loaded and loaded >= 6
		var skin_path := (pixel_character.get_child(0) as Sprite2D).texture.resource_path
		male_seen = male_seen or "Male Skin" in skin_path
		female_seen = female_seen or "Female Skin" in skin_path
	player.set_character_appearance_seed(same_seed)
	print("Character sprite test: layers=%d animated=%s seed=%s genders=%s variants=%s" % [
		textured_layers,
		idle_region != moving_region,
		seed_stable,
		male_seen and female_seen,
		all_variants_loaded,
	])
	get_tree().quit(0 if textured_layers >= 6 and idle_region != moving_region \
		and seed_stable and male_seen and female_seen and all_variants_loaded else 1)
