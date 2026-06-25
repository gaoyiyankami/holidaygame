class_name Player
extends CharacterBody2D

enum AttackPhase {
	NONE,
	WINDUP,
	ACTIVE,
	RECOVERY,
}

enum AttackKind {
	NORMAL,
	AIR,
	DASH,
	LOW,
}

signal health_changed(current_health: int, max_health: int)
signal body_parts_changed(summary: String)
signal stats_changed(attack_damage: int, attack_speed_bonus: int)
signal mana_changed(current_mana: int, max_mana: int)
signal died
signal pvp_defeated(victim_peer_id: int, killer_peer_id: int)

@export_category("Movement")
@export var move_speed: float = 300.0
@export var acceleration: float = 1800.0
@export var air_acceleration: float = 1100.0
@export var friction: float = 2200.0
@export var jump_velocity: float = -620.0

@export_category("Jump Feel")
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12
@export var jump_cut_multiplier: float = 0.45

@export_category("Combat")
@export var attack_damage: int = 3
@export var combo_reset_time: float = 0.5
@export var spell_damage: int = 2

@export_category("Magic")
@export var max_mana: int = 100
@export var spell_cost: int = 25
@export var mana_regen_per_second: float = 7.0
@export var health_regen_interval: float = 6.0

@export_category("Dash")
@export var dash_speed: float = 760.0
@export var dash_duration: float = 0.16
@export var dash_cooldown: float = 0.65

@export_category("Health")
@export var max_health: int = 5
@export var invincibility_duration: float = 0.75
@export var hurt_lock_duration: float = 0.18
@export var knockback_speed: float = 460.0

@export_category("Block")
@export var perfect_block_duration: float = 0.2
@export var block_cooldown: float = 1.0
@export var block_damage_reduction: float = 0.5
@export var block_move_multiplier: float = 0.3

var _gravity: float = 1600.0
var _health: int
var _mana: int
var _mana_regen_buffer: float = 0.0
var _next_health_regen_msec: int = 0
var _rapid_regeneration: bool = false
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _extra_jumps: int = 0
var _extra_jumps_left: int = 0
var _attack_timer: float = 0.0
var _attack_phase: AttackPhase = AttackPhase.NONE
var _attack_kind: AttackKind = AttackKind.NORMAL
var _attack_cooldown_timer: float = 0.0
var _combo_reset_timer: float = 0.0
var _combo_step: int = 0
var _combo_queued: bool = false
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _dash_direction: float = 1.0
var _invincibility_timer: float = 0.0
var _hurt_lock_timer: float = 0.0
var _is_dead: bool = false
var _controls_enabled: bool = true
var _attack_speed_multiplier: float = 1.0
var _arm_attack_multiplier: float = 1.0
var _attack_damage_multiplier: float = 1.0
var _movement_multiplier: float = 1.0
var _jump_multiplier: float = 1.0
var _dash_multiplier: float = 1.0
var _animation_time: float = 0.0
var _is_blocking: bool = false
var _block_timer: float = 0.0
var _block_cooldown_timer: float = 0.0
var _block_facing: float = 1.0
var _can_block: bool = true
var _movement_stun_timer: float = 0.0
var _attack_stun_timer: float = 0.0
var _pvp_enabled: bool = false
var _last_attacker_peer_id: int = 0
var _network_target_position: Vector2
var _network_target_velocity: Vector2
var _network_facing: float = 1.0
var _hit_targets: Dictionary = {}
var _parts: Dictionary = {}
var _sword_tween: Tween

const MAGIC_BOLT_SCENE := preload("res://scenes/combat/magic_bolt.tscn")

@onready var _visual: Node2D = $Visual
@onready var _parts_root: Node2D = $Visual/Parts
@onready var _sword_pivot: Node2D = $Visual/SwordPivot
@onready var _attack_area: Area2D = $Visual/SwordPivot/AttackArea
@onready var _slash_visual: Polygon2D = $Visual/SwordPivot/AttackArea/SlashVisual
@onready var _dash_visual: Polygon2D = $Visual/DashVisual
@onready var _shield: Node2D = $Visual/Shield
@onready var _camera: Camera2D = $Camera2D
@onready var _king_label: Label = $KingLabel


func _ready() -> void:
	add_to_group("player")
	_gravity = float(ProjectSettings.get_setting("physics/2d/default_gravity", 1600.0))
	_create_body_parts()
	_refresh_body_health()
	_mana = max_mana
	mana_changed.emit(_mana, max_mana)
	_network_target_position = global_position


func _physics_process(delta: float) -> void:
	_animation_time += delta
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		if global_position.distance_to(_network_target_position) > 180.0:
			global_position = _network_target_position
		else:
			global_position = global_position.lerp(_network_target_position, minf(delta * 22.0, 1.0))
		velocity = _network_target_velocity
		_visual.scale.x = _network_facing
		_animate_body_parts()
		return

	_regenerate_mana(delta)
	_update_health_regeneration()
	_update_timers(delta)
	_update_block()
	if _dash_timer > 0.0:
		_update_dash(delta)
	elif not _is_dead and _controls_enabled and _hurt_lock_timer <= 0.0 \
		and _movement_stun_timer <= 0.0:
		_apply_gravity(delta)
		_handle_horizontal_movement(delta)
		_handle_jump()
		_handle_attack(delta)
		_handle_dash()
		_handle_spell()
	else:
		_apply_gravity(delta)
		if _is_dead:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	move_and_slide()
	_animate_body_parts()
	if multiplayer.has_multiplayer_peer():
		_receive_network_state.rpc(
			global_position,
			velocity,
			_visual.scale.x,
			int(_attack_phase),
			int(_attack_kind),
			_is_blocking,
			_dash_timer > 0.0,
			_animation_time,
			_sword_pivot.rotation,
			_slash_visual.visible,
			_shield.rotation
		)


