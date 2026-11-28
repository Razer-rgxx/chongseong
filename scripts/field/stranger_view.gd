class_name StrangerView
extends Node3D
## 총 든 낯선 사람의 몸(docs/stranger.md). 긴 어두운 외투, 후드, 이 시대에 없는 긴 총 모양(도형만). 싸울 수 없고 부딪힘도 없다.
## 모드: stand → turn(등을 돌린다) / aim(영주를 겨눈다) → fade(지지직거리며 흩어진다) → gone 신호.
## 꾸밈용 난수(번쩍임 흔들림)는 화면 쪽이라 전역 randf를 쓴다.

signal gone

var _mode: StringName = &"stand"
var _t: float = 0.0
var _yaw: float = 0.0
var _yaw_to: float = 0.0
var _raise: float = 0.0
var _body: Node3D
var _gun: Node3D
var _flash_t: float = 0.0
var _flash: OmniLight3D
var _flash_ball: MeshInstance3D
var _fade_len: float = 1.2

const BLUE := Color(0.35, 0.72, 1.0)


static func make(parent: Node3D, at: Vector3, face_to: Vector3) -> StrangerView:
	var v := StrangerView.new()
	parent.add_child(v)
	v.position = at
	v._build()
	v._yaw = v._yaw_for(face_to)
	v._yaw_to = v._yaw
	v.rotation.y = v._yaw
	return v


func _yaw_for(target: Vector3) -> float:
	var d: Vector3 = target - position
	return atan2(-d.x, -d.z)


