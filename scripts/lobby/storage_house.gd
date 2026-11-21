class_name StorageHouse
extends Plot
## 검 보관집(2026-11-21): 마을 북동쪽 터. 짓기 전에는 빈 터(Plot), 지으면 2층 반목조 집이 한 조각씩 올라간다.
## 문 옆 검집 걸이에 산 검집이 단계마다 하나씩 걸린다. 세계에 글자는 없다.

## 집 너비 × 깊이(m). 앞(+Z)이 남쪽 광장을 본다.
const SIZE: Vector2 = Vector2(5.0, 4.0)
## 검집 걸이: 집 앞에서의 자리(집 기준 m)와 못 수(검집 단계 수).
const RACK_AT: Vector3 = Vector3(1.55, 0.0, 2.75)
const PEGS: int = 2

var _sheaths: Array[Node3D] = []
var _level: int = 0


func _init() -> void:
	size = SIZE


## 터나 집을 만들고 걸이에 산 검집을 건다.
func build_with(built: bool, level: int) -> void:
	build(built)
	set_level(level)


## 걸이의 검집 수(산 단계). 집이 없으면 아무것도 안 건다.
func set_level(level: int) -> void:
	_level = level
	for i in _sheaths.size():
		_sheaths[i].visible = i < level


func _make_body(root: Node3D) -> Vector3:
	var top: Vector3 = VillageBuilder.house(root, Vector3.ZERO, 0.0, SIZE, true, _rng)
	VillageBuilder.box(root, Vector3(1.6, 0.16, 0.7), Vector3(-SIZE.x * 0.18, 0.08, SIZE.y / 2.0 + 0.35), VillageBuilder.stone())   # 문 앞 돌계단
	_make_rack(root)
	set_level(_level)
	return top


func _site_extra(site: Node3D) -> void:
	_logs_and_stones(site, Vector3(-1.3, 0.0, -0.4))
	var stone := VillageBuilder.stone()
	for i in 4:
		VillageBuilder.box(site, Vector3(0.5, 0.25, 0.35), Vector3(-SIZE.x / 2.0 + 0.5 + i * 1.3, 0.12, -SIZE.y / 2.0 + 0.25), stone, Vector3(0, _rng.randf_range(-0.2, 0.2), 0))


## 검집 걸이: 두 기둥과 가로대, 못마다 검집(가죽 집, 쇠 끝, 손잡이). 산 단계만 보인다.
func _make_rack(root: Node3D) -> void:
	var rack := Node3D.new()
	rack.position = RACK_AT
	root.add_child(rack)
	var wood := VillageBuilder.timber()
	var w: float = 1.3
	for sx in [-1.0, 1.0]:
		VillageBuilder.box(rack, Vector3(0.12, 1.75, 0.12), Vector3(sx * w / 2.0, 0.875, 0.0), wood)
	VillageBuilder.box(rack, Vector3(w + 0.2, 0.12, 0.14), Vector3(0.0, 1.62, 0.0), wood)
	VillageBuilder.box(rack, Vector3(w, 0.08, 0.1), Vector3(0.0, 0.35, 0.0), wood)
	var leather := VillageBuilder.plain(Color(0.17, 0.09, 0.05), 0.7)
	var iron := VillageBuilder.plain(Color(0.42, 0.4, 0.37), 0.45, 0.8)
	var grip := VillageBuilder.plain(Color(0.08, 0.06, 0.05), 0.8)
	_sheaths = []
	for i in PEGS:
		var x: float = lerpf(-w / 2.0 + 0.35, w / 2.0 - 0.35, float(i) / float(maxi(1, PEGS - 1)))
		VillageBuilder.box(rack, Vector3(0.04, 0.04, 0.14), Vector3(x, 1.52, 0.1), iron)   # 못
		var s := Node3D.new()
		s.position = Vector3(x, 0.0, 0.12)
		s.rotation.z = (0.06 if i % 2 == 0 else -0.05)
		rack.add_child(s)
		VillageBuilder.box(s, Vector3(0.1, 0.98, 0.055), Vector3(0.0, 0.98, 0.0), leather)    # 집
		VillageBuilder.box(s, Vector3(0.115, 0.09, 0.065), Vector3(0.0, 0.52, 0.0), iron)     # 끝 쇠
		VillageBuilder.box(s, Vector3(0.12, 0.07, 0.07), Vector3(0.0, 1.44, 0.0), iron)       # 아가리 쇠
		VillageBuilder.box(s, Vector3(0.05, 0.03, 0.12), Vector3(0.0, 1.2, 0.04), leather)    # 띠
		VillageBuilder.box(s, Vector3(0.3, 0.045, 0.06), Vector3(0.0, 1.5, 0.0), iron)        # 코등이
		VillageBuilder.cyl(s, 0.022, 0.024, 0.2, Vector3(0.0, 1.62, 0.0), grip, 8)          # 손잡이
		VillageBuilder.ball(s, 0.038, Vector3(0.0, 1.74, 0.0), iron)                         # 머리
		_sheaths.append(s)
