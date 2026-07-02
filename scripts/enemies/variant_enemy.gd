class_name VariantEnemy
extends CharacterBody2D

signal defeated

const DAMAGE_OVER_TIME_SCRIPT := preload("res://scripts/combat/damage_over_time.gd")
const ENEMY_PROJECTILE_SCRIPT := preload("res://scripts/combat/enemy_projectile.gd")
const ENEMY_HAZARD_SCRIPT := preload("res://scripts/combat/enemy_hazard.gd")

enum State { IDLE, CHASE, TURN, WINDUP, ATTACK, RECOVERY, HURT, DEAD }

const BOSS_SUMMON_POOL := ["crypt_dog", "corrupted_dog", "pounce_dog", "venom_dog", "bomber_dog"]
const SKELETON_GENERAL_SUMMON_POOL := ["skeleton", "skeleton_shield", "skeleton_spear"]
const CRIMSON_WITCH_SUMMON_POOL := ["cursed_doll", "ghost_mage", "lightning_slime"]
const BOSS_MAX_SUMMONS := 3
const BOSS_BAR_WIDTH := 260.0
const BOSS_BAR_HEIGHT := 16.0
const ONE_WAY_PLATFORM_LAYER := 1 << 5
const RANGED_MODES := ["ranged", "summoner", "bomb_throw", "mage", "ghost_mage", "turret", "laser"]

const PROFILES := {
	"crypt_dog": {
		"name": "地穴犬", "family": "dog", "mode": "bite", "speed": 118.0,
		"range": 70.0, "damage": 2, "windup": 0.28, "duration": 0.18, "cooldown": 0.82,
		"color": Color("82604a"),
		"parts": [["head", "头", 5, true], ["body", "身体", 7, true], ["front_paws", "前爪", 4, false], ["back_legs", "后腿", 4, false]],
	},
	"corrupted_dog": {
		"name": "腐化犬", "family": "dog", "mode": "combo", "speed": 158.0,
		"range": 76.0, "damage": 2, "windup": 0.20, "duration": 0.50, "cooldown": 0.98,
		"color": Color("8b3fa1"),
		"parts": [["head", "头", 6, true], ["body", "身体", 8, true], ["front_paws", "前爪", 5, false], ["back_legs", "后腿", 5, false]],
	},
	"pounce_dog": {
		"name": "跳扑犬", "family": "dog", "mode": "leap", "speed": 136.0,
		"range": 150.0, "damage": 3, "windup": 0.50, "duration": 0.34, "cooldown": 1.12,
		"color": Color("3b8fb5"),
		"parts": [["head", "头", 5, true], ["body", "身体", 11, true], ["front_paws", "前爪", 4, false], ["back_legs", "后腿", 4, false]],
	},
	"venom_dog": {
		"name": "毒牙犬", "family": "dog", "mode": "poison", "speed": 138.0,
		"range": 72.0, "damage": 2, "windup": 0.30, "duration": 0.2, "cooldown": 1.0,
		"color": Color("579446"),
		"parts": [["head", "头", 6, true], ["body", "身体", 7, true], ["front_paws", "前爪", 4, false], ["back_legs", "后腿", 4, false], ["fangs", "毒牙", 5, false]],
	},
	"bomber_dog": {
		"name": "自爆犬", "family": "dog", "mode": "explode", "speed": 152.0,
		"range": 88.0, "damage": 6, "windup": 0.75, "duration": 0.08, "cooldown": 0.1,
		"color": Color("be4435"),
		"parts": [["head", "头", 4, true], ["body", "身体", 4, true], ["front_paws", "前爪", 3, false], ["back_legs", "后腿", 3, false], ["core", "爆炸核心", 4, false]],
	},
	"stone_bug": {
		"name": "石壳虫", "family": "bug", "mode": "charge", "speed": 92.0,
		"range": 125.0, "damage": 4, "windup": 0.35, "duration": 0.38, "cooldown": 1.05,
		"color": Color("8d806b"),
		"parts": [["head", "头", 5, true], ["body", "身体", 13, true], ["shell", "硬壳", 10, false]],
	},
	"dive_bat": {
		"name": "飞扑蝠", "family": "bat", "mode": "dive", "speed": 132.0,
		"range": 190.0, "damage": 3, "windup": 0.3, "duration": 0.42, "cooldown": 0.82,
		"color": Color("675ab4"),
		"parts": [["head", "头", 4, true], ["body", "身体", 7, true], ["wings", "翅膀", 5, false]],
	},
	"skeleton": {
		"name": "骷髅兵", "family": "skeleton", "mode": "slash", "speed": 108.0,
		"range": 82.0, "damage": 3, "windup": 0.32, "duration": 0.2, "cooldown": 0.88,
		"color": Color("d9d0b9"),
		"parts": [["head", "头", 5, true], ["body", "身体", 10, true], ["left_arm", "左臂", 4, false], ["right_arm", "右臂", 4, false], ["legs", "腿", 7, false]],
	},
	"skeleton_archer": {
		"name": "骷髅弓手", "family": "skeleton", "mode": "ranged", "speed": 88.0,
		"range": 390.0, "min_range": 145.0, "damage": 2, "windup": 0.42, "duration": 0.08, "cooldown": 1.25,
		"color": Color("c7a35c"),
		"parts": [["head", "头", 4, true], ["body", "身体", 8, true], ["left_arm", "左臂", 3, false], ["right_arm", "右臂", 3, false], ["legs", "腿", 6, false]],
	},
	"fire_slime": {
		"name": "火焰史莱姆", "family": "slime", "mode": "slime_jump", "speed": 82.0,
		"range": 135.0, "damage": 3, "windup": 0.38, "duration": 0.38, "cooldown": 1.0,
		"color": Color("e96b20"),
		"parts": [["body", "身体", 18, true], ["core", "核心", 8, false]],
	},
	"skeleton_shield": {
		"name": "骷髅盾兵", "family": "skeleton", "mode": "shield", "speed": 76.0,
		"range": 78.0, "damage": 3, "windup": 0.38, "duration": 0.22, "cooldown": 1.0,
		"color": Color("9aa9bb"), "parts": [["head", "头", 6, false], ["body", "身体", 12, true], ["shell", "盾牌", 14, false], ["right_arm", "武器手", 6, false], ["legs", "后腿", 5, false], ["core", "骨核", 5, false]],
	},
	"skeleton_spear": {
		"name": "骷髅枪兵", "family": "skeleton", "mode": "spear", "speed": 96.0,
		"range": 142.0, "damage": 4, "windup": 0.48, "duration": 0.30, "cooldown": 1.12,
		"color": Color("c9bd8d"), "parts": [["head", "头", 6, false], ["body", "身体", 10, true], ["weapon", "长枪", 10, false], ["right_arm", "手臂", 6, false], ["legs", "腿部", 6, false]],
	},
	"skeleton_bomber": {
		"name": "骷髅投弹手", "family": "skeleton", "mode": "bomb_throw", "speed": 72.0,
		"range": 410.0, "min_range": 155.0, "damage": 4, "windup": 0.62, "duration": 0.10, "cooldown": 1.45,
		"color": Color("c77c3b"), "parts": [["head", "头", 5, false], ["body", "身体", 9, true], ["left_arm", "左臂", 5, false], ["right_arm", "炸弹包", 8, false], ["legs", "腿部", 5, false]],
	},
	"dungeon_mage": {
		"name": "地牢法师", "family": "skeleton", "mode": "mage", "speed": 82.0,
		"range": 430.0, "min_range": 150.0, "damage": 4, "windup": 0.48, "duration": 0.10, "cooldown": 1.18,
		"color": Color("5964c2"), "parts": [["head", "头", 6, false], ["body", "身体", 10, true], ["left_arm", "左手", 5, false], ["right_arm", "右手", 5, false], ["weapon", "法杖", 10, false]],
	},
	"summoning_priest": {
		"name": "召唤祭司", "family": "skeleton", "mode": "summoner", "speed": 62.0,
		"range": 390.0, "min_range": 170.0, "damage": 3, "windup": 0.72, "duration": 0.12, "cooldown": 2.4,
		"color": Color("9b55bd"), "parts": [["head", "头", 6, false], ["body", "身体", 12, true], ["left_arm", "左手", 6, false], ["right_arm", "右手", 6, false], ["weapon", "法器", 14, false]],
	},
	"frost_slime": {
		"name": "冰霜史莱姆", "family": "slime", "mode": "frost_jump", "speed": 78.0,
		"range": 130.0, "damage": 3, "windup": 0.42, "duration": 0.36, "cooldown": 1.05,
		"color": Color("5fb9db"), "parts": [["body", "身体", 18, true], ["core", "冰晶核心", 12, false]],
	},
	"lightning_slime": {
		"name": "雷电史莱姆", "family": "slime", "mode": "lightning", "speed": 90.0,
		"range": 92.0, "damage": 4, "windup": 0.34, "duration": 0.22, "cooldown": 0.92,
		"color": Color("dec43d"), "parts": [["body", "身体", 16, true], ["core", "雷核", 10, false], ["shell", "储电外膜", 8, false]],
	},
	"splitting_slime": {
		"name": "分裂史莱姆", "family": "slime", "mode": "split_jump", "speed": 72.0,
		"range": 128.0, "damage": 3, "windup": 0.42, "duration": 0.36, "cooldown": 1.1,
		"color": Color("61c88b"), "parts": [["body", "身体", 18, true], ["core", "分裂核", 12, false], ["shell", "粘液层", 10, false]],
	},
	"spike_vine": {
		"name": "尖刺藤蔓", "family": "plant", "mode": "vine", "speed": 0.0,
		"range": 360.0, "min_range": 0.0, "damage": 4, "windup": 0.58, "duration": 0.10, "cooldown": 1.35,
		"color": Color("3e8d50"), "parts": [["root", "根部", 12, true], ["body", "藤身", 8, false], ["weapon", "尖刺", 8, false], ["core", "毒花", 7, false]],
	},
	"man_eating_flower": {
		"name": "食人花", "family": "plant", "mode": "flower", "speed": 0.0,
		"range": 380.0, "min_range": 95.0, "damage": 4, "windup": 0.46, "duration": 0.12, "cooldown": 1.1,
		"color": Color("c83d62"), "parts": [["head", "花头", 12, false], ["body", "花茎", 10, false], ["root", "根部", 12, true], ["core", "毒囊", 8, false]],
	},
	"shadow_assassin": {
		"name": "暗影刺客", "family": "skeleton", "mode": "assassin", "speed": 178.0,
		"range": 185.0, "damage": 5, "windup": 0.30, "duration": 0.30, "cooldown": 0.92,
		"color": Color("4d3a78"), "parts": [["head", "头", 6, false], ["body", "身体", 12, true], ["left_arm", "左匕首", 8, false], ["right_arm", "右匕首", 8, false], ["shell", "暗影披风", 14, false]],
	},
	"berserker": {
		"name": "狂战士", "family": "skeleton", "mode": "berserker", "speed": 132.0,
		"range": 92.0, "damage": 5, "windup": 0.34, "duration": 0.54, "cooldown": 0.95,
		"color": Color("a93b35"), "parts": [["head", "头", 8, false], ["body", "身体", 16, true], ["left_arm", "左臂", 8, false], ["right_arm", "右臂", 10, false], ["weapon", "武器", 10, false], ["legs", "腿部", 8, false]],
	},
	"bomb_goblin": {
		"name": "炸弹哥布林", "family": "skeleton", "mode": "bomb_throw", "speed": 104.0,
		"range": 400.0, "min_range": 170.0, "damage": 5, "windup": 0.56, "duration": 0.10, "cooldown": 1.34,
		"color": Color("aa6b2e"), "parts": [["head", "头", 5, false], ["body", "身体", 9, true], ["right_arm", "炸弹", 10, false], ["left_leg", "左腿", 6, false], ["right_leg", "右腿", 6, false]],
	},
	"cursed_doll": {
		"name": "诅咒人偶", "family": "skeleton", "mode": "curse", "speed": 76.0,
		"range": 74.0, "damage": 3, "windup": 0.42, "duration": 0.22, "cooldown": 1.05,
		"color": Color("967082"), "parts": [["head", "头", 8, false], ["body", "身体", 12, true], ["left_arm", "抓取臂", 6, false], ["right_arm", "诅咒针", 14, false]],
	},
	"ghost_mage": {
		"name": "幽魂法师", "family": "bat", "mode": "ghost_mage", "speed": 92.0,
		"range": 460.0, "min_range": 150.0, "damage": 5, "windup": 0.52, "duration": 0.10, "cooldown": 1.2,
		"color": Color("6795ba"), "parts": [["head", "头", 6, false], ["body", "灵体", 12, true], ["left_arm", "左手", 7, false], ["right_arm", "右手", 7, false], ["wings", "灵魂灯", 14, false]],
	},
	"dungeon_turret": {
		"name": "地牢炮台", "family": "bug", "mode": "turret", "speed": 0.0,
		"range": 520.0, "min_range": 0.0, "damage": 5, "windup": 0.62, "duration": 0.10, "cooldown": 1.45,
		"color": Color("69747e"), "parts": [["body", "底座", 14, true], ["head", "炮口", 14, false], ["shell", "装甲", 14, false], ["core", "能量核", 8, false]],
	},
	"crystal_drone": {
		"name": "魔晶浮游炮", "family": "bat", "mode": "laser", "speed": 108.0,
		"range": 500.0, "min_range": 180.0, "damage": 6, "windup": 0.72, "duration": 0.10, "cooldown": 1.55,
		"color": Color("40b6b2"), "parts": [["body", "魔晶核心", 16, true], ["left_wing", "左浮翼", 8, false], ["right_wing", "右浮翼", 8, false], ["head", "炮口", 16, false]],
	},
	"fire_lizard": {
		"name": "火焰蜥蜴", "family": "dog", "mode": "fire_breath", "speed": 112.0,
		"range": 330.0, "min_range": 80.0, "damage": 5, "windup": 0.46, "duration": 0.12, "cooldown": 1.08,
		"color": Color("c9542b"), "parts": [["head", "头", 9, false], ["body", "身体", 14, true], ["core", "火囊", 14, false], ["tail", "尾巴", 9, false], ["legs", "腿部", 10, false]],
	},
	"heavy_hammer_guard": {
		"name": "重锤守卫", "family": "skeleton", "mode": "hammer", "speed": 68.0,
		"range": 112.0, "damage": 7, "windup": 0.78, "duration": 0.34, "cooldown": 1.45,
		"color": Color("79604c"), "parts": [["head", "头", 10, true], ["body", "身体", 22, true], ["left_arm", "左臂", 10, false], ["right_arm", "右臂", 12, false], ["legs", "腿", 12, false], ["weapon", "巨锤", 24, false]],
	},
	"dual_blade_hunter": {
		"name": "双刀猎手", "family": "skeleton", "mode": "dual_blade", "speed": 166.0,
		"range": 88.0, "damage": 5, "windup": 0.24, "duration": 0.48, "cooldown": 0.78,
		"color": Color("596974"), "parts": [["head", "头", 8, true], ["body", "身体", 16, true], ["left_arm", "左刀", 12, false], ["right_arm", "右刀", 12, false], ["legs", "腿", 12, false], ["shell", "披风", 12, false]],
	},
	"blood_armor_knight": {
		"name": "血甲骑士", "family": "elite_humanoid", "mode": "elite_blood", "speed": 122.0,
		"range": 106.0, "damage": 7, "windup": 0.42, "duration": 0.42, "cooldown": 0.88,
		"color": Color("8f233c"), "parts": [["head", "头盔", 10, false], ["body", "身体", 18, true], ["left_arm", "左臂", 10, false], ["right_arm", "右臂", 12, false], ["shell", "血甲", 18, false], ["legs", "腿部", 12, false]],
	},
	"blackflame_lancer": {
		"name": "黑焰枪骑", "family": "elite_humanoid", "mode": "elite_lancer", "speed": 142.0,
		"range": 185.0, "damage": 8, "windup": 0.50, "duration": 0.42, "cooldown": 1.02,
		"color": Color("5c328f"), "parts": [["head", "头", 9, false], ["body", "身体", 20, true], ["weapon", "长枪", 18, false], ["core", "黑焰核心", 16, false], ["left_leg", "左腿", 11, false], ["right_leg", "右腿", 11, false]],
	},
	"abyss_executioner": {
		"name": "深渊执行者", "family": "elite_humanoid", "mode": "elite_executioner", "speed": 92.0,
		"range": 122.0, "damage": 10, "windup": 0.68, "duration": 0.48, "cooldown": 1.12,
		"color": Color("402052"), "parts": [["head", "头", 12, false], ["body", "身体", 26, true], ["left_arm", "左臂", 14, false], ["right_arm", "右臂", 14, false], ["weapon", "巨剑", 24, false], ["legs", "腿部", 16, false], ["core", "深渊核心", 14, false]],
	},
	"skeleton_general": {
		"name": "骸骨将军", "family": "boss_humanoid", "mode": "boss", "speed": 92.0,
		"range": 250.0, "damage": 7, "windup": 0.44, "duration": 0.38, "cooldown": 0.9,
		"color": Color("b9aa82"), "parts": [["helmet", "头盔", 35, false], ["head", "头部", 30, false], ["shell", "胸甲", 50, false], ["body", "身体", 60, true], ["left_arm", "左臂", 30, false], ["right_arm", "右臂", 30, false], ["shield", "盾牌", 40, false], ["weapon", "长剑", 35, false], ["legs", "腿部", 10, false]],
	},
	"crimson_witch": {
		"name": "猩红女巫", "family": "boss_mage", "mode": "boss", "speed": 88.0,
		"range": 470.0, "damage": 8, "windup": 0.48, "duration": 0.42, "cooldown": 0.86,
		"color": Color("9f1747"), "parts": [["head", "头", 30, false], ["body", "身体", 50, true], ["left_arm", "血球手", 30, false], ["right_arm", "诅咒手", 30, false], ["weapon", "法杖", 45, false], ["core", "血晶核心", 45, false], ["shell", "披风", 25, false], ["wings", "魔法护盾", 25, false]],
	},
	"abyss_hound_king": {
		"name": "深渊猎犬王", "family": "boss_dog", "mode": "boss", "speed": 112.0,
		"range": 285.0, "damage": 5, "windup": 0.42, "duration": 0.34, "cooldown": 0.82,
		"color": Color("7d193d"),
		"parts": [
			["head", "头", 24, false], ["body", "身体", 46, false],
			["left_front_paw", "左前爪", 18, false], ["right_front_paw", "右前爪", 18, false],
			["left_hind_leg", "左后腿", 18, false], ["right_hind_leg", "右后腿", 18, false],
			["tail", "尾巴", 14, false], ["core", "核心", 24, true],
		],
	},
}

