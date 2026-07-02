class_name Player
extends CharacterBody2D

const DAMAGE_OVER_TIME_SCRIPT := preload("res://scripts/combat/damage_over_time.gd")

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
@export var charged_wave_cost: int = 80
@export var super_wave_cost: int = 100
@export var spell_cooldown: float = 1.0
@export var mana_regen_per_second: float = 7.0
@export var health_regen_interval_msec: int = 6000

@export_category("Dash")
@export var dash_speed: float = 760.0
@export var dash_duration: float = 0.16
@export var dash_cooldown: float = 0.65

@export_category("Health")
@export var max_health: int = 5
@export var invincibility_duration: float = 0.75
@export var pvp_invincibility_duration: float = 0.22
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
var _spell_animation_timer: float = 0.0
var _spell_cooldown_timer: float = 0.0
var _spell_charge_time: float = 0.0
var _is_charging_spell: bool = false
var _spell_visual_tier: int = 0
var _spell_charge_cue_tier: int = 0
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
var _enemy_slow_timer: float = 0.0
var _enemy_slow_multiplier: float = 1.0
var _enemy_weakness_timer: float = 0.0
var _enemy_weakness_multiplier: float = 1.0
var _fire_build_level: int = 0
var _frost_build_level: int = 0
var _lightning_build_level: int = 0
var _counter_build_level: int = 0
var _charge_build_level: int = 0
var _elemental_hit_counter: int = 0
var _movement_multiplier: float = 1.0
var _jump_multiplier: float = 1.0
var _dash_multiplier: float = 1.0
var _animation_time: float = 0.0
var _walk_cycle: float = 0.0
var _footstep_timer: float = 0.0
var _footstep_index: int = 0
var _was_on_floor: bool = false
var _is_blocking: bool = false
var _block_timer: float = 0.0
var _block_cooldown_timer: float = 0.0
var _block_facing: float = 1.0
var _can_block: bool = true
var _last_down_tap_msec: int = -10000
var _drop_through_timer: float = 0.0
var _movement_stun_timer: float = 0.0
var _attack_stun_timer: float = 0.0
var _pvp_enabled: bool = false
var _last_attacker_peer_id: int = 0
var _network_target_position: Vector2
var _network_target_velocity: Vector2
var _network_target_grounded: bool = true
var _network_facing: float = 1.0
var _network_send_timer: float = 0.0
var _network_heartbeat_timer: float = 0.0
var _network_keyframe_timer: float = 0.0
var _network_state_sequence: int = 0
var _last_received_state_sequence: int = -1
var _network_prediction_seconds: float = 0.025
var _last_network_sent_position: Vector2
var _last_network_sent_velocity: Vector2
var _last_network_sent_facing: float = 1.0
var _network_attack_sequence: int = 0
var _network_effect_sequence: int = 0
var _hit_targets: Dictionary = {}
var _parts: Dictionary = {}
var _sword_tween: Tween
var _health_regen_timer: Timer
var _applied_upgrade_count: int = 0
var _pixel_character: Node2D
var _pixel_layers: Array[Sprite2D] = []
var _redrawn_action_sprite: Sprite2D
var _spell_burst_sprite: Sprite2D
var _white_slash_sprite: Sprite2D
var _appearance_seed: int = 0
var _pixel_frame: Vector2i = Vector2i.ZERO

const CHARACTER_ASSET_ROOT := "res://assets/characters/gandalf/"
const CHARACTER_FRAME_SIZE := Vector2i(80, 64)
const CHARACTER_VISUAL_POSITION := Vector2(0, -29)
const CHARACTER_VISUAL_SCALE := Vector2(-1.98, 1.98)
const REDRAWN_ACTION_TEXTURE := preload("res://assets/characters/redrawn/adventurer_actions.png")
const REDRAWN_ACTION_FRAME_SIZE := Vector2i(192, 144)
const REDRAWN_ACTION_POSITION := Vector2(0, -32)
const SPELL_BURST_TEXTURE := preload("res://assets/characters/effects/adventurer_spell_burst.png")
const WHITE_SLASH_TEXTURE := preload("res://assets/characters/effects/adventurer_white_slash.png")
const SHIELD_READY_POSITION := Vector2(25, -7)
const SHIELD_STOWED_POSITION := Vector2(10, 12)
const BLOCK_SHEATHE_DURATION := 0.10
const BLOCK_RAISE_DURATION := 0.16
const MALE_UNDERWEAR := [
	"Underwear.png", "Skyblue Underwear.png", "Red Underwear.png",
	"Purple Underwear.png", "Orange Underwear.png", "Green Underwear.png",
]
const MALE_PANTS := [
	"Pants.png", "Purple Pants.png", "Orange Pants.png", "Green Pants.png",
	"Blue Pants.png",
]
const MALE_SHIRTS := [
	"Shirt.png", "Shirt v2.png", "Purple Shirt v2.png", "orange Shirt v2.png",
	"Green Shirt v2.png", "Blue Shirt v2.png",
]
const MALE_FOOTWEAR := ["Shoes.png", "Boots.png"]
const FEMALE_UNDERWEAR := [
	"Green Panties and Bra.png", "Blue Panties and Bra.png",
	"Orange Panties and Bra.png", "Red Panties and Bra.png",
	"Purple Panties and Bra.png", "Skyblue Panties and Bra.png",
]
const FEMALE_CORSETS := [
	"Corset.png", "Corset v2.png", "Green Corset.png", "Green Corset v2.png",
	"Blue Corset.png", "Blue Corset v2.png", "Purple Corset.png",
	"Purple Corset v2.png", "Orange Corset.png", "Orange Corset v2.png",
]
const FEMALE_SOCKS := [
	"Socks.png", "Green Socks.png", "Orange Socks.png", "Purple Socks.png",
	"Red Socks.png", "Skyblue Socks.png",
]
const MAGIC_BOLT_SCENE := preload("res://scenes/combat/magic_bolt.tscn")
const CHARGED_WAVE_TIME := 1.0
const SUPER_WAVE_TIME := 3.0
const ONE_WAY_PLATFORM_LAYER := 1 << 5
const DROP_THROUGH_DURATION := 0.28
const DOUBLE_TAP_DOWN_MSEC := 260

@onready var _visual: Node2D = $Visual
@onready var _parts_root: Node2D = $Visual/Parts
@onready var _sword_pivot: Node2D = $Visual/SwordPivot
@onready var _attack_area: Area2D = $Visual/SwordPivot/AttackArea
@onready var _attack_collision: CollisionShape2D = $Visual/SwordPivot/AttackArea/CollisionShape2D
@onready var _slash_visual: Polygon2D = $Visual/SwordPivot/AttackArea/SlashVisual
@onready var _dash_visual: Polygon2D = $Visual/DashVisual
@onready var _shield: Node2D = $Visual/Shield
@onready var _camera: Camera2D = $Camera2D
@onready var _king_label: Label = $KingLabel
@onready var _player_name_label: Label = $PlayerNameLabel
@onready var _player_health_label: Label = $PlayerHealthLabel
@onready var _avatar: TextureRect = $Avatar


func _ready() -> void:
	add_to_group("player")
	collision_mask |= ONE_WAY_PLATFORM_LAYER
	_gravity = float(ProjectSettings.get_setting("physics/2d/default_gravity", 1600.0))
	_create_body_parts()
	_create_pixel_character()
	set_character_appearance_seed(Time.get_ticks_usec())
	_health_regen_timer = Timer.new()
	_health_regen_timer.name = "HealthRegenerationTimer"
	_health_regen_timer.wait_time = float(health_regen_interval_msec) / 1000.0
	_health_regen_timer.one_shot = false
	_health_regen_timer.timeout.connect(_on_health_regeneration_timeout)
	add_child(_health_regen_timer)
	_refresh_body_health()
	_mana = max_mana
	mana_changed.emit(_mana, max_mana)
	_network_target_position = global_position
	_last_network_sent_position = global_position
	_was_on_floor = is_on_floor()


