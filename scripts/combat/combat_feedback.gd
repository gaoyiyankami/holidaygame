extends Node

var _hitstop_active: bool = false
var _shake_tween: Tween
var _headless: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_headless = DisplayServer.get_name() == "headless"


func hit(world_position: Vector2, material: String, strength: float = 1.0, allow_hitstop: bool = true) -> void:
	SFX.play_at("hit_%s" % material, world_position, 0.065)
	if _headless:
		return
	_spawn_hit_sparks(world_position, material, strength)
	_shake_camera(strength)
	if allow_hitstop and strength >= 0.8:
		_apply_hitstop(0.035 if strength < 1.35 else 0.055)


func _spawn_hit_sparks(world_position: Vector2, material: String, strength: float) -> void:
	var host := get_tree().current_scene
	if host == null:
		return
	var root := Node2D.new()
	root.global_position = world_position
	root.z_index = 140
	host.add_child(root)
	var color := _material_color(material)
	var count := clampi(roundi(5.0 + strength * 3.0), 5, 10)
	for index in count:
		var shard := Polygon2D.new()
		var size := randf_range(2.5, 5.5) * minf(strength, 1.6)
		shard.polygon = PackedVector2Array([
			Vector2(-size, 0), Vector2(0, -size * 0.45),
			Vector2(size, 0), Vector2(0, size * 0.45),
		])
		shard.color = color.lightened(randf_range(0.0, 0.35))
		root.add_child(shard)
		var direction := Vector2.RIGHT.rotated(TAU * float(index) / count + randf_range(-0.35, 0.35))
		var tween := shard.create_tween().set_parallel(true)
		tween.tween_property(shard, "position", direction * randf_range(18.0, 36.0) * strength, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(shard, "modulate:a", 0.0, 0.16).set_delay(0.04)
	var flash := Polygon2D.new()
	flash.polygon = PackedVector2Array([Vector2(0, -9), Vector2(9, 0), Vector2(0, 9), Vector2(-9, 0)])
	flash.color = Color.WHITE
	root.add_child(flash)
	var root_tween := root.create_tween().set_parallel(true)
	root_tween.tween_property(flash, "scale", Vector2(2.0, 2.0) * strength, 0.11)
	root_tween.tween_property(flash, "modulate:a", 0.0, 0.11)
	root_tween.chain().tween_callback(root.queue_free).set_delay(0.12)


func _material_color(material: String) -> Color:
	match material:
		"metal":
			return Color(0.82, 0.9, 1.0, 1.0)
		"stone":
			return Color(0.72, 0.6, 0.45, 1.0)
		"magic":
			return Color(0.48, 0.82, 1.0, 1.0)
		_:
			return Color(1.0, 0.28, 0.2, 1.0)


func _shake_camera(strength: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		return
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if not is_instance_valid(camera):
		return
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	var amount := clampf(2.0 + strength * 2.5, 2.0, 7.0)
	_shake_tween = camera.create_tween()
	for index in 4:
		_shake_tween.tween_property(camera, "offset", Vector2(randf_range(-amount, amount), randf_range(-amount, amount)), 0.025)
	_shake_tween.tween_property(camera, "offset", Vector2.ZERO, 0.04)


func _apply_hitstop(duration: float) -> void:
	if _hitstop_active:
		return
	_hitstop_active = true
	Engine.time_scale = 0.16
	_reset_hitstop_after(duration)


func _reset_hitstop_after(duration: float) -> void:
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstop_active = false


func _exit_tree() -> void:
	Engine.time_scale = 1.0