@export var archetype: String = "crypt_dog"
@export_range(0.1, 10.0, 0.05) var health_scale: float = 1.0
@export_range(0.1, 10.0, 0.05) var attack_scale: float = 1.0

var _profile: Dictionary
var _parts: Dictionary = {}
var _target: Player
var _state: State = State.IDLE
var _state_timer: float = 0.0
var _gravity: float = 1600.0
var _facing: float = 1.0
var _queued_facing: float = 1.0
var _attack_direction: Vector2 = Vector2.RIGHT
var _attack_has_hit: bool = false
var _combo_hits_left: int = 0
var _combo_timer: float = 0.0
var _movement_multiplier: float = 1.0
var _attack_multiplier: float = 1.0
var _movement_stun_timer: float = 0.0
var _attack_stun_timer: float = 0.0
var _animation_time: float = 0.0
var _flying: bool = false
var _explosion_enabled: bool = true
var _poison_enabled: bool = true
var _death_effect_enabled: bool = true
var _hover_y: float
var _boss_attack: String = "claw"
var _boss_summon_cooldown: float = 2.0
var _boss_regen_timer: float = 4.0
var _boss_special_index: int = 0
var _summoned_enemies: Array[Node] = []
var _boss_bar_root: Node2D
var _boss_bar_fill: Polygon2D
var _boss_bar_label: Label
var _boss_slam_done: bool = false
var _boss_wave_done: bool = false
var _network_proxy: bool = false
var _network_last_sequence: int = -1
var _network_target_position: Vector2
var _network_target_velocity: Vector2 = Vector2.ZERO
var _network_stale_time: float = 0.0
var _network_death_playing: bool = false
var _special_timer: float = 0.0
var _ability_counter: int = 0
var _enraged: bool = false
var _stealthed: bool = false
var _charged: bool = false
var _backstep_timer: float = 0.0
var _summoner_owner: Node
var _attack_telegraph: Polygon2D
var _platform_nav := PlatformChaseAgent.new()

@onready var _visual: Node2D = $Visual
@onready var _parts_root: Node2D = $Visual/Parts
@onready var _attack_area: Area2D = $Visual/AttackArea
@onready var _attack_visual: Polygon2D = $Visual/AttackArea/AttackVisual
@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _health_label: Label = $HealthLabel


func _ready() -> void:
	add_to_group("enemy")
	collision_mask |= ONE_WAY_PLATFORM_LAYER
	_profile = PROFILES.get(archetype, PROFILES["crypt_dog"]).duplicate(true)
	_apply_difficulty_scaling()
	_gravity = float(ProjectSettings.get_setting("physics/2d/default_gravity", 1600.0))
	_flying = str(_profile.get("family", "")) == "bat"
	_hover_y = global_position.y
	_apply_collision_shape()
	_create_body_parts()
	_setup_attack_telegraph()
	if str(_profile.get("mode", "")) == "boss":
		floor_snap_length = 18.0
		_setup_boss_health_bar()
	_target = get_tree().get_first_node_in_group("player") as Player
	_network_target_position = global_position
	_update_health_label()
	if not _network_proxy:
		SFX.play_at("boss_intro" if str(_profile.get("mode", "")) == "boss" else "enemy_spawn", global_position, 0.04)


func _physics_process(delta: float) -> void:
	if _network_proxy:
		_update_network_proxy(delta)
		return
	if _state == State.DEAD:
		return
	_platform_nav.tick(self, delta)
	_animation_time += delta
	_update_archetype_mechanics(delta)
	if str(_profile.get("mode", "")) == "boss":
		_update_boss_timers(delta)
	_movement_stun_timer = maxf(0.0, _movement_stun_timer - delta)
	_attack_stun_timer = maxf(0.0, _attack_stun_timer - delta)
	if not _flying and not is_on_floor():
		velocity.y += _gravity * delta
	elif _flying and _state not in [State.ATTACK, State.HURT]:
		velocity.y = sin(_animation_time * 3.2) * 18.0
	if _movement_stun_timer > 0.0 or _attack_stun_timer > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, 1000.0 * delta)
	else:
		_update_state(delta)
	move_and_slide()
	_update_attack_telegraph()
	_animate_parts()


func _update_state(delta: float) -> void:
	_refresh_target()
	if not is_instance_valid(_target):
		velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
		return
	var direction := signf(_target.global_position.x - global_position.x)
	match _state:
		State.IDLE, State.CHASE:
			if _needs_turn(direction):
				_start_turn(direction)
			elif _can_attack():
				_change_state(State.WINDUP)
			else:
				_state = State.CHASE
				_chase_target(delta, direction)
		State.TURN, State.WINDUP, State.RECOVERY, State.HURT:
			velocity.x = move_toward(velocity.x, 0.0, 1100.0 * delta)
			_tick_state(delta)
		State.ATTACK:
			_update_attack(delta)
			_tick_state(delta)


func _chase_target(delta: float, direction: float) -> void:
	var speed := maxf(90.0, float(_profile.get("speed", 100.0))) * _movement_multiplier
	var mode := str(_profile.get("mode", "bite"))
	var predicted_x := _target.global_position.x + _target.velocity.x * (0.18 if mode not in RANGED_MODES else 0.08)
	direction = signf(predicted_x - global_position.x)
	if is_zero_approx(direction):
		direction = _facing
	if not _flying:
		direction = _platform_nav.steer(self, _target, delta, direction, speed)
	var distance_x := absf(_target.global_position.x - global_position.x)
	var vertical_gap := absf(_target.global_position.y - global_position.y)
	var desired_velocity := direction * speed
	if mode in RANGED_MODES and distance_x < float(_profile.get("min_range", 120.0)) and vertical_gap < 72.0:
		desired_velocity = -direction * speed
	elif mode == "spear" and distance_x < 92.0:
		desired_velocity = -direction * speed * 0.8
	if _target.is_network_attack_active() and distance_x < 165.0 \
		and mode in RANGED_MODES + ["assassin", "dual_blade"]:
		desired_velocity = -direction * speed * 1.55
	desired_velocity += _platform_nav.separation(self) * speed * 0.48
	if _flying:
		var desired_y := _target.global_position.y - 110.0
		velocity.y = clampf((desired_y - global_position.y) * 2.2, -110.0, 110.0)
		velocity.x = move_toward(velocity.x, desired_velocity, 780.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, desired_velocity, 900.0 * delta)


func _refresh_target() -> void:
	var best: Player
	var best_distance := INF
	for node in get_tree().get_nodes_in_group("player"):
		var player := node as Player
		if not is_instance_valid(player) or player.get_health() <= 0:
			continue
		var distance := global_position.distance_squared_to(player.global_position)
		if distance < best_distance:
			best = player
			best_distance = distance
	if is_instance_valid(best):
		_target = best


func _can_attack() -> bool:
	var distance_x := absf(_target.global_position.x - global_position.x)
	var distance_y := absf(_target.global_position.y - global_position.y)
	var attack_range := float(_profile.get("range", 75.0))
	var mode := str(_profile.get("mode", "bite"))
	if not _flying and distance_y > 82.0:
		return false
	if mode in RANGED_MODES:
		if mode == "summoner" and not _has_living_part(&"weapon"):
			return distance_x <= attack_range and distance_y < 180.0
		if mode in ["turret", "laser"] and not _has_living_part(&"head"):
			return false
		return distance_x <= attack_range and distance_x >= float(_profile.get("min_range", 120.0)) \
			and _platform_nav.has_line_of_sight(self, _target)
	if mode in ["flower", "vine", "fire_breath"]:
		return distance_x <= attack_range and distance_y < 150.0
	return distance_x <= attack_range and distance_y < (180.0 if _flying else 95.0)


func _change_state(next_state: State) -> void:
	_state = next_state
	_attack_visual.visible = false
	if is_instance_valid(_attack_telegraph):
		_attack_telegraph.visible = next_state == State.WINDUP
	_attack_area.scale = Vector2.ONE
	_attack_visual.scale = Vector2.ONE
	_set_parts_tint(Color.WHITE)
	match next_state:
		State.TURN:
			_state_timer = 0.16
			_set_parts_tint(Color(0.7, 0.85, 1.0))
		State.WINDUP:
			_state_timer = float(_profile.get("windup", 0.25))
			_set_parts_tint(Color(1.0, 0.7, 0.25))
			SFX.play_at("enemy_windup", global_position, 0.07)
		State.ATTACK:
			_begin_attack()
		State.RECOVERY:
			_state_timer = float(_profile.get("cooldown", 0.8))
			_set_parts_tint(Color(0.72, 0.72, 0.72))
		State.HURT:
			_state_timer = 0.16