func _game_controller() -> Node:
	var node := get_parent()
	while is_instance_valid(node):
		if node.has_method("request_pvp_damage"):
			return node
		node = node.get_parent()
	return get_tree().current_scene


func _has_active_multiplayer_session() -> bool:
	var peer := multiplayer.multiplayer_peer
	return multiplayer.has_multiplayer_peer() and not (peer is OfflineMultiplayerPeer)


func _physics_process(delta: float) -> void:
	_animation_time += delta
	if _has_active_multiplayer_session() and not is_multiplayer_authority():
		_update_network_proxy_timers(delta)
		var predicted_position := _network_target_position \
			+ _network_target_velocity * _network_prediction_seconds
		if global_position.distance_to(predicted_position) > 140.0:
			global_position = predicted_position
		else:
			global_position = global_position.lerp(predicted_position, minf(delta * 45.0, 1.0))
		velocity = _network_target_velocity
		_visual.scale.x = _network_facing
		_animate_body_parts()
		return

	_regenerate_mana(delta)
	_update_timers(delta)
	_update_platform_drop(delta)
	_update_block()
	if _dash_timer > 0.0:
		_handle_attack(delta)
		_update_dash(delta)
	elif not _is_dead and _controls_enabled and _hurt_lock_timer <= 0.0 \
		and _movement_stun_timer <= 0.0:
		_apply_gravity(delta)
		_handle_horizontal_movement(delta)
		_handle_jump()
		_handle_attack(delta)
		_handle_dash()
		_handle_spell(delta)
	else:
		_apply_gravity(delta)
		if _is_dead:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	move_and_slide()
	_update_movement_sfx(delta)
	_animate_body_parts()
	_network_send_timer -= delta
	_network_heartbeat_timer -= delta
	_network_keyframe_timer -= delta
	if _has_active_multiplayer_session() and _network_send_timer <= 0.0:
		var facing := signf(_visual.scale.x)
		var active_motion := velocity.length_squared() > 625.0 \
			or _dash_timer > 0.0 or _attack_phase != AttackPhase.NONE or _is_blocking
		var state_changed := global_position.distance_squared_to(
			_last_network_sent_position
		) > 0.25 \
			or velocity.distance_squared_to(_last_network_sent_velocity) > 4.0 \
			or not is_equal_approx(facing, _last_network_sent_facing)
		_network_send_timer = 1.0 / (60.0 if active_motion else 12.0)
		if not state_changed and _network_heartbeat_timer > 0.0:
			return
		_network_heartbeat_timer = 0.25
		var reliable_keyframe := _network_keyframe_timer <= 0.0
		if reliable_keyframe:
			_network_keyframe_timer = 0.10 if active_motion else 0.25
		_network_state_sequence += 1
		_last_network_sent_position = global_position
		_last_network_sent_velocity = velocity
		_last_network_sent_facing = facing
		var main := _game_controller()
		if is_instance_valid(main) and main.has_method("submit_player_network_state"):
			main.submit_player_network_state(
				get_multiplayer_authority(),
				_network_state_sequence,
				global_position,
				velocity,
				facing,
				main.get_estimated_server_msec(),
				reliable_keyframe,
				is_on_floor()
			)


func _update_network_proxy_timers(delta: float) -> void:
	# The server owns damage resolution even when the player node is owned by a
	# client. These timers must keep advancing on remote proxies; otherwise one
	# hit leaves a client-owned player permanently invulnerable on the server.
	_invincibility_timer = maxf(_invincibility_timer - delta, 0.0)
	_hurt_lock_timer = maxf(_hurt_lock_timer - delta, 0.0)
	_spell_animation_timer = maxf(_spell_animation_timer - delta, 0.0)
	_spell_cooldown_timer = maxf(_spell_cooldown_timer - delta, 0.0)
	_movement_stun_timer = maxf(_movement_stun_timer - delta, 0.0)
	_attack_stun_timer = maxf(_attack_stun_timer - delta, 0.0)
	if _is_blocking:
		_block_timer += delta
	else:
		_block_timer = 0.0


func _update_timers(delta: float) -> void:
	_invincibility_timer = maxf(_invincibility_timer - delta, 0.0)
	_hurt_lock_timer = maxf(_hurt_lock_timer - delta, 0.0)
	_spell_animation_timer = maxf(_spell_animation_timer - delta, 0.0)
	_spell_cooldown_timer = maxf(_spell_cooldown_timer - delta, 0.0)
	_movement_stun_timer = maxf(_movement_stun_timer - delta, 0.0)
	_attack_stun_timer = maxf(_attack_stun_timer - delta, 0.0)
	_enemy_slow_timer = maxf(_enemy_slow_timer - delta, 0.0)
	_enemy_weakness_timer = maxf(_enemy_weakness_timer - delta, 0.0)
	if _enemy_slow_timer <= 0.0:
		_enemy_slow_multiplier = 1.0
	if _enemy_weakness_timer <= 0.0:
		_enemy_weakness_multiplier = 1.0
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


func _update_platform_drop(delta: float) -> void:
	if _drop_through_timer > 0.0:
		_drop_through_timer = maxf(0.0, _drop_through_timer - delta)
		collision_mask &= ~ONE_WAY_PLATFORM_LAYER
		if _drop_through_timer <= 0.0:
			collision_mask |= ONE_WAY_PLATFORM_LAYER
		return
	collision_mask |= ONE_WAY_PLATFORM_LAYER
	if not _controls_enabled or _is_dead:
		return
	if not Input.is_action_just_pressed("move_down"):
		return
	var now := Time.get_ticks_msec()
	var double_tap := now - _last_down_tap_msec <= DOUBLE_TAP_DOWN_MSEC
	_last_down_tap_msec = now
	if double_tap and is_on_floor():
		_drop_through_timer = DROP_THROUGH_DURATION
		_stop_block(false)
		collision_mask &= ~ONE_WAY_PLATFORM_LAYER
		position.y += 3.0
		velocity.y = maxf(velocity.y, 120.0)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += _gravity * delta


