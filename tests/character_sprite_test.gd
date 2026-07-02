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
	var resized_and_facing_right := pixel_character.position.is_equal_approx(Vector2(0, -29)) \
		and pixel_character.scale.is_equal_approx(Vector2(-1.98, 1.98))
	var shield_on_right := (player.get_node("Visual/Shield") as Node2D).position.x > 0.0
	var same_seed := player.get_character_appearance_seed()
	player.set_character_appearance_seed(same_seed)
	var seed_stable := player.get_character_appearance_seed() == same_seed
	var canonical_loaded := (pixel_character.get_child(0) as Sprite2D).texture.resource_path.ends_with("Male Skin1.png") \
		and (pixel_character.get_child(2) as Sprite2D).texture.resource_path.ends_with("Pants.png") \
		and (pixel_character.get_child(3) as Sprite2D).texture.resource_path.ends_with("Shirt.png") \
		and (pixel_character.get_child(6) as Sprite2D).texture.resource_path.ends_with("Male Hair1.png")
	var redrawn_action := player.get_node("Visual/RedrawnAction") as Sprite2D
	var redrawn_ready := redrawn_action.texture.get_width() == 1536 \
		and redrawn_action.texture.get_height() == 720
	player.call("_start_attack", 2, Player.AttackKind.NORMAL)
	player.call("_update_redrawn_action_visual")
	var combo_two_row := int(redrawn_action.region_rect.position.y / 144.0) == 1
	var attack_area := player.get_node("Visual/SwordPivot/AttackArea") as Area2D
	var attack_shape := (attack_area.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	var normal_range_aligned := attack_area.position.is_equal_approx(Vector2(58, 0)) \
		and attack_shape.size.is_equal_approx(Vector2(76, 62)) \
		and is_zero_approx((attack_area.get_node("SlashVisual") as Polygon2D).rotation)
	player.call("_update_pixel_frame", true)
	var combo_two_windup_start := Vector2i(
		int((pixel_character.get_child(0) as Sprite2D).region_rect.position.x / 80.0),
		int((pixel_character.get_child(0) as Sprite2D).region_rect.position.y / 64.0)
	) == Vector2i(0, 5)
	player.set("_attack_timer", float(player.call("_get_windup_duration", 2)) * 0.4)
	player.call("_update_pixel_frame", true)
	var combo_two_windup_end := int((pixel_character.get_child(0) as Sprite2D).region_rect.position.x / 80.0) == 1
	player.call("_begin_active_attack")
	player.call("_update_pixel_frame", true)
	var white_slash := attack_area.get_node("WhiteSlash") as Sprite2D
	var combo_two_active_start := int((pixel_character.get_child(0) as Sprite2D).region_rect.position.x / 80.0) == 1
	player.set("_attack_timer", float(player.call("_get_active_duration", 2)) * 0.5)
	player.call("_update_pixel_frame", true)
	player.call("_animate_body_parts")
	var combo_two_active_middle := int((pixel_character.get_child(0) as Sprite2D).region_rect.position.x / 80.0) == 2 \
		and white_slash.visible and white_slash.modulate.a > 0.9 \
		and white_slash.texture.resource_path.ends_with("adventurer_white_slash.png") \
		and is_zero_approx(pixel_character.rotation) \
		and pixel_character.scale.is_equal_approx(Vector2(-1.98, 1.98))
	player.set("_attack_timer", float(player.call("_get_active_duration", 2)) * 0.15)
	player.call("_update_pixel_frame", true)
	var combo_two_active_end := int((pixel_character.get_child(0) as Sprite2D).region_rect.position.x / 80.0) == 3
	player.call("_begin_attack_recovery")
	player.call("_update_pixel_frame", true)
	var combo_two_recovery_start := int((pixel_character.get_child(0) as Sprite2D).region_rect.position.x / 80.0) == 3
	player.set("_attack_timer", float(player.call("_get_recovery_duration", 2)) * 0.5)
	player.call("_update_pixel_frame", true)
	var combo_two_recovery_middle := int((pixel_character.get_child(0) as Sprite2D).region_rect.position.x / 80.0) == 0
	player.set("_attack_timer", 0.0)
	player.call("_update_pixel_frame", true)
	var combo_two_recovery_end := int((pixel_character.get_child(0) as Sprite2D).region_rect.position.x / 80.0) == 0
	var combo_two_animation := combo_two_windup_start and combo_two_windup_end \
		and combo_two_active_start and combo_two_active_middle and combo_two_active_end \
		and combo_two_recovery_start and combo_two_recovery_middle and combo_two_recovery_end
	player.call("_finish_attack")
	player.call("_start_attack", 3, Player.AttackKind.NORMAL)
	player.call("_update_redrawn_action_visual")
	var combo_three_row := int(redrawn_action.region_rect.position.y / 144.0) == 2
	player.call("_update_pixel_frame", true)
	var combo_three_windup := int((pixel_character.get_child(0) as Sprite2D).region_rect.position.x / 80.0) == 0
	player.call("_begin_active_attack")
	player.set("_attack_timer", float(player.call("_get_active_duration", 3)) * 0.5)
	player.call("_update_pixel_frame", true)
	var combo_three_active := int((pixel_character.get_child(0) as Sprite2D).region_rect.position.x / 80.0) == 2
	player.call("_finish_attack")
	player.call("_start_block")
	player.call("_update_redrawn_action_visual")
	player.call("_update_pixel_frame", true)
	var defense_sheathe := redrawn_action.visible \
		and int(redrawn_action.region_rect.position.y / 144.0) == 4 \
		and int(redrawn_action.region_rect.position.x / 192.0) == 0
	player.set("_block_timer", 0.2)
	player.call("_update_block_equipment_visual")
	player.call("_update_redrawn_action_visual")
	var defense_ready := defense_sheathe \
		and int(redrawn_action.region_rect.position.x / 192.0) >= 6 \
		and not (pixel_character.get_child(7) as Sprite2D).visible \
		and not (player.get_node("Visual/Shield") as Node2D).visible
	player.call("_stop_block", false)
	player.call("_update_redrawn_action_visual")
	var defense_released := (pixel_character.get_child(7) as Sprite2D).visible \
		and not redrawn_action.visible and pixel_character.visible
	player.call("_start_attack", 1, Player.AttackKind.DASH)
	player.call("_update_redrawn_action_visual")
	var dash_row := int(redrawn_action.region_rect.position.y / 144.0) == 3
	player.call("_update_pixel_frame", true)
	var dash_windup := int((pixel_character.get_child(0) as Sprite2D).region_rect.position.x / 80.0) == 0
	player.call("_begin_active_attack")
	player.set("_attack_timer", float(player.call("_get_active_duration", 1)) * 0.35)
	player.call("_update_pixel_frame", true)
	player.call("_animate_body_parts")
	var dash_attack_ready := dash_row and dash_windup \
		and int((pixel_character.get_child(0) as Sprite2D).region_rect.position.x / 80.0) == 3 \
		and white_slash.visible and redrawn_action.visible
	player.call("_finish_attack")
	player.call("cast_spell")
	player.call("_update_pixel_frame", true)
	player.call("_update_spell_burst")
	var spell_ready := int((pixel_character.get_child(0) as Sprite2D).region_rect.position.y / 64.0) == 4 \
		and (pixel_character.get_node("SpellBurst") as Sprite2D).visible
	print("Character sprite test: layers=%d animated=%s scale=%s seed=%s canonical=%s redrawn=%s actions=%s" % [
		textured_layers,
		idle_region != moving_region,
		resized_and_facing_right,
		seed_stable,
		canonical_loaded,
		redrawn_ready,
		normal_range_aligned and combo_two_row and combo_two_animation \
			and combo_three_row and combo_three_windup \
			and combo_three_active and defense_ready and defense_released \
			and dash_attack_ready and shield_on_right and spell_ready,
	])
	get_tree().quit(0 if textured_layers >= 6 and idle_region != moving_region \
		and resized_and_facing_right and seed_stable and canonical_loaded and redrawn_ready \
		and normal_range_aligned and combo_two_row and combo_two_animation \
		and combo_three_row and combo_three_windup and combo_three_active \
		and defense_ready and defense_released \
		and dash_attack_ready and shield_on_right and spell_ready else 1)