func _begin_attack() -> void:
	_ability_counter += 1
	_state_timer = float(_profile.get("duration", 0.2))
	_attack_has_hit = false
	_attack_direction = (_target.global_position - global_position).normalized()
	if is_zero_approx(_attack_direction.x):
		_attack_direction.x = _facing
	_attack_visual.visible = true
	var mode := str(_profile.get("mode", "bite"))
	if mode in RANGED_MODES or mode in ["summoner", "bomb_throw", "vine", "flower", "fire_breath"]:
		SFX.play_at("enemy_ranged", global_position, 0.08)
	else:
		SFX.play_at("enemy_melee", global_position, 0.08)
	if archetype in ["man_eating_flower", "spike_vine", "cursed_doll"]:
		SFX.play_at("poison", global_position, 0.045)
	match mode:
		"boss":
			_begin_boss_attack()
		"combo", "berserker", "dual_blade", "elite_blood":
			_combo_hits_left = 2 if mode == "dual_blade" else 3
			_combo_timer = 0.0
		"leap", "charge", "slime_jump", "frost_jump", "split_jump", "spear", "assassin", "elite_lancer":
			velocity.x = _facing * (390.0 if mode == "leap" else 320.0) * _movement_multiplier
			if mode in ["leap", "slime_jump", "frost_jump", "split_jump", "assassin"]:
				velocity.y = -260.0 if mode == "leap" else -300.0
			if mode == "assassin":
				_set_stealth(false)
			if mode == "elite_lancer" and _has_living_part(&"core"):
				_spawn_ground_hazard(global_position + Vector2(_facing * 72.0, 25.0), 46.0, 3, Color(0.35, 0.05, 0.55, 0.52), 0.15, 2.2)
		"dive":
			velocity = _attack_direction * 360.0 * _movement_multiplier
		"ranged", "mage", "ghost_mage", "turret", "laser":
			_spawn_projectile()
		"summoner":
			_summon_priest_minion()
		"bomb_throw":
			_spawn_bomb_hazard()
		"vine":
			_spawn_vine_strike()
		"flower":
			if absf(_target.global_position.x - global_position.x) < 100.0:
				_attack_area.scale = Vector2(1.25, 1.15)
			else:
				_spawn_projectile()
		"fire_breath":
			if _has_living_part(&"tail") and _ability_counter % 3 == 0:
				_attack_area.scale = Vector2(1.8, 1.25)
				_attack_visual.scale = _attack_area.scale
			else:
				_spawn_fire_breath()
		"hammer", "elite_executioner":
			_attack_area.scale = Vector2(2.1, 1.45)
			_attack_visual.scale = _attack_area.scale
			if _has_living_part(&"weapon"):
				_spawn_ground_hazard(global_position + Vector2(_facing * 72.0, 24.0), 82.0, int(_profile.get("damage", 6)), Color(0.72, 0.42, 0.18, 0.48), 0.38, 0.5)
		"shield":
			_attack_area.scale = Vector2(1.25, 1.15)
			_attack_visual.scale = _attack_area.scale
		"explode":
			if _explosion_enabled:
				_attack_area.scale = Vector2(2.5, 2.1)
				_attack_visual.scale = Vector2(2.5, 2.1)
			else:
				_profile["damage"] = 1
	if archetype == "frost_slime" and _has_living_part(&"core"):
		SFX.play_at("frost", global_position, 0.04)
		_spawn_ground_hazard(global_position + Vector2(0, 22), 58.0, 1, Color(0.35, 0.8, 1.0, 0.34), 0.28, 1.9, 1.5)
	elif archetype == "lightning_slime" and _charged and _has_living_part(&"core"):
		SFX.play_at("lightning", global_position, 0.035)
		_spawn_radial_discharge()
		_charged = false
		_special_timer = 2.2
	elif archetype == "berserker" and _ability_counter % 3 == 0 and _has_living_part(&"weapon"):
		_spawn_ground_hazard(global_position + Vector2(_facing * 54.0, 24.0), 70.0, maxi(1, int(_profile.get("damage", 5)) / 2), Color(0.92, 0.22, 0.12, 0.38), 0.26, 0.52)


func _update_attack(delta: float) -> void:
	var mode := str(_profile.get("mode", "bite"))
	match mode:
		"boss":
			_update_boss_attack()
		"combo", "berserker", "dual_blade", "elite_blood":
			_combo_timer -= delta
			if _combo_hits_left > 0 and _combo_timer <= 0.0:
				_attack_has_hit = false
				_try_damage_player()
				_combo_hits_left -= 1
				_combo_timer = 0.18
		"leap", "charge", "slime_jump", "frost_jump", "split_jump", "spear", "assassin", "elite_lancer":
			velocity.x = _facing * (390.0 if mode == "leap" else 320.0) * _movement_multiplier
			_try_damage_player()
		"dive":
			velocity = _attack_direction * 360.0 * _movement_multiplier
			_try_damage_player()
		"ranged", "summoner", "bomb_throw", "mage", "ghost_mage", "turret", "laser", "vine":
			velocity.x = 0.0
		"flower", "fire_breath":
			velocity.x = 0.0
			if mode == "flower" and absf(_target.global_position.x - global_position.x) < 108.0:
				_try_damage_player()
			elif mode == "fire_breath" and _has_living_part(&"tail") and _ability_counter % 3 == 0:
				_try_damage_player()
		"hammer", "elite_executioner", "shield", "curse", "lightning":
			velocity.x = 0.0
			_try_damage_player()
		"explode":
			velocity.x = 0.0
			_try_damage_player()
		_:
			velocity.x = 0.0
			_try_damage_player()


func _tick_state(delta: float) -> void:
	_state_timer = maxf(0.0, _state_timer - delta)
	if _state_timer > 0.0:
		return
	if _state == State.TURN:
		_facing = _queued_facing
		_visual.scale.x = _facing
		_change_state(State.IDLE)
	elif _state == State.WINDUP:
		_change_state(State.ATTACK)
	elif _state == State.ATTACK:
		if str(_profile.get("mode", "")) == "explode" and _explosion_enabled:
			_die(false)
		else:
			_change_state(State.RECOVERY)
	else:
		_change_state(State.IDLE)


func _update_archetype_mechanics(delta: float) -> void:
	_special_timer -= delta
	_backstep_timer = maxf(0.0, _backstep_timer - delta)
	if _backstep_timer > 0.0:
		velocity.x = -_facing * float(_profile.get("speed", 100.0)) * 1.45
	var ratio := _total_health_ratio()
	if archetype == "berserker" and not _enraged and ratio <= 0.30:
		_enraged = true
		_profile["speed"] = float(_profile.get("speed", 132.0)) * 1.35
		_profile["damage"] = roundi(float(_profile.get("damage", 5)) * 1.3)
		_profile["windup"] = float(_profile.get("windup", 0.34)) * 0.68
		_profile["cooldown"] = float(_profile.get("cooldown", 0.95)) * 0.62
		_set_parts_tint(Color(1.35, 0.42, 0.36, 1.0))
	elif archetype == "abyss_executioner" and not _enraged and ratio <= 0.40 and _has_living_part(&"core"):
		_enraged = true
		_profile["speed"] = float(_profile.get("speed", 92.0)) * 1.4
		_profile["damage"] = roundi(float(_profile.get("damage", 10)) * 1.35)
		_profile["cooldown"] = float(_profile.get("cooldown", 1.12)) * 0.62
	if archetype == "lightning_slime":
		if not _has_living_part(&"shell") or not _has_living_part(&"core"):
			_charged = false
		elif _special_timer <= 0.0:
			_charged = not _charged
			_special_timer = 1.0 if _charged else 2.2
			_set_parts_tint(Color(1.3, 1.25, 0.42, 1.0) if _charged else Color.WHITE)
	elif archetype == "shadow_assassin":
		if not _has_living_part(&"shell"):
			_set_stealth(false)
		elif _special_timer <= 0.0 and _state in [State.IDLE, State.CHASE, State.RECOVERY]:
			_set_stealth(not _stealthed)
			_special_timer = 1.15 if _stealthed else 3.8
	elif archetype == "spike_vine" and _special_timer <= 0.0 and _has_living_part(&"core"):
		_spawn_ground_hazard(global_position + Vector2(0, 24), 56.0, 1, Color(0.25, 0.72, 0.22, 0.38), 0.35, 2.4, 0.0, 0.0)
		_special_timer = 4.5
	elif archetype == "ghost_mage" and _has_living_part(&"wings"):
		modulate.a = 0.82 + sin(_animation_time * 5.0) * 0.12
	elif archetype != "shadow_assassin":
		modulate.a = 1.0


func _set_stealth(enabled: bool) -> void:
	_stealthed = enabled
	modulate.a = 0.28 if enabled else 1.0


func _total_health_ratio() -> float:
	var current := 0
	var maximum := 0
	for value in _parts.values():
		var part := value as BodyPart
		current += part.health
		maximum += part.max_health
	return float(current) / maxf(1.0, float(maximum))


func _has_living_part(id: StringName) -> bool:
	var part := _parts.get(id) as BodyPart
	return is_instance_valid(part) and part.health > 0


func _spawn_ground_hazard(
	spawn_position: Vector2,
	radius: float,
	damage: int,
	color: Color,
	delay: float,
	lifetime: float,
	slow_duration: float = 0.0,
	weakness_duration: float = 0.0
) -> void:
	var hazard := ENEMY_HAZARD_SCRIPT.new()
	hazard.damage = maxi(1, damage)
	hazard.radius = radius
	hazard.startup_delay = delay
	hazard.lifetime = lifetime
	hazard.tick_interval = maxf(0.45, lifetime - delay)
	hazard.visual_color = color
	hazard.slow_duration = slow_duration
	hazard.weakness_duration = weakness_duration
	hazard.global_position = spawn_position
	get_tree().current_scene.add_child(hazard)


func _spawn_bomb_hazard() -> void:
	if not _has_living_part(&"right_arm") or not is_instance_valid(_target):
		_spawn_projectile()
		return
	var offsets: Array[float] = [0.0]
	if _ability_counter % 3 == 0:
		offsets = [-62.0, 0.0, 62.0]
	SFX.play_at("bomb_warning", global_position, 0.025)
	for offset in offsets:
		var hazard_position := _target.global_position + Vector2(offset, 24)
		_spawn_ground_hazard(
			hazard_position, 56.0 if offsets.size() > 1 else 64.0,
			int(_profile.get("damage", 4)), Color(1.0, 0.42, 0.08, 0.52), 0.62, 0.78
		)
	get_tree().create_timer(0.62).timeout.connect(func() -> void: SFX.play_at("explosion", global_position, 0.05))


func _spawn_vine_strike() -> void:
	if not is_instance_valid(_target) or not _has_living_part(&"weapon"):
		return
	_spawn_ground_hazard(
		_target.global_position + Vector2(0, 28), 44.0,
		int(_profile.get("damage", 4)), Color(0.35, 0.86, 0.24, 0.5), 0.55, 0.72
	)


func _spawn_fire_breath() -> void:
	if not _has_living_part(&"core"):
		_attack_area.scale = Vector2(1.2, 1.0)
		return
	for angle_offset in [-0.18, 0.0, 0.18]:
		var projectile := ENEMY_PROJECTILE_SCRIPT.new()
		projectile.global_position = global_position + Vector2(_facing * 38.0, -8.0)
		projectile.direction = Vector2(_facing, 0).rotated(angle_offset)
		projectile.speed = 285.0
		projectile.damage = maxi(1, roundi(float(_profile.get("damage", 5)) * 0.7))
		projectile.radius = 13.0
		projectile.visual_length = 34.0
		projectile.visual_color = Color(1.0, 0.23, 0.03, 0.9)
		projectile.shape_style = "flame"
		projectile.source_position = global_position
		get_tree().current_scene.add_child(projectile)


func _spawn_radial_discharge() -> void:
	for index in range(8):
		var projectile := ENEMY_PROJECTILE_SCRIPT.new()
		projectile.global_position = global_position + Vector2(0, -8)
		projectile.direction = Vector2.RIGHT.rotated(TAU * float(index) / 8.0)
		projectile.speed = 310.0
		projectile.damage = maxi(1, roundi(float(_profile.get("damage", 4)) * 0.55 * _attack_multiplier))
		projectile.radius = 8.0
		projectile.visual_length = 24.0
		projectile.visual_color = Color(1.0, 0.9, 0.18, 0.95)
		projectile.shape_style = "shard"
		projectile.source_position = global_position
		get_tree().current_scene.add_child(projectile)


func _try_damage_player() -> void:
	if _attack_has_hit:
		return
	var closest: BodyPart
	var closest_distance := INF
	for area in _attack_area.get_overlapping_areas():
		if area is BodyPart:
			var part := area as BodyPart
			if not is_instance_valid(part.actor) or not part.actor.is_in_group("player"):
				continue
			var distance := global_position.distance_squared_to(part.global_position)
			if distance < closest_distance:
				closest = part
				closest_distance = distance
	if not is_instance_valid(closest):
		return
	var damage := maxi(1, roundi(float(_profile.get("damage", 2)) * _attack_multiplier))
	if archetype == "shadow_assassin" and closest.actor.has_method("is_facing_position") \
		and not closest.actor.is_facing_position(global_position.x):
		damage = maxi(1, roundi(float(damage) * 1.65))
	if archetype == "abyss_hound_king":
		var boss_base := 8 if _boss_attack == "slam" else (7 if _boss_attack == "charge" else 5)
		damage = maxi(1, roundi(float(boss_base) * attack_scale * _attack_multiplier))
	var applied := false
	if multiplayer.has_multiplayer_peer():
		if not multiplayer.is_server():
			return
		var main := get_tree().current_scene
		if is_instance_valid(main) and main.has_method("server_apply_enemy_player_damage"):
			applied = main.server_apply_enemy_player_damage(
				closest.actor as Player,
				closest.part_id,
				damage,
				global_position,
				"melee"
			)
	else:
		applied = closest.receive_damage(damage, global_position, "melee")
	if applied:
		_attack_has_hit = true
		if str(_profile.get("mode", "")) == "poison" and _poison_enabled:
			_apply_poison_to_player(closest.actor as Player, 3, 0.8)
		match archetype:
			"frost_slime":
				if _has_living_part(&"core") and closest.actor.has_method("apply_enemy_slow"):
					_apply_status_to_player(closest.actor as Player, "slow", 2.0, 0.55)
			"cursed_doll":
				if _has_living_part(&"right_arm") and closest.actor.has_method("apply_enemy_weakness"):
					_apply_status_to_player(closest.actor as Player, "weakness", 4.0, 0.68)
			"lightning_slime":
				if _has_living_part(&"core") and closest.actor.has_method("apply_combat_stun"):
					_apply_status_to_player(closest.actor as Player, "stun", 0.28, 1.0)
			"blood_armor_knight":
				if _has_living_part(&"shell"):
					_heal_parts(3)
			"dual_blade_hunter":
				if _has_living_part(&"shell"):
					_backstep_timer = 0.28


func _apply_status_to_player(player: Player, effect: String, duration: float, strength: float) -> void:
	if not is_instance_valid(player):
		return
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		var main := get_tree().current_scene
		if is_instance_valid(main) and main.has_method("server_apply_enemy_player_status"):
			main.server_apply_enemy_player_status(player, effect, duration, strength)
			return
	if effect == "slow":
		player.apply_enemy_slow(duration, strength)
	elif effect == "weakness":
		player.apply_enemy_weakness(duration, strength)
	elif effect == "stun":
		player.apply_combat_stun(duration)


func _apply_poison_to_player(player: Player, ticks: int, interval: float) -> void:
	if not is_instance_valid(player):
		return
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		var main := get_tree().current_scene
		if is_instance_valid(main) and main.has_method("server_apply_enemy_player_poison"):
			main.server_apply_enemy_player_poison(player, global_position, ticks, interval)
			return
	var effect := DAMAGE_OVER_TIME_SCRIPT.new()
	effect.configure(player, global_position, 1, ticks, interval)
	player.add_child(effect)