func _handle_horizontal_movement(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	var guard_speed := block_move_multiplier if _is_blocking else 1.0
	var target_speed := direction * move_speed * _movement_multiplier * guard_speed * _enemy_slow_multiplier

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
		SFX.play("jump", 0.04)
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
	elif _jump_buffer_timer > 0.0 and _extra_jumps_left > 0:
		velocity.y = jump_velocity * _jump_multiplier
		SFX.play("jump", 0.08, 1.0)
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
	_cancel_spell_charge()
	_combo_step = step
	_attack_kind = kind
	_attack_phase = AttackPhase.WINDUP
	_attack_timer = _get_windup_duration(step) / _effective_attack_speed()
	_hit_targets.clear()
	_set_slash_aura_visible(false)
	_slash_visual.scale = Vector2(0.9 + step * 0.12, 0.82 + step * 0.08)
	_slash_visual.color = Color(1.0, 0.82 - step * 0.08, 0.2, 0.78)
	match _attack_kind:
		AttackKind.AIR:
			_set_attack_hitbox_size(Vector2(76, 62))
			_attack_area.position = Vector2(52, 18)
			_slash_visual.scale = Vector2(1.1, 1.2)
		AttackKind.DASH:
			_set_attack_hitbox_size(Vector2(76, 62))
			_attack_area.position = Vector2(72, 0)
			_slash_visual.scale = Vector2(1.45, 0.85)
		AttackKind.LOW:
			_set_attack_hitbox_size(Vector2(76, 62))
			_attack_area.position = Vector2(58, 34)
			_slash_visual.scale = Vector2(1.3, 0.72)
		_:
			_set_attack_hitbox_size(Vector2(76, 62))
			_attack_area.position = Vector2(48.0 + step * 5.0, 0)
	_configure_slash_aura(step, int(kind))
	_play_sword_windup(step)
	if _has_active_multiplayer_session():
		_send_network_combat_effect("attack", step, int(kind), _visual.scale.x)


func _set_attack_hitbox_size(size: Vector2) -> void:
	if not is_instance_valid(_attack_collision):
		return
	var rectangle := _attack_collision.shape as RectangleShape2D
	if is_instance_valid(rectangle):
		rectangle.size = size


func _begin_active_attack() -> void:
	_attack_phase = AttackPhase.ACTIVE
	var swing_key := "sword_swing_%d" % clampi(_combo_step, 1, 3)
	SFX.play(swing_key, 0.035)
	_attack_timer = _get_active_duration(_combo_step) / _effective_attack_speed()
	_set_slash_aura_visible(true)
	_play_sword_swing(_combo_step)
	if _has_active_multiplayer_session() and is_multiplayer_authority():
		_network_attack_sequence += 1
		var main := _game_controller()
		if is_instance_valid(main) and main.has_method("request_pvp_melee_swing"):
			main.request_pvp_melee_swing(
				get_multiplayer_authority(),
				_network_attack_sequence,
				int(_attack_kind),
				_combo_step,
				signf(_visual.scale.x),
				global_position,
				main.get_estimated_server_msec()
			)
	if _attack_kind == AttackKind.AIR:
		velocity.y = 220.0
	elif _attack_kind == AttackKind.DASH:
		velocity.x = _dash_direction * dash_speed * _dash_multiplier * 1.1
	_damage_overlapping_enemies()


func _begin_attack_recovery() -> void:
	_attack_phase = AttackPhase.RECOVERY
	_attack_timer = _get_recovery_duration(_combo_step) / _effective_attack_speed()
	_set_slash_aura_visible(false)
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
				var main := _game_controller()
				if _has_active_multiplayer_session() and is_instance_valid(main) \
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
		var damage := maxi(1, roundi(base_damage * _attack_damage_multiplier * _enemy_weakness_multiplier))
		if _apply_damage_to_part(part, damage):
			_hit_targets[target_id] = true
			_trigger_build_effects(part, damage)


func _trigger_build_effects(part: BodyPart, damage: int) -> void:
	if not is_instance_valid(part) or not is_instance_valid(part.actor):
		return
	_elemental_hit_counter += 1
	if _fire_build_level > 0:
		var effect := DAMAGE_OVER_TIME_SCRIPT.new()
		effect.configure(part.actor, global_position, maxi(1, _fire_build_level), 2 + _fire_build_level, 0.65)
		part.actor.add_child(effect)
		SFX.play_at("explosion", part.global_position, 0.08, -7.0)
	if _frost_build_level > 0 and part.actor.has_method("apply_movement_stun"):
		part.actor.apply_movement_stun(0.10 + 0.08 * _frost_build_level)
		SFX.play_at("frost", part.global_position, 0.05, -5.0)
	if _lightning_build_level > 0 and _elemental_hit_counter % 3 == 0:
		_chain_lightning(part.actor, maxi(1, roundi(float(damage) * (0.28 + 0.12 * _lightning_build_level))))
	if _fire_build_level > 0 and _frost_build_level > 0 and _elemental_hit_counter % 4 == 0:
		part.receive_damage(_fire_build_level + _frost_build_level, global_position, "magic")


func _chain_lightning(primary_target: Node, chain_damage: int) -> void:
	var candidates: Array[Node2D] = []
	for node in get_tree().get_nodes_in_group("enemy"):
		if node != primary_target and node is Node2D \
			and is_instance_valid(node) and global_position.distance_to((node as Node2D).global_position) <= 240.0:
			candidates.append(node as Node2D)
	candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool: return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position))
	for index in mini(_lightning_build_level, candidates.size()):
		var target := candidates[index]
		if target.has_method("take_damage"):
			target.take_damage(chain_damage, global_position)
			if _frost_build_level > 0 and target.has_method("apply_movement_stun"):
				target.apply_movement_stun(0.18)
	SFX.play("lightning", 0.035)


func _apply_damage_to_part(part: BodyPart, damage: int) -> bool:
	if part.actor is Player and _has_active_multiplayer_session():
		# PvP melee is resolved once per swing by the server. Client-side overlap
		# is intentionally not used because remote proxies can be a frame behind.
		return true
	var damage_kind := "low" if _attack_kind == AttackKind.LOW else "melee"
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
		var main := _game_controller()
		if is_instance_valid(main) and main.has_method("show_local_combat_message"):
			main.show_local_combat_message((global_position + part.actor.global_position) * 0.5, "拼刀！")
		return true
	if _has_active_multiplayer_session() and part.actor.is_in_group("enemy"):
		var main := _game_controller()
		if is_instance_valid(main) and main.has_method("request_enemy_part_damage"):
			return main.request_enemy_part_damage(
				part.actor,
				part.part_id,
				damage,
				damage_kind,
				global_position
			)
	return part.receive_damage(damage, global_position, damage_kind)


func request_network_damage(target: Player, part_id: StringName, damage: int, damage_kind: String) -> void:
	var main := _game_controller()
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
			part.apply_authoritative_state(int(values[0]), int(values[1]))
	_rebuild_part_effects()
	_refresh_body_health()


func _create_pixel_character() -> void:
	_pixel_character = Node2D.new()
	_pixel_character.name = "PixelCharacter"
	_pixel_character.position = CHARACTER_VISUAL_POSITION
	_pixel_character.scale = CHARACTER_VISUAL_SCALE
	_pixel_character.z_index = 2
	_visual.add_child(_pixel_character)
	_parts_root.z_index = 8
	_shield.z_index = 6
	_sword_pivot.z_index = 7
	_pixel_layers.clear()
	for index in 8:
		var sprite := Sprite2D.new()
		sprite.name = "Layer%d" % index
		sprite.centered = true
		sprite.region_enabled = true
		sprite.region_rect = Rect2(Vector2.ZERO, CHARACTER_FRAME_SIZE)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.z_index = index
		_pixel_character.add_child(sprite)
		_pixel_layers.append(sprite)
	_redrawn_action_sprite = Sprite2D.new()
	_redrawn_action_sprite.name = "RedrawnAction"
	_redrawn_action_sprite.texture = REDRAWN_ACTION_TEXTURE
	_redrawn_action_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_redrawn_action_sprite.region_enabled = true
	_redrawn_action_sprite.region_rect = Rect2(Vector2.ZERO, REDRAWN_ACTION_FRAME_SIZE)
	_redrawn_action_sprite.position = REDRAWN_ACTION_POSITION
	_redrawn_action_sprite.z_index = 4
	_redrawn_action_sprite.visible = false
	_visual.add_child(_redrawn_action_sprite)
	_spell_burst_sprite = Sprite2D.new()
	_spell_burst_sprite.name = "SpellBurst"
	_spell_burst_sprite.texture = SPELL_BURST_TEXTURE
	_spell_burst_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spell_burst_sprite.position = Vector2(-12, -5)
	_spell_burst_sprite.scale = Vector2(0.075, 0.075)
	_spell_burst_sprite.z_index = 9
	_spell_burst_sprite.visible = false
	_pixel_character.add_child(_spell_burst_sprite)
	for part in _parts.values():
		(part as BodyPart).set_art_visible(false)
	for node_name in ["Hilt", "Guard", "Blade"]:
		var weapon_art := _sword_pivot.get_node_or_null(node_name) as CanvasItem
		if is_instance_valid(weapon_art):
			weapon_art.visible = false
	_white_slash_sprite = Sprite2D.new()
	_white_slash_sprite.name = "WhiteSlash"
	_white_slash_sprite.texture = WHITE_SLASH_TEXTURE
	_white_slash_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_white_slash_sprite.scale = Vector2(0.105, 0.105)
	_white_slash_sprite.z_index = 10
	_white_slash_sprite.visible = false
	_attack_area.add_child(_white_slash_sprite)
	_shield.position = SHIELD_READY_POSITION
	_shield.visible = false