func _update_timers(delta: float) -> void:
	_invincibility_timer = maxf(_invincibility_timer - delta, 0.0)
	_hurt_lock_timer = maxf(_hurt_lock_timer - delta, 0.0)
	_movement_stun_timer = maxf(_movement_stun_timer - delta, 0.0)
	_attack_stun_timer = maxf(_attack_stun_timer - delta, 0.0)
	_dash_cooldown_timer = maxf(_dash_cooldown_timer - delta, 0.0)
	_block_cooldown_timer = maxf(_block_cooldown_timer - delta, 0.0)
	_combo_reset_timer = maxf(_combo_reset_timer - delta, 0.0)
	if _combo_reset_timer <= 0.0 and _attack_phase == AttackPhase.NONE:
		_combo_step = 0

	if is_on_floor():
		_coyote_timer = coyote_time
		_extra_jumps_left = _extra_jumps
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += _gravity * delta


func _handle_horizontal_movement(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	var guard_speed := block_move_multiplier if _is_blocking else 1.0
	var target_speed := direction * move_speed * _movement_multiplier * guard_speed

	if not is_zero_approx(direction):
		var current_acceleration := acceleration if is_on_floor() else air_acceleration
		velocity.x = move_toward(velocity.x, target_speed, current_acceleration * delta)
		if not _is_blocking:
			_visual.scale.x = signf(direction)
		else:
			_visual.scale.x = _block_facing
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)


func _handle_jump() -> void:
	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = jump_velocity * _jump_multiplier
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
	elif _jump_buffer_timer > 0.0 and _extra_jumps_left > 0:
		velocity.y = jump_velocity * _jump_multiplier
		_jump_buffer_timer = 0.0
		_extra_jumps_left -= 1

	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier


func _handle_attack(delta: float) -> void:
	_attack_cooldown_timer = maxf(_attack_cooldown_timer - delta, 0.0)
	if _attack_stun_timer > 0.0:
		return

	if Input.is_action_just_pressed("attack"):
		if _is_blocking:
			_stop_block()
			_start_attack(1, AttackKind.LOW)
			return
		if _attack_phase != AttackPhase.NONE and _combo_step < 3:
			_combo_queued = true
		elif _attack_phase == AttackPhase.NONE and _attack_cooldown_timer <= 0.0:
			if _dash_timer > 0.0:
				_start_attack(1, AttackKind.DASH)
			elif not is_on_floor():
				_start_attack(1, AttackKind.AIR)
			elif Input.is_action_pressed("move_down"):
				_start_attack(1, AttackKind.LOW)
			else:
				_start_attack((_combo_step % 3) + 1, AttackKind.NORMAL)

	if _attack_phase == AttackPhase.NONE:
		return

	_attack_timer = maxf(_attack_timer - delta, 0.0)
	match _attack_phase:
		AttackPhase.WINDUP:
			if _attack_timer <= 0.0:
				_begin_active_attack()
		AttackPhase.ACTIVE:
			_damage_overlapping_enemies()
			if _attack_timer <= 0.0:
				_begin_attack_recovery()
		AttackPhase.RECOVERY:
			if _attack_timer <= 0.0:
				_finish_attack()


func _start_attack(step: int, kind: AttackKind = AttackKind.NORMAL) -> void:
	_combo_step = step
	_attack_kind = kind
	_attack_phase = AttackPhase.WINDUP
	_attack_timer = _get_windup_duration(step) / _effective_attack_speed()
	_hit_targets.clear()
	_slash_visual.visible = false
	_slash_visual.scale = Vector2(0.9 + step * 0.12, 0.82 + step * 0.08)
	_slash_visual.color = Color(1.0, 0.82 - step * 0.08, 0.2, 0.78)
	match _attack_kind:
		AttackKind.AIR:
			_attack_area.position = Vector2(52, 18)
			_slash_visual.scale = Vector2(1.1, 1.2)
		AttackKind.DASH:
			_attack_area.position = Vector2(72, 0)
			_slash_visual.scale = Vector2(1.45, 0.85)
		AttackKind.LOW:
			_attack_area.position = Vector2(58, 34)
			_slash_visual.scale = Vector2(1.3, 0.72)
		_:
			_attack_area.position = Vector2(48.0 + step * 5.0, 0)
	_play_sword_windup(step)
	if multiplayer.has_multiplayer_peer():
		_sync_combat_effect.rpc("attack", step, int(kind), _visual.scale.x)


func _begin_active_attack() -> void:
	_attack_phase = AttackPhase.ACTIVE
	_attack_timer = _get_active_duration(_combo_step) / _effective_attack_speed()
	_slash_visual.visible = true
	_play_sword_swing(_combo_step)
	if _attack_kind == AttackKind.AIR:
		velocity.y = 220.0
	elif _attack_kind == AttackKind.DASH:
		velocity.x = _dash_direction * dash_speed * _dash_multiplier * 1.1
	_damage_overlapping_enemies()


func _begin_attack_recovery() -> void:
	_attack_phase = AttackPhase.RECOVERY
	_attack_timer = _get_recovery_duration(_combo_step) / _effective_attack_speed()
	_slash_visual.visible = false
	_play_sword_recovery()


func _finish_attack() -> void:
	_attack_phase = AttackPhase.NONE
	if _combo_queued and _combo_step < 3:
		_combo_queued = false
		_start_attack(_combo_step + 1, AttackKind.NORMAL)
	else:
		_combo_queued = false
		_attack_cooldown_timer = (0.1 if _combo_step < 3 else 0.24) / _effective_attack_speed()
		_combo_reset_timer = combo_reset_time


