class_name GhostView
extends Node3D
## 검 주인의 잔영(docs/sword_hill.md 2번, 규칙은 Ghost). 재 빛으로 반쯤 비치는 영주가 주인의 검을 쥐고 기록대로 움직인다.
## 기사 모델(LordCharacter)이 있으면 그것을 재 빛으로 칠해 쓰고, 없으면 기둥과 머리 모양. 몸에서 재가 떨어져 날린다.
## 나타날 때 서서히 짙어지고, 기록이 끝나 갈수록 흐려진다. 사라지면(gone) 흩어지며 지운다.

## 몸이 비치는 정도(0 불투명 … 1 투명).
@export var see_through: float = 0.5
## 나타나는 시간(초).
@export var fade_in: float = 0.35

var ghost: Ghost
var rules: Rules
var _body: Node3D
var _char: LordCharacter = null
var _ash: CPUParticles3D
var _meshes: Array[GeometryInstance3D] = []
var _t: float = 0.0
var _leaving: float = -1.0
var _swing: float = 0.0
var _arm: Node3D = null


func setup(r: Rules, g: Ghost) -> void:
	rules = r
	ghost = g


func _ready() -> void:
	_body = Node3D.new()
	add_child(_body)
	var sd: SwordData = rules.data.sword_by_id(ghost.sword_id)
	var sword: Sword = Sword.new(sd, rules.data) if sd else null
	if LordCharacter.available():
		_char = LordCharacter.new()
		_body.add_child(_char)
		_char.recolor(Color(0.42, 0.42, 0.44), Color(0.5, 0.46, 0.4), 0.25)
		if sword:
			_char.set_sword(sword, rules.data.grades)
		_char.play("idle")
	else:
		_simple_body(sword)
	for n in _body.find_children("*", "GeometryInstance3D", true, false):
		var gi := n as GeometryInstance3D
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_meshes.append(gi)
	_ash = _make_ash()
	add_child(_ash)
	_set_fade(1.0)


## 모델이 없을 때: 재 빛 기둥 몸과 머리, 오른손에 주인의 검.
func _simple_body(sword: Sword) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.2, 0.19, 0.18)
	m.roughness = 1.0
	m.rim_enabled = true
	m.rim = 0.6
	m.rim_tint = 0.3
	var torso := CapsuleMesh.new()
	torso.radius = 0.24
	torso.height = 1.3
	var t := MeshInstance3D.new()
	t.mesh = torso
	t.material_override = m
	t.position.y = 0.9
	_body.add_child(t)
	var head := SphereMesh.new()
	head.radius = 0.15
	head.height = 0.3
	var h := MeshInstance3D.new()
	h.mesh = head
	h.material_override = m
	h.position.y = 1.72
	_body.add_child(h)
	_arm = Node3D.new()
	_arm.position = Vector3(0.28, 1.2, 0)
	_body.add_child(_arm)
	if sword:
		var sm := SwordModel.for_sword(sword, rules.data.grades)
		sm.rotation.x = -PI * 0.5
		sm.position = Vector3(0, -0.1, -0.1)
		_arm.add_child(sm)


func _make_ash() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 28
	p.lifetime = 1.6
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.25, 0.8, 0.25)
	p.position.y = 0.9
	p.direction = Vector3(0.2, 1.0, 0.0)
	p.spread = 30.0
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.4
	p.gravity = Vector3(0.15, 0.25, 0.0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.4
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	fade.colors = PackedColorArray([Color(0.45, 0.43, 0.4, 0.0), Color(0.45, 0.43, 0.4, 0.5), Color(0.3, 0.29, 0.27, 0.0)])
	p.color_ramp = fade
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = HitFx._soft_dot()
	q.material = m
	p.mesh = q
	return p


## 규칙의 한 칼(Rules.ghost_swung).
func swing(big: bool) -> void:
	if _char:
		_char.play("big" if big else "slash", 1.2)
	_swing = 0.25


## 규칙에서 사라졌다: 흩어지며 지운다.
func leave() -> void:
	if _leaving < 0.0:
		_leaving = 0.0
		_ash.amount = 40
		_ash.initial_velocity_max = 1.2


func draw(alpha: float, delta: float) -> void:
	_t += delta
	if _leaving >= 0.0:
		_leaving += delta
		_set_fade(1.0 - clampf(_leaving / 0.6, 0.0, 1.0))
		if _leaving > 1.8:
			queue_free()
		return
	var p: Vector2 = ghost.prev_pos.lerp(ghost.pos, alpha)
	var w: Vector3 = Grid.cells_to_world(p)
	w.y = HillBuilder.height(w.x, w.z)
	var moved: float = Grid.cells_to_meters(ghost.pos.distance_to(ghost.prev_pos)) / maxf(0.001, rules.dt)
	position = w
	rotation.y = lerp_angle(rotation.y, atan2(-cos(ghost.face), -sin(ghost.face)), 1.0 - exp(-14.0 * delta))
	if _char and _swing <= 0.0:
		var want: String = "run" if moved > 3.0 else ("walk" if moved > 0.4 else "idle")
		_char.play(want)
	_swing -= delta
	if _arm:
		_arm.rotation.x = -sin(clampf(_swing / 0.25, 0.0, 1.0) * PI) * 1.6
	# 나타나며 짙어지고, 끝으로 갈수록 흐려진다
	var k: float = clampf(_t / fade_in, 0.0, 1.0) * (1.0 - smoothstep(0.8, 1.0, ghost.progress()))
	_set_fade(k)


func _set_fade(k: float) -> void:
	var tr: float = lerpf(1.0, see_through, clampf(k, 0.0, 1.0))
	for gi in _meshes:
		if is_instance_valid(gi):
			gi.transparency = tr
	_ash.emitting = k > 0.05 or _leaving >= 0.0 and _leaving < 0.6