func _configure_slash_aura(step: int, kind: int) -> void:
	_slash_visual.rotation = 0.0
	if not is_instance_valid(_white_slash_sprite):
		return
	var effect_scale := 0.10 + float(clampi(step, 1, 3) - 1) * 0.012
	if kind == AttackKind.DASH:
		effect_scale = 0.135
	elif kind == AttackKind.LOW:
		effect_scale = 0.115
	_white_slash_sprite.position = Vector2.ZERO
	_white_slash_sprite.rotation = 0.0
	_white_slash_sprite.scale = Vector2(effect_scale, effect_scale)
	_white_slash_sprite.flip_v = step == 2 and kind == AttackKind.NORMAL
	_white_slash_sprite.modulate = Color.WHITE


func _set_slash_aura_visible(enabled: bool) -> void:
	_slash_visual.visible = false
	if is_instance_valid(_white_slash_sprite):
		_white_slash_sprite.visible = enabled


func set_character_appearance_seed(seed_value: int) -> void:
	_appearance_seed = seed_value if seed_value != 0 else 1
	if not is_instance_valid(_pixel_character):
		return
	var paths: Array[String] = [
		CHARACTER_ASSET_ROOT + "Character skin colors/Male Skin1.png",
		CHARACTER_ASSET_ROOT + "Male Clothing/Underwear.png",
		CHARACTER_ASSET_ROOT + "Male Clothing/Pants.png",
		CHARACTER_ASSET_ROOT + "Male Clothing/Shirt.png",
		"",
		CHARACTER_ASSET_ROOT + "Male Clothing/Boots.png",
		CHARACTER_ASSET_ROOT + "Male Hair/Male Hair1.png",
		CHARACTER_ASSET_ROOT + "Male Hand/Male Sword.png",
	]
	for index in _pixel_layers.size():
		var path := paths[index] if index < paths.size() else ""
		_pixel_layers[index].texture = load(path) as Texture2D if not path.is_empty() else null
	_update_pixel_frame(true)


func _rng_pick(rng: RandomNumberGenerator, values: Array) -> String:
	return str(values[rng.randi_range(0, values.size() - 1)])


func _update_pixel_limb_visibility() -> void:
	pass


func get_character_appearance_seed() -> int:
	return _appearance_seed


func configure_network_authority(peer_id: int) -> void:
	set_multiplayer_authority(peer_id)
	_network_keyframe_timer = 0.0
	_camera.enabled = peer_id == multiplayer.get_unique_id()
	if not is_multiplayer_authority():
		_controls_enabled = false


func set_camera_world_width(width: int, height: int = 720) -> void:
	_camera.limit_left = 0
	_camera.limit_right = width
	_camera.limit_top = 0
	_camera.limit_bottom = height


func set_pvp_enabled(enabled: bool) -> void:
	_pvp_enabled = enabled


func set_player_display_name(display_name: String) -> void:
	_player_name_label.text = display_name.left(18)


func get_player_display_name() -> String:
	return _player_name_label.text


func set_avatar_base64(encoded_avatar: String) -> void:
	if encoded_avatar.is_empty():
		_avatar.texture = null
		return
	var image_bytes := Marshalls.base64_to_raw(encoded_avatar)
	var image := Image.new()
	if image.load_png_from_buffer(image_bytes) != OK:
		_avatar.texture = null
		return
	_avatar.texture = ImageTexture.create_from_image(image)


func clear_input_state() -> void:
	for action in ["move_left", "move_right", "jump", "attack", "dash", "move_down", "spell"]:
		Input.action_release(action)
	_cancel_spell_charge()
	velocity.x = 0.0


func apply_pvp_upgrade(upgrade_index: int) -> void:
	var upgrades := ["attack", "attack_speed", "move_speed", "double_jump", "attack_range", "part_health", "magic_damage", "max_mana", "mana_regen", "dash_cooldown", "rapid_regeneration"]
	var selected: String = upgrades[upgrade_index % upgrades.size()]
	if selected == "double_jump" and has_double_jump_upgrade():
		selected = upgrades[(upgrade_index + 1) % upgrades.size()]
	if selected == "rapid_regeneration" and has_rapid_regeneration():
		selected = upgrades[(upgrade_index + 1) % upgrades.size()]
	apply_upgrade(selected)


func reset_for_pvp(spawn_position: Vector2) -> void:
	_network_keyframe_timer = 0.0
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
	health_regen_interval_msec = 6000
	_rapid_regeneration = false
	_applied_upgrade_count = 0
	_fire_build_level = 0
	_frost_build_level = 0
	_lightning_build_level = 0
	_counter_build_level = 0
	_charge_build_level = 0
	_elemental_hit_counter = 0
	if is_instance_valid(_health_regen_timer):
		_health_regen_timer.wait_time = 6.0
		_health_regen_timer.stop()
	dash_cooldown = 0.65
	_attack_area.scale.x = 1.0
	_can_block = true
	_block_cooldown_timer = 0.0
	_movement_stun_timer = 0.0
	_attack_stun_timer = 0.0
	_spell_cooldown_timer = 0.0
	_spell_charge_time = 0.0
	_is_charging_spell = false
	_spell_visual_tier = 0
	_spell_charge_cue_tier = 0
	_footstep_timer = 0.0
	_footstep_index = 0
	_was_on_floor = false
	_stop_block(false)
	_is_dead = false
	_last_attacker_peer_id = 0
	_mana = max_mana
	mana_changed.emit(_mana, max_mana)
	collision_layer = 2
	collision_mask = 1 | ONE_WAY_PLATFORM_LAYER
	modulate = Color.WHITE
	rotation = 0.0
	_shield.visible = false
	_sword_pivot.position = Vector2(14, -8)
	for part in _parts.values():
		(part as BodyPart).reset_part()
	global_position = spawn_position
	velocity = Vector2.ZERO
	_controls_enabled = is_multiplayer_authority()
	_refresh_body_health()
	stats_changed.emit(attack_damage, get_attack_speed_bonus())


func set_king(enabled: bool) -> void:
	_king_label.visible = enabled


func receive_network_state(
	state_sequence: int,
	network_position: Vector2,
	network_velocity: Vector2,
	facing: float,
	prediction_seconds: float,
	server_direct: bool = false,
	grounded: bool = true
) -> void:
	if state_sequence <= _last_received_state_sequence:
		return
	_last_received_state_sequence = state_sequence
	_network_target_position = network_position
	_network_target_velocity = network_velocity
	_network_target_grounded = grounded
	_network_facing = facing
	_network_prediction_seconds = clampf(prediction_seconds, 0.0, 0.12)
	if server_direct:
		global_position = network_position
		velocity = network_velocity
		_visual.scale.x = facing


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
	return get_melee_damage_for(int(_attack_kind), _combo_step)


