extends Node


func _ready() -> void:
	SFX.enabled = true
	var assets_ok := SFX.SETTINGS.size() == 40
	var durations_ok := true
	for key in SFX.SETTINGS:
		var stream: AudioStream = SFX.get("_streams").get(key)
		assets_ok = assets_ok and stream != null
		durations_ok = durations_ok and stream != null and stream.get_length() >= 0.05

	SFX.reset_limiter()
	var active_before := int(SFX.get("_active_count"))
	SFX.play("ui_confirm")
	SFX.play("ui_confirm")
	var limiter_ok := int(SFX.get("_active_count")) == active_before + 1
	SFX.play_at("enemy_melee", Vector2(120, 80))
	await get_tree().process_frame
	var spatial_ok := false
	for child in SFX.get_children():
		if child is AudioStreamPlayer2D:
			spatial_ok = true
			break

	print("Audio SFX test: assets=%s durations=%s limiter=%s spatial=%s" % [
		assets_ok, durations_ok, limiter_ok, spatial_ok,
	])
	for child in SFX.get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer2D:
			child.stop()
			child.stream = null
			child.queue_free()
	await get_tree().create_timer(0.25).timeout
	get_tree().quit(0 if assets_ok and durations_ok and limiter_ok and spatial_ok else 1)