func _damage_overlapping_enemies() -> void:
	for area in _attack_area.get_overlapping_areas():
		if area is MagicBolt:
			var bolt := area as MagicBolt
			if bolt.caster != self:
				var main := get_tree().current_scene
				if multiplayer.has_multiplayer_peer() and is_instance_valid(main) \
					and main.has_method("request_magic_bolt_destroy"):
					main.request_magic_bolt_destroy(get_multiplayer_authority(), bolt.global_position)
				else:
					bolt.destroy_by_attack()
	var closest_by_actor: Dictionary = {}
	for area in _attack_area.get_overlapping_areas():
		if not (area is BodyPart):
			continue
		var part := area as BodyPart
		if part.actor == self:
			continue
		var target_id := part.actor.get_instance_id()
		if _hit_targets.has(target_id):
			continue
		var distance := _attack_area.global_position.distance_squared_to(part.global_position)
		if _attack_kind == AttackKind.LOW:
			distance = -part.global_position.y
		if not closest_by_actor.has(target_id) or distance < closest_by_actor[target_id]["distance"]:
			closest_by_actor[target_id] = {"part": part, "distance": distance}

	for target_id in closest_by_actor:
		var part: BodyPart = closest_by_actor[target_id]["part"]
		var base_damage := attack_damage * (2 if _combo_step == 3 else 1)
		if _attack_kind == AttackKind.AIR:
			base_damage = roundi(base_damage * 1.35)
		elif _attack_kind == AttackKind.DASH:
			base_damage = roundi(base_damage * 1.6)
		elif _attack_kind == AttackKind.LOW:
			base_damage = roundi(base_damage * 1.2)
		var damage := maxi(1, roundi(base_damage * _attack_damage_multiplier))
		if _apply_damage_to_part(part, damage):
			_hit_targets[target_id] = true


func _apply_damage_to_part(part: BodyPart, damage: int) -> bool:
	if part.actor is Player and multiplayer.has_multiplayer_peer():
		request_network_damage(part.actor as Player, part.part_id, damage, "melee")
		return true
	if part.actor.has_method("is_melee_attack_active") and part.actor.is_melee_attack_active() \
		and _can_clash_with(part.actor):
		var hard_clash: bool = _combo_step == 3 and part.actor.has_method("get_attack_step") \
			and part.actor.get_attack_step() == 3
		apply_clash_result(signf(global_position.x - part.actor.global_position.x), hard_clash)
		if part.actor.has_method("apply_clash_result"):
			part.actor.apply_clash_result(
				signf(part.actor.global_position.x - global_position.x),
				hard_clash
			)
		var main := get_tree().current_scene
		if is_instance_valid(main) and main.has_method("show_local_combat_message"):
			main.show_local_combat_message((global_position + part.actor.global_position) * 0.5, "拼刀！")
		return true
	var damage_kind := "low" if _attack_kind == AttackKind.LOW else "melee"
	return part.receive_damage(damage, global_position, damage_kind)


func request_network_damage(target: Player, part_id: StringName, damage: int, damage_kind: String) -> void:
	var main := get_tree().current_scene
	if not is_instance_valid(main) or not main.has_method("request_pvp_damage"):
		return
	main.request_pvp_damage(
		get_multiplayer_authority(),
		target.get_multiplayer_authority(),
		part_id,
		damage,
		damage_kind
	)


func server_apply_part_damage(
	part_id: StringName,
	damage: int,
	source_position: Vector2,
	attacker_peer_id: int,
	damage_kind: String = "melee"
) -> bool:
	_last_attacker_peer_id = attacker_peer_id
	var part: BodyPart = _parts.get(part_id)
	if is_instance_valid(part):
		return part.receive_damage(damage, source_position, damage_kind)
	return false


func get_body_state() -> Dictionary:
	var state := {}
	for id in _parts:
		var part := _parts[id] as BodyPart
		state[String(id)] = [part.health, part.max_health]
	return state


func apply_body_state(state: Dictionary, attacker_peer_id: int = 0) -> void:
	_last_attacker_peer_id = attacker_peer_id
	for id in state:
		var part := _parts.get(StringName(id)) as BodyPart
		var values: Array = state[id]
		if is_instance_valid(part) and values.size() >= 2:
			var previous_health := part.health
			part.apply_authoritative_state(int(values[0]), int(values[1]))
			if part.health > previous_health:
				_show_heal_feedback(part)
	_rebuild_part_effects()
	_refresh_body_health()


func configure_network_authority(peer_id: int) -> void:
	set_multiplayer_authority(peer_id)
	_camera.enabled = peer_id == multiplayer.get_unique_id()
	if not is_multiplayer_authority():
		_controls_enabled = false


func set_camera_world_width(width: int) -> void:
	_camera.limit_left = 0
	_camera.limit_right = width
	_camera.limit_top = 0
	_camera.limit_bottom = 720


func set_pvp_enabled(enabled: bool) -> void:
	_pvp_enabled = enabled


@rpc("any_peer", "call_local", "reliable")
func apply_pvp_upgrade(upgrade_index: int) -> void:
	var upgrades := ["attack", "attack_speed", "move_speed", "double_jump", "attack_range", "part_health", "magic_damage", "max_mana", "mana_regen", "dash_cooldown", "rapid_regeneration"]
	var selected: String = upgrades[upgrade_index % upgrades.size()]
	if selected == "double_jump" and has_double_jump_upgrade():
		selected = upgrades[(upgrade_index + 1) % upgrades.size()]
	if selected == "rapid_regeneration" and has_rapid_regeneration():
		selected = upgrades[(upgrade_index + 1) % upgrades.size()]
	apply_upgrade(selected)