func get_melee_damage_for(kind: int, step: int) -> int:
	var base_damage := attack_damage * (2 if step == 3 else 1)
	match kind:
		AttackKind.AIR:
			base_damage = roundi(base_damage * 1.35)
		AttackKind.DASH:
			base_damage = roundi(base_damage * 1.6)
		AttackKind.LOW:
			base_damage = roundi(base_damage * 1.2)
	return maxi(1, roundi(base_damage * _attack_damage_multiplier * _enemy_weakness_multiplier))


func server_confirm_melee_swing(kind: int, step: int, facing: float) -> void:
	_attack_kind = clampi(kind, AttackKind.NORMAL, AttackKind.LOW) as AttackKind
	_combo_step = clampi(step, 1, 3)
	_attack_phase = AttackPhase.ACTIVE
	if not is_zero_approx(facing):
		_visual.scale.x = signf(facing)


func get_best_pvp_hit_part(hit_position: Vector2, low_attack: bool) -> StringName:
	var preferred := ["left_leg", "right_leg"] if low_attack else [
		"torso", "head", "left_arm", "right_arm", "left_leg", "right_leg"
	]
	var best_id: StringName = &""
	var best_distance := INF
	for id in preferred:
		var part := _parts.get(id) as BodyPart
		if not is_instance_valid(part) or part.health <= 0:
			continue
		var distance := part.global_position.distance_squared_to(hit_position)
		if distance < best_distance:
			best_distance = distance
			best_id = StringName(id)
	if best_id == &"" and low_attack:
		return get_best_pvp_hit_part(hit_position, false)
	return best_id


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
		return 0.18
	if _attack_kind == AttackKind.LOW:
		return 0.13
	match step:
		1:
			return 0.15
		2:
			return 0.17
		_:
			return 0.21


func _get_recovery_duration(step: int) -> float:
	if _attack_kind == AttackKind.AIR:
		return 0.2
	if _attack_kind == AttackKind.DASH:
		return 0.2
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


func _handle_spell(delta: float) -> void:
	if _is_charging_spell:
		if Input.is_action_just_released("spell") or not Input.is_action_pressed("spell"):
			_release_spell_charge()
		else:
			_spell_charge_time = minf(_spell_charge_time + delta, SUPER_WAVE_TIME)
			if _spell_charge_cue_tier < 1 and _spell_charge_time >= CHARGED_WAVE_TIME:
				_spell_charge_cue_tier = 1
				SFX.play("charge_ready", 0.02)
			if _spell_charge_cue_tier < 2 and _spell_charge_time >= SUPER_WAVE_TIME:
				_spell_charge_cue_tier = 2
				SFX.play("super_ready", 0.015)
		return
	if not Input.is_action_just_pressed("spell") or _spell_cooldown_timer > 0.0:
		return
	if _mana < spell_cost or _attack_stun_timer > 0.0:
		return
	_stop_block()
	_is_charging_spell = true
	_spell_charge_time = 0.0
	_spell_visual_tier = 0
	_spell_charge_cue_tier = 0
	SFX.play("spell_charge", 0.03)


func start_dash() -> void:
	if _dash_cooldown_timer > 0.0 or _is_dead:
		return
	_cancel_spell_charge()
	_stop_block()
	var input_direction := Input.get_axis("move_left", "move_right")
	_dash_direction = input_direction if not is_zero_approx(input_direction) else signf(_visual.scale.x)
	if is_zero_approx(_dash_direction):
		_dash_direction = 1.0
	_visual.scale.x = _dash_direction
	_dash_timer = dash_duration
	SFX.play("dash", 0.035)
	_dash_cooldown_timer = dash_cooldown
	_invincibility_timer = maxf(_invincibility_timer, dash_duration)
	_attack_timer = 0.0
	_attack_phase = AttackPhase.NONE
	_combo_queued = false
	_set_slash_aura_visible(false)
	_dash_visual.visible = true
	_set_parts_tint(Color(0.35, 0.95, 1.0, 0.42))
	velocity = Vector2(_dash_direction * dash_speed * _dash_multiplier, 0.0)
	if _has_active_multiplayer_session():
		_send_network_combat_effect("dash", 0, 0, _dash_direction)


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
	if damage_kind in ["spell", "projectile"]:
		SFX.play("block", 0.04)
		_trigger_counter_attack(source_position, false)
		return 0
	if damage_kind == "low":
		return amount
	if _block_timer <= perfect_block_duration:
		SFX.play("perfect_block", 0.025)
		_trigger_counter_attack(source_position, true)
		_stun_attacker(source_position)
		var main := _game_controller()
		if is_instance_valid(main) and main.has_method("show_local_combat_message"):
			main.show_local_combat_message(global_position + Vector2(0, -55), "格挡！")
		return 0
	SFX.play("block", 0.04)
	return maxi(1, ceili(amount * (1.0 - block_damage_reduction)))


func _trigger_counter_attack(source_position: Vector2, perfect: bool) -> void:
	if _counter_build_level <= 0:
		return
	var closest: Node2D
	var closest_distance := 150.0 * 150.0
	for node in get_tree().get_nodes_in_group("enemy"):
		if not (node is Node2D):
			continue
		var enemy := node as Node2D
		var distance := enemy.global_position.distance_squared_to(source_position)
		if distance < closest_distance:
			closest = enemy
			closest_distance = distance
	if not is_instance_valid(closest) or not closest.has_method("take_damage"):
		return
	var counter_damage := maxi(1, roundi(float(attack_damage) * (0.45 + _counter_build_level * 0.3)))
	if perfect:
		counter_damage *= 2
	closest.take_damage(counter_damage, global_position)
	if _lightning_build_level > 0:
		_chain_lightning(closest, maxi(1, counter_damage / 2))


func _update_block() -> void:
	if _drop_through_timer > 0.0:
		_stop_block(false)
		return
	if not _can_block or _is_dead:
		_stop_block()
		return
	if Input.is_action_just_pressed("move_down") and is_on_floor() and _block_cooldown_timer <= 0.0:
		_start_block()
	if _is_blocking:
		_block_timer += get_physics_process_delta_time()
		_update_block_equipment_visual()
		if not Input.is_action_pressed("move_down"):
			_stop_block()


func _start_block() -> void:
	_cancel_spell_charge()
	_is_blocking = true
	_block_timer = 0.0
	_block_facing = signf(_visual.scale.x)
	if is_zero_approx(_block_facing):
		_block_facing = 1.0
	_begin_block_visual()
	if _has_active_multiplayer_session():
		_send_network_combat_effect("block_start", 0, 0, _block_facing)


func _stop_block(start_cooldown: bool = true) -> void:
	var was_blocking := _is_blocking
	_is_blocking = false
	_block_timer = 0.0
	if was_blocking and start_cooldown:
		_block_cooldown_timer = block_cooldown
	if was_blocking and _has_active_multiplayer_session() and is_multiplayer_authority():
		_send_network_combat_effect("block_stop", 0, 0, _block_facing)
	_end_block_visual()


func _begin_block_visual() -> void:
	_shield.visible = false
	_shield.position = SHIELD_STOWED_POSITION
	_shield.rotation = deg_to_rad(22.0)
	_shield.modulate = Color(0.55, 0.9, 1.0, 1.0)
	_set_pixel_sword_visible(true)


func _end_block_visual() -> void:
	_shield.visible = false
	_shield.position = SHIELD_READY_POSITION
	_shield.rotation = 0.0
	_shield.modulate = Color.WHITE
	_set_pixel_sword_visible(true)


func _update_block_equipment_visual() -> void:
	if not _is_blocking:
		return
	_shield.visible = false
	_set_pixel_sword_visible(_block_timer < BLOCK_SHEATHE_DURATION)


