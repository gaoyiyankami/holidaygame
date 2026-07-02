extends SceneTree


func _initialize() -> void:
	call_deferred("_render")


func _render() -> void:
	print("SESSION RENDER START")
	var scene := load("res://scenes/main/main.tscn") as PackedScene
	var main := scene.instantiate()
	root.add_child(main)
	current_scene = main
	paused = false
	await process_frame
	print("SESSION RENDER MENU")
	await _capture("res://tmp_main_menu_ui.png")
	print("SESSION RENDER PAUSE SETUP")
	main.call("_start_single_arena_mode")
	await physics_frame
	main.call("_open_pause_menu")
	paused = false
	await _capture("res://tmp_pause_ui.png")
	print("SESSION RENDER RESULT SETUP")
	main.call("_resume_game")
	main.set("_run_elapsed", 754.0)
	main.set("_run_defeated", 67)
	main.set("_wave", 24)
	main.call("_show_run_result", false)
	paused = false
	await _capture("res://tmp_result_ui.png")
	print("SESSION RENDER DONE")
	paused = false
	quit()


func _capture(path: String) -> void:
	print("CAPTURE %s FRAME" % path)
	await process_frame
	print("CAPTURE %s DRAW" % path)
	await RenderingServer.frame_post_draw
	print("CAPTURE %s SAVE" % path)
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
