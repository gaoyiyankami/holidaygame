extends SceneTree


func _initialize() -> void:
	call_deferred("_render")


func _render() -> void:
	var scene := load("res://scenes/main/main.tscn") as PackedScene
	var main := scene.instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	main.call("_show_settings_menu")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tmp_settings_ui.png"))
	main.call("_start_single_arena_mode")
	main.call("_clear_active_enemies")
	main.set("_wave", 5)
	main.call("_begin_arena_shop", 5)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tmp_shop_ui.png"))
	quit()