func _spawn_projectile() -> void:
	if _attack_multiplier < 0.45 or not is_instance_valid(_target):
		return
	var angle_offsets: Array[float] = [0.0]
	if archetype == "dungeon_mage" and _ability_counter % 3 == 0 and _has_living_part(&"weapon"):
		angle_offsets = [-0.14, 0.0, 0.14]
	elif archetype == "dungeon_turret" and _ability_counter % 3 == 0 and _has_living_part(&"head"):
		angle_offsets = [-0.06, 0.0, 0.06]
	for angle_offset in angle_offsets:
		var projectile := ENEMY_PROJECTILE_SCRIPT.new()
		projectile.global_position = global_position + Vector2(_facing * 32.0, -10.0)
		projectile.direction = (_target.global_position - projectile.global_position).normalized().rotated(angle_offset)
		projectile.damage = maxi(1, roundi(float(_profile.get("damage", 2)) * _attack_multiplier))
		projectile.source_position = global_position
		match archetype:
			"skeleton_archer":
				projectile.speed = 520.0
				projectile.radius = 6.0
				projectile.visual_length = 38.0
				projectile.shape_style = "arrow"
				projectile.visual_color = Color(0.88, 0.72, 0.36, 0.96)
			"dungeon_mage":
				projectile.speed = 300.0 if _has_living_part(&"weapon") else 220.0
				projectile.damage = maxi(1, projectile.damage if _has_living_part(&"weapon") else roundi(projectile.damage * 0.55))
				projectile.radius = 11.0
				projectile.shape_style = "orb"
				projectile.visual_color = Color(0.38, 0.42, 1.0, 0.92)
			"ghost_mage":
				projectile.speed = 330.0
				projectile.radius = 13.0
				projectile.homing_strength = 2.5 if _has_living_part(&"right_arm") else 0.0
				projectile.target = _target
				projectile.shape_style = "skull"
				projectile.visual_color = Color(0.45, 0.9, 1.0, 0.88)
			"dungeon_turret":
				projectile.speed = 620.0
				projectile.visual_length = 58.0
				projectile.radius = 9.0
				projectile.shape_style = "needle"
				projectile.visual_color = Color(1.0, 0.62, 0.16, 0.95)
				if not _has_living_part(&"core"):
					projectile.speed *= 0.62
			"crystal_drone":
				projectile.speed = 820.0
				projectile.visual_length = 120.0
				projectile.radius = 15.0
				projectile.shape_style = "laser"
				projectile.visual_color = Color(0.22, 1.0, 0.92, 0.92)
			"man_eating_flower":
				projectile.speed = 340.0
				projectile.poison_ticks = 3 if _has_living_part(&"core") else 0
				projectile.shape_style = "poison"
				projectile.visual_color = Color(0.45, 0.9, 0.22, 0.9)
			"summoning_priest":
				projectile.speed = 280.0
				projectile.damage = maxi(1, roundi(projectile.damage * 0.55))
				projectile.shape_style = "orb"
				projectile.visual_color = Color(0.72, 0.32, 0.92, 0.9)
		get_tree().current_scene.add_child(projectile)
	if archetype == "dungeon_mage":
		_backstep_timer = 0.24


func _heal_parts(amount: int) -> void:
	for iteration in amount:
		for value in _parts.values():
			var part := value as BodyPart
			if part.heal_one():
				break


func _start_turn(direction: float) -> void:
	_queued_facing = signf(direction)
	_change_state(State.TURN)


func _needs_turn(direction: float) -> bool:
	return not is_zero_approx(direction) and signf(direction) != signf(_facing)


func take_damage(amount: int, source_position: Vector2) -> void:
	if archetype == "abyss_hound_king" and amount >= 9999:
		_die(false)
		return
	var body: BodyPart = _parts.get("body")
	if is_instance_valid(body):
		body.receive_damage(amount, source_position)


func can_receive_part_damage() -> bool:
	return _state != State.DEAD


func get_archetype() -> String:
	return archetype


func set_network_proxy(enabled: bool) -> void:
	_network_proxy = enabled
	set_physics_process(true)


func get_network_facing() -> float:
	return _facing


func get_network_state_id() -> int:
	return int(_state)


func serialize_network_state() -> Dictionary:
	return {
		"position": global_position,
		"velocity": velocity,
		"facing": _facing,
		"state": int(_state),
		"state_timer": _state_timer,
		"animation_time": _animation_time,
		"parts": get_part_health_state(),
		"scale": scale,
		"attack_visual_scale": _attack_visual.scale,
		"attack_area_scale": _attack_area.scale,
		"boss_attack": _boss_attack,
		"special_timer": _special_timer,
		"ability_counter": _ability_counter,
		"enraged": _enraged,
		"stealthed": _stealthed,
		"charged": _charged,
	}


func get_part_health_state() -> Dictionary:
	var state := {}
	for id in _parts:
		var part := _parts[id] as BodyPart
		if is_instance_valid(part):
			state[String(id)] = [part.health, part.max_health]
	return state


func apply_network_state(state: Dictionary) -> void:
	var sequence := int(state.get("snapshot_sequence", 0))
	if sequence <= _network_last_sequence:
		return
	var first_snapshot := _network_last_sequence < 0
	_network_last_sequence = sequence
	var new_position: Vector2 = state.get("position", global_position)
	_network_target_velocity = state.get("velocity", Vector2.ZERO)
	var sample_age := 0.0
	var main := get_tree().current_scene
	if is_instance_valid(main) and main.has_method("get_estimated_server_msec"):
		sample_age = clampf(
			float(main.get_estimated_server_msec() - int(state.get("server_msec", 0))) / 1000.0,
			0.0,
			0.12
		)
	_network_target_position = new_position + _network_target_velocity * sample_age
	_network_stale_time = 0.0
	if first_snapshot or global_position.distance_to(_network_target_position) > 180.0:
		global_position = _network_target_position
	velocity = _network_target_velocity
	_facing = signf(float(state.get("facing", _facing)))
	if is_zero_approx(_facing):
		_facing = 1.0
	_visual.scale.x = _facing
	var previous_state := int(_state)
	_state = int(state.get("state", previous_state))
	_state_timer = float(state.get("state_timer", _state_timer))
	_animation_time = float(state.get("animation_time", _animation_time))
	scale = state.get("scale", scale)
	_attack_visual.scale = state.get("attack_visual_scale", Vector2.ONE)
	_attack_area.scale = state.get("attack_area_scale", Vector2.ONE)
	_boss_attack = str(state.get("boss_attack", _boss_attack))
	_special_timer = float(state.get("special_timer", _special_timer))
	_ability_counter = int(state.get("ability_counter", _ability_counter))
	_enraged = bool(state.get("enraged", _enraged))
	_stealthed = bool(state.get("stealthed", _stealthed))
	_charged = bool(state.get("charged", _charged))
	if state.has("parts") and state["parts"] is Dictionary:
		apply_part_health_state(state["parts"])
	_apply_network_visual_state(previous_state, first_snapshot)
	_animate_parts()


func _update_network_proxy(delta: float) -> void:
	_network_stale_time += delta
	_state_timer = maxf(0.0, _state_timer - delta)
	_animation_time += delta
	velocity = _network_target_velocity
	var predicted := _network_target_position + _network_target_velocity * minf(_network_stale_time, 0.10)
	var blend := 1.0 - exp(-30.0 * delta)
	global_position = global_position.lerp(predicted, blend)
	_update_attack_telegraph()
	_animate_parts()


func _apply_network_visual_state(previous_state: int, first_snapshot: bool) -> void:
	var windup := _state == State.WINDUP
	var attacking := _state == State.ATTACK
	if is_instance_valid(_attack_telegraph):
		_attack_telegraph.visible = windup
	_attack_visual.visible = attacking
	if windup:
		_set_parts_tint(Color(1.0, 0.7, 0.25))
	elif _state == State.RECOVERY:
		_set_parts_tint(Color(0.72, 0.72, 0.72))
	elif _charged:
		_set_parts_tint(Color(1.3, 1.25, 0.42, 1.0))
	elif _enraged:
		_set_parts_tint(Color(1.35, 0.42, 0.36, 1.0))
	else:
		_set_parts_tint(Color.WHITE)
	modulate.a = 0.28 if _stealthed else 1.0
	if first_snapshot or previous_state == int(_state):
		return
	if _state == State.WINDUP:
		SFX.play_at("enemy_windup", global_position, 0.05)
	elif _state == State.ATTACK:
		var mode := str(_profile.get("mode", "bite"))
		SFX.play_at("enemy_ranged" if mode in RANGED_MODES else "enemy_melee", global_position, 0.05)


func play_network_death() -> void:
	if _network_death_playing:
		return
	_network_death_playing = true
	_state = State.DEAD
	_network_target_velocity = Vector2.ZERO
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	_attack_area.set_deferred("monitoring", false)
	if is_instance_valid(_attack_telegraph):
		_attack_telegraph.visible = false
	_attack_visual.visible = false
	_health_label.text = "击败！"
	SFX.play_at("enemy_death", global_position, 0.05)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.32)
	tween.tween_property(self, "scale", scale * Vector2(1.18, 0.2), 0.32)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)


func apply_part_health_state(state: Dictionary) -> void:
	for id in state:
		var part := _parts.get(StringName(id)) as BodyPart
		var values: Array = state[id]
		if is_instance_valid(part) and values.size() >= 2:
			part.apply_authoritative_state(int(values[0]), int(values[1]))
	_recalculate_part_effects()
	_update_health_label()


func receive_part_damage_by_id(
	part_id: StringName,
	amount: int,
	source_position: Vector2,
	damage_kind: String = "melee"
) -> bool:
	var part := _parts.get(part_id) as BodyPart
	return is_instance_valid(part) and part.receive_damage(amount, source_position, damage_kind)


func modify_incoming_damage(amount: int, source_position: Vector2, damage_kind: String) -> int:
	if archetype == "skeleton_shield" and _has_living_part(&"shell"):
		var source_side := signf(source_position.x - global_position.x)
		if is_zero_approx(source_side) or source_side == signf(_facing):
			return maxi(1, ceili(float(amount) * 0.22))
	if archetype == "ghost_mage" and _has_living_part(&"wings"):
		return maxi(1, ceili(float(amount) * 0.5))
	if archetype == "skeleton_general" and _has_living_part(&"left_arm"):
		var source_side := signf(source_position.x - global_position.x)
		if _has_living_part(&"shield") and (is_zero_approx(source_side) or source_side == signf(_facing)):
			return maxi(1, ceili(float(amount) * 0.38))
	if archetype == "crimson_witch" and _has_living_part(&"wings"):
		return maxi(1, ceili(float(amount) * 0.42))
	if archetype == "lightning_slime" and _charged and damage_kind == "melee":
		_charged = false
		_special_timer = 2.2
		if is_instance_valid(_target):
			_target.take_damage(maxi(1, roundi(2.0 * attack_scale)), global_position)
	var shell: BodyPart = _parts.get("shell")
	if is_instance_valid(shell) and shell.health > 0:
		return maxi(1, ceili(float(amount) * 0.6))
	return amount


func modify_part_incoming_damage(part: BodyPart, amount: int, source_position: Vector2, damage_kind: String) -> int:
	if archetype == "abyss_hound_king" and part.part_id == &"core" and _boss_living_limbs() > 0:
		return 0
	if archetype == "skeleton_shield" and part.part_id == &"core":
		return amount * 2
	return modify_incoming_damage(amount, source_position, damage_kind)


func get_movement_multiplier() -> float:
	return _movement_multiplier


func get_attack_multiplier() -> float:
	return _attack_multiplier


func get_health_scale() -> float:
	return health_scale


func get_attack_scale() -> float:
	return attack_scale


func get_spawn_offset() -> Vector2:
	return Vector2(0, -20) if str(_profile.get("mode", "")) == "boss" else Vector2.ZERO


func apply_movement_stun(duration: float) -> void:
	_movement_stun_timer = maxf(_movement_stun_timer, duration)


func apply_combat_stun(duration: float) -> void:
	_movement_stun_timer = maxf(_movement_stun_timer, duration)
	_attack_stun_timer = maxf(_attack_stun_timer, duration)
	_change_state(State.RECOVERY)


func apply_clash_result(direction: float, hard_clash: bool) -> void:
	velocity.x = direction * 200.0
	if hard_clash:
		apply_combat_stun(0.45)
	else:
		_change_state(State.RECOVERY)


func get_attack_stun_time() -> float:
	return _attack_stun_timer


func get_archetype_name() -> String:
	return archetype


func get_movement_stun_time() -> float:
	return _movement_stun_timer


func is_melee_attack_active() -> bool:
	return _state == State.ATTACK and str(_profile.get("mode", "")) not in RANGED_MODES


func get_network_attack_kind() -> int:
	return Player.AttackKind.DASH if str(_profile.get("mode", "")) in ["leap", "charge", "dive"] else Player.AttackKind.NORMAL


func get_attack_step() -> int:
	return 1


func on_body_part_damaged(part: BodyPart, _amount: int, source_position: Vector2) -> void:
	var knockback := signf(global_position.x - source_position.x)
	if is_zero_approx(knockback):
		knockback = 1.0
	velocity.x = knockback * 220.0
	_update_health_label()
	if part.health <= 0 and part.vital:
		_die(true)
	else:
		_change_state(State.HURT)