func _set_pixel_sword_visible(enabled: bool) -> void:
	if _pixel_layers.size() < 8:
		return
	var left_arm := _parts.get("left_arm") as BodyPart
	var right_arm := _parts.get("right_arm") as BodyPart
	var can_hold_weapon := (is_instance_valid(left_arm) and left_arm.health > 0) \
		or (is_instance_valid(right_arm) and right_arm.health > 0)
	_pixel_layers[7].visible = enabled and can_hold_weapon


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
	for node in get_tree().get_nodes_in_group("enemy"):
		var candidate := node as Node2D
		if not is_instance_valid(candidate):
			continue
		var distance := candidate.global_position.distance_squared_to(source_position)
		if distance < best_distance:
			attacker = candidate
			best_distance = distance
	if not is_instance_valid(attacker):
		return
	if attacker is Player and _has_active_multiplayer_session():
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
	_set_slash_aura_visible(false)


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
		_set_slash_aura_visible(false)
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
	_refresh_body_health()
	if part.health <= 0 and part.vital:
		_die()
		return
	if _is_blocking:
		_invincibility_timer = minf(_invincibility_timer, 0.08)
		return
	_cancel_spell_charge()
	SFX.play("player_hurt", 0.05)
	_invincibility_timer = pvp_invincibility_duration if _pvp_enabled \
		else invincibility_duration
	_hurt_lock_timer = minf(hurt_lock_duration, 0.12) if _pvp_enabled \
		else hurt_lock_duration
	_attack_timer = 0.0
	_attack_phase = AttackPhase.NONE
	_combo_queued = false
	_dash_timer = 0.0
	_set_slash_aura_visible(false)
	_dash_visual.visible = false
	if is_instance_valid(_pixel_character):
		_pixel_character.modulate = Color(1.0, 0.35, 0.35, 1.0)
		var hurt_tween := create_tween()
		hurt_tween.tween_property(_pixel_character, "modulate", Color.WHITE, 0.14)

	var knockback_direction := signf(global_position.x - source_position.x)
	if is_zero_approx(knockback_direction):
		knockback_direction = 1.0
	velocity = Vector2(knockback_direction * knockback_speed, -230.0)


func apply_network_knockback(knockback_velocity: Vector2) -> void:
	velocity = knockback_velocity


func get_health() -> int:
	return _health


func is_dead() -> bool:
	return _is_dead


func _on_health_regeneration_timeout() -> void:
	if _is_dead or _health >= max_health:
		_health_regen_timer.stop()
		return
	if _has_active_multiplayer_session() and not is_multiplayer_authority():
		return
	if _has_active_multiplayer_session():
		var main := _game_controller()
		if is_instance_valid(main) and main.has_method("request_player_regeneration"):
			main.request_player_regeneration(get_multiplayer_authority())
	else:
		heal_next_body_part()


func heal_next_body_part() -> bool:
	for id in ["torso", "head", "left_arm", "right_arm", "left_leg", "right_leg"]:
		var part := _parts.get(id) as BodyPart
		if is_instance_valid(part) and part.heal_one():
			return true
	return false


func restore_for_arena_wave() -> void:
	for part in _parts.values():
		var body_part := part as BodyPart
		body_part.apply_authoritative_state(body_part.max_health, body_part.max_health)
	_mana = max_mana
	_is_dead = false
	_invincibility_timer = 0.0
	_hurt_lock_timer = 0.0
	_spell_cooldown_timer = 0.0
	_cancel_spell_charge()
	_refresh_body_health()
	mana_changed.emit(_mana, max_mana)


func revive_for_coop(spawn_position: Vector2) -> void:
	restore_for_arena_wave()
	_network_keyframe_timer = 0.0
	global_position = spawn_position
	velocity = Vector2.ZERO
	collision_layer = 2
	collision_mask = 1 | ONE_WAY_PLATFORM_LAYER
	modulate = Color.WHITE
	rotation = 0.0
	_last_attacker_peer_id = 0
	_controls_enabled = is_multiplayer_authority()
	_update_pixel_frame(true)


func get_health_regen_interval() -> float:
	return float(health_regen_interval_msec) / 1000.0


func get_health_regen_interval_msec() -> int:
	return health_regen_interval_msec


func get_next_health_regen_msec() -> int:
	if not is_instance_valid(_health_regen_timer) or _health_regen_timer.is_stopped():
		return 0
	return Time.get_ticks_msec() + roundi(_health_regen_timer.time_left * 1000.0)


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
	return _cast_spell_tier(0)


func cast_charged_spell(charge_seconds: float) -> bool:
	var tier := 0
	if charge_seconds >= SUPER_WAVE_TIME:
		tier = 2
	elif charge_seconds >= CHARGED_WAVE_TIME:
		tier = 1
	return _cast_spell_tier(tier)


func _release_spell_charge() -> void:
	if not _is_charging_spell:
		return
	var held_time := _spell_charge_time
	_is_charging_spell = false
	_spell_charge_time = 0.0
	cast_charged_spell(held_time)


func _cancel_spell_charge() -> void:
	_is_charging_spell = false
	_spell_charge_time = 0.0
	_spell_charge_cue_tier = 0


func _cast_spell_tier(tier: int) -> bool:
	if _spell_cooldown_timer > 0.0 or _is_dead:
		return false
	tier = clampi(tier, 0, 2)
	var mana_cost := spell_cost
	var damage_multiplier := 1
	if tier == 1:
		mana_cost = maxi(60, charged_wave_cost - _charge_build_level * 5)
		damage_multiplier = 3 + _charge_build_level
	elif tier == 2:
		mana_cost = maxi(80, super_wave_cost - _charge_build_level * 5)
		damage_multiplier = 5 + _charge_build_level * 2
	if _mana < mana_cost:
		return false
	_mana -= mana_cost
	_spell_cooldown_timer = spell_cooldown
	_spell_animation_timer = 0.48 if tier > 0 else 0.36
	_spell_visual_tier = tier
	mana_changed.emit(_mana, max_mana)
	var bolt := MAGIC_BOLT_SCENE.instantiate() as MagicBolt
	bolt.caster = self
	bolt.damage = spell_damage * damage_multiplier
	bolt.power_tier = tier
	bolt.fire_level = _fire_build_level
	bolt.frost_level = _frost_build_level
	bolt.lightning_level = _lightning_build_level
	bolt.direction = signf(_visual.scale.x)
	if is_zero_approx(bolt.direction):
		bolt.direction = 1.0
	bolt.global_position = global_position + Vector2(bolt.direction * 42.0, -10.0)
	_game_controller().add_child(bolt)
	match tier:
		1:
			SFX.play("charged_wave", 0.02)
		2:
			SFX.play("super_wave", 0.015)
		_:
			SFX.play("spell_cast", 0.035)
	if _has_active_multiplayer_session():
		var action := "spell" if tier == 0 else "spell_charge_%d" % tier
		_send_network_combat_effect(action, 0, 0, bolt.direction)
	return true


func get_spell_cooldown_time() -> float:
	return _spell_cooldown_timer


func get_spell_charge_time() -> float:
	return _spell_charge_time


func is_charging_spell() -> bool:
	return _is_charging_spell


func _send_network_combat_effect(action: String, step: int, kind: int, facing: float) -> void:
	if not is_multiplayer_authority():
		return
	_network_effect_sequence += 1
	var main := _game_controller()
	if is_instance_valid(main) and main.has_method("request_player_combat_effect"):
		main.request_player_combat_effect(
			get_multiplayer_authority(),
			_network_effect_sequence,
			action,
			step,
			kind,
			facing
		)


