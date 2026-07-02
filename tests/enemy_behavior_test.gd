extends Node


func _ready() -> void:
	$Main.call("_start_single_player")
	await get_tree().physics_frame
	await get_tree().physics_frame

	var player := $Main/Player as Player
	var enemy := $Main/TrainingDummy as TrainingDummy
	enemy.set_physics_process(false)
	enemy.position = player.position + Vector2(120, 0)
	enemy.get_node("Visual").scale.x = 1.0
	enemy.velocity = Vector2.ZERO

	enemy.call("_change_state", TrainingDummy.State.TURN)
	enemy.set("_queued_turn_direction", -1.0)
	await get_tree().create_timer(0.06, true).timeout
	var turn_not_instant: bool = enemy.get_node("Visual").scale.x > 0.0
	enemy.call("_tick_timed_state", enemy.turn_duration + 0.01, TrainingDummy.State.IDLE)
	var turn_finished: bool = enemy.get_node("Visual").scale.x < 0.0

	enemy.set("_attack_variant", 1)
	enemy.call("_change_state", TrainingDummy.State.ATTACK)
	var attack_area := enemy.get_node("Visual/AttackArea") as Area2D
	var variant_range: bool = attack_area.scale.x > 1.2 and attack_area.position.x > 44.0
	enemy.call("_change_state", TrainingDummy.State.RECOVERY)
	var range_reset: bool = attack_area.scale.is_equal_approx(Vector2.ONE)

	enemy.call("_change_state", TrainingDummy.State.JUMP_WINDUP)
	var windup_velocity_ok: bool = absf(enemy.velocity.y) < 1.0
	enemy.call("_tick_timed_state", enemy.jump_windup + 0.03, TrainingDummy.State.JUMP)
	var entered_jump: bool = enemy.velocity.y < -100.0

	print("Enemy behavior test: turn_delay=%s turn_done=%s variant=%s reset=%s jump_windup=%s jump=%s" % [
		turn_not_instant,
		turn_finished,
		variant_range,
		range_reset,
		windup_velocity_ok,
		entered_jump,
	])
	get_tree().quit(0 if turn_not_instant and turn_finished and variant_range \
		and range_reset and windup_velocity_ok and entered_jump else 1)
