class_name SwordGlitch
extends RefCounted
## 쥔 칼이 사이버 카타나로 깨지며 바뀌는 연출(docs/stranger.md). 쥔 SwordModel 곁에 색이 갈라진 사본(빨강·청록), 어긋난 네모 조각,
## 옛 칼과 카타나가 번갈아 보이는 깜빡임을 얹는다. 화면 꾸밈이라 전역 randf를 쓴다(규칙과 무관).

var length: float = 1.5
var t: float = 0.0
var _old: SwordModel
var _new: SwordModel
var _parts: Array[Node3D] = []
var _bars: Array[MeshInstance3D] = []
var _holder: Node3D
var _t_jit: float = 0.0


## old는 지금 쥔 칼 모델(없으면 null). 같은 부모(손)에 사본들을 단다.
static func start(old: SwordModel, katana_form: FormData, grades: GradeTable) -> SwordGlitch:
	var g := SwordGlitch.new()
	g.length = randf_range(1.2, 1.8)
	g._old = old
	g._new = SwordModel.make(katana_form, 4, SwordModel.KATANA_SEED, grades.colors[4])
	if old == null:
		return g
	g._holder = old.get_parent() as Node3D
	g._new.position = old.position
	g._new.visible = false
	g._holder.add_child(g._new)
	for c in [Color(1.0, 0.1, 0.2), Color(0.1, 1.0, 0.9)]:
		var cp := SwordModel.make(katana_form, 4, SwordModel.KATANA_SEED, c)
		cp.position = old.position
		_unlit(cp, c)
		g._holder.add_child(cp)
		g._parts.append(cp)
	var bm := BoxMesh.new()
	bm.size = Vector3(0.09, 0.06, 0.03)
	for i in 5:
		var mi := MeshInstance3D.new()
		mi.mesh = bm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(0.3, 0.8, 1.0) if i % 2 == 0 else Color(1.0, 0.2, 0.5)
		mi.material_override = m
		g._holder.add_child(mi)
		g._bars.append(mi)
	return g


static func _unlit(n: Node, c: Color) -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	for ch in n.get_children():
		if ch is MeshInstance3D:
			(ch as MeshInstance3D).material_override = m
		_unlit(ch, c)


func done() -> bool:
	return t >= length


func update(delta: float) -> void:
	t += delta
	var k: float = clampf(t / length, 0.0, 1.0)
	_t_jit += delta
	if _old == null or _t_jit < 0.04:
		return
	_t_jit = 0.0
	var showing_new: bool = randf() < k * 0.85
	_old.visible = not showing_new or randf() < 0.3
	_new.visible = showing_new
	var spread: float = 0.012 + 0.05 * sin(k * PI)
	for i in _parts.size():
		var p: Node3D = _parts[i]
		p.visible = randf() < 0.75
		p.position = _old.position + Vector3((i * 2 - 1) * randf_range(0.2, 1.0) * spread, randf_range(-0.03, 0.03), 0.0)
	var L: float = _old.blade_length
	for b in _bars:
		b.visible = randf() < 0.7
		b.position = _old.position + Vector3(randf_range(-0.12, 0.12), randf_range(0.0, L), randf_range(-0.03, 0.03))
		b.scale = Vector3(randf_range(0.6, 2.2), randf_range(0.5, 1.6), 1.0)
	_old.position.x = randf_range(-0.01, 0.01) * (1.0 + 4.0 * k)


## 끝: 사본과 옛 칼을 치운다(진짜 칼은 LordView.set_sword가 새로 쥔다).
func finish() -> void:
	for n in _parts + _bars + [_new]:
		if n and is_instance_valid(n):
			n.queue_free()
	_parts.clear()
	_bars.clear()
	if _old and is_instance_valid(_old):
		_old.visible = true