func apply_network_combat_effect(action: String, step: int, kind: int, facing: float) -> void:
	_visual.scale.x = facing
	match action:
		"attack":
			_combo_step = step
			_attack_kind = kind
			_attack_phase = AttackPhase.WINDUP
			_configure_slash_aura(step, kind)
			_set_slash_aura_visible(false)
			_play_sword_windup(step)
			var tween := create_tween()
			tween.tween_interval(_get_windup_duration(step) / _effective_attack_speed())
			tween.tween_callback(func() -> void:
				_attack_phase = AttackPhase.ACTIVE
				_set_slash_aura_visible(true)
				_play_sword_swing(step)
				SFX.play_at("sword_swing_%d" % clampi(step, 1, 3), global_position, 0.035)
			)
			tween.tween_interval(_get_active_duration(step) / _effective_attack_speed())
			tween.tween_callback(func() -> void:
				_attack_phase = AttackPhase.RECOVERY
				_set_slash_aura_visible(false)
				_play_sword_recovery()
			)
			tween.tween_interval(_get_recovery_duration(step) / _effective_attack_speed())
			tween.tween_callback(func() -> void:
				_set_slash_aura_visible(false)
				_attack_phase = AttackPhase.NONE
			)
		"dash":
			SFX.play_at("dash", global_position, 0.035)
			_dash_visual.visible = true
			_set_parts_tint(Color(0.35, 0.95, 1.0, 0.42))
			var tween := create_tween()
			tween.tween_interval(dash_duration)
			tween.tween_callback(func() -> void:
				_dash_visual.visible = false
				_set_parts_tint(Color.WHITE)
			)
		"spell", "spell_charge_1", "spell_charge_2":
			var tier := 0 if action == "spell" else int(action.get_slice("_", 2))
			_spell_visual_tier = tier
			_spell_animation_timer = 0.48 if tier > 0 else 0.36
			var bolt := MAGIC_BOLT_SCENE.instantiate() as MagicBolt
			bolt.caster = self
			bolt.damage = spell_damage * (5 if tier == 2 else (3 if tier == 1 else 1))
			bolt.power_tier = tier
			bolt.direction = facing
			if not multiplayer.is_server():
				bolt.collision_layer = 0
				bolt.collision_mask = 0
			bolt.global_position = global_position + Vector2(facing * 42.0, -10.0)
			_game_controller().add_child(bolt)
			SFX.play_at("super_wave" if tier == 2 else ("charged_wave" if tier == 1 else "spell_cast"), global_position, 0.02)
		"block_start":
			_is_blocking = true
			_block_timer = 0.0
			_begin_block_visual()
		"block_stop":
			_is_blocking = false
			_block_timer = 0.0
			_end_block_visual()


func _sync_combat_effect(action: String, step: int, kind: int, facing: float) -> void:
	# Kept as a local compatibility wrapper for existing tests.
	apply_network_combat_effect(action, step, kind, facing)


func set_controls_enabled(enabled: bool) -> void:
	_controls_enabled = enabled
	if not enabled:
		velocity.x = 0.0
		_attack_timer = 0.0
		_attack_phase = AttackPhase.NONE
		_combo_queued = false
		_set_slash_aura_visible(false)
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
				health_regen_interval_msec = 3000
				_health_regen_timer.wait_time = 3.0
				if _health < max_health:
					_health_regen_timer.start()
		"fire_build":
			_fire_build_level += 1
		"frost_build":
			_frost_build_level += 1
		"lightning_build":
			_lightning_build_level += 1
		"counter_build":
			_counter_build_level += 1
		"charge_build":
			_charge_build_level += 1
	_applied_upgrade_count += 1
	stats_changed.emit(attack_damage, get_attack_speed_bonus())


func get_attack_speed_bonus() -> int:
	return roundi((_attack_speed_multiplier - 1.0) * 100.0)


func get_applied_upgrade_count() -> int:
	return _applied_upgrade_count


func get_build_levels() -> Dictionary:
	return {
		"fire": _fire_build_level,
		"frost": _frost_build_level,
		"lightning": _lightning_build_level,
		"counter": _counter_build_level,
		"charge": _charge_build_level,
	}


func get_movement_multiplier() -> float:
	return _movement_multiplier


func get_attack_damage_multiplier() -> float:
	return _attack_damage_multiplier * _enemy_weakness_multiplier


func apply_enemy_slow(duration: float, multiplier: float = 0.6) -> void:
	_enemy_slow_timer = maxf(_enemy_slow_timer, duration)
	_enemy_slow_multiplier = minf(_enemy_slow_multiplier, clampf(multiplier, 0.25, 1.0))


func apply_enemy_weakness(duration: float, multiplier: float = 0.7) -> void:
	_enemy_weakness_timer = maxf(_enemy_weakness_timer, duration)
	_enemy_weakness_multiplier = minf(_enemy_weakness_multiplier, clampf(multiplier, 0.25, 1.0))


func apply_all_attribute_upgrade() -> void:
	for upgrade_id in [
		"attack", "attack_speed", "move_speed", "double_jump", "attack_range",
		"part_health", "magic_damage", "max_mana", "mana_regen",
		"dash_cooldown", "rapid_regeneration", "fire_build", "frost_build",
		"lightning_build", "counter_build", "charge_build",
	]:
		apply_upgrade(upgrade_id)


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
	if not is_instance_valid(_health_regen_timer):
		return
	if _is_dead or _health >= max_health:
		_health_regen_timer.stop()
	elif _health_regen_timer.is_stopped() \
		and (not _has_active_multiplayer_session() or is_multiplayer_authority()):
		_health_regen_timer.start()


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
	if _pixel_layers.size() >= 8:
		var left_arm := _parts.get("left_arm") as BodyPart
		var right_arm := _parts.get("right_arm") as BodyPart
		_pixel_layers[7].visible = (
			is_instance_valid(left_arm) and left_arm.health > 0
		) or (
			is_instance_valid(right_arm) and right_arm.health > 0
		)
	_update_pixel_limb_visibility()
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
	_shield.visible = false
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
	if _pixel_layers.size() >= 8:
		var left_arm := _parts.get("left_arm") as BodyPart
		var right_arm := _parts.get("right_arm") as BodyPart
		_pixel_layers[7].visible = (
			is_instance_valid(left_arm) and left_arm.health > 0
		) or (
			is_instance_valid(right_arm) and right_arm.health > 0
		)
	_update_pixel_limb_visibility()
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
	if is_instance_valid(_player_health_label):
		_player_health_label.text = "生命 %d/%d" % [_health, max_health]
		var ratio := float(_health) / maxf(float(max_health), 1.0)
		_player_health_label.modulate = Color(0.4, 1.0, 0.45) if ratio > 0.5 \
			else Color(1.0, 0.8, 0.25) if ratio > 0.2 else Color(1.0, 0.25, 0.2)


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
	var animation_grounded := _is_animation_grounded()
	if animation_grounded and absf(velocity.x) > 18.0 and _attack_phase == AttackPhase.NONE and _dash_timer <= 0.0:
		_walk_cycle += absf(velocity.x) * get_physics_process_delta_time() * 0.035
	elif animation_grounded and absf(velocity.x) <= 18.0:
		_walk_cycle = 0.0
	_update_pixel_frame()
	_update_block_equipment_visual()
	if is_instance_valid(_pixel_character):
		_pixel_character.position = CHARACTER_VISUAL_POSITION
		_pixel_character.rotation = 0.0
		_pixel_character.scale = CHARACTER_VISUAL_SCALE
	_update_redrawn_action_visual()
	_update_spell_burst()
	for part in _parts.values():
		(part as BodyPart).animate_transform(Vector2.ZERO, 0.0, 0.45)