func _on_part_destroyed(part: BodyPart) -> void:
	match str(part.part_id):
		"front_paws":
			_movement_multiplier *= 0.62
		"back_legs", "legs", "left_leg", "right_leg":
			_movement_multiplier *= 0.48
		"wings":
			_flying = false
			_movement_multiplier *= 0.4
		"left_arm", "right_arm":
			_attack_multiplier *= 0.62
		"fangs":
			_poison_enabled = false
			_attack_multiplier *= 0.65
		"core":
			_explosion_enabled = false
			_death_effect_enabled = false
		"left_front_paw", "right_front_paw", "left_hind_leg", "right_hind_leg":
			_movement_multiplier *= 0.86
		"tail":
			_attack_multiplier *= 0.82
		"weapon":
			_attack_multiplier *= 0.58
		"left_wing", "right_wing":
			_movement_multiplier *= 0.72
	if archetype == "shadow_assassin" and part.part_id == &"shell":
		_set_stealth(false)
	if archetype in ["bomb_goblin", "skeleton_bomber"] and part.part_id == &"right_arm":
		_spawn_ground_hazard(global_position + Vector2(0, 20), 58.0, 4, Color(1.0, 0.32, 0.04, 0.55), 0.08, 0.3)
	if archetype == "abyss_executioner" and part.part_id == &"core":
		_enraged = false
	if archetype == "skeleton_shield" and part.part_id == &"core":
		apply_combat_stun(1.2)
	if archetype == "skeleton_spear" and part.part_id == &"weapon":
		_profile["range"] = 78.0
	if archetype == "dungeon_turret" and part.part_id == &"core":
		_profile["cooldown"] = float(_profile.get("cooldown", 1.45)) * 1.7
	if archetype == "crystal_drone" and part.part_id in [&"left_wing", &"right_wing"] \
		and not _has_living_part(&"left_wing") and not _has_living_part(&"right_wing"):
		_flying = false
	if archetype == "abyss_hound_king" and _boss_living_limbs() == 0:
		var core: BodyPart = _parts.get("core")
		if is_instance_valid(core):
			core.set_tint(Color(1.0, 0.25, 0.55, 1.0))
	_update_health_label()


func _recalculate_part_effects() -> void:
	var family := str(_profile.get("family", "dog"))
	_movement_multiplier = 1.0
	_attack_multiplier = 1.0
	_flying = family == "bat"
	_explosion_enabled = true
	_poison_enabled = true
	_death_effect_enabled = true
	for value in _parts.values():
		var part := value as BodyPart
		if not is_instance_valid(part) or part.health > 0:
			continue
		match str(part.part_id):
			"front_paws":
				_movement_multiplier *= 0.62
			"back_legs", "legs", "left_leg", "right_leg":
				_movement_multiplier *= 0.48
			"left_wing", "right_wing":
				_movement_multiplier *= 0.72
			"wings":
				_flying = false
				_movement_multiplier *= 0.4
			"left_arm", "right_arm":
				_attack_multiplier *= 0.62
			"fangs":
				_poison_enabled = false
				_attack_multiplier *= 0.65
			"core":
				_explosion_enabled = false
				_death_effect_enabled = false
			"left_front_paw", "right_front_paw", "left_hind_leg", "right_hind_leg":
				_movement_multiplier *= 0.86
			"tail":
				_attack_multiplier *= 0.82
	if archetype == "abyss_hound_king" and _boss_living_limbs() == 0:
		var core: BodyPart = _parts.get("core")
		if is_instance_valid(core):
			core.set_tint(Color(1.0, 0.25, 0.55, 1.0))


func _die(create_death_effect: bool = true) -> void:
	if _state == State.DEAD:
		return
	_state = State.DEAD
	SFX.play_at("enemy_death", global_position, 0.07)
	if create_death_effect and archetype in ["fire_slime", "fire_lizard", "bomb_goblin", "skeleton_bomber"]:
		SFX.play_at("explosion", global_position, 0.04)
	collision_layer = 0
	collision_mask = 0
	_attack_area.set_deferred("monitoring", false)
	if create_death_effect and _death_effect_enabled and archetype == "fire_slime":
		var hazard := ENEMY_HAZARD_SCRIPT.new()
		hazard.damage = maxi(1, roundi(2.0 * attack_scale))
		hazard.global_position = global_position + Vector2(0, 22)
		get_tree().current_scene.call_deferred("add_child", hazard)
	if create_death_effect and archetype == "splitting_slime" and _death_effect_enabled:
		_spawn_split_slimes()
	if create_death_effect and archetype == "fire_lizard" and _has_living_part(&"core"):
		_spawn_ground_hazard(global_position + Vector2(0, 22), 72.0, 5, Color(1.0, 0.18, 0.02, 0.58), 0.24, 0.55)
	for summoned in _summoned_enemies:
		if is_instance_valid(summoned):
			if get_parent() != null and get_parent().has_method("unregister_summoned_enemy"):
				get_parent().unregister_summoned_enemy(summoned)
			summoned.queue_free()
	_summoned_enemies.clear()
	_health_label.text = "击败！"
	defeated.emit()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.32)
	tween.tween_property(self, "scale", Vector2(1.18, 0.2), 0.32)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)


func _create_body_parts() -> void:
	var base_color: Color = _profile.get("color", Color.WHITE)
	var parts_data: Array = _profile.get("parts", [])
	for index in range(parts_data.size()):
		var data: Array = parts_data[index]
		var part_id := StringName(str(data[0]))
		var geometry := _part_geometry(str(_profile.get("family", "dog")), part_id, index)
		var color := base_color.lightened(0.07 * float(index % 3))
		_add_body_part(part_id, str(data[1]), int(data[2]), bool(data[3]), geometry[0], geometry[1], color)


func _apply_difficulty_scaling() -> void:
	health_scale = maxf(0.1, health_scale)
	attack_scale = maxf(0.1, attack_scale)
	_profile["damage"] = maxi(1, roundi(float(_profile.get("damage", 2)) * attack_scale))
	var parts_data: Array = _profile.get("parts", [])
	for index in range(parts_data.size()):
		var part_data: Array = parts_data[index]
		part_data[2] = maxi(1, roundi(float(part_data[2]) * health_scale))
		parts_data[index] = part_data
	_profile["parts"] = parts_data


func _add_body_part(id: StringName, label: String, hp: int, vital: bool, size: Vector2, part_position: Vector2, color: Color) -> void:
	var part := BodyPart.new()
	_parts_root.add_child(part)
	part.configure(self, id, label, hp, vital, size, part_position, color, 8)
	_style_body_part(part, id, size, color)
	part.health_changed.connect(_on_part_health_changed)
	part.destroyed.connect(_on_part_destroyed)
	_parts[id] = part


func _style_body_part(part: BodyPart, id: StringName, size: Vector2, color: Color) -> void:
	part.set_visual_polygon(_part_visual_polygon(id, size))
	var half := size * 0.5
	var accent := color.lightened(0.32)
	var dark := color.darkened(0.34)
	match str(id):
		"core":
			part.add_visual_detail(PackedVector2Array([
				Vector2(0, -half.y * 0.72), Vector2(half.x * 0.62, 0),
				Vector2(0, half.y * 0.72), Vector2(-half.x * 0.62, 0),
			]), accent, 2)
		"head":
			part.add_visual_detail(PackedVector2Array([
				Vector2(-half.x * 0.45, -1), Vector2(-half.x * 0.12, -half.y * 0.18),
				Vector2(half.x * 0.34, -1), Vector2(half.x * 0.18, half.y * 0.2),
			]), dark, 2)
		"weapon":
			part.add_visual_detail(PackedVector2Array([
				Vector2(-2, -half.y), Vector2(2, -half.y), Vector2(2, half.y), Vector2(-2, half.y),
			]), accent, 2)
		"shell", "shield", "helmet":
			part.add_visual_detail(PackedVector2Array([
				Vector2(0, -half.y * 0.7), Vector2(half.x * 0.55, 0),
				Vector2(0, half.y * 0.7), Vector2(-half.x * 0.55, 0),
			]), dark, 2)
		"wings", "left_wing", "right_wing":
			part.add_visual_detail(PackedVector2Array([
				Vector2(-half.x * 0.8, 0), Vector2(0, -2), Vector2(half.x * 0.8, 0), Vector2(0, 3),
			]), accent, 2)
	if archetype in ["frost_slime", "lightning_slime", "splitting_slime", "crystal_drone"]:
		part.add_visual_detail(PackedVector2Array([
			Vector2(0, -half.y * 0.48), Vector2(half.x * 0.34, 0),
			Vector2(0, half.y * 0.48), Vector2(-half.x * 0.34, 0),
		]), Color(accent, 0.82), 3)