@rpc("any_peer", "call_local", "reliable")
func reset_for_pvp(spawn_position: Vector2) -> void:
	attack_damage = 3
	move_speed = 300.0
	_attack_speed_multiplier = 1.0
	_arm_attack_multiplier = 1.0
	_attack_damage_multiplier = 1.0
	_movement_multiplier = 1.0
	_jump_multiplier = 1.0
	_dash_multiplier = 1.0
	_extra_jumps = 0
	_extra_jumps_left = 0
	spell_damage = 2
	max_mana = 100
	mana_regen_per_second = 7.0
	health_regen_interval = 6.0
	_rapid_regeneration = false
	_next_health_regen_msec = 0
	dash_cooldown = 0.65
	_attack_area.scale.x = 1.0
	_can_block = true
	_block_cooldown_timer = 0.0
	_movement_stun_timer = 0.0
	_attack_stun_timer = 0.0
	_stop_block(false)
	_is_dead = false
	_last_attacker_peer_id = 0
	_mana = max_mana
	mana_changed.emit(_mana, max_mana)
	collision_layer = 2
	collision_mask = 1
	modulate = Color.WHITE
	rotation = 0.0
	_shield.visible = true
	_sword_pivot.position = Vector2(14, -8)
	for part in _parts.values():
		(part as BodyPart).reset_part()
	global_position = spawn_position
	velocity = Vector2.ZERO
	_controls_enabled = is_multiplayer_authority()
	_refresh_body_health()
	stats_changed.emit(attack_damage, get_attack_speed_bonus())


@rpc("any_peer", "call_local", "reliable")
func set_king(enabled: bool) -> void:
	_king_label.visible = enabled


@rpc("authority", "call_remote", "unreliable_ordered")
func _receive_network_state(
	network_position: Vector2,
	network_velocity: Vector2,
	facing: float,
	attack_phase: int,
	attack_kind: int,
	blocking: bool,
	dashing: bool,
	animation_time: float,
	sword_rotation: float,
	slash_visible: bool,
	shield_rotation: float
) -> void:
	_network_target_position = network_position
	_network_target_velocity = network_velocity
	_network_facing = facing
	_attack_phase = attack_phase as AttackPhase
	_attack_kind = attack_kind as AttackKind
	_is_blocking = blocking
	_animation_time = animation_time
	_sword_pivot.rotation = sword_rotation
	_slash_visual.visible = slash_visible
	_shield.rotation = shield_rotation
	_shield.modulate = Color(0.55, 0.9, 1.0, 1.0) if blocking else Color.WHITE
	_dash_visual.visible = dashing


func is_network_attack_active() -> bool:
	return _attack_phase == AttackPhase.ACTIVE


func is_facing_position(target_x: float) -> bool:
	var direction := signf(target_x - global_position.x)
	return is_zero_approx(direction) or direction == signf(_visual.scale.x)


func get_network_attack_kind() -> int:
	return int(_attack_kind)


func get_attack_step() -> int:
	return _combo_step


func can_destroy_magic_bolt_at(hit_position: Vector2) -> bool:
	return is_network_attack_active() \
		and _attack_area.global_position.distance_to(hit_position) <= 100.0


func has_double_jump_upgrade() -> bool:
	return _extra_jumps > 0


func can_clash_with_player(other: Player) -> bool:
	return _can_clash_with(other)


func _can_clash_with(other: Node) -> bool:
	if not other.has_method("get_network_attack_kind"):
		return false
	var other_kind := int(other.get_network_attack_kind())
	if _attack_kind == AttackKind.LOW or other_kind == AttackKind.LOW:
		return _attack_kind == AttackKind.LOW and other_kind == AttackKind.LOW
	return _attack_kind == AttackKind.NORMAL and other_kind == AttackKind.NORMAL


func get_network_melee_damage() -> int:
	var base_damage := attack_damage * (2 if _combo_step == 3 else 1)
	match _attack_kind:
		AttackKind.AIR:
			base_damage = roundi(base_damage * 1.35)
		AttackKind.DASH:
			base_damage = roundi(base_damage * 1.6)
		AttackKind.LOW:
			base_damage = roundi(base_damage * 1.2)
	return maxi(1, roundi(base_damage * _attack_damage_multiplier))


func get_spell_damage() -> int:
	return spell_damage


func _get_windup_duration(step: int) -> float:
	if _attack_kind == AttackKind.AIR:
		return 0.1
	if _attack_kind == AttackKind.DASH:
		return 0.07
	if _attack_kind == AttackKind.LOW:
		return 0.11
	match step:
		1:
			return 0.12
		2:
			return 0.14
		_:
			return 0.2


func _get_active_duration(step: int) -> float:
	if _attack_kind == AttackKind.AIR:
		return 0.16
	if _attack_kind == AttackKind.DASH:
		return 0.14
	if _attack_kind == AttackKind.LOW:
		return 0.13
	match step:
		1:
			return 0.11
		2:
			return 0.12
		_:
			return 0.16


func _get_recovery_duration(step: int) -> float:
	if _attack_kind == AttackKind.AIR:
		return 0.2
	if _attack_kind == AttackKind.DASH:
		return 0.18
	if _attack_kind == AttackKind.LOW:
		return 0.17
	match step:
		1:
			return 0.14
		2:
			return 0.16
		_:
			return 0.23


func _handle_dash() -> void:
	if not Input.is_action_just_pressed("dash") or _dash_cooldown_timer > 0.0:
		return
	start_dash()


func _handle_spell() -> void:
	if not Input.is_action_just_pressed("spell"):
		return
	cast_spell()


