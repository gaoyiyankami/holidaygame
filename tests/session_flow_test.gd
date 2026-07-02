extends Node


func _ready() -> void:
	var main_scene := load("res://scenes/main/main.tscn") as PackedScene
	var main := main_scene.instantiate()
	add_child(main)
	await get_tree().process_frame

	var start_vbox := main.get_node("UI/StartMenu/Margin/VBox") as VBoxContainer
	var title_flow_ok: bool = main.get_node_or_null("UI/StartMenu/Margin/VBox/QuitButton") != null \
		and start_vbox.get_child_count() == 9 \
		and main.get_node("UI/StartMenu").size.y >= 650.0

	main.call("_start_single_arena_mode")
	await get_tree().physics_frame
	main.set("_run_elapsed", 125.0)
	main.set("_run_defeated", 8)
	main.call("_open_pause_menu")
	var single_pause_ok: bool = bool(main.get("_game_paused")) \
		and main.get_node("UI/PauseOverlay").visible \
		and get_tree().paused \
		and "已暂停" in main.get_node("UI/PauseOverlay/Panel/Margin/VBox/Context").text

	main.call("_show_pause_settings")
	var pause_settings_ok: bool = main.get_node("UI/SettingsPanel").visible \
		and not main.get_node("UI/PauseOverlay").visible \
		and main.get("_settings_context") == "pause"
	main.call("_on_settings_back")
	pause_settings_ok = pause_settings_ok \
		and main.get_node("UI/PauseOverlay").visible \
		and not main.get_node("UI/SettingsPanel").visible
	main.call("_resume_game")
	var resume_ok: bool = not get_tree().paused \
		and not bool(main.get("_game_paused")) \
		and not main.get_node("UI/PauseOverlay").visible

	var online_peer := ENetMultiplayerPeer.new()
	var online_peer_ok := online_peer.create_server(17431, 1, 4) == OK
	multiplayer.multiplayer_peer = online_peer
	main.call("_open_pause_menu")
	var online_menu_ok: bool = online_peer_ok and bool(main.get("_game_paused")) \
		and not get_tree().paused \
		and "仍在继续" in main.get_node("UI/PauseOverlay/Panel/Margin/VBox/Context").text \
		and not main.get_node("UI/PauseOverlay/Panel/Margin/VBox/RestartButton").visible
	main.call("_resume_game")
	multiplayer.multiplayer_peer = null

	main.call("_on_player_died")
	var result_summary := str(main.get_node("UI/ResultOverlay/Panel/Margin/VBox/Summary").text)
	var result_ok: bool = main.get_node("UI/ResultOverlay").visible \
		and bool(main.get("_result_open")) \
		and get_tree().paused \
		and "02:05" in result_summary \
		and "击败敌人  8" in result_summary \
		and main.get_node("UI/ResultOverlay/Panel/Margin/VBox/RetryButton").visible

	var config := ConfigFile.new()
	var records_ok: bool = config.load("user://settings.cfg") == OK \
		and int(config.get_value("records", "best_wave", 0)) >= 1 \
		and int(config.get_value("records", "best_defeated", 0)) >= 8
	print("Session flow test: title=%s pause=%s settings=%s resume=%s online=%s result=%s records=%s" % [
		title_flow_ok, single_pause_ok, pause_settings_ok, resume_ok,
		online_menu_ok, result_ok, records_ok,
	])
	get_tree().paused = false
	get_tree().quit(0 if title_flow_ok and single_pause_ok and pause_settings_ok \
		and resume_ok and online_menu_ok and result_ok and records_ok else 1)