func _mat(c: Color, rough: float = 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _glow(c: Color, e: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = e
	return m


func _box(parent: Node3D, size: Vector3, at: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = at
	parent.add_child(mi)
	return mi


func _build() -> void:
	_body = Node3D.new()
	add_child(_body)
	var coat := _mat(Color(0.05, 0.055, 0.07))
	var cloth := _mat(Color(0.08, 0.085, 0.1))
	# 외투: 아래로 갈수록 넓은 긴 자락(원뿔 통), 어깨, 후드
	var skirt := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.2
	cm.bottom_radius = 0.34
	cm.height = 1.35
	cm.radial_segments = 10
	skirt.mesh = cm
	skirt.material_override = coat
	skirt.position = Vector3(0, 0.68, 0)
	_body.add_child(skirt)
	_box(_body, Vector3(0.56, 0.18, 0.3), Vector3(0, 1.38, 0), cloth)
	var hood := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.19
	hm.height = 0.42
	hood.mesh = hm
	hood.material_override = cloth
	hood.position = Vector3(0, 1.66, 0.02)
	_body.add_child(hood)
	var face := _box(_body, Vector3(0.16, 0.14, 0.04), Vector3(0, 1.64, -0.17), _mat(Color(0.01, 0.01, 0.02)))
	face.name = "Face"
	_box(_body, Vector3(0.1, 0.012, 0.045), Vector3(0, 1.655, -0.19), _glow(BLUE, 1.2))   # 후드 속에서 가늘게 비치는 푸른 빛(눈 자리)
	# 총: 오른 어깨에 축이 있는 긴 총 모양. 앞은 -Z
	_gun = Node3D.new()
	_gun.position = Vector3(0.24, 1.3, -0.08)
	_body.add_child(_gun)
	var steel := _mat(Color(0.03, 0.03, 0.04), 0.35)
	steel.metallic = 0.8
	_box(_gun, Vector3(0.07, 0.09, 0.9), Vector3(0, 0, -0.5), steel)      # 몸통
	_box(_gun, Vector3(0.035, 0.035, 0.55), Vector3(0, 0.01, -1.2), steel) # 가는 총열
	_box(_gun, Vector3(0.06, 0.1, 0.28), Vector3(0, -0.03, 0.15), steel)  # 개머리
	_box(_gun, Vector3(0.05, 0.13, 0.07), Vector3(0, -0.11, -0.45), steel) # 손잡이
	_box(_gun, Vector3(0.05, 0.05, 0.25), Vector3(0, 0.085, -0.5), steel)  # 위에 얹은 조준경
	_box(_gun, Vector3(0.052, 0.012, 0.2), Vector3(0, 0.085, -0.5), _glow(BLUE, 2.0))   # 조준경의 푸른 줄
	# 총구 번쩍임(평소엔 숨김)
	_flash_ball = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.14
	sm.height = 0.28
	_flash_ball.mesh = sm
	_flash_ball.material_override = _glow(Color(1.0, 0.92, 0.7), 8.0)
	_flash_ball.position = Vector3(0, 0.01, -1.55)
	_flash_ball.visible = false
	_gun.add_child(_flash_ball)
	_flash = OmniLight3D.new()
	_flash.light_color = Color(1.0, 0.85, 0.6)
	_flash.omni_range = 10.0
	_flash.light_energy = 0.0
	_flash.position = Vector3(0, 0.01, -1.6)
	_gun.add_child(_flash)
	_apply_gun()


func _apply_gun() -> void:
	# 내려 든 총은 몸 앞에 비스듬히, 겨누면 앞으로 곧게
	_gun.rotation = Vector3(lerpf(-1.05, 0.04, _raise), lerpf(0.25, 0.0, _raise), 0.0)


## 총구 위치(세계 좌표).
func muzzle_point() -> Vector3:
	return _gun.to_global(Vector3(0, 0.01, -1.55))


func turn_away(from: Vector3) -> void:
	_mode = &"turn"
	_t = 0.0
	var d: Vector3 = position - from
	_yaw_to = atan2(-d.x, -d.z)   # 영주 반대쪽을 본다


func aim_at(target: Vector3) -> void:
	_mode = &"aim"
	_t = 0.0
	_yaw_to = _yaw_for(target)


func shoot() -> void:
	_flash_t = 0.09


func fade(seconds: float = 1.2) -> void:
	_mode = &"fade"
	_t = 0.0
	_fade_len = seconds


func update(delta: float) -> void:
	_t += delta
	_yaw = lerp_angle(_yaw, _yaw_to, 1.0 - exp(-5.0 * delta))
	rotation.y = _yaw
	var up: float = 1.0 if _mode == &"aim" else (_raise if _mode == &"fade" else 0.0)
	_raise = move_toward(_raise, up, delta * 2.5)
	_apply_gun()
	_flash_t = maxf(_flash_t - delta, 0.0)
	_flash_ball.visible = _flash_t > 0.0
	_flash.light_energy = 6.0 if _flash_t > 0.0 else 0.0
	if _mode == &"fade":
		# 흩어지는 잡음: 깜빡임이 잦아지고, 가로로 어긋나며 얇아졌다가 사라진다
		var k: float = clampf(_t / _fade_len, 0.0, 1.0)
		visible = randf() > k * 0.85
		_body.scale = Vector3(1.0 + (randf() - 0.5) * 0.14 * k, 1.0 + (randf() - 0.5) * 0.04 * k, 1.0)
		_body.position.x = (randf() - 0.5) * 0.18 * k
		if k >= 1.0:
			visible = false
			gone.emit()
			set_process(false)
			_mode = &"done"


## 떨어뜨린 낯선 물건(차가운 푸른빛이 은은한 납작한 상자)을 만든다. 호출한 쪽이 지운다.
static func make_drop(parent: Node3D, at: Vector3) -> Node3D:
	var n := Node3D.new()
	parent.add_child(n)
	n.position = at
	var shell := StandardMaterial3D.new()
	shell.albedo_color = Color(0.06, 0.07, 0.09)
	shell.metallic = 0.8
	shell.roughness = 0.3
	var glow := StandardMaterial3D.new()
	glow.albedo_color = StrangerView.BLUE
	glow.emission_enabled = true
	glow.emission = StrangerView.BLUE
	glow.emission_energy_multiplier = 2.5
	var a := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.7, 0.07, 0.16)
	a.mesh = bm
	a.material_override = shell
	a.position = Vector3(0, 0.12, 0)
	a.rotation.y = 0.5
	n.add_child(a)
	var b := MeshInstance3D.new()
	var bm2 := BoxMesh.new()
	bm2.size = Vector3(0.62, 0.075, 0.02)
	b.mesh = bm2
	b.material_override = glow
	b.position = Vector3(0, 0.12, 0)
	b.rotation.y = 0.5
	n.add_child(b)
	var l := OmniLight3D.new()
	l.light_color = StrangerView.BLUE
	l.omni_range = 4.0
	l.light_energy = 0.9
	l.position = Vector3(0, 0.5, 0)
	n.add_child(l)
	return n