func start_dash() -> void:
	if _dash_cooldown_timer > 0.0 or _is_dead:
		return
	_stop_block()
	var input_direction := Input.get_axis("move_left", "move_right")
	_dash_direction = input_direction if not is_zero_approx(input_direction) else signf(_visual.scale.x)
	if is_zero_approx(_dash_direction):
		_dash_direction = 1.0
	_visual.scale.x = _dash_direction
	_dash_timer = dash_duration
	_dash_cooldown_timer = dash_cooldown
	_invincibility_timer = maxf(_invincibility_timer, dash_duration)
	_attack_timer = 0.0
	_attack_phase = AttackPhase.NONE
	_combo_queued = false
	_slash_visual.visible = false
	_dash_visual.visible = true
	_set_parts_tint(Color(0.35, 0.95, 1.0, 0.42))
	velocity = Vector2(_dash_direction * dash_speed * _dash_multiplier, 0.0)
	if multiplayer.has_multiplayer_peer():
		_sync_combat_effect.rpc("dash", 0, 0, _dash_direction)


func _update_dash(delta: float) -> void:
	_dash_timer = maxf(_dash_timer - delta, 0.0)
	velocity = Vector2(_dash_direction * dash_speed * _dash_multiplier, 0.0)
	_handle_attack(delta)
	if _dash_timer <= 0.0:
		_dash_visual.visible = false
		_set_parts_tint(Color.WHITE)
		velocity.x *= 0.45


func take_damage(amount: int, source_position: Vector2) -> void:
	if _is_dead or _invincibility_timer > 0.0:
		return
	var torso: BodyPart = _parts.get("torso")
	if is_instance_valid(torso):
		torso.receive_damage(amount, source_position)


func can_receive_part_damage() -> bool:
	return not _is_dead and _invincibility_timer <= 0.0


func modify_incoming_damage(amount: int, source_position: Vector2, damage_kind: String = "melee") -> int:
	if not _is_blocking:
		return amount
	if damage_kind == "spell":
		return 0
	if damage_kind == "low":
		return amount
	if _block_timer <= perfect_block_duration:
		_stun_attacker(source_position)
		return 0
	return maxi(1, ceili(amount * (1.0 - block_damage_reduction)))


func _update_block() -> void:
	if not _can_block or _is_dead:
		_stop_block()
		return
	if Input.is_action_just_pressed("move_down") and is_on_floor() and _block_cooldown_timer <= 0.0:
		_start_block()
	if _is_blocking:
		_block_timer += get_physics_process_delta_time()
		if not Input.is_action_pressed("move_down"):
			_stop_block()


func _start_block() -> void:
	_is_blocking = true
	_block_timer = 0.0
	_block_facing = signf(_visual.scale.x)
	if is_zero_approx(_block_facing):
		_block_facing = 1.0
	_shield.rotation = deg_to_rad(-8.0)
	_shield.modulate = Color(0.55, 0.9, 1.0, 1.0)
	if multiplayer.has_multiplayer_peer():
		_sync_combat_effect.rpc("block_start", 0, 0, _block_facing)


func _stop_block(start_cooldown: bool = true) -> void:
	var was_blocking := _is_blocking
	_is_blocking = false
	_block_timer = 0.0
	if was_blocking and start_cooldown:
		_block_cooldown_timer = block_cooldown
	if was_blocking and multiplayer.has_multiplayer_peer() and is_multiplayer_authority():
		_sync_combat_effect.rpc("block_stop", 0, 0, _block_facing)
	if is_instance_valid(_shield):
		_shield.rotation = 0.0
		_shield.modulate = Color.WHITE


func _stun_attacker(source_position: Vector2) -> void:
	var attacker: Node2D
	var best_distance := 4900.0
	for node in get_tree().get_nodes_in_group("player"):
		if node == self:
			continue
		var candidate := node as Node2D
		var distance := candidate.global_position.distance_squared_to(source_position)
		if distance < best_distance:
			attacker = candidate
			best_distance = distance
	for node in get_tree().current_scene.get_children():
		if node is TrainingDummy:
			var candidate := node as Node2D
			var distance := candidate.global_position.distance_squared_to(source_position)
			if distance < best_distance:
				attacker = candidate
				best_distance = distance
	if not is_instance_valid(attacker):
		return
	if attacker is Player and multiplayer.has_multiplayer_peer():
		(attacker as Player).apply_combat_stun.rpc(1.0)
	elif attacker.has_method("apply_combat_stun"):
		attacker.apply_combat_stun(1.0)
	elif attacker.has_method("apply_movement_stun"):
		attacker.apply_movement_stun(1.0)


@rpc("any_peer", "call_local", "reliable")
func apply_network_stun(duration: float) -> void:
	apply_combat_stun(duration)


@rpc("any_peer", "call_local", "reliable")
func apply_combat_stun(duration: float) -> void:
	_movement_stun_timer = maxf(_movement_stun_timer, duration)
	_attack_stun_timer = maxf(_attack_stun_timer, duration)
	velocity.x = 0.0
	_attack_phase = AttackPhase.NONE
	_attack_timer = 0.0
	_combo_queued = false
	_slash_visual.visible = false


@rpc("any_peer", "call_local", "reliable")
func apply_clash_recoil(direction: float) -> void:
	apply_combat_stun(0.45)
	velocity.x = direction * 260.0


@rpc("any_peer", "call_local", "reliable")
func apply_clash_result(direction: float, hard_clash: bool) -> void:
	if hard_clash:
		apply_combat_stun(0.45)
	else:
		_attack_phase = AttackPhase.NONE
		_attack_timer = 0.0
		_combo_queued = false
		_slash_visual.visible = false
	velocity.x = direction * 220.0


func apply_movement_stun(duration: float) -> void:
	_movement_stun_timer = maxf(_movement_stun_timer, duration)
	velocity.x = 0.0


func is_blocking() -> bool:
	return _is_blocking


func can_block() -> bool:
	return _can_block


func get_block_cooldown_time() -> float:
	return _block_cooldown_timer


func get_movement_stun_time() -> float:
	return _movement_stun_timer


func get_attack_stun_time() -> float:
	return _attack_stun_timer


func is_perfect_block_active() -> bool:
	return _is_blocking and _block_timer <= perfect_block_duration