func _part_visual_polygon(id: StringName, size: Vector2) -> PackedVector2Array:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var key := str(id)
	if archetype in ["skeleton_bomber", "bomb_goblin"] and key == "right_arm":
		return PackedVector2Array([Vector2(0, -hy), Vector2(hx * 0.72, -hy * 0.72), Vector2(hx, 0), Vector2(hx * 0.72, hy * 0.72), Vector2(0, hy), Vector2(-hx * 0.72, hy * 0.72), Vector2(-hx, 0), Vector2(-hx * 0.72, -hy * 0.72)])
	if archetype in ["shadow_assassin", "dual_blade_hunter"] and key in ["left_arm", "right_arm"]:
		return PackedVector2Array([Vector2(0, -hy), Vector2(hx, -hy * 0.25), Vector2(hx * 0.3, hy), Vector2(-hx * 0.3, hy), Vector2(-hx, -hy * 0.25)])
	if archetype == "cursed_doll" and key == "right_arm":
		return PackedVector2Array([Vector2(0, -hy), Vector2(hx, hy * 0.72), Vector2(0, hy), Vector2(-hx, hy * 0.72)])
	if archetype == "ghost_mage" and key == "body":
		return PackedVector2Array([Vector2(-hx * 0.72, -hy), Vector2(hx * 0.72, -hy), Vector2(hx, -hy * 0.15), Vector2(hx * 0.5, hy * 0.45), Vector2(hx * 0.82, hy), Vector2(0, hy * 0.62), Vector2(-hx * 0.78, hy), Vector2(-hx * 0.48, hy * 0.35), Vector2(-hx, -hy * 0.15)])
	if archetype == "dungeon_mage":
		if key == "head":
			return PackedVector2Array([Vector2(0, -hy), Vector2(hx, hy * 0.1), Vector2(hx * 0.55, hy), Vector2(-hx * 0.55, hy), Vector2(-hx, hy * 0.1)])
		if key == "body":
			return PackedVector2Array([Vector2(-hx * 0.48, -hy), Vector2(hx * 0.48, -hy), Vector2(hx, hy), Vector2(-hx, hy)])
		if key == "weapon":
			return PackedVector2Array([Vector2(0, -hy), Vector2(hx, -hy * 0.72), Vector2(hx * 0.32, -hy * 0.42), Vector2(hx * 0.22, hy), Vector2(-hx * 0.22, hy), Vector2(-hx * 0.32, -hy * 0.42), Vector2(-hx, -hy * 0.72)])
	if archetype == "summoning_priest":
		if key == "head":
			return PackedVector2Array([Vector2(-hx, -hy * 0.4), Vector2(-hx * 0.58, -hy), Vector2(0, -hy * 0.55), Vector2(hx * 0.58, -hy), Vector2(hx, -hy * 0.4), Vector2(hx * 0.62, hy), Vector2(-hx * 0.62, hy)])
		if key == "body":
			return PackedVector2Array([Vector2(-hx * 0.35, -hy), Vector2(hx * 0.35, -hy), Vector2(hx, hy), Vector2(0, hy * 0.68), Vector2(-hx, hy)])
		if key == "weapon":
			return PackedVector2Array([Vector2(0, -hy), Vector2(hx, -hy * 0.2), Vector2(hx * 0.45, hy), Vector2(-hx * 0.45, hy), Vector2(-hx, -hy * 0.2)])
	if archetype in ["berserker", "heavy_hammer_guard", "abyss_executioner"] and key == "weapon":
		if archetype == "berserker":
			return PackedVector2Array([Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx * 0.48, -hy * 0.25), Vector2(hx * 0.12, -hy * 0.05), Vector2(hx * 0.12, hy), Vector2(-hx * 0.12, hy), Vector2(-hx * 0.12, -hy * 0.05)])
		if archetype == "heavy_hammer_guard":
			return PackedVector2Array([Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, -hy * 0.38), Vector2(hx * 0.16, -hy * 0.22), Vector2(hx * 0.16, hy), Vector2(-hx * 0.16, hy), Vector2(-hx * 0.16, -hy * 0.22), Vector2(-hx, -hy * 0.38)])
		return PackedVector2Array([Vector2(0, -hy), Vector2(hx, -hy * 0.42), Vector2(hx * 0.28, hy), Vector2(-hx * 0.28, hy), Vector2(-hx, -hy * 0.42)])
	if archetype == "crimson_witch":
		if key == "body":
			return PackedVector2Array([Vector2(-hx * 0.45, -hy), Vector2(hx * 0.45, -hy), Vector2(hx, hy), Vector2(0, hy * 0.68), Vector2(-hx, hy)])
		if key == "wings":
			return PackedVector2Array([Vector2(0, -hy), Vector2(hx * 0.78, -hy * 0.55), Vector2(hx, 0), Vector2(hx * 0.78, hy * 0.55), Vector2(0, hy), Vector2(-hx * 0.78, hy * 0.55), Vector2(-hx, 0), Vector2(-hx * 0.78, -hy * 0.55)])
	if archetype in ["frost_slime", "lightning_slime", "splitting_slime"]:
		if key == "body":
			if archetype == "splitting_slime":
				return PackedVector2Array([Vector2(-hx, hy * 0.35), Vector2(-hx * 0.82, -hy * 0.42), Vector2(-hx * 0.42, -hy), Vector2(0, -hy * 0.62), Vector2(hx * 0.42, -hy), Vector2(hx * 0.86, -hy * 0.32), Vector2(hx, hy * 0.42), Vector2(hx * 0.55, hy), Vector2(-hx * 0.58, hy)])
			return PackedVector2Array([Vector2(-hx, hy * 0.38), Vector2(-hx * 0.82, -hy * 0.38), Vector2(-hx * 0.48, -hy * 0.82), Vector2(0, -hy), Vector2(hx * 0.55, -hy * 0.78), Vector2(hx * 0.9, -hy * 0.25), Vector2(hx, hy * 0.42), Vector2(hx * 0.62, hy), Vector2(-hx * 0.62, hy)])
		if key == "shell" and archetype == "lightning_slime":
			return PackedVector2Array([Vector2(-hx, -hy * 0.25), Vector2(-hx * 0.2, -hy), Vector2(0, -hy * 0.2), Vector2(hx * 0.75, -hy), Vector2(hx * 0.22, hy * 0.05), Vector2(hx, hy * 0.35), Vector2(0, hy), Vector2(-hx * 0.72, hy * 0.55)])
	if archetype in ["spike_vine", "man_eating_flower"]:
		match key:
			"root": return PackedVector2Array([Vector2(-hx, hy * 0.25), Vector2(-hx * 0.55, -hy * 0.35), Vector2(-hx * 0.18, -hy), Vector2(hx * 0.15, -hy * 0.45), Vector2(hx * 0.62, -hy * 0.12), Vector2(hx, hy * 0.4), Vector2(hx * 0.28, hy), Vector2(-hx * 0.55, hy)])
			"body": return PackedVector2Array([Vector2(-hx * 0.7, hy), Vector2(-hx, hy * 0.22), Vector2(-hx * 0.35, -hy * 0.08), Vector2(-hx * 0.72, -hy), Vector2(hx * 0.42, -hy), Vector2(hx, -hy * 0.2), Vector2(hx * 0.35, hy * 0.12), Vector2(hx * 0.7, hy)])
			"head": return PackedVector2Array([Vector2(-hx, 0), Vector2(-hx * 0.62, -hy * 0.78), Vector2(0, -hy), Vector2(hx * 0.92, -hy * 0.38), Vector2(hx * 0.45, 0), Vector2(hx, hy * 0.5), Vector2(0, hy), Vector2(-hx * 0.72, hy * 0.68)])
			"weapon": return PackedVector2Array([Vector2(-hx, hy * 0.32), Vector2(-hx * 0.4, -hy * 0.18), Vector2(-hx * 0.1, -hy), Vector2(hx * 0.18, -hy * 0.15), Vector2(hx, 0), Vector2(hx * 0.12, hy * 0.28), Vector2(-hx * 0.35, hy)])
	if archetype in ["dungeon_turret", "crystal_drone"]:
		match key:
			"body": return PackedVector2Array([Vector2(-hx, hy), Vector2(-hx * 0.76, -hy * 0.45), Vector2(-hx * 0.34, -hy), Vector2(hx * 0.42, -hy), Vector2(hx, -hy * 0.22), Vector2(hx * 0.82, hy), Vector2.ZERO]) if archetype == "dungeon_turret" else PackedVector2Array([Vector2(0, -hy), Vector2(hx, 0), Vector2(0, hy), Vector2(-hx, 0)])
			"head": return PackedVector2Array([Vector2(-hx, -hy * 0.55), Vector2(hx * 0.72, -hy * 0.38), Vector2(hx, 0), Vector2(hx * 0.72, hy * 0.38), Vector2(-hx, hy * 0.55), Vector2(-hx * 0.7, 0)])
			"left_wing": return PackedVector2Array([Vector2(hx, -hy * 0.3), Vector2(-hx, -hy), Vector2(-hx * 0.6, hy), Vector2(hx, hy * 0.35)])
			"right_wing": return PackedVector2Array([Vector2(-hx, -hy * 0.3), Vector2(hx, -hy), Vector2(hx * 0.6, hy), Vector2(-hx, hy * 0.35)])
	if archetype == "fire_lizard":
		match key:
			"head": return PackedVector2Array([Vector2(-hx, -hy * 0.52), Vector2(hx * 0.35, -hy), Vector2(hx, -hy * 0.24), Vector2(hx * 0.72, hy * 0.2), Vector2(hx, hy * 0.62), Vector2(-hx * 0.5, hy), Vector2(-hx, hy * 0.25)])
			"body": return PackedVector2Array([Vector2(-hx, 0), Vector2(-hx * 0.55, -hy * 0.82), Vector2(hx * 0.45, -hy), Vector2(hx, -hy * 0.22), Vector2(hx * 0.72, hy * 0.72), Vector2(-hx * 0.48, hy)])
			"tail": return PackedVector2Array([Vector2(hx, -hy * 0.18), Vector2(-hx * 0.65, -hy), Vector2(-hx, -hy * 0.2), Vector2(-hx * 0.62, hy), Vector2(hx, hy * 0.2)])
	if archetype in ["bomb_goblin"] and key == "head":
		return PackedVector2Array([Vector2(-hx, -hy * 0.2), Vector2(-hx * 0.25, -hy), Vector2(hx * 0.25, -hy), Vector2(hx, -hy * 0.2), Vector2(hx * 0.45, hy), Vector2(-hx * 0.45, hy)])
	if archetype == "cursed_doll" and key in ["head", "body"]:
		return PackedVector2Array([Vector2(-hx, -hy * 0.65), Vector2(-hx * 0.55, -hy), Vector2(hx * 0.72, -hy * 0.82), Vector2(hx, -hy * 0.15), Vector2(hx * 0.7, hy), Vector2(-hx * 0.62, hy), Vector2(-hx, hy * 0.32)])
	if archetype in ["skeleton_shield"] and key == "shell":
		return PackedVector2Array([Vector2(0, -hy), Vector2(hx, -hy * 0.62), Vector2(hx * 0.86, hy * 0.42), Vector2(0, hy), Vector2(-hx * 0.86, hy * 0.42), Vector2(-hx, -hy * 0.62)])
	if archetype in ["skeleton_spear", "blackflame_lancer"] and key == "weapon":
		return PackedVector2Array([Vector2(0, -hy), Vector2(hx * 0.65, -hy * 0.66), Vector2(hx * 0.18, -hy * 0.46), Vector2(hx * 0.18, hy), Vector2(-hx * 0.18, hy), Vector2(-hx * 0.18, -hy * 0.46), Vector2(-hx * 0.65, -hy * 0.66)])
	if archetype in ["heavy_hammer_guard"] and key == "weapon":
		return PackedVector2Array([Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, -hy * 0.34), Vector2(hx * 0.2, -hy * 0.2), Vector2(hx * 0.2, hy), Vector2(-hx * 0.2, hy), Vector2(-hx * 0.2, -hy * 0.2), Vector2(-hx, -hy * 0.34)])
	if archetype in ["shadow_assassin", "dual_blade_hunter"] and key == "shell":
		return PackedVector2Array([Vector2(-hx * 0.2, -hy), Vector2(hx, -hy * 0.65), Vector2(hx * 0.5, hy), Vector2(0, hy * 0.55), Vector2(-hx, hy), Vector2(-hx * 0.55, -hy * 0.45)])
	if archetype in ["blood_armor_knight", "blackflame_lancer", "abyss_executioner"] and key == "body":
		return PackedVector2Array([Vector2(-hx * 0.72, -hy), Vector2(hx * 0.72, -hy), Vector2(hx, -hy * 0.25), Vector2(hx * 0.78, hy), Vector2(0, hy * 0.72), Vector2(-hx * 0.78, hy), Vector2(-hx, -hy * 0.25)])
	match key:
		"helmet": return PackedVector2Array([Vector2(-hx, hy * 0.25), Vector2(-hx * 0.72, -hy * 0.7), Vector2(0, -hy), Vector2(hx * 0.72, -hy * 0.7), Vector2(hx, hy * 0.25), Vector2(hx * 0.4, hy), Vector2(-hx * 0.4, hy)])
		"head": return PackedVector2Array([Vector2(-hx * 0.7, -hy), Vector2(hx * 0.62, -hy), Vector2(hx, -hy * 0.32), Vector2(hx * 0.76, hy * 0.72), Vector2(0, hy), Vector2(-hx * 0.78, hy * 0.68), Vector2(-hx, -hy * 0.25)])
		"body": return PackedVector2Array([Vector2(-hx * 0.68, -hy), Vector2(hx * 0.68, -hy), Vector2(hx, -hy * 0.25), Vector2(hx * 0.72, hy), Vector2(-hx * 0.72, hy), Vector2(-hx, -hy * 0.25)])
		"left_arm", "right_arm": return PackedVector2Array([Vector2(-hx * 0.7, -hy), Vector2(hx * 0.7, -hy), Vector2(hx, hy * 0.6), Vector2(0, hy), Vector2(-hx, hy * 0.6)])
		"legs", "left_leg", "right_leg": return PackedVector2Array([Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx * 0.72, hy * 0.25), Vector2(hx, hy), Vector2(0, hy * 0.72), Vector2(-hx, hy), Vector2(-hx * 0.72, hy * 0.25)])
		"weapon": return PackedVector2Array([Vector2(0, -hy), Vector2(hx, -hy * 0.62), Vector2(hx * 0.32, hy), Vector2(-hx * 0.32, hy), Vector2(-hx, -hy * 0.62)])
		"shell": return PackedVector2Array([Vector2(0, -hy), Vector2(hx, -hy * 0.45), Vector2(hx * 0.78, hy * 0.55), Vector2(0, hy), Vector2(-hx * 0.78, hy * 0.55), Vector2(-hx, -hy * 0.45)])
		"shield": return PackedVector2Array([Vector2(0, -hy), Vector2(hx, -hy * 0.6), Vector2(hx * 0.82, hy * 0.45), Vector2(0, hy), Vector2(-hx * 0.82, hy * 0.45), Vector2(-hx, -hy * 0.6)])
		"core": return PackedVector2Array([Vector2(0, -hy), Vector2(hx, 0), Vector2(0, hy), Vector2(-hx, 0)])
		"wings", "left_wing", "right_wing": return PackedVector2Array([Vector2(-hx, 0), Vector2(-hx * 0.35, -hy), Vector2(0, -hy * 0.22), Vector2(hx * 0.5, -hy), Vector2(hx, 0), Vector2(hx * 0.2, hy), Vector2(-hx * 0.25, hy * 0.45)])
		"root": return PackedVector2Array([Vector2(-hx, hy), Vector2(-hx * 0.72, -hy * 0.2), Vector2(0, -hy), Vector2(hx * 0.72, -hy * 0.2), Vector2(hx, hy), Vector2(0, hy * 0.6)])
	return PackedVector2Array([Vector2(-hx, 0), Vector2(-hx * 0.55, -hy), Vector2(hx * 0.55, -hy), Vector2(hx, 0), Vector2(hx * 0.55, hy), Vector2(-hx * 0.55, hy)])


func _part_geometry(family: String, id: StringName, _index: int) -> Array:
	if family == "boss_dog":
		match str(id):
			"head": return [Vector2(42, 38), Vector2(54, -22)]
			"body": return [Vector2(92, 52), Vector2(0, 0)]
			"left_front_paw": return [Vector2(23, 35), Vector2(34, 36)]
			"right_front_paw": return [Vector2(23, 35), Vector2(58, 34)]
			"left_hind_leg": return [Vector2(23, 35), Vector2(-36, 36)]
			"right_hind_leg": return [Vector2(23, 35), Vector2(-58, 34)]
			"tail": return [Vector2(48, 16), Vector2(-67, -12)]
			"core": return [Vector2(24, 24), Vector2(0, -2)]
	if family == "dog":
		match str(id):
			"head": return [Vector2(24, 22), Vector2(31, -13)]
			"body": return [Vector2(50, 27), Vector2(0, 0)]
			"front_paws": return [Vector2(18, 25), Vector2(21, 21)]
			"back_legs": return [Vector2(18, 25), Vector2(-21, 21)]
			"fangs": return [Vector2(12, 9), Vector2(45, -8)]
			"core": return [Vector2(18, 18), Vector2(-4, -2)]
			"tail": return [Vector2(38, 15), Vector2(-38, -4)]
			"legs": return [Vector2(42, 24), Vector2(-2, 22)]
	if family == "bug":
		match str(id):
			"head": return [Vector2(22, 20), Vector2(28, 5)]
			"body": return [Vector2(48, 25), Vector2(0, 8)]
			"shell": return [Vector2(43, 18), Vector2(-5, -7)]
			"core": return [Vector2(16, 16), Vector2(0, 6)]
	if family == "bat":
		match str(id):
			"head": return [Vector2(18, 18), Vector2(18, 0)]
			"body": return [Vector2(27, 24), Vector2(0, 2)]
			"wings": return [Vector2(74, 15), Vector2(-4, -3)]
			"left_wing": return [Vector2(34, 18), Vector2(-27, -3)]
			"right_wing": return [Vector2(34, 18), Vector2(27, -3)]
			"left_arm": return [Vector2(12, 28), Vector2(-19, 5)]
			"right_arm": return [Vector2(12, 28), Vector2(19, 5)]
	if family == "skeleton":
		match str(id):
			"head": return [Vector2(22, 22), Vector2(0, -38)]
			"body": return [Vector2(28, 38), Vector2(0, -8)]
			"right_arm":
				if archetype in ["skeleton_bomber", "bomb_goblin"]: return [Vector2(28, 28), Vector2(28, -8)]
				if archetype == "cursed_doll": return [Vector2(9, 52), Vector2(27, -8)]
				if archetype in ["shadow_assassin", "dual_blade_hunter"]: return [Vector2(15, 48), Vector2(26, -8)]
				return [Vector2(13, 35), Vector2(23, -8)]
			"left_arm":
				if archetype in ["shadow_assassin", "dual_blade_hunter"]: return [Vector2(15, 48), Vector2(-26, -8)]
				return [Vector2(13, 35), Vector2(-23, -8)]
			"legs": return [Vector2(28, 31), Vector2(0, 28)]
			"left_leg": return [Vector2(13, 31), Vector2(-9, 28)]
			"right_leg": return [Vector2(13, 31), Vector2(9, 28)]
			"weapon":
				if archetype == "berserker": return [Vector2(38, 58), Vector2(39, -11)]
				if archetype == "heavy_hammer_guard": return [Vector2(46, 72), Vector2(43, -8)]
				return [Vector2(12, 54), Vector2(37, -8)]
			"shell": return [Vector2(38, 44), Vector2(-4, -7)]
			"core": return [Vector2(16, 16), Vector2(0, -10)]
	if family == "slime":
		return [Vector2(48, 38), Vector2(0, 4)] if id == &"body" else [Vector2(17, 17), Vector2(0, 1)]
	if family == "plant":
		match str(id):
			"root": return [Vector2(54, 20), Vector2(0, 25)]
			"body": return [Vector2(22, 52), Vector2(0, -3)]
			"head": return [Vector2(43, 36), Vector2(0, -40)]
			"weapon": return [Vector2(64, 16), Vector2(8, -18)]
			"core": return [Vector2(18, 18), Vector2(0, -22)]
	if family in ["boss_humanoid", "boss_mage"]:
		match str(id):
			"helmet": return [Vector2(42, 28), Vector2(0, -82)]
			"head": return [Vector2(34, 30), Vector2(0, -68)]
			"body": return [Vector2(46, 66), Vector2(0, -25)]
			"left_arm": return [Vector2(18, 55), Vector2(-36, -28)]
			"right_arm": return [Vector2(18, 55), Vector2(36, -28)]
			"legs": return [Vector2(44, 46), Vector2(0, 30)]
			"shell": return [Vector2(58, 70), Vector2(0, -25)]
			"shield": return [Vector2(44, 68), Vector2(-50, -25)]
			"weapon": return [Vector2(16, 88), Vector2(55, -25)]
			"core": return [Vector2(24, 24), Vector2(0, -28)]
			"wings": return [Vector2(94, 54), Vector2(0, -32)]
	if family == "elite_humanoid":
		match str(id):
			"head": return [Vector2(28, 28), Vector2(0, -49)]
			"body": return [Vector2(38, 48), Vector2(0, -15)]
			"left_arm": return [Vector2(15, 42), Vector2(-28, -14)]
			"right_arm": return [Vector2(15, 42), Vector2(28, -14)]
			"legs": return [Vector2(36, 36), Vector2(0, 29)]
			"left_leg": return [Vector2(16, 36), Vector2(-10, 29)]
			"right_leg": return [Vector2(16, 36), Vector2(10, 29)]
			"shell": return [Vector2(50, 54), Vector2(0, -16)]
			"weapon": return [Vector2(34, 92), Vector2(50, -14)] if archetype == "abyss_executioner" else [Vector2(20, 78), Vector2(46, -14)]
			"core": return [Vector2(20, 20), Vector2(0, -18)]
	return [Vector2(20, 20), Vector2.ZERO]