func _update_movement_sfx(delta: float) -> void:
	_footstep_timer = maxf(0.0, _footstep_timer - delta)
	var grounded := is_on_floor()
	if grounded and not _was_on_floor:
		SFX.play("land", 0.055)
	if grounded and absf(velocity.x) > 55.0 and _dash_timer <= 0.0 \
		and _attack_phase == AttackPhase.NONE and not _is_blocking:
		if _footstep_timer <= 0.0:
			_footstep_index = (_footstep_index + 1) % 2
			SFX.play("footstep_%d" % (_footstep_index + 1), 0.075)
			var speed_ratio := clampf(absf(velocity.x) / maxf(move_speed, 1.0), 0.0, 1.4)
			_footstep_timer = lerpf(0.34, 0.16, minf(speed_ratio, 1.0))
	_was_on_floor = grounded


func _update_redrawn_action_visual() -> void:
	if not is_instance_valid(_redrawn_action_sprite):
		return
	var action_visible := _attack_phase != AttackPhase.NONE or _is_blocking
	_redrawn_action_sprite.visible = action_visible
	_pixel_character.visible = not action_visible
	if not action_visible:
		return
	var row := 4
	var column := 0
	if _attack_phase != AttackPhase.NONE:
		row = 3 if _attack_kind == AttackKind.DASH else clampi(_combo_step - 1, 0, 2)
		var progress := _get_attack_phase_progress()
		match _attack_phase:
			AttackPhase.WINDUP:
				column = clampi(floori(progress * 3.0), 0, 2)
			AttackPhase.ACTIVE:
				column = clampi(3 + floori(progress * 3.0), 3, 5)
			AttackPhase.RECOVERY:
				column = clampi(6 + floori(progress * 2.0), 6, 7)
	else:
		var defense_progress := clampf(
			_block_timer / (BLOCK_SHEATHE_DURATION + BLOCK_RAISE_DURATION),
			0.0,
			1.0
		)
		column = clampi(floori(defense_progress * 8.0), 0, 7)
	_redrawn_action_sprite.region_rect = Rect2(
		Vector2(column * REDRAWN_ACTION_FRAME_SIZE.x, row * REDRAWN_ACTION_FRAME_SIZE.y),
		REDRAWN_ACTION_FRAME_SIZE
	)


func _update_spell_burst() -> void:
	if not is_instance_valid(_spell_burst_sprite):
		return
	var casting := _spell_animation_timer > 0.0 or _is_charging_spell
	_spell_burst_sprite.visible = casting
	if not casting:
		return
	if _is_charging_spell:
		var charge_ratio := clampf(_spell_charge_time / SUPER_WAVE_TIME, 0.0, 1.0)
		var pulse_wave := (sin(_animation_time * (8.0 + charge_ratio * 8.0)) + 1.0) * 0.5
		var pulse := 0.06 + charge_ratio * 0.07 + pulse_wave * 0.018
		_spell_burst_sprite.scale = Vector2(pulse, pulse)
		_spell_burst_sprite.rotation = _animation_time * (1.8 + charge_ratio * 2.2)
		_spell_burst_sprite.modulate = Color(0.3, 0.62 + charge_ratio * 0.35, 1.0, 0.5 + charge_ratio * 0.5)
		if _spell_charge_time >= SUPER_WAVE_TIME:
			_spell_burst_sprite.modulate = Color(0.9, 1.0, 1.0, 1.0)
		elif _spell_charge_time >= CHARGED_WAVE_TIME:
			_spell_burst_sprite.modulate = Color(0.35, 0.9, 1.0, 0.95)
		return
	var animation_duration := 0.48 if _spell_visual_tier > 0 else 0.36
	var progress := clampf(1.0 - _spell_animation_timer / animation_duration, 0.0, 1.0)
	var release_scale := 0.065 + float(_spell_visual_tier) * 0.025 + sin(progress * PI) * 0.025
	_spell_burst_sprite.scale = Vector2(release_scale, release_scale)
	_spell_burst_sprite.rotation = progress * PI * (0.5 + float(_spell_visual_tier) * 0.25)
	_spell_burst_sprite.modulate = Color(0.55, 0.86, 1.0, sin(progress * PI))


func _get_attack_phase_progress() -> float:
	var duration := 1.0
	match _attack_phase:
		AttackPhase.WINDUP:
			duration = _get_windup_duration(_combo_step) / _effective_attack_speed()
		AttackPhase.ACTIVE:
			duration = _get_active_duration(_combo_step) / _effective_attack_speed()
		AttackPhase.RECOVERY:
			duration = _get_recovery_duration(_combo_step) / _effective_attack_speed()
	return clampf(1.0 - _attack_timer / maxf(duration, 0.001), 0.0, 1.0)


func _update_pixel_frame(force: bool = false) -> void:
	if _pixel_layers.is_empty():
		return
	var row := 0
	var frame_count := 5
	var fps := 6.0
	if _is_dead:
		row = 6
		frame_count = 10
		fps = 9.0
	elif _spell_animation_timer > 0.0 or _is_charging_spell:
		row = 4
		frame_count = 4
		fps = 11.0
	elif _attack_phase != AttackPhase.NONE:
		row = 5
		frame_count = 6
		fps = 12.0 * _effective_attack_speed()
	elif _is_blocking:
		row = 5
		frame_count = 2
		fps = 3.0
	elif not _is_animation_grounded():
		row = 3
		frame_count = 4
		fps = 7.0
	elif absf(velocity.x) > 190.0:
		row = 2
		frame_count = 8
		fps = 12.0
	elif absf(velocity.x) > 18.0:
		row = 1
		frame_count = 8
		fps = 9.0
	var column := floori(_animation_time * fps) % frame_count
	if row in [1, 2]:
		column = floori(_walk_cycle) % frame_count
	elif _spell_animation_timer > 0.0 or _is_charging_spell:
		var cast_progress := fmod(_spell_charge_time * 1.8, 1.0) if _is_charging_spell else clampf(1.0 - _spell_animation_timer / (0.48 if _spell_visual_tier > 0 else 0.36), 0.0, 1.0)
		column = clampi(floori(cast_progress * 4.0), 0, 3)
	elif _attack_phase != AttackPhase.NONE:
		match _attack_phase:
			AttackPhase.WINDUP:
				column = 0 if _get_attack_phase_progress() < 0.35 else 1
			AttackPhase.ACTIVE:
				if _attack_kind == AttackKind.LOW:
					column = 3
				elif _get_attack_phase_progress() < 0.20:
					column = 1
				elif _get_attack_phase_progress() < 0.58:
					column = 2
				else:
					column = 3
			AttackPhase.RECOVERY:
				column = 3 if _get_attack_phase_progress() < 0.35 else 0
	if _is_blocking:
		column = 4 if _block_timer < BLOCK_SHEATHE_DURATION else 5
	var next_frame := Vector2i(column, row)
	if not force and next_frame == _pixel_frame:
		return
	_pixel_frame = next_frame
	var region := Rect2(
		Vector2(next_frame.x * CHARACTER_FRAME_SIZE.x, next_frame.y * CHARACTER_FRAME_SIZE.y),
		CHARACTER_FRAME_SIZE
	)
	for sprite in _pixel_layers:
		sprite.region_rect = region


func _is_animation_grounded() -> bool:
	if _has_active_multiplayer_session() and not is_multiplayer_authority():
		return _network_target_grounded
	return is_on_floor()


func _animate_part(id: StringName, offset: Vector2, angle: float) -> void:
	var part: BodyPart = _parts.get(id)
	if is_instance_valid(part):
		part.animate_transform(offset, angle)


func _set_parts_tint(color: Color) -> void:
	for part in _parts.values():
		(part as BodyPart).set_tint(color)
	if is_instance_valid(_pixel_character):
		_pixel_character.modulate = color


func _die() -> void:
	_cancel_spell_charge()
	SFX.play("player_hurt", 0.0, 2.0)
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