func is_guarding() -> bool:
	return _is_blocking


func is_dash_invulnerable() -> bool:
	return _dash_timer > 0.0 and _invincibility_timer > 0.0


func is_attack_recovering() -> bool:
	return _attack_phase == AttackPhase.RECOVERY


func get_attack_kind() -> AttackKind:
	return _attack_kind


func on_body_part_damaged(part: BodyPart, _amount: int, source_position: Vector2) -> void:
	_invincibility_timer = invincibility_duration
	_hurt_lock_timer = hurt_lock_duration
	_attack_timer = 0.0
	_attack_phase = AttackPhase.NONE
	_combo_queued = false
	_dash_timer = 0.0
	_slash_visual.visible = false
	_dash_visual.visible = false

	var knockback_direction := signf(global_position.x - source_position.x)
	if is_zero_approx(knockback_direction):
		knockback_direction = 1.0
	velocity = Vector2(knockback_direction * knockback_speed, -230.0)
	_refresh_body_health()
	if part.health <= 0 and part.vital:
		_die()


func get_health() -> int:
	return _health


func _update_health_regeneration() -> void:
	if _is_dead:
		_next_health_regen_msec = 0
		return
	if _health >= max_health:
		_next_health_regen_msec = 0
		return
	var now := Time.get_ticks_msec()
	if _next_health_regen_msec <= 0:
		_next_health_regen_msec = now + roundi(health_regen_interval * 1000.0)
		return
	if now < _next_health_regen_msec:
		return
	_next_health_regen_msec = now + roundi(health_regen_interval * 1000.0)
	if multiplayer.has_multiplayer_peer():
		var main := get_tree().current_scene
		if is_instance_valid(main) and main.has_method("request_player_regeneration"):
			main.request_player_regeneration(get_multiplayer_authority())
	else:
		heal_next_body_part()


func heal_next_body_part() -> bool:
	for id in ["torso", "head", "left_arm", "right_arm", "left_leg", "right_leg"]:
		var part := _parts.get(id) as BodyPart
		if is_instance_valid(part) and part.heal_one():
			_show_heal_feedback(part)
			return true
	return false


func _show_heal_feedback(part: BodyPart) -> void:
	var label := Label.new()
	label.text = "+1 %s" % part.display_name
	label.position = part.global_position - Vector2(45, 50)
	label.size = Vector2(90, 35)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.25, 1.0, 0.45))
	get_tree().current_scene.add_child(label)
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 28.0, 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.7)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)


func get_health_regen_interval() -> float:
	return health_regen_interval


func get_next_health_regen_msec() -> int:
	return _next_health_regen_msec


func has_rapid_regeneration() -> bool:
	return _rapid_regeneration


func get_mana() -> int:
	return _mana


func _regenerate_mana(delta: float) -> void:
	if _mana >= max_mana:
		_mana_regen_buffer = 0.0
		return
	_mana_regen_buffer += mana_regen_per_second * delta
	var restored := floori(_mana_regen_buffer)
	if restored <= 0:
		return
	_mana_regen_buffer -= restored
	_mana = mini(_mana + restored, max_mana)
	mana_changed.emit(_mana, max_mana)


func cast_spell() -> bool:
	if _mana < spell_cost:
		return false
	_mana -= spell_cost
	mana_changed.emit(_mana, max_mana)
	var bolt := MAGIC_BOLT_SCENE.instantiate() as MagicBolt
	bolt.caster = self
	bolt.damage = spell_damage
	bolt.direction = signf(_visual.scale.x)
	if is_zero_approx(bolt.direction):
		bolt.direction = 1.0
	bolt.global_position = global_position + Vector2(bolt.direction * 42.0, -10.0)
	get_tree().current_scene.add_child(bolt)
	if multiplayer.has_multiplayer_peer():
		_sync_combat_effect.rpc("spell", 0, 0, bolt.direction)
	return true


@rpc("authority", "call_remote", "reliable")
func _sync_combat_effect(action: String, step: int, kind: int, facing: float) -> void:
	_visual.scale.x = facing
	match action:
		"attack":
			_combo_step = step
			_attack_kind = kind
			_attack_phase = AttackPhase.WINDUP
			_slash_visual.visible = false
			_play_sword_windup(step)
			var tween := create_tween()
			tween.tween_interval(_get_windup_duration(step) / _effective_attack_speed())
			tween.tween_callback(func() -> void:
				_attack_phase = AttackPhase.ACTIVE
				_slash_visual.visible = true
				_play_sword_swing(step)
			)
			tween.tween_interval(_get_active_duration(step) / _effective_attack_speed())
			tween.tween_callback(func() -> void:
				_attack_phase = AttackPhase.RECOVERY
				_slash_visual.visible = false
				_play_sword_recovery()
			)
			tween.tween_interval(_get_recovery_duration(step) / _effective_attack_speed())
			tween.tween_callback(func() -> void:
				_slash_visual.visible = false
				_attack_phase = AttackPhase.NONE
			)
		"dash":
			_dash_visual.visible = true
			_set_parts_tint(Color(0.35, 0.95, 1.0, 0.42))
			var tween := create_tween()
			tween.tween_interval(dash_duration)
			tween.tween_callback(func() -> void:
				_dash_visual.visible = false
				_set_parts_tint(Color.WHITE)
			)
		"spell":
			var bolt := MAGIC_BOLT_SCENE.instantiate() as MagicBolt
			bolt.caster = self
			bolt.damage = spell_damage
			bolt.direction = facing
			if not multiplayer.is_server():
				bolt.collision_layer = 0
				bolt.collision_mask = 0
			bolt.global_position = global_position + Vector2(facing * 42.0, -10.0)
			get_tree().current_scene.add_child(bolt)
		"block_start":
			_shield.visible = true
			_shield.modulate = Color(0.55, 0.9, 1.0, 1.0)
			_is_blocking = true
		"block_stop":
			_is_blocking = false
			_shield.modulate = Color.WHITE