func _apply_collision_shape() -> void:
	var rectangle := _collision.shape as RectangleShape2D
	if not is_instance_valid(rectangle):
		return
	_collision.position = Vector2(0, 2)
	match str(_profile.get("family", "dog")):
		"boss_dog":
			rectangle.size = Vector2(132, 82)
			_collision.position = Vector2(0, 11)
		"boss_humanoid", "boss_mage":
			rectangle.size = Vector2(72, 126)
			_collision.position = Vector2(0, -16)
		"elite_humanoid":
			rectangle.size = Vector2(62, 96)
			_collision.position = Vector2(0, -8)
		"skeleton": rectangle.size = Vector2(48, 78)
		"bat": rectangle.size = Vector2(70, 34)
		"slime": rectangle.size = Vector2(48, 40)
		"plant": rectangle.size = Vector2(54, 82)
		_: rectangle.size = Vector2(76, 46)


func _on_part_health_changed(_part: BodyPart) -> void:
	_update_health_label()


func _update_health_label() -> void:
	var health := 0
	var maximum := 0
	for value in _parts.values():
		var part := value as BodyPart
		health += part.health
		maximum += part.max_health
	_health_label.text = "%s %d/%d" % [str(_profile.get("name", "怪物")), health, maximum]
	if archetype == "abyss_hound_king" and _boss_living_limbs() > 0:
		_health_label.text += "  核心封锁×%d" % _boss_living_limbs()
	_update_boss_health_bar(health, maximum)


func _setup_boss_health_bar() -> void:
	if is_instance_valid(_boss_bar_root):
		return
	_boss_bar_root = Node2D.new()
	_boss_bar_root.position = Vector2(0, -112)
	add_child(_boss_bar_root)
	var background := Polygon2D.new()
	var half_width := BOSS_BAR_WIDTH * 0.5
	var half_height := BOSS_BAR_HEIGHT * 0.5
	background.polygon = PackedVector2Array([
		Vector2(-half_width - 3.0, -half_height - 3.0),
		Vector2(half_width + 3.0, -half_height - 3.0),
		Vector2(half_width + 3.0, half_height + 3.0),
		Vector2(-half_width - 3.0, half_height + 3.0),
	])
	background.color = Color(0.06, 0.0, 0.02, 0.86)
	_boss_bar_root.add_child(background)
	_boss_bar_fill = Polygon2D.new()
	_boss_bar_fill.color = Color(0.95, 0.05, 0.16, 0.94)
	_boss_bar_root.add_child(_boss_bar_fill)
	var frame := Line2D.new()
	frame.width = 2.0
	frame.default_color = Color(1.0, 0.76, 0.3, 0.95)
	frame.closed = true
	frame.points = PackedVector2Array([
		Vector2(-half_width, -half_height),
		Vector2(half_width, -half_height),
		Vector2(half_width, half_height),
		Vector2(-half_width, half_height),
	])
	_boss_bar_root.add_child(frame)
	_boss_bar_label = Label.new()
	_boss_bar_label.position = Vector2(-half_width, -36)
	_boss_bar_label.size = Vector2(BOSS_BAR_WIDTH, 24)
	_boss_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_bar_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.52, 1.0))
	_boss_bar_label.add_theme_font_size_override("font_size", 18)
	_boss_bar_root.add_child(_boss_bar_label)


func _update_boss_health_bar(health: int, maximum: int) -> void:
	if str(_profile.get("mode", "")) != "boss" or not is_instance_valid(_boss_bar_fill):
		return
	var ratio := clampf(float(health) / maxf(1.0, float(maximum)), 0.0, 1.0)
	var half_width := BOSS_BAR_WIDTH * 0.5
	var half_height := BOSS_BAR_HEIGHT * 0.5
	var right := -half_width + BOSS_BAR_WIDTH * ratio
	_boss_bar_fill.polygon = PackedVector2Array([
		Vector2(-half_width, -half_height),
		Vector2(right, -half_height),
		Vector2(right, half_height),
		Vector2(-half_width, half_height),
	])
	_boss_bar_fill.color = Color(0.95, 0.05 + (1.0 - ratio) * 0.18, 0.16, 0.94)
	var suffix := ""
	if archetype == "abyss_hound_king":
		var locked := _boss_living_limbs()
		suffix = ("  核心封锁×%d" % locked) if locked > 0 else "  核心暴露"
	_boss_bar_label.text = "%s  %d/%d%s" % [str(_profile.get("name", "Boss")), health, maximum, suffix]


func _set_parts_tint(color: Color) -> void:
	for value in _parts.values():
		(value as BodyPart).set_tint(color)


func _setup_attack_telegraph() -> void:
	_attack_telegraph = Polygon2D.new()
	_attack_telegraph.name = "AttackTelegraph"
	_attack_telegraph.z_index = -2
	_attack_telegraph.visible = false
	var mode := str(_profile.get("mode", "bite"))
	var attack_range := clampf(float(_profile.get("range", 80.0)), 65.0, 440.0)
	var ranged := mode in RANGED_MODES or mode in ["bomb_throw", "summoner", "vine", "flower", "fire_breath"]
	if ranged:
		_attack_telegraph.polygon = PackedVector2Array([
			Vector2(18, -7), Vector2(attack_range, -12), Vector2(attack_range + 18, 0),
			Vector2(attack_range, 12), Vector2(18, 7),
		])
	else:
		var width := 42.0 if mode in ["hammer", "elite_executioner", "boss"] else 26.0
		attack_range = minf(attack_range, 210.0)
		_attack_telegraph.polygon = PackedVector2Array([
			Vector2(12, -10), Vector2(attack_range, -width), Vector2(attack_range + 20, 0),
			Vector2(attack_range, width), Vector2(12, 10),
		])
	_attack_telegraph.color = Color(0.96, 0.13, 0.08, 0.34) if mode != "boss" else Color(0.86, 0.08, 0.46, 0.4)
	_visual.add_child(_attack_telegraph)
	_visual.move_child(_attack_telegraph, 0)


func _update_attack_telegraph() -> void:
	if not is_instance_valid(_attack_telegraph) or not _attack_telegraph.visible:
		return
	var windup := maxf(0.01, float(_profile.get("windup", 0.25)))
	var progress := clampf(1.0 - _state_timer / windup, 0.0, 1.0)
	_attack_telegraph.modulate.a = 0.38 + progress * 0.62
	_attack_telegraph.scale.y = 0.82 + sin(progress * PI) * 0.3
	_attack_telegraph.position.x = sin(_animation_time * 18.0) * (1.0 + progress * 2.0)


func _animate_parts() -> void:
	var moving := absf(velocity.x) > 20.0
	var locomotion_speed := clampf(absf(velocity.x) / maxf(70.0, float(_profile.get("speed", 100.0))), 0.75, 1.8)
	var cycle_speed := 10.5 * locomotion_speed if moving else 2.2
	var step := sin(_animation_time * cycle_speed)
	var opposite_step := sin(_animation_time * cycle_speed + PI)
	var lift := maxf(0.0, step)
	var opposite_lift := maxf(0.0, opposite_step)
	var idle_breath := sin(_animation_time * 2.2)
	var family := str(_profile.get("family", "dog"))
	for key in _parts.keys():
		var part := _parts[key] as BodyPart
		var offset := Vector2.ZERO
		var angle := 0.0
		var part_scale := Vector2.ONE
		match family:
			"boss_dog":
				offset.y = (-absf(step) * 2.0 if moving else idle_breath * 1.0)
				if str(key) in ["left_front_paw", "right_hind_leg"]:
					offset += Vector2(step * 5.0, -lift * 4.0)
					angle = step * 0.12
				elif str(key) in ["right_front_paw", "left_hind_leg"]:
					offset += Vector2(opposite_step * 5.0, -opposite_lift * 4.0)
					angle = opposite_step * 0.12
				elif str(key) == "head":
					offset += Vector2(step * 1.5, -absf(step) * 1.5)
					angle = -step * 0.045
				elif str(key) == "tail":
					angle = step * 0.22 + idle_breath * 0.05
			"dog", "bug":
				offset.y = (-absf(step) * 1.8 if moving else idle_breath * 0.8)
				if str(key) == "front_paws":
					offset += Vector2(step * 4.5, -lift * 3.5)
					angle = step * 0.1
				elif str(key) in ["back_legs", "legs"]:
					offset += Vector2(opposite_step * 4.5, -opposite_lift * 3.5)
					angle = opposite_step * 0.1
				elif str(key) in ["head", "weapon"]:
					offset.x = step * 1.5
					angle = -step * 0.06
				elif str(key) in ["shell", "body"]:
					angle = step * 0.025
			"bat":
				offset.y = idle_breath * 2.2
				if str(key) in ["wings", "left_wing", "right_wing"]:
					var wing_side := 1.0 if str(key) == "left_wing" else -1.0
					offset.y += step * 5.5
					angle = step * 0.18 * wing_side
				elif str(key) == "head":
					offset.y += -step * 1.2
				elif str(key) in ["body", "core"]:
					angle = step * 0.025
			"skeleton":
				offset.y = (-absf(step) * 1.7 if moving else idle_breath * 0.55)
				if str(key) in ["left_arm", "right_arm"]:
					var arm_side := 1.0 if str(key) == "left_arm" else -1.0
					offset.x = step * 2.0 * arm_side
					angle = step * 0.2 * arm_side
				elif str(key) == "legs":
					offset += Vector2(step * 3.8, -lift * 2.5)
					angle = step * 0.075
				elif str(key) in ["left_leg", "right_leg"]:
					var leg_phase := step if str(key) == "left_leg" else opposite_step
					offset += Vector2(leg_phase * 3.8, -maxf(0.0, leg_phase) * 3.0)
					angle = leg_phase * 0.11
				elif str(key) in ["body", "shell"]:
					angle = -step * 0.025
				elif str(key) in ["head", "helmet"]:
					offset.y -= absf(step) * 0.8
				elif str(key) == "weapon":
					angle = -step * 0.12
			"slime":
				offset.y = (-absf(step) * 3.0 if moving else idle_breath * 0.8)
				var squash := absf(step) if moving else (idle_breath + 1.0) * 0.15
				part_scale = Vector2(1.0 + squash * 0.09, 1.0 - squash * 0.075)
				if str(key) == "core":
					offset.x = step * 1.8
			"plant":
				if str(key) in ["head", "weapon", "core"]:
					angle = step * (0.1 if moving else 0.06)
					offset.x = step * 2.2
				elif str(key) == "body":
					angle = -step * 0.035
			"boss_humanoid", "boss_mage":
				offset.y = (-absf(step) * 1.3 if moving else idle_breath * 0.65)
				if str(key) in ["left_arm", "right_arm", "weapon"]:
					angle = step * (0.13 if str(key) == "left_arm" else -0.13)
				elif str(key) in ["legs", "left_leg", "right_leg"]:
					offset.x = step * 3.0
					angle = step * 0.06
			"elite_humanoid":
				offset.y = (-absf(step) * 1.6 if moving else idle_breath * 0.55)
				if str(key) in ["left_arm", "right_arm", "weapon"]:
					angle = step * (0.18 if str(key) == "left_arm" else -0.18)
				elif str(key) in ["legs", "left_leg", "right_leg"]:
					var elite_leg_phase := step if str(key) != "right_leg" else opposite_step
					offset += Vector2(elite_leg_phase * 4.2, -maxf(0.0, elite_leg_phase) * 3.0)
					angle = elite_leg_phase * 0.1
				elif str(key) in ["body", "core", "shell"]:
					angle = -step * 0.025
		var attack_pose := _attack_part_pose(str(key))
		offset += attack_pose.get("offset", Vector2.ZERO) as Vector2
		angle += float(attack_pose.get("angle", 0.0))
		part_scale *= attack_pose.get("scale", Vector2.ONE) as Vector2
		part.animate_transform(offset, angle)
		part.animate_scale(part_scale)