func set_controls_enabled(enabled: bool) -> void:
	_controls_enabled = enabled
	if not enabled:
		velocity.x = 0.0
		_attack_timer = 0.0
		_attack_phase = AttackPhase.NONE
		_combo_queued = false
		_slash_visual.visible = false
		_dash_visual.visible = false


func apply_attack_upgrade() -> void:
	attack_damage += 1
	stats_changed.emit(attack_damage, get_attack_speed_bonus())


func apply_attack_speed_upgrade() -> void:
	_attack_speed_multiplier += 0.20
	stats_changed.emit(attack_damage, get_attack_speed_bonus())


func apply_max_health_upgrade() -> void:
	for part in _parts.values():
		(part as BodyPart).increase_max_health(2, 2)
	_refresh_body_health()


func apply_upgrade(upgrade_id: String) -> void:
	match upgrade_id:
		"attack":
			apply_attack_upgrade()
		"attack_speed":
			apply_attack_speed_upgrade()
		"move_speed":
			move_speed *= 1.30
		"double_jump":
			_extra_jumps = maxi(_extra_jumps, 1)
			_extra_jumps_left = _extra_jumps
		"attack_range":
			_attack_area.scale.x *= 1.20
		"part_health":
			apply_max_health_upgrade()
		"magic_damage":
			spell_damage += 1
		"max_mana":
			max_mana += 20
			_mana = mini(_mana + 20, max_mana)
			mana_changed.emit(_mana, max_mana)
		"mana_regen":
			mana_regen_per_second *= 1.5
		"dash_cooldown":
			dash_cooldown = maxf(0.25, dash_cooldown * 0.85)
		"rapid_regeneration":
			if not _rapid_regeneration:
				_rapid_regeneration = true
				health_regen_interval = 3.0
				_next_health_regen_msec = Time.get_ticks_msec() \
					+ roundi(health_regen_interval * 1000.0)
	stats_changed.emit(attack_damage, get_attack_speed_bonus())


func get_attack_speed_bonus() -> int:
	return roundi((_attack_speed_multiplier - 1.0) * 100.0)


func get_movement_multiplier() -> float:
	return _movement_multiplier


func get_attack_damage_multiplier() -> float:
	return _attack_damage_multiplier


func _create_body_parts() -> void:
	_add_body_part("head", "头部", 8, true, Vector2(22, 18), Vector2(0, -34), Color(0.45, 0.82, 1.0), 16)
	_add_body_part("torso", "身体", 14, true, Vector2(28, 32), Vector2(0, -7), Color(0.18, 0.62, 0.96), 16)
	_add_body_part("left_arm", "左臂", 7, false, Vector2(10, 28), Vector2(-21, -7), Color(0.28, 0.72, 1.0), 16)
	_add_body_part("right_arm", "右臂", 7, false, Vector2(10, 28), Vector2(21, -7), Color(0.28, 0.72, 1.0), 16)
	_add_body_part("left_leg", "左腿", 7, false, Vector2(11, 30), Vector2(-9, 24), Color(0.12, 0.45, 0.82), 16)
	_add_body_part("right_leg", "右腿", 7, false, Vector2(11, 30), Vector2(9, 24), Color(0.12, 0.45, 0.82), 16)


func _add_body_part(
	id: StringName,
	label: String,
	hp: int,
	vital: bool,
	part_size: Vector2,
	part_position: Vector2,
	color: Color,
	layer: int
) -> void:
	var part := BodyPart.new()
	_parts_root.add_child(part)
	part.configure(self, id, label, hp, vital, part_size, part_position, color, layer)
	part.health_changed.connect(_on_part_health_changed)
	part.destroyed.connect(_on_part_destroyed)
	part.regenerated.connect(_on_part_regenerated)
	_parts[id] = part


func _on_part_health_changed(_part: BodyPart) -> void:
	_refresh_body_health()


func _on_part_destroyed(part: BodyPart) -> void:
	match part.part_id:
		"left_arm", "right_arm":
			_arm_attack_multiplier *= 0.72
			_attack_damage_multiplier *= 0.72
			_can_block = false
			_stop_block()
			_shield.visible = false
			if part.part_id == "right_arm":
				_sword_pivot.position.x = -14.0
		"left_leg", "right_leg":
			_movement_multiplier *= 0.72
			_jump_multiplier *= 0.82
			_dash_multiplier *= 0.7
	_refresh_body_health()


func _on_part_regenerated(_part: BodyPart) -> void:
	_rebuild_part_effects()
	_refresh_body_health()


func _rebuild_part_effects() -> void:
	_arm_attack_multiplier = 1.0
	_attack_damage_multiplier = 1.0
	_movement_multiplier = 1.0
	_jump_multiplier = 1.0
	_dash_multiplier = 1.0
	_can_block = true
	_shield.visible = true
	_sword_pivot.position = Vector2(14, -8)
	for id in ["left_arm", "right_arm"]:
		var arm := _parts.get(id) as BodyPart
		if is_instance_valid(arm) and arm.health <= 0:
			_arm_attack_multiplier *= 0.72
			_attack_damage_multiplier *= 0.72
			_can_block = false
			_shield.visible = false
			if id == "right_arm":
				_sword_pivot.position.x = -14.0
	for id in ["left_leg", "right_leg"]:
		var leg := _parts.get(id) as BodyPart
		if is_instance_valid(leg) and leg.health <= 0:
			_movement_multiplier *= 0.72
			_jump_multiplier *= 0.82
			_dash_multiplier *= 0.7
	var head := _parts.get("head") as BodyPart
	var torso := _parts.get("torso") as BodyPart
	if not _is_dead and ((is_instance_valid(head) and head.health <= 0) or (is_instance_valid(torso) and torso.health <= 0)):
		_die()


func _refresh_body_health() -> void:
	_health = 0
	max_health = 0
	var lines: Array[String] = []
	for id in ["head", "torso", "left_arm", "right_arm", "left_leg", "right_leg"]:
		var part: BodyPart = _parts.get(id)
		if not is_instance_valid(part):
			continue
		_health += part.health
		max_health += part.max_health
		lines.append("%s %d/%d" % [part.display_name, part.health, part.max_health])
	health_changed.emit(_health, max_health)
	body_parts_changed.emit("  ".join(lines))


func _play_sword_windup(step: int) -> void:
	if _sword_tween and _sword_tween.is_valid():
		_sword_tween.kill()
	var start_angle := deg_to_rad(-72.0 if step != 2 else 58.0)
	if _attack_kind == AttackKind.AIR:
		start_angle = deg_to_rad(-25.0)
	elif _attack_kind == AttackKind.DASH:
		start_angle = deg_to_rad(-12.0)
	elif _attack_kind == AttackKind.LOW:
		start_angle = deg_to_rad(-32.0)
	if step == 3:
		start_angle = deg_to_rad(-105.0)
	_sword_tween = create_tween()
	_sword_tween.tween_property(
		_sword_pivot,
		"rotation",
		start_angle,
		_get_windup_duration(step) / _effective_attack_speed()
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _play_sword_swing(step: int) -> void:
	if _sword_tween and _sword_tween.is_valid():
		_sword_tween.kill()
	var end_angle := deg_to_rad(68.0 if step != 2 else -66.0)
	if _attack_kind == AttackKind.AIR:
		end_angle = deg_to_rad(112.0)
	elif _attack_kind == AttackKind.DASH:
		end_angle = deg_to_rad(8.0)
	elif _attack_kind == AttackKind.LOW:
		end_angle = deg_to_rad(38.0)
	if step == 3:
		end_angle = deg_to_rad(105.0)
	_sword_tween = create_tween()
	_sword_tween.tween_property(
		_sword_pivot,
		"rotation",
		end_angle,
		_get_active_duration(step) / _effective_attack_speed()
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _play_sword_recovery() -> void:
	if _sword_tween and _sword_tween.is_valid():
		_sword_tween.kill()
	_sword_tween = create_tween()
	_sword_tween.tween_property(
		_sword_pivot,
		"rotation",
		deg_to_rad(25.0),
		_get_recovery_duration(_combo_step) / _effective_attack_speed()
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _effective_attack_speed() -> float:
	return maxf(0.35, _attack_speed_multiplier * _arm_attack_multiplier)


func _animate_body_parts() -> void:
	var moving := absf(velocity.x) > 25.0 and is_on_floor()
	var airborne := not is_on_floor()
	var phase := _animation_time * 8.5
	var step := sin(phase)
	var breathe := sin(_animation_time * 2.2)

	_animate_part("torso", Vector2(0, breathe * 0.7), step * 0.02 if moving else 0.0)
	_animate_part("head", Vector2(0, breathe * 0.85), 0.0)

	if airborne:
		_animate_part("left_arm", Vector2(-1, -2), 0.0)
		_animate_part("right_arm", Vector2(1, -2), 0.0)
		_animate_part("left_leg", Vector2(2, -3), 0.0)
		_animate_part("right_leg", Vector2(-2, 1), 0.0)
	elif moving:
		_animate_part("left_arm", Vector2(step * 2.2, -step * 1.0), 0.0)
		_animate_part("right_arm", Vector2(-step * 2.2, step * 1.0), 0.0)
		_animate_part("left_leg", Vector2(step * 2.6, -maxf(step, 0.0) * 2.0), 0.0)
		_animate_part("right_leg", Vector2(-step * 2.6, maxf(step, 0.0) * 2.0), 0.0)
	else:
		_animate_part("left_arm", Vector2.ZERO, breathe * 0.025)
		_animate_part("right_arm", Vector2.ZERO, -breathe * 0.025)
		_animate_part("left_leg", Vector2.ZERO, 0.0)
		_animate_part("right_leg", Vector2.ZERO, 0.0)

	if _attack_kind == AttackKind.LOW and _attack_phase != AttackPhase.NONE:
		_animate_part("torso", Vector2(0, 7), 0.0)
		_animate_part("head", Vector2(0, 7), 0.0)
		_animate_part("left_leg", Vector2(-2, 4), 0.0)
		_animate_part("right_leg", Vector2(2, 4), 0.0)

	if _attack_phase != AttackPhase.NONE:
		var attack_arm: BodyPart = _parts.get("right_arm")
		if is_instance_valid(attack_arm) and attack_arm.health > 0:
			attack_arm.animate_transform(Vector2(2, -2), _sword_pivot.rotation * 0.3, 0.45)


func _animate_part(id: StringName, offset: Vector2, angle: float) -> void:
	var part: BodyPart = _parts.get(id)
	if is_instance_valid(part):
		part.animate_transform(offset, angle)


func _set_parts_tint(color: Color) -> void:
	for part in _parts.values():
		(part as BodyPart).set_tint(color)


func _die() -> void:
	_is_dead = true
	collision_layer = 0
	collision_mask = 1
	if _pvp_enabled:
		_controls_enabled = false
		modulate = Color(1.0, 1.0, 1.0, 0.25)
		pvp_defeated.emit(get_multiplayer_authority(), _last_attacker_peer_id)
		return
	var death_tween := create_tween()
	death_tween.set_parallel(true)
	death_tween.tween_property(self, "modulate:a", 0.0, 0.55)
	death_tween.tween_property(self, "rotation", deg_to_rad(90.0), 0.55)
	death_tween.set_parallel(false)
	death_tween.tween_callback(died.emit)