func _attack_part_pose(key: String) -> Dictionary:
	var windup_amount := 0.0
	var strike_amount := 0.0
	if _state == State.WINDUP:
		var duration := maxf(0.01, float(_profile.get("windup", 0.25)))
		windup_amount = smoothstep(0.0, 1.0, 1.0 - _state_timer / duration)
	elif _state == State.ATTACK:
		var duration := maxf(0.01, float(_profile.get("duration", 0.2)))
		var progress := clampf(1.0 - _state_timer / duration, 0.0, 1.0)
		strike_amount = 1.0 - progress * 0.55
	elif _state == State.RECOVERY:
		var duration := maxf(0.01, float(_profile.get("cooldown", 0.8)))
		strike_amount = maxf(0.0, 0.35 * (_state_timer / duration))
	else:
		return {"offset": Vector2.ZERO, "angle": 0.0, "scale": Vector2.ONE}

	var offset := Vector2.ZERO
	var angle := 0.0
	var target_scale := Vector2.ONE
	var mode := str(_profile.get("mode", "bite"))
	match mode:
		"shield":
			if key == "shell":
				offset = Vector2(5.0 * windup_amount + 16.0 * strike_amount, -5.0 * windup_amount)
				angle = -0.14 * windup_amount + 0.16 * strike_amount
			elif key in ["body", "head"]:
				offset.x = 7.0 * strike_amount - 4.0 * windup_amount
		"spear", "elite_lancer":
			if key in ["weapon", "right_arm"]:
				offset = Vector2(-16.0 * windup_amount + 28.0 * strike_amount, -4.0 * windup_amount)
				angle = -0.34 * windup_amount + 0.1 * strike_amount
			elif key in ["body", "head", "core"]:
				offset.x = -5.0 * windup_amount + 12.0 * strike_amount
		"bomb_throw":
			if key == "right_arm":
				offset = Vector2(-6.0 * windup_amount + 18.0 * strike_amount, -18.0 * windup_amount - 4.0 * strike_amount)
				angle = -1.05 * windup_amount + 0.88 * strike_amount
			elif key == "left_arm":
				angle = 0.35 * windup_amount
		"ranged", "mage", "ghost_mage", "summoner", "turret", "laser":
			if key in ["weapon", "right_arm", "head"]:
				offset = Vector2(-5.0 * windup_amount - 10.0 * strike_amount, -8.0 * windup_amount)
				angle = -0.42 * windup_amount + 0.22 * strike_amount
			elif key in ["left_arm", "left_wing", "right_wing", "wings"]:
				offset.y = -7.0 * windup_amount + 4.0 * strike_amount
				angle = (0.3 if key in ["left_arm", "left_wing"] else -0.3) * windup_amount
			elif key in ["body", "core"]:
				target_scale = Vector2(1.0 + 0.1 * windup_amount, 1.0 + 0.1 * windup_amount)
		"slime_jump", "frost_jump", "split_jump", "lightning":
			if key in ["body", "core", "shell"]:
				target_scale = Vector2(1.18, 0.72) if windup_amount > strike_amount else Vector2(0.82, 1.28)
				offset.y = 7.0 * windup_amount - 9.0 * strike_amount
		"vine", "flower":
			if key in ["head", "weapon", "core"]:
				offset = Vector2(-9.0 * windup_amount + 17.0 * strike_amount, -7.0 * windup_amount)
				angle = -0.48 * windup_amount + 0.62 * strike_amount
		"hammer", "elite_executioner":
			if key == "weapon":
				offset = Vector2(-12.0 * windup_amount + 18.0 * strike_amount, -20.0 * windup_amount + 13.0 * strike_amount)
				angle = -1.18 * windup_amount + 1.28 * strike_amount
			elif key in ["left_arm", "right_arm"]:
				offset.y = -9.0 * windup_amount + 7.0 * strike_amount
				angle = -0.62 * windup_amount + 0.72 * strike_amount
			elif key in ["body", "head"]:
				offset = Vector2(-5.0 * windup_amount + 9.0 * strike_amount, 4.0 * strike_amount)
		"combo", "berserker", "dual_blade", "elite_blood", "assassin", "curse":
			var swing_side := -1.0 if (_ability_counter + _combo_hits_left) % 2 == 0 else 1.0
			if key in ["weapon", "left_arm", "right_arm"]:
				offset = Vector2(-7.0 * windup_amount + 14.0 * strike_amount, swing_side * 5.0 * strike_amount)
				angle = swing_side * (-0.72 * windup_amount + 1.05 * strike_amount)
			elif key in ["body", "head"]:
				offset.x = -4.0 * windup_amount + 8.0 * strike_amount
		"fire_breath":
			if key in ["head", "core"]:
				offset.x = -7.0 * windup_amount + 12.0 * strike_amount
				target_scale = Vector2(1.0 + 0.14 * windup_amount, 1.0 + 0.14 * windup_amount)
			elif key == "tail":
				angle = -0.7 * windup_amount + 0.9 * strike_amount
		"boss":
			if key in ["weapon", "left_arm", "right_arm", "shield"]:
				offset = Vector2(-9.0 * windup_amount + 18.0 * strike_amount, -10.0 * windup_amount)
				angle = -0.7 * windup_amount + 0.85 * strike_amount
			elif key in ["body", "core", "head"]:
				offset.x = -4.0 * windup_amount + 9.0 * strike_amount
		_:
			if key in ["head", "front_paws", "left_arm", "right_arm", "fangs"]:
				offset.x = -6.0 * windup_amount + 14.0 * strike_amount
				angle = -0.2 * windup_amount + 0.32 * strike_amount
	return {"offset": offset, "angle": angle, "scale": target_scale}


func _summon_priest_minion() -> void:
	_cleanup_boss_summons()
	if not _has_living_part(&"weapon") or _special_timer > 0.0 or _summoned_enemies.size() >= 2:
		_spawn_projectile()
		return
	_spawn_summoned_enemy(["skeleton", "cursed_doll"], 82.0, 0.72)
	SFX.play_at("summon", global_position, 0.035)
	_special_timer = 8.0


func _spawn_split_slimes() -> void:
	if get_parent() == null:
		return
	for side in [-1.0, 1.0]:
		_spawn_summoned_enemy(["frost_slime"], 54.0 * side, 0.62, true)
	# Split offspring stay alive after the parent finishes its death cleanup.
	_summoned_enemies.clear()


func _spawn_summoned_enemy(
	pool: Array,
	horizontal_offset: float,
	spawn_scale: float,
	allow_multiple: bool = false
) -> void:
	var scene := load("res://scenes/enemies/variant_enemy.tscn") as PackedScene
	if scene == null or get_parent() == null or pool.is_empty():
		return
	if not allow_multiple and _summoned_enemies.size() >= BOSS_MAX_SUMMONS:
		return
	var parent := get_parent()
	var enemy := scene.instantiate()
	var enemy_type := str(pool[randi() % pool.size()])
	enemy.set("archetype", enemy_type)
	enemy.set("health_scale", maxf(0.45, health_scale * 0.72))
	enemy.set("attack_scale", maxf(0.45, attack_scale * 0.78))
	enemy.set("_summoner_owner", self)
	parent.add_child(enemy)
	SFX.play_at("summon", global_position, 0.045)
	var spawn_offset := Vector2.ZERO
	if enemy.has_method("get_spawn_offset"):
		spawn_offset = enemy.get_spawn_offset()
	(enemy as Node2D).global_position = global_position + Vector2(horizontal_offset, -8.0) + spawn_offset
	(enemy as Node2D).scale = Vector2(spawn_scale, spawn_scale)
	enemy.name = "Summon_%d_%d" % [get_instance_id(), _summoned_enemies.size()]
	enemy.add_to_group("boss_summon")
	if parent.has_method("register_summoned_enemy"):
		parent.register_summoned_enemy(enemy)
	_summoned_enemies.append(enemy)


func _begin_boss_attack() -> void:
	_cleanup_boss_summons()
	var distance := absf(_target.global_position.x - global_position.x)
	_boss_special_index += 1
	_boss_slam_done = false
	_boss_wave_done = false
	if archetype == "crimson_witch":
		_begin_crimson_witch_attack()
		return
	var phase_ratio := _total_health_ratio()
	if archetype == "skeleton_general" and phase_ratio <= 0.35 and _boss_special_index % 2 == 0:
		_boss_attack = "wave"
		_state_timer = 0.48
		_attack_visual.visible = false
		_spawn_boss_wave()
	elif _boss_summon_cooldown <= 0.0 and _summoned_enemies.size() < BOSS_MAX_SUMMONS \
		and (archetype != "skeleton_general" or phase_ratio <= 0.70):
		_boss_attack = "summon"
		_state_timer = 0.78
		_attack_visual.visible = false
		velocity = Vector2.ZERO
		_boss_summon_cooldown = 7.0
		_summon_boss_minion()
		if archetype == "skeleton_general":
			_summon_boss_minion()
	elif _boss_special_index % 5 == 0:
		_boss_attack = "slam"
		_state_timer = 0.76
		_attack_area.scale = Vector2(2.7, 1.55)
		_attack_visual.scale = Vector2(2.7, 1.55)
		_attack_visual.visible = true
		velocity.x = 0.0
		velocity.y = -430.0
	elif _boss_special_index % 3 == 0:
		_boss_attack = "wave"
		_state_timer = 0.42
		_attack_area.scale = Vector2(1.0, 1.0)
		_attack_visual.visible = false
		_spawn_boss_wave()
	elif distance > 118.0:
		_boss_attack = "charge"
		_state_timer = 0.55
		_attack_area.scale = Vector2(1.65, 1.25)
		_attack_visual.scale = Vector2(1.65, 1.25)
		velocity.x = _facing * 470.0 * _movement_multiplier
	else:
		_boss_attack = "claw"
		_state_timer = 0.26
		_attack_area.scale = Vector2(1.25, 1.4)
		_attack_visual.scale = Vector2(1.25, 1.4)


func _update_boss_attack() -> void:
	match _boss_attack:
		"charge":
			velocity.x = _facing * 470.0 * _movement_multiplier
			_try_damage_player()
		"claw":
			velocity.x = 0.0
			_try_damage_player()
		"slam":
			velocity.x = 0.0
			if not _boss_slam_done and (is_on_floor() and velocity.y >= 0.0 or _state_timer <= 0.12):
				_boss_slam_done = true
				_spawn_boss_slam()
		"wave":
			velocity.x = 0.0
		"witch_curse":
			velocity.x = 0.0
		"summon":
			velocity = Vector2.ZERO


func _begin_crimson_witch_attack() -> void:
	velocity = Vector2.ZERO
	var phase_ratio := _total_health_ratio()
	if _boss_special_index % 5 == 0 and _has_living_part(&"shell") and is_instance_valid(_target):
		_boss_attack = "wave"
		_state_timer = 0.36
		global_position = _target.global_position + Vector2(-_facing * 230.0, -18.0)
		_spawn_witch_volley()
	elif _boss_summon_cooldown <= 0.0 and _summoned_enemies.size() < BOSS_MAX_SUMMONS \
		and phase_ratio <= 0.65 and _has_living_part(&"core"):
		_boss_attack = "summon"
		_state_timer = 0.72
		_attack_visual.visible = false
		_boss_summon_cooldown = 6.0
		_summon_boss_minion()
	elif _boss_special_index % 4 == 0:
		_boss_attack = "witch_curse"
		_state_timer = 0.62
		_attack_visual.visible = false
		_spawn_witch_curse()
		if phase_ratio <= 0.30:
			_heal_parts(5)
	else:
		_boss_attack = "wave"
		_state_timer = 0.48
		_attack_visual.visible = false
		_spawn_witch_volley()


func _summon_boss_dogs() -> void:
	_summon_boss_minion()


func _summon_boss_minion() -> void:
	_cleanup_boss_summons()
	if _summoned_enemies.size() >= BOSS_MAX_SUMMONS:
		return
	var pool: Array = BOSS_SUMMON_POOL
	if archetype == "skeleton_general":
		pool = SKELETON_GENERAL_SUMMON_POOL
	elif archetype == "crimson_witch":
		pool = CRIMSON_WITCH_SUMMON_POOL
	var side := -1.0 if _summoned_enemies.size() % 2 == 0 else 1.0
	_spawn_summoned_enemy(pool, side * 128.0, 0.78)


func _cleanup_boss_summons() -> void:
	var living_summons: Array = []
	for enemy in _summoned_enemies:
		if is_instance_valid(enemy):
			living_summons.append(enemy)
	_summoned_enemies.clear()
	for enemy in living_summons:
		_summoned_enemies.append(enemy)


func _spawn_boss_slam() -> void:
	var hazard := ENEMY_HAZARD_SCRIPT.new()
	hazard.damage = maxi(1, roundi(float(_profile.get("damage", 6)) * 1.15))
	hazard.lifetime = 0.48
	hazard.tick_interval = 0.48
	hazard.radius = 128.0
	hazard.global_position = global_position + Vector2(0, 30)
	get_tree().current_scene.add_child(hazard)


func _spawn_boss_wave() -> void:
	if _boss_wave_done:
		return
	_boss_wave_done = true
	SFX.play_at("charged_wave", global_position, 0.025)
	var projectile := ENEMY_PROJECTILE_SCRIPT.new()
	projectile.global_position = global_position + Vector2(_facing * 72.0, -14.0)
	projectile.direction = Vector2(_facing, 0)
	projectile.speed = 560.0
	projectile.damage = maxi(1, roundi(float(_profile.get("damage", 6))))
	projectile.radius = 22.0
	projectile.visual_length = 96.0
	projectile.visual_color = Color(0.95, 0.18, 1.0, 0.88)
	projectile.shape_style = "laser"
	projectile.source_position = global_position
	get_tree().current_scene.add_child(projectile)


func _spawn_witch_volley() -> void:
	if not is_instance_valid(_target):
		return
	for angle_offset in [-0.16, 0.0, 0.16]:
		var projectile := ENEMY_PROJECTILE_SCRIPT.new()
		projectile.global_position = global_position + Vector2(_facing * 48.0, -34.0)
		var direction := (_target.global_position - projectile.global_position).normalized()
		projectile.direction = direction.rotated(angle_offset)
		projectile.speed = 470.0
		projectile.damage = maxi(1, roundi(float(_profile.get("damage", 8)) * 0.72))
		projectile.radius = 17.0
		projectile.visual_length = 54.0
		projectile.visual_color = Color(0.96, 0.08, 0.35, 0.9)
		projectile.shape_style = "blood_orb"
		projectile.source_position = global_position
		get_tree().current_scene.add_child(projectile)


func _spawn_witch_curse() -> void:
	if not is_instance_valid(_target):
		return
	var hazard := ENEMY_HAZARD_SCRIPT.new()
	hazard.damage = maxi(1, roundi(float(_profile.get("damage", 8)) * 0.8))
	hazard.lifetime = 1.8
	hazard.tick_interval = 0.6
	hazard.radius = 92.0
	hazard.startup_delay = 0.45
	hazard.visual_color = Color(0.82, 0.04, 0.22, 0.5)
	hazard.weakness_duration = 4.0 if _has_living_part(&"right_arm") else 0.0
	hazard.global_position = _target.global_position + Vector2(0, 24)
	get_tree().current_scene.add_child(hazard)


func _update_boss_timers(delta: float) -> void:
	_boss_summon_cooldown = maxf(0.0, _boss_summon_cooldown - delta)
	if archetype != "abyss_hound_king":
		return
	_boss_regen_timer -= delta
	if _boss_regen_timer > 0.0:
		return
	_boss_regen_timer = 4.0
	for id in [&"head", &"body"]:
		var part: BodyPart = _parts.get(id)
		if is_instance_valid(part):
			part.heal_one()
			part.heal_one()
	_update_health_label()


func _boss_living_limbs() -> int:
	var living := 0
	for id in [&"left_front_paw", &"right_front_paw", &"left_hind_leg", &"right_hind_leg"]:
		var part: BodyPart = _parts.get(id)
		if is_instance_valid(part) and part.health > 0:
			living += 1
	return living
