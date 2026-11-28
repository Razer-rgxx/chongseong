class_name MoveFx
extends Node3D
## 좌클릭 동작 20가지와 속성 4가지의 효과(이펙트팀, docs/attacks.md 4절). 판정이 닿는 자리를 짧고 또렷하게 그려서
## 동작마다 어디가 맞는지 배우게 한다: 부채꼴은 공중의 베기 빛(SlashFx), 띠는 땅의 띠 자국과 칼 높이의 줄기,
## 원은 테가 빛나는 원판, 고리는 퍼지는 고리. 늦게 터지는 판정(내려찍기, 발도)은 그동안 옅은 미리 보기를 그린다.
## main이 쓰는 법:
##   var fx := MoveFx.new(); add_child(fx); fx.setup(rules)   # Rules에 있는 신호만 잇는다(아직 없어도 죽지 않는다)
##   _process에서 fx.draw(alpha)                                # 날아가는 것과 영주를 따라가는 것을 틱 사이로 이어 그린다
##   쥔 칼이 바뀌면 fx.tint = 칼 색                               # 속성이 없을 때의 빛 색(기본은 쇠의 흰빛)
## 갤러리(scripts/debug/move_gallery.gd)는 on_* 함수를 가짜 info로 바로 부른다.
## 모양과 재질은 MoveArt(아트팀), 흙먼지·흙덩이·불똥은 PullFx의 것을 쓴다. 꾸밈용 랜덤은 이 노드의 것(규칙 rng와 따로).
## 이 노드는 top_level이고 원점에 있어서 자식의 위치가 곧 세계 좌표다.

const SIGNALS: Array[StringName] = [&"move_started", &"move_area", &"projectile_spawned", &"projectile_ended", &"lord_landed"]
## 동시에 살아 있는 알갱이 노드의 최대 수(소용돌이·연속 찌르기가 자주 터진다). 넘치면 알갱이만 거른다.
const MAX_PARTICLES: int = 24
## 동시에 살아 있는 효과 묶음의 최대 수. 넘치면 오래된 것부터 지운다.
const MAX_FX: int = 48
## info에 열쇠가 없을 때 쓰는 칼 길이와 칼 폭(칸, 라디안). 장검.
const BASE_REACH: float = 1.55
const BASE_ARC: float = 1.9
## 같은 동작의 판정이 이 시간(초) 안에 또 오면 한 번만 그린다(move_started와 첫 move_area가 겹칠 때).
const SAME_HIT: float = 0.03
## 메아리: 이만큼 어둡게, 이만큼 크게.
const ECHO_DIM: float = 0.55
const ECHO_GROW: float = 1.12
## 날아가는 것이 끝 신호 없이 이만큼(초) 지나면 스스로 지운다.
const SHOT_MAX_AGE: float = 5.0
## 칼 던지기의 도는 빠르기(라디안/초).
const SPIN_SPEED: float = 26.0

@export var blade_height: float = 1.0
@export var waist_height: float = 0.95
@export var projectile_height: float = 0.9
## 땅 자국이 다 드러난 뒤 머무는 시간과 식는 시간(초). 큰 것은 더 길다.
@export var mark_hold: float = 0.1
@export var mark_fade: float = 0.4

var rules: Rules = null
## 땅 높이(m)를 돌려주는 함수(x, z). 들판은 FieldBuilder.walk_height를 넣는다(EnemyFx.height_of와 같다). 없으면 HillBuilder.height.
var height_of: Callable = Callable()
## 속성이 없을 때의 빛 색. main이 쥔 칼에 맞춰 넣는다(LordView의 SlashFx 색과 같게).
var tint: Color = MoveArt.STEEL
## 입은 베기 빛 꾸미기를 따르나(결투는 영주가 둘이라 끈다).
var use_cosmetic: bool = true

var _built: bool = false
var _rng := RandomNumberGenerator.new()
var _clock: float = 0.0
var _alpha: float = 1.0
var _slash: SlashFx
var _pull_fx: PullFx
var _layer: Node3D
var _shot_layer: Node3D
var _parts: Node3D
## 날아가는 것: 인스턴스 id → {p, root, age, start, kind, returning, spin, ring, trail, mat, emit}
var _shots: Dictionary = {}
## 영주를 따라가는 효과(소용돌이).
var _follow: Array[Node3D] = []
## 미리 보기(내려찍기, 발도, 도약, 반격 자세): 동작 → 효과 묶음.
var _tele: Dictionary = {}
## 동작 → 마지막으로 그린 때(_clock).
var _last_hit: Dictionary = {}
## 신호가 안 오면 대신 그리는 것(갈고리 베기의 도착): 동작 → {node, fired}.
var _pending: Dictionary = {}
var _soft_add: StandardMaterial3D
var _soft_mix: StandardMaterial3D
var _bolt_mat: StandardMaterial3D
var _shard_mesh: BoxMesh
var _unit_box := BoxMesh.new()
## 고리·띠 메시는 모양이 같으면 같이 쓴다(소용돌이·연속 찌르기가 자주 만든다). 재질은 늘 새로.
var _meshes: Dictionary = {}


func _ready() -> void:
	_build()


func _build() -> void:
	if _built:
		return
	_built = true
	top_level = true
	transform = Transform3D.IDENTITY
	_rng.randomize()
	_slash = SlashFx.new()
	add_child(_slash)
	_pull_fx = PullFx.new()
	add_child(_pull_fx)
	_layer = Node3D.new()
	add_child(_layer)
	_shot_layer = Node3D.new()
	add_child(_shot_layer)
	_parts = Node3D.new()
	add_child(_parts)
	_soft_add = _soft(true)
	_soft_mix = _soft(false)
	_bolt_mat = StandardMaterial3D.new()
	_bolt_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bolt_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_bolt_mat.albedo_color = MoveArt.BOLT.lerp(Color.WHITE, 0.35)
	_bolt_mat.disable_receive_shadows = true
	_unit_box.size = Vector3.ONE
	var shard_mat := StandardMaterial3D.new()
	shard_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shard_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	shard_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shard_mat.vertex_color_use_as_albedo = true
	_shard_mesh = BoxMesh.new()
	_shard_mesh.size = Vector3(0.05, 0.28, 0.05)
	_shard_mesh.material = shard_mat


## Rules의 신호 중 있는 것만 잇는다. 이름으로 이어서 신호가 아직 없어도 이 스크립트는 읽힌다.
func setup(r: Rules) -> void:
	_build()
	rules = r
	if r == null:
		return
	var handlers: Dictionary = {
		&"move_started": Callable(self, "on_move_started"),
		&"move_area": Callable(self, "on_move_area"),
		&"projectile_spawned": Callable(self, "on_projectile_spawned"),
		&"projectile_ended": Callable(self, "on_projectile_ended"),
		&"lord_landed": Callable(self, "on_landed"),
	}
	for s in SIGNALS:
		var c: Callable = handlers[s]
		if r.has_signal(s) and not r.is_connected(s, c):
			r.connect(s, c)


## 걸어 다니는 점프(30단계)에서 내려앉았다: 발밑에 작은 흙먼지(PullFx의 것).
func on_landed(at: Vector2) -> void:
	_build()
	_pull_fx._dust(_ground(at, 0.0), 7, 1.0, 0.26)


## 남은 효과를 모두 지운다(판이 끝날 때, 갤러리에서 다음 동작 전).
func clear() -> void:
	for layer: Node3D in [_layer, _shot_layer, _parts]:
		for c in layer.get_children():
			c.queue_free()
	_shots.clear()
	_follow.clear()
	_tele.clear()
	_pending.clear()
	_last_hit.clear()


# ---------------------------------------------------------------- 신호

## 동작 하나가 시작됐다. 바로 맞는 동작은 판정 자리를, 늦게 맞는 동작은 미리 보기를 그린다.
func on_move_started(move: StringName, info: Dictionary) -> void:
	_build()
	var i: Dictionary = _norm(move, info, false)
	match move:
		&"smash", &"iaido":
			_telegraph(move, i, float(info.get("delay", MoveMotion.DELAY.get(move, 0.15))))
		&"leap":
			if i.has("from"):
				_pull_fx._dust(_ground(i["from"], 0.0), roundi(12 * float(i["k"])), 1.4, 0.35)
			_telegraph(move, i, float(i["time"]))
		&"wave", &"boomerang":
			pass   # 날아가는 것이 그린다(projectile_spawned)
		&"parry", &"draw":
			_stance(i)
		&"lunge":
			_lunge(i)
		&"retreat":
			_hit(move, i)
			_hop(i)
		&"blink":
			_blink(i)
			_hit(move, i)
		&"hook":
			_hook(i)
		&"whirl":
			_swirl(i)
			_hit(move, i)
		&"pull":
			_pull(i)
		_:
			_hit(move, i)


## 늦게 터지는 판정. 미리 보기를 거두고 판정 자리를 그린다.
func on_move_area(move: StringName, info: Dictionary) -> void:
	_build()
	var i: Dictionary = _norm(move, info, true)
	_end_tele(move)
	if _pending.has(move):
		var pd: Dictionary = _pending[move]
		_pending.erase(move)
		var fired: float = float(pd["fired"])
		if fired < 0.0:
			var n: Node = pd["node"]
			if is_instance_valid(n):
				n.queue_free()
		elif _clock - fired < 0.5:
			return   # 대신 그린 것이 이미 나갔다
	if move in [&"parry", &"draw"] and i["shape"] == &"circle":
		var h := _holder()
		var at: Vector2 = i["at"]
		_glint(h, _ground(at, 1.3), 1.5, MoveArt.STEEL, float(i["k"]), 0.3)
		_free_later(h, 0.4)
	_hit(move, i)


func on_projectile_spawned(p: Projectile) -> void:
	_build()
	var key: int = p.get_instance_id()
	if _shots.has(key):
		return
	var c: Color = _col(p.element)
	if p.kind == &"bullet":   # 사이버 검의 탄(docs/cyber_swords.md): 차가운 청록의 가는 빛
		c = Color(0.35, 0.85, 0.95)
	var root := Node3D.new()
	_shot_layer.add_child(root)
	var v: Dictionary = {
		"p": p, "root": root, "age": 0.0, "start": p.prev_pos, "kind": p.kind, "returning": p.returning,
		"spin": null, "ring": null, "trail": null, "mat": null, "emit": null,
	}
	if p.kind == &"boomerang":
		var tilt := Node3D.new()
		tilt.rotation.z = 0.22
		root.add_child(tilt)
		var spin := Node3D.new()
		spin.scale = Vector3.ONE * 1.3   # 멀리 날아가도 보이게 조금 크게
		tilt.add_child(spin)
		var sw := _thrown_sword(p)
		sw.rotation.x = -PI / 2.0
		sw.position.z = (sw.blade_length - sw.grip_length) * 0.5
		spin.add_child(sw)
		var r: float = (sw.blade_length + sw.grip_length) * 0.5 + 0.12
		var ring := MeshInstance3D.new()
		ring.mesh = _ring_mesh(r * 0.25, r + 0.1, 40)
		var rm := MoveArt.streak_material(c)
		rm.set_shader_parameter("fade", 1.0)
		ring.material_override = rm
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.rotation.y = PI / 2.0   # 줄기의 머리가 칼끝(-Z) 쪽
		ring.scale.z = -1.0 if p.returning else 1.0
		spin.add_child(ring)
		v["spin"] = spin
		v["ring"] = ring
	else:
		var w: float = Grid.cells_to_meters(p.width if p.width > 0.0 else 1.2)
		var m := MeshInstance3D.new()
		m.mesh = MoveArt.wave_mesh(w)
		var mat := MoveArt.wave_material(c)
		mat.set_shader_parameter("fade", 1.0)
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(m)
		var tr := MeshInstance3D.new()
		tr.mesh = _band_mesh(1.0, w * 0.7)
		var tm := MoveArt.streak_material(c)
		tm.set_shader_parameter("fade", 0.45)
		tr.material_override = tm
		tr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(tr)
		v["mat"] = mat
		v["trail"] = tr
	if p.element != &"":
		v["emit"] = _trail_emitter(p.element)
	_shots[key] = v
	_place(v, _alpha)


func on_projectile_ended(p: Projectile) -> void:
	_build()
	var c: Color = _col(p.element)
	var at: Vector3 = _ground(p.pos, projectile_height - 0.3)
	if _room():
		_pull_fx._sparks(at, 10, c)
	if p.element == &"bolt":
		var hb := _holder()
		_crackle(hb, {"c": _ground(p.pos, 0.3), "round": true, "inner": 0.0, "outer": 0.8, "along": 1.6, "across": 1.6, "rot": 0.0}, 0.8)
		_free_later(hb, 0.3)
	var key: int = p.get_instance_id()
	if not _shots.has(key):
		return
	var v: Dictionary = _shots[key]
	_shots.erase(key)
	var e: CPUParticles3D = v["emit"]
	if e != null and is_instance_valid(e):
		e.emitting = false
		var te := e.create_tween()
		te.tween_interval(e.lifetime + 0.1)
		te.tween_callback(e.queue_free)
	var root: Node3D = v["root"]
	if not is_instance_valid(root):
		return
	var tw := root.create_tween()
	if v["mat"] != null:
		var mat: ShaderMaterial = v["mat"]
		var tr: MeshInstance3D = v["trail"]
		tw.tween_property(mat, "shader_parameter/fade", 0.0, 0.08)
		tw.parallel().tween_property(tr.material_override, "shader_parameter/fade", 0.0, 0.08)
	tw.tween_callback(root.queue_free)


## main이 매 화면 부른다. alpha는 지난 틱과 이번 틱 사이(0~1).
func draw(alpha: float) -> void:
	_alpha = alpha
	for key in _shots.keys():
		_place(_shots[key], alpha)
	if _follow.is_empty() or rules == null:
		return
	var at: Vector3 = _ground(rules.lord.prev_pos.lerp(rules.lord.pos, alpha), 0.0)
	for i in range(_follow.size() - 1, -1, -1):
		if not is_instance_valid(_follow[i]):
			_follow.remove_at(i)
		else:
			_follow[i].position = at


func _process(delta: float) -> void:
	_clock += delta
	for key in _shots.keys():
		var v: Dictionary = _shots[key]
		v["age"] = float(v["age"]) + delta
		if v["spin"] != null:
			var s: Node3D = v["spin"]
			s.rotation.y += (SPIN_SPEED if bool(v["returning"]) else -SPIN_SPEED) * delta
		if float(v["age"]) > SHOT_MAX_AGE:
			on_projectile_ended(v["p"])


# ---------------------------------------------------------------- info

## info를 읽기 쉽게 채운다. 없는 열쇠는 설계서 1절의 첫 값(장검 기준)으로. area면 move_area에서 온 것.
## 더하는 열쇠: el(속성), color, k(밝기, 메아리면 어둡다), side(쓸어 가는 쪽, MoveMotion과 같다).
func _norm(move: StringName, info: Dictionary, area: bool) -> Dictionary:
	var i: Dictionary = info.duplicate()
	var L: LordState = rules.lord if rules != null else null
	var lord_pos: Vector2 = L.pos if L != null else Vector2.ZERO
	if not i.has("face"):
		i["face"] = L.face if L != null else -PI / 2.0
	var face: float = float(i["face"])
	var fwd := Vector2(cos(face), sin(face))
	var B: float = BASE_REACH
	var shape: StringName = &"arc"
	match move:
		&"thrust":
			shape = &"line"
			_def(i, "reach", B * 1.5)
			_def(i, "width", 0.5)
		&"flurry":
			shape = &"line"
			_def(i, "reach", B * 1.2)
			_def(i, "width", 0.4)
		&"iaido":
			shape = &"line"
			_def(i, "reach", B * 3.0)
			_def(i, "width", 0.6)
		&"cross":
			shape = &"plus"
			_def(i, "reach", B * 1.3)
			_def(i, "width", 0.6)
		&"lunge":
			shape = &"line"
			_def(i, "width", 1.6)
			_def(i, "reach", 3.5)
		&"smash":
			shape = &"circle"
			_def(i, "radius", 1.6)
			_def(i, "at", lord_pos + fwd * B * 0.8)
		&"spin":
			shape = &"circle"
			_def(i, "radius", float(i.get("reach", B)))
		&"whirl":
			shape = &"circle"
			_def(i, "radius", B * 0.9)
		&"leap":
			shape = &"circle"
			_def(i, "radius", 2.0)
		&"quake":
			shape = &"ring" if area else &"circle"
			_def(i, "radius", 3.5 if area else 1.5)
			_def(i, "thick", 1.0)
		&"parry", &"draw":
			shape = &"circle" if area else &"arc"
			_def(i, "radius", B * (1.6 if move == &"draw" else 1.2))
		&"crescent":
			_def(i, "reach", B * 0.9)
			_def(i, "arc", deg_to_rad(220.0))
		&"rising":
			_def(i, "arc", BASE_ARC * 0.8)
		&"pull":
			_def(i, "reach", B * 2.5)
			_def(i, "arc", deg_to_rad(60.0))
	_def(i, "shape", shape)
	if move in [&"leap", &"blink", &"hook"] and i.has("to"):
		if not area:
			i["at"] = i["to"]   # 시작할 때의 at은 영주 자리일 수 있다. 판정은 내리는·나타나는·닿는 자리
		_def(i, "at", i["to"])
	elif move in [&"retreat", &"lunge"] and i.has("from"):
		_def(i, "at", i["from"])
	_def(i, "at", lord_pos)
	_def(i, "reach", B)
	_def(i, "arc", BASE_ARC)
	_def(i, "width", 0.5)
	_def(i, "radius", B)
	_def(i, "thick", 1.0)
	_def(i, "big", false)
	_def(i, "time", float(MoveMotion.TIME.get(move, 0.2)))
	var echo: bool = bool(i.get("echo", false))
	i["k"] = ECHO_DIM if echo else 1.0
	if echo:
		for key in ["reach", "width", "radius", "thick"]:
			i[key] = float(i[key]) * ECHO_GROW
	var el: StringName = StringName(i.get("element", &""))
	i["el"] = el
	i["color"] = _col(el)
	var pm: StringName = &"parry_counter" if move in [&"parry", &"draw"] and i["shape"] == &"circle" else (&"parry" if move == &"draw" else move)
	var side: float = float(MoveMotion.plan(pm, info, null)["side"])
	i["side"] = side if side != 0.0 else 1.0
	return i


static func _def(i: Dictionary, key: String, v: Variant) -> void:
	if not i.has(key):
		i[key] = v


func _col(el: StringName) -> Color:
	if el != &"":
		return MoveArt.element_color(el)
	if use_cosmetic:   # 영주 꾸미기의 베기 빛(docs/cosmetics.md)이 속성 없는 판정 빛도 칠한다
		var c: Color = Cosmetics.slash_color(Meta.cos_look)
		if c.a > 0.0:
			return c
	return tint


# ---------------------------------------------------------------- 판정 자리

## 판정 모양 하나를 그린다(같은 동작이 SAME_HIT 안에 또 오면 거른다). 속성을 얹는다.
func _hit(move: StringName, i: Dictionary) -> void:
	if _last_hit.has(move) and _clock - float(_last_hit[move]) < SAME_HIT:
		return
	_last_hit[move] = _clock
	var h := _holder()
	match StringName(i["shape"]):
		&"line":
			_line(h, move, i)
		&"plus":
			_plus(h, i)
		&"circle":
			_circle(h, move, i)
		&"ring":
			_ring(h, i)
		_:
			_arc(h, move, i)
	_element(h, i)
	_free_later(h, 1.8)


## 부채꼴: 공중의 베기 빛(SlashFx). 큰 베기와 속성이 있으면 칼끝이 닿는 땅에 테를 긋는다.
func _arc(h: Node3D, move: StringName, i: Dictionary) -> void:
	var at: Vector2 = i["at"]
	var face: float = float(i["face"])
	var arc: float = clampf(float(i["arc"]), 0.05, TAU)
	var reach: float = Grid.cells_to_meters(float(i["reach"]))
	var side: float = float(i["side"])
	var big: bool = bool(i["big"])
	var k: float = float(i["k"])
	var c: Color = i["color"]
	var tilt: float = 0.0
	if move == &"rising":
		tilt = 0.55 * side
	elif not big:
		tilt = 0.3 * side
	_slash.color = Color(c.r * k, c.g * k, c.b * k)
	_slash.arc_fade = 0.3 if big else 0.2
	_slash.arc(_ground(at, _slash.arc_height), face, arc, reach, side, tilt, big)
	if big or i["el"] != &"":
		var m := _mark(h, _ring_mesh(maxf(0.0, reach - 0.3), reach + 0.04, 40), c, 0.75, _ground(at, 0.03))
		_orient_part(m, face, arc, side)
		var mat: ShaderMaterial = m.material_override
		_play_mark(h, mat, 0.08, 0.05, 0.35, k * (1.0 if big else 0.8), arc / TAU)


## 띠: 땅의 띠 자국이 빠르게 드러나고, 칼 높이에 밝은 줄기.
func _line(h: Node3D, move: StringName, i: Dictionary) -> void:
	var at: Vector2 = i["at"]
	var face: float = float(i["face"])
	var length: float = Grid.cells_to_meters(float(i["reach"]))
	var width: float = Grid.cells_to_meters(float(i["width"]))
	var k: float = float(i["k"])
	var c: Color = i["color"]
	var reveal: float = 0.05
	var hold: float = mark_hold
	var fade: float = mark_fade
	var sw: float = 0.32
	var off := Vector3.ZERO
	var fwd := Vector3(cos(face), 0.0, sin(face))
	match move:
		&"flurry":
			reveal = 0.03
			hold = 0.0
			fade = 0.22
			sw = 0.22
			off = Vector3(-fwd.z, 0.0, fwd.x) * _rng.randf_range(-0.12, 0.12)
		&"iaido":
			reveal = 0.035
			hold = 0.25
			fade = 0.6
			sw = 0.5
	var m := _mark(h, _band_mesh(length, width), c, 0.5, _ground(at, 0.03))
	m.rotation.y = -face - PI / 2.0
	_play_mark(h, m.material_override, reveal, hold, fade, k)
	var a: Vector3 = _ground(at, blade_height) + fwd * 0.3 + off
	_streak(h, a, a + fwd * (length - 0.3), sw, c, k, reveal, 0.2 if move != &"iaido" else 0.35)


## 십자: 앞 띠 + 그 가운데를 가로지르는 띠(길이 = reach × 1.6 / 1.3, info.cross가 있으면 그것). 앞 띠가 먼저, 가로 띠가 곧이어.
func _plus(h: Node3D, i: Dictionary) -> void:
	var at: Vector2 = i["at"]
	var face: float = float(i["face"])
	var reach: float = float(i["reach"])
	var length: float = Grid.cells_to_meters(reach)
	var cross: float = Grid.cells_to_meters(float(i.get("cross", reach * 1.6 / 1.3)))
	var width: float = Grid.cells_to_meters(float(i["width"]))
	var k: float = float(i["k"])
	var c: Color = i["color"]
	var fwd := Vector3(cos(face), 0.0, sin(face))
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	var m1 := _mark(h, _band_mesh(length, width), c, 0.5, _ground(at, 0.03))
	m1.rotation.y = -face - PI / 2.0
	_play_mark(h, m1.material_override, 0.05, mark_hold + 0.05, mark_fade, k)
	var mid: Vector3 = _ground(at, 0.0) + fwd * length * 0.5
	var m2 := _mark(h, _band_mesh(cross, width), c, 0.5, mid - right * cross * 0.5 + Vector3(0.0, 0.032, 0.0))
	m2.rotation.y = -(face + PI / 2.0) - PI / 2.0
	var mat2: ShaderMaterial = m2.material_override
	mat2.set_shader_parameter("progress", 0.0)
	var tw := h.create_tween()
	tw.tween_interval(0.06)
	tw.tween_callback(func() -> void: _play_mark(h, mat2, 0.05, mark_hold, mark_fade, k))
	var a: Vector3 = _ground(at, blade_height) + fwd * 0.3
	_streak(h, a, a + fwd * (length - 0.3), 0.32, c, k, 0.05, 0.22)
	var b: Vector3 = mid + Vector3(0.0, blade_height, 0.0) - right * cross * 0.5
	var tw2 := h.create_tween()
	tw2.tween_interval(0.06)
	tw2.tween_callback(func() -> void: _streak(h, b, b + right * cross, 0.32, c, k, 0.05, 0.22))


## 원: 테가 빛나는 원판. 회전·소용돌이·반격은 쓸어 가는 쪽으로 드러나고 허리 높이에 도는 줄기,
## 내려찍기·도약·지진은 갈라진 틈과 흙먼지.
func _circle(h: Node3D, move: StringName, i: Dictionary) -> void:
	var at: Vector2 = i["at"]
	var face: float = float(i["face"])
	var r: float = Grid.cells_to_meters(float(i["radius"]))
	var k: float = float(i["k"])
	var c: Color = i["color"]
	var side: float = float(i["side"])
	var sweep: bool = move in [&"spin", &"whirl", &"parry", &"draw"]
	# 휘두르는 원은 테만(가는 그을음과 빛줄), 내리찍는 원은 테 안쪽까지 그을린 넓은 고리
	var inner: float = maxf(0.0, r - 0.4) if sweep else r * 0.7
	var m := _mark(h, _ring_mesh(inner, r + 0.03, 56), c, 0.8 if sweep else 0.85, _ground(at, 0.03))
	var mat: ShaderMaterial = m.material_override
	match move:
		&"spin", &"whirl", &"parry", &"draw":
			_orient_part(m, face, TAU, side)
			var light: bool = move == &"whirl"
			_play_mark(h, mat, 0.1, 0.0 if light else mark_hold, 0.25 if light else mark_fade, k * (0.75 if light else 1.0))
			_streak_ring(h, _ground(at, waist_height), r, face, side, c, k * (0.8 if light else 1.0), TAU * 0.6, 0.3)
		_:
			m.scale = Vector3(0.82, 1.0, 0.82)
			var tw := h.create_tween()
			tw.tween_property(m, "scale", Vector3.ONE, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_play_mark(h, mat, 0.0, mark_hold + 0.1, mark_fade + 0.2, k)
			if move in [&"smash", &"leap", &"quake"]:
				_cracks(h, at, r * 0.95, c if i["el"] != &"" else Color(1.0, 0.52, 0.22), k)
				if _room():
					_pull_fx._dust(_ground(at, 0.0), roundi((16.0 + r * 4.0) * k), 1.2 + r * 0.45, 0.32 + r * 0.04)
				if _room():
					_pull_fx._pebbles(_ground(at, 0.0), roundi((4.0 + r) * k))


## 고리(지진의 여진): 안에서 밖으로 조금 퍼지며 식는 고리와 고리를 따라 이는 흙먼지.
func _ring(h: Node3D, i: Dictionary) -> void:
	var at: Vector2 = i["at"]
	var r: float = Grid.cells_to_meters(float(i["radius"]))
	var t: float = Grid.cells_to_meters(float(i["thick"]))
	var k: float = float(i["k"])
	var inner: float = maxf(0.0, r - t * 0.5)
	var outer: float = r + t * 0.5
	# 고리의 앞 테가 안쪽 끝에서 바깥 끝까지 쓸고 나간다(그 사이가 맞는 폭)
	var m := _mark(h, _ring_mesh(maxf(0.0, outer - 0.55), outer, 64), i["color"], 0.75, _ground(at, 0.03))
	var s: float = clampf(inner / outer, 0.3, 1.0)
	m.scale = Vector3(s, 1.0, s)
	var tw := h.create_tween()
	tw.tween_property(m, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_play_mark(h, m.material_override, 0.0, mark_hold, mark_fade, k)
	var p := _emitter({"c": _ground(at, 0.1), "round": true, "inner": inner, "outer": outer}, roundi((10.0 + outer * 2.0) * k), 0.9)
	if p:
		_dust_look(p, 1.2)


# ---------------------------------------------------------------- 움직이는 동작

## 돌진베기: 지나간 길의 띠(맞는 폭)가 영주를 따라 드러나고, 같은 길에 잔상 줄기.
func _lunge(i: Dictionary) -> void:
	if not (i.has("from") and i.has("to")):
		_hit(&"lunge", i)
		return
	var from: Vector2 = i["from"]
	var to: Vector2 = i["to"]
	var go: Vector2 = to - from
	if go.length() < 0.05:
		_hit(&"lunge", i)
		return
	_last_hit[&"lunge"] = _clock
	var h := _holder()
	var t: float = maxf(0.05, float(i["time"]))
	var k: float = float(i["k"])
	var c: Color = i["color"]
	var face: float = go.angle()
	_edges(h, from, face, Grid.cells_to_meters(go.length()), Grid.cells_to_meters(float(i["width"])) * 0.5, c, k * 0.9, t, mark_hold, mark_fade)
	_path(h, from, to, 1.3, c, k, t, 0.3)
	var j: Dictionary = i.duplicate()
	j["shape"] = &"line"
	j["at"] = from
	j["face"] = face
	j["reach"] = go.length()
	_element(h, j)
	_free_later(h, t + 1.2)


## 물러나 베기의 뒤로 뛰기: 베기가 끝날 무렵(time - 0.15초) 뒤로 물러나는 길에 옅은 잔상.
func _hop(i: Dictionary) -> void:
	if not (i.has("from") and i.has("to")):
		return
	var h := _holder()
	var t: float = float(i["time"])
	var hop: float = MoveMotion.RETREAT_HOP
	var tw := h.create_tween()
	tw.tween_interval(maxf(0.0, t - hop))
	tw.tween_callback(func() -> void: _path(h, i["from"], i["to"], 0.6, MoveArt.STEEL, float(i["k"]) * 0.3, hop, 0.2))
	_free_later(h, t + 0.6)


## 순간 베기: 떠난 자리와 나타난 자리에 검은 연기와 쇠의 번쩍임.
func _blink(i: Dictionary) -> void:
	if not (i.has("from") and i.has("to")):
		return
	var h := _holder()
	var k: float = float(i["k"])
	for p: Vector2 in [i["from"], i["to"]]:
		_smoke(_ground(p, 0.9), k)
		_glint(h, _ground(p, 1.25), 0.9, MoveArt.STEEL, k, 0.25)
	_free_later(h, 0.5)


## 갈고리 베기: 날아가는 길에 잔상, 닿으면(move_area, 없으면 time 뒤에 대신) 그 자리에서 벤다.
func _hook(i: Dictionary) -> void:
	if not (i.has("from") and i.has("to")):
		_hit(&"hook", i)
		return
	var t: float = maxf(0.05, float(i["time"]))
	var h := _holder()
	_path(h, i["from"], i["to"], 1.1, i["color"], float(i["k"]) * 0.8, t, 0.25, 0.5)
	_free_later(h, t + 0.6)
	var p := _holder()
	_pending[&"hook"] = {"node": p, "fired": -1.0}
	var tw := p.create_tween()
	tw.tween_interval(t + 0.1)
	tw.tween_callback(func() -> void:
		if _pending.has(&"hook"):
			_pending[&"hook"]["fired"] = _clock
		_hit(&"hook", i)
		p.queue_free())


## 끌어당기기: 부채꼴의 땅(옅게)과, 부채꼴 안에서 영주 앞으로 모여드는 줄기.
func _pull(i: Dictionary) -> void:
	_last_hit[&"pull"] = _clock
	var h := _holder()
	var at: Vector2 = i["at"]
	var face: float = float(i["face"])
	var arc: float = clampf(float(i["arc"]), 0.05, TAU)
	var reach: float = Grid.cells_to_meters(float(i["reach"]))
	var k: float = float(i["k"])
	var c: Color = i["color"]
	var m := _mark(h, _ring_mesh(maxf(0.0, reach - 0.3), reach + 0.03, 40), c, 0.75, _ground(at, 0.03))
	_orient_part(m, face, arc, float(i["side"]))
	_play_mark(h, m.material_override, 0.06, 0.04, 0.3, k * 0.8, arc / TAU)
	for e in [-0.5, 0.5]:
		var a: float = face + arc * float(e)
		var em := _mark(h, _band_mesh(reach, 0.22), c, 0.5, _ground(at, 0.03))
		em.rotation.y = -a - PI / 2.0
		_play_mark(h, em.material_override, 0.06, 0.04, 0.3, k * 0.8)
	var o: Vector3 = _ground(at, 0.0)
	var front: Vector3 = o + Vector3(cos(face), 0.0, sin(face)) * Grid.cells_to_meters(1.0)
	for n in 7:
		var a: float = face + _rng.randf_range(-0.5, 0.5) * arc
		var d := Vector3(cos(a), 0.0, sin(a))
		var start: Vector3 = o + d * reach * _rng.randf_range(0.5, 1.0) + Vector3(0.0, _rng.randf_range(0.4, 1.4), 0.0)
		var to: Vector3 = front + Vector3(0.0, start.y, 0.0)
		var head: Vector3 = start + (to - start).normalized() * 1.8
		var s := _streak(h, start, head, 0.3, c, k, 0.0, 0.24)
		var tw := h.create_tween()
		tw.tween_property(s, "position", start.lerp(to, 0.75), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_element(h, i)
	_free_later(h, 1.2)


## 소용돌이: 도는 동안(time) 영주를 따라다니며 허리 높이에서 도는 줄기. 한 바퀴마다의 판정은 move_area가 그린다.
func _swirl(i: Dictionary) -> void:
	var h := _holder()
	var t: float = maxf(0.1, float(i["time"]))
	var r: float = Grid.cells_to_meters(float(i["radius"]))
	var side: float = float(i["side"])
	var k: float = float(i["k"]) * 0.7
	h.position = _ground(i["at"], 0.0)
	var m := MeshInstance3D.new()
	m.mesh = _ring_mesh(maxf(0.0, r - 0.6), r * 0.92, 48)
	var mat := MoveArt.streak_material(i["color"])
	mat.set_shader_parameter("fade", 0.0)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position.y = waist_height + 0.15
	if side > 0.0:
		m.scale.z = -1.0
	m.rotation.y = -float(i["face"])
	h.add_child(m)
	_follow.append(h)
	var tw := h.create_tween()
	tw.tween_property(m, "rotation:y", m.rotation.y + side * TAU * t / 0.3, t + 0.15)
	var tf := h.create_tween()
	tf.tween_property(mat, "shader_parameter/fade", k, 0.06)
	tf.tween_interval(maxf(0.0, t - 0.06))
	tf.tween_property(mat, "shader_parameter/fade", 0.0, 0.15)
	tf.tween_callback(h.queue_free)


# ---------------------------------------------------------------- 미리 보기

## 늦게 터지는 판정: delay 동안 판정 모양이 옅게 드러난다(다 드러나는 때가 맞는 때). move_area가 오면 거둔다.
func _telegraph(move: StringName, i: Dictionary, delay: float) -> void:
	_end_tele(move)
	var h := _holder()
	_tele[move] = h
	var d: float = maxf(0.05, delay)
	var at: Vector2 = i["at"]
	var k: float = float(i["k"]) * 0.55
	var c: Color = i["color"]
	var mat: ShaderMaterial
	if i["shape"] == &"line":
		# 띠의 두 가장자리가 영주에게서 앞으로 자란다
		var mats: Array[ShaderMaterial] = _edges(h, at, float(i["face"]), Grid.cells_to_meters(float(i["reach"])), Grid.cells_to_meters(float(i["width"])) * 0.5, c, k, 0.0, 0.0, 0.0)
		var tl := h.create_tween().set_parallel()
		for em in mats:
			em.set_shader_parameter("progress", 0.0)
			tl.tween_property(em, "shader_parameter/progress", 1.0, d)
		tl.chain().tween_interval(0.2)
		tl.chain().tween_callback(h.queue_free)
		return
	else:
		var r: float = Grid.cells_to_meters(float(i["radius"]))
		var m := _mark(h, _ring_mesh(maxf(0.0, r - 0.22), r, 56), c, 0.5, _ground(at, 0.03))
		_orient_part(m, float(i["face"]) + PI, TAU, -1.0)
		mat = m.material_override
	mat.set_shader_parameter("progress", 0.0)
	mat.set_shader_parameter("fade", _level(mat, k))
	var tw := h.create_tween()
	tw.tween_property(mat, "shader_parameter/progress", 1.0, d)
	tw.tween_property(mat, "shader_parameter/fade", 0.0, 0.2)
	tw.tween_callback(h.queue_free)


## 반격 자세: 반격이 닿을 둘레에 옅게 숨 쉬는 테, 칼에 작은 번쩍임. 맞으면(move_area) 거둔다.
func _stance(i: Dictionary) -> void:
	_end_tele(&"parry")
	var h := _holder()
	_tele[&"parry"] = h
	var t: float = maxf(0.1, float(i["time"]))
	var at: Vector2 = i["at"]
	var face: float = float(i["face"])
	var k: float = float(i["k"])
	var r: float = Grid.cells_to_meters(float(i["radius"]))
	var m := _mark(h, _ring_mesh(maxf(0.0, r - 0.18), r, 56), MoveArt.STEEL, 0.5, _ground(at, 0.03))
	var mat: ShaderMaterial = m.material_override
	var f0: float = _level(mat, 0.6 * k)
	mat.set_shader_parameter("fade", 0.0)
	var tw := h.create_tween()
	tw.tween_property(mat, "shader_parameter/fade", f0, t * 0.35)
	tw.tween_property(mat, "shader_parameter/fade", f0 * 0.85, t * 0.65)
	tw.tween_property(mat, "shader_parameter/fade", 0.0, 0.1)
	tw.tween_callback(h.queue_free)
	_glint(h, _ground(at, 1.35) + Vector3(cos(face), 0.0, sin(face)) * 0.45, 0.45, MoveArt.STEEL, 0.8 * k, t)


func _end_tele(move: StringName) -> void:
	if not _tele.has(move):
		return
	var n: Node = _tele[move]
	_tele.erase(move)
	if is_instance_valid(n):
		n.queue_free()


# ---------------------------------------------------------------- 속성

## 판정 자리에 속성을 얹는다. 불: 불씨(테는 자국 색), 서리: 얼음 조각과 잠깐 서리 판, 벼락: 짧게 튀는 번개, 피: 검붉은 안개.
func _element(h: Node3D, i: Dictionary) -> void:
	var el: StringName = i["el"]
	if el == &"":
		return
	var k: float = float(i["k"])
	var ar: Dictionary = _area(i)
	match el:
		&"fire":
			_embers(ar, k)
		&"ice":
			_frost(h, ar, k)
			_shards(ar, k)
		&"bolt":
			_crackle(h, ar, k)
		&"blood":
			_mist(ar, k)


## 판정 자리를 알갱이 뿌릴 넓이로: c(가운데, 세계), round면 inner~outer(m)의 고리, 아니면 along × across(m) 상자를 rot만큼 돌린 것.
func _area(i: Dictionary) -> Dictionary:
	var at: Vector2 = i["at"]
	var face: float = float(i["face"])
	var fwd := Vector2(cos(face), sin(face))
	var reach: float = float(i["reach"])
	match StringName(i["shape"]):
		&"line", &"plus":
			var across: float = float(i["width"]) if i["shape"] == &"line" else reach * 1.23
			return {"c": _ground(at + fwd * reach * 0.5, 0.1), "round": false, "along": Grid.cells_to_meters(reach), "across": Grid.cells_to_meters(across), "rot": -face - PI / 2.0}
		&"circle":
			return {"c": _ground(at, 0.1), "round": true, "inner": 0.0, "outer": Grid.cells_to_meters(float(i["radius"]))}
		&"ring":
			var r: float = float(i["radius"])
			var t: float = float(i["thick"]) * 0.5
			return {"c": _ground(at, 0.1), "round": true, "inner": Grid.cells_to_meters(maxf(0.0, r - t)), "outer": Grid.cells_to_meters(r + t)}
	var arc: float = float(i["arc"])
	var rm: float = Grid.cells_to_meters(reach)
	if arc >= PI:
		return {"c": _ground(at, 0.1), "round": true, "inner": rm * 0.3, "outer": rm}
	return {"c": _ground(at + fwd * reach * 0.6, 0.1), "round": false, "along": rm * 0.7, "across": 2.0 * rm * sin(arc * 0.5) * 0.9, "rot": -face - PI / 2.0}


func _embers(ar: Dictionary, k: float) -> void:
	var p := _emitter(ar, roundi(26 * k), 1.0)
	if p == null:
		return
	p.explosiveness = 0.7
	p.direction = Vector3.UP
	p.spread = 30.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 2.4
	p.gravity = Vector3(0.0, 0.8, 0.0)
	p.damping_min = 0.4
	p.damping_max = 1.0
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.0
	var f: Color = MoveArt.FIRE
	_ramp(p, [Color(f.r * 2.5, f.g * 2.5, f.b * 2.5, 0.0), Color(f.r * 2.5, f.g * 2.0, f.b * 1.5, 1.0), Color(0.6, 0.12, 0.02, 0.0)], [0.0, 0.15, 1.0])
	p.mesh = _dot_quad(0.13, true)


## 서리 판: 판정 자리에 잠깐 깔리는 푸른 흰빛(고리 모양에는 깔지 않는다).
func _frost(h: Node3D, ar: Dictionary, k: float) -> void:
	if bool(ar["round"]) and float(ar["inner"]) > 0.0:
		return
	var m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2.ONE
	m.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = _soft_add.albedo_texture
	mat.albedo_color = Color(MoveArt.ICE.lerp(Color.WHITE, 0.55), 0.3 * k)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var c: Vector3 = ar["c"]
	m.position = Vector3(c.x, c.y - 0.06, c.z)
	if bool(ar["round"]):
		var d: float = float(ar["outer"]) * 2.2
		m.scale = Vector3(d, 1.0, d)
	else:
		m.rotation.y = float(ar["rot"])
		m.scale = Vector3(float(ar["across"]) * 1.4, 1.0, float(ar["along"]) * 1.25)
	h.add_child(m)
	var tw := h.create_tween()
	tw.tween_interval(0.15)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.6)


func _shards(ar: Dictionary, k: float) -> void:
	var p := _emitter(ar, roundi(18 * k), 0.55)
	if p == null:
		return
	p.direction = Vector3.UP
	p.spread = 55.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.5
	p.gravity = Vector3(0.0, -11.0, 0.0)
	p.particle_flag_align_y = true
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	var c: Color = MoveArt.ICE
	_ramp(p, [Color(c.r * 1.4, c.g * 1.4, c.b * 1.4, 1.0), Color(c, 0.0)], [0.0, 1.0])
	p.mesh = _shard_mesh


## 번개: 판정 자리 위를 짧게 튀는 꺾인 줄기 몇 가닥, 두 번 깜빡인다.
func _crackle(h: Node3D, ar: Dictionary, k: float) -> void:
	var root := Node3D.new()
	h.add_child(root)
	var n: int = 3 if k < 1.0 else 4
	_bolts(root, ar, n)
	var tw := h.create_tween()
	tw.tween_interval(0.06)
	tw.tween_callback(func() -> void: root.visible = false)
	tw.tween_interval(0.03)
	tw.tween_callback(func() -> void:
		for c in root.get_children():
			c.queue_free()
		_bolts(root, ar, n)
		root.visible = true)
	tw.tween_interval(0.07)
	tw.tween_callback(root.queue_free)


func _bolts(root: Node3D, ar: Dictionary, n: int) -> void:
	for _b in n:
		var a: Vector3 = _area_point(ar, _rng.randf_range(0.05, 0.5))
		var b: Vector3 = _area_point(ar, _rng.randf_range(0.2, 0.9))
		var segs: int = 5
		var prev: Vector3 = a
		var jit: float = maxf(0.15, a.distance_to(b) * 0.12)
		for s in range(1, segs + 1):
			var p: Vector3 = b if s == segs else a.lerp(b, float(s) / segs) + Vector3(_rng.randf_range(-jit, jit), _rng.randf_range(-jit, jit) * 0.6, _rng.randf_range(-jit, jit))
			_segment(root, prev, p, 0.035)
			prev = p


func _segment(root: Node3D, a: Vector3, b: Vector3, w: float) -> void:
	var d: Vector3 = b - a
	var length: float = d.length()
	if length < 0.01:
		return
	var up: Vector3 = Vector3.UP if absf(d.y / length) < 0.99 else Vector3.RIGHT
	var m := MeshInstance3D.new()
	m.mesh = _unit_box
	m.material_override = _bolt_mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.transform = Transform3D(Basis.looking_at(d, up) * Basis.from_scale(Vector3(w, w, length)), (a + b) * 0.5)
	root.add_child(m)


func _mist(ar: Dictionary, k: float) -> void:
	var p := _emitter(ar, roundi(16 * k), 1.0)
	if p == null:
		return
	p.explosiveness = 0.8
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 1.1
	p.damping_min = 0.6
	p.damping_max = 1.2
	p.gravity = Vector3(0.0, 0.25, 0.0)
	_grow(p, 0.5, 1.7)
	_ramp(p, [Color(0.36, 0.02, 0.03, 0.0), Color(0.36, 0.02, 0.03, 0.6 * k), Color(0.18, 0.0, 0.01, 0.0)], [0.0, 0.15, 1.0])
	p.mesh = _dot_quad(0.9, false)


## 날아가는 것에 붙어 따라오는 속성 알갱이(위치는 _place가 옮긴다).
func _trail_emitter(el: StringName) -> CPUParticles3D:
	if not _room():
		return null
	var p := CPUParticles3D.new()
	p.amount = 24
	p.lifetime = 0.45
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.35
	p.direction = Vector3.UP
	p.spread = 180.0
	match el:
		&"fire":
			p.initial_velocity_min = 0.3
			p.initial_velocity_max = 1.2
			p.gravity = Vector3(0.0, 1.2, 0.0)
			var f: Color = MoveArt.FIRE
			_ramp(p, [Color(f.r * 2.5, f.g * 2.0, f.b * 1.5, 1.0), Color(0.6, 0.12, 0.02, 0.0)], [0.0, 1.0])
			p.mesh = _dot_quad(0.12, true)
		&"ice":
			p.initial_velocity_min = 0.5
			p.initial_velocity_max = 1.5
			p.gravity = Vector3(0.0, -6.0, 0.0)
			p.particle_flag_align_y = true
			p.scale_amount_min = 0.4
			p.scale_amount_max = 0.8
			_ramp(p, [Color(MoveArt.ICE * 1.4, 1.0), Color(MoveArt.ICE, 0.0)], [0.0, 1.0])
			p.mesh = _shard_mesh
		&"bolt":
			p.lifetime = 0.15
			p.initial_velocity_min = 2.0
			p.initial_velocity_max = 4.0
			_ramp(p, [Color(MoveArt.BOLT * 2.0, 1.0), Color(MoveArt.BOLT, 0.0)], [0.0, 1.0])
			p.mesh = _dot_quad(0.07, true)
		_:
			p.lifetime = 0.7
			p.initial_velocity_min = 0.1
			p.initial_velocity_max = 0.4
			p.gravity = Vector3(0.0, 0.2, 0.0)
			_grow(p, 0.5, 1.5)
			_ramp(p, [Color(0.36, 0.02, 0.03, 0.55), Color(0.18, 0.0, 0.01, 0.0)], [0.0, 1.0])
			p.mesh = _dot_quad(0.55, false)
	_parts.add_child(p)
	p.emitting = true
	return p


# ---------------------------------------------------------------- 그리는 조각

## 효과 하나를 담는 노드. 트윈을 이 노드에 묶어서 지우면 트윈도 함께 멈춘다. 너무 많으면 오래된 것부터 지운다.
func _holder() -> Node3D:
	var h := Node3D.new()
	_layer.add_child(h)
	if _layer.get_child_count() > MAX_FX:
		_layer.get_child(0).queue_free()
	return h


func _free_later(h: Node, t: float) -> void:
	var tw := h.create_tween()
	tw.tween_interval(t)
	tw.tween_callback(h.queue_free)


func _ring_mesh(inner: float, outer: float, segments: int = 48) -> ArrayMesh:
	var key: String = "r%.2f_%.2f_%d" % [inner, outer, segments]
	if not _meshes.has(key):
		_cache_room()
		_meshes[key] = MoveArt.ring_mesh(inner, outer, segments)
	return _meshes[key]


func _band_mesh(length: float, width: float) -> ArrayMesh:
	var key: String = "b%.2f_%.2f" % [length, width]
	if not _meshes.has(key):
		_cache_room()
		_meshes[key] = MoveArt.band_mesh(length, width)
	return _meshes[key]


func _cache_room() -> void:
	if _meshes.size() >= 96:
		_meshes.clear()


## 칸 위치의 땅 위 lift m(세계 좌표).
func _ground(cells: Vector2, lift: float) -> Vector3:
	var w: Vector3 = Grid.cells_to_world(cells)
	w.y = (float(height_of.call(w.x, w.z)) if height_of.is_valid() else HillBuilder.height(w.x, w.z)) + lift
	return w


## 땅 자국 한 장(MoveArt.ground_mark_material, 빛줄 있음). glow_at은 빛줄이 있는 UV.y.
func _mark(h: Node3D, mesh: Mesh, c: Color, glow_at: float, pos: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	var mat := MoveArt.ground_mark_material(c, true)
	mat.set_shader_parameter("glow_at", glow_at)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = pos
	h.add_child(m)
	return m


## 띠 판정의 두 가장자리(가는 빛줄 두 줄): from에서 face 쪽으로 length m, 가운데에서 half m 떨어져.
## reveal > 0이면 그동안 드러나고 hold 뒤 fade 동안 식는다(fade = 0이면 재질만 돌려주고 움직이지 않는다).
func _edges(h: Node3D, from: Vector2, face: float, length: float, half: float, c: Color, k: float, reveal: float, hold: float, fade: float) -> Array[ShaderMaterial]:
	var right := Vector3(-sin(face), 0.0, cos(face))
	var out: Array[ShaderMaterial] = []
	for s in [-1.0, 1.0]:
		var m := _mark(h, _band_mesh(length, 0.24), c, 0.5, _ground(from, 0.03) + right * half * float(s))
		m.rotation.y = -face - PI / 2.0
		var mat: ShaderMaterial = m.material_override
		mat.set_shader_parameter("fade", _level(mat, k))
		if fade > 0.0:
			_play_mark(h, mat, reveal, hold, fade, k)
		out.append(mat)
	return out


## 고리 메시(UV.x × TAU = 각도)를 face ± arc/2만 덮게 돌린다. side > 0(오른쪽→왼쪽)이면 거울로 뒤집어 드러나는 쪽을 맞춘다.
func _orient_part(m: Node3D, face: float, arc: float, side: float) -> void:
	if side > 0.0:
		m.scale.z = -1.0
		m.rotation.y = -(face + arc * 0.5)
	else:
		m.rotation.y = -(face - arc * 0.5)


## 땅 자국: reveal초 동안 progress 0 → upto로 드러나고, hold초 머문 뒤 fade초 동안 식는다. k는 처음 밝기.
func _play_mark(h: Node3D, mat: ShaderMaterial, reveal: float, hold: float, fade: float, k: float, upto: float = 1.0) -> void:
	mat.set_shader_parameter("fade", _level(mat, k))
	mat.set_shader_parameter("progress", 0.0 if reveal > 0.0 else upto)
	var tw := h.create_tween()
	if reveal > 0.0:
		tw.tween_property(mat, "shader_parameter/progress", upto, reveal)
	tw.tween_interval(maxf(0.001, hold))
	tw.tween_property(mat, "shader_parameter/fade", 0.0, fade).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


## 땅 자국의 밝기 k(0~1). 재질의 fade는 빛줄(fade³)보다 그을음(거의 0.6까지 진하다)을 늦게 지워서, fade만 낮추면
## 빛만 죽고 검은 자국이 남는다. 그래서 k < 1이면 fade를 낮춰 그을음을 옅게 하고 glow를 키워 빛줄을 k만큼 되살린다.
## 처음 fade 값을 돌려준다(그 값에서 0으로 식히면 된다).
func _level(mat: ShaderMaterial, k: float) -> float:
	if k >= 0.95:
		mat.set_shader_parameter("glow", 1.0)
		return 1.0
	var f: float = clampf(0.62 * k, 0.12, 0.6)
	mat.set_shader_parameter("glow", k / (f * f * f))
	return f


## 더해 그리는 잔상 줄기: 꼬리 a에서 머리 b로, 가로 판과 세로 판을 겹쳐 어느 쪽에서 봐도 보인다.
## grow > 0이면 grow초 동안 꼬리에서 머리로 자라고, 그다음 fade초 동안 사라진다. 돌려준 노드를 옮겨도 된다.
func _streak(h: Node3D, a: Vector3, b: Vector3, width: float, c: Color, k: float, grow: float, fade: float) -> Node3D:
	var length: float = a.distance_to(b)
	var node := Node3D.new()
	h.add_child(node)
	if length < 0.01:
		return node
	node.position = a
	var d: Vector3 = (b - a) / length
	node.basis = Basis.looking_at(d, Vector3.UP if absf(d.y) < 0.99 else Vector3.RIGHT)
	var mesh := _band_mesh(length, width)
	var mat := MoveArt.streak_material(c)
	mat.set_shader_parameter("fade", k)
	for n in 2:
		var m := MeshInstance3D.new()
		m.mesh = mesh
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.rotation.z = PI * 0.5 * n
		node.add_child(m)
	var tw := h.create_tween()
	if grow > 0.0:
		node.scale = Vector3(1.0, 1.0, 0.02)
		tw.tween_property(node, "scale:z", 1.0, grow)
	tw.tween_property(mat, "shader_parameter/fade", 0.0, fade).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	return node


## 움직이는 동작의 잔상: from에서 to까지 허리 높이에 굵은 줄기가 grow초 동안 영주를 따라 자란다.
func _path(h: Node3D, from: Vector2, to: Vector2, width: float, c: Color, k: float, grow: float, fade: float, lift: float = 0.0) -> void:
	var y: float = waist_height + lift
	_streak(h, _ground(from, y), _ground(to, y), width, c, k, grow, fade)


## 허리 높이에서 도는 줄기 고리(회전베기, 소용돌이, 반격). 머리가 face에서 출발해 side 쪽으로 turn만큼 돌며 사라진다.
func _streak_ring(h: Node3D, at: Vector3, r: float, face: float, side: float, c: Color, k: float, turn: float, time: float) -> void:
	var m := MeshInstance3D.new()
	m.mesh = _ring_mesh(maxf(0.0, r - 0.5), r, 48)
	var mat := MoveArt.streak_material(c)
	mat.set_shader_parameter("fade", k)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = at
	if side > 0.0:
		m.scale.z = -1.0
	m.rotation.y = -face
	h.add_child(m)
	var tw := h.create_tween()
	tw.tween_property(m, "rotation:y", -face + side * turn, time)
	tw.parallel().tween_property(mat, "shader_parameter/fade", 0.0, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## 갈라진 틈: 빠르게 자라고 잠깐 틈에서 빛이 났다가 어두운 금으로 남은 뒤 사라진다.
func _cracks(h: Node3D, at: Vector2, r: float, c: Color, k: float) -> void:
	var m := MeshInstance3D.new()
	m.mesh = MoveArt.crack_mesh(_rng.randi(), r)
	var mat := MoveArt.crack_material(c)
	mat.set_shader_parameter("grow", 0.0)
	mat.set_shader_parameter("energy", 1.1 * k)
	mat.set_shader_parameter("fade", k)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = _ground(at, 0.035)
	m.rotation.y = _rng.randf() * TAU
	h.add_child(m)
	var tw := h.create_tween()
	tw.tween_property(mat, "shader_parameter/grow", 1.0, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mat, "shader_parameter/energy", 0.0, 0.6)
	tw.tween_interval(0.4)
	tw.tween_property(mat, "shader_parameter/fade", 0.0, 0.6)


## 쇠의 번쩍임(빌보드). 깊이 검사를 받으니 카메라 쪽으로 조금 당긴다.
func _glint(h: Node3D, p: Vector3, size: float, c: Color, k: float, life: float) -> void:
	var m := MeshInstance3D.new()
	m.mesh = MoveArt.glint_mesh(size)
	var mat := MoveArt.glint_material(c)
	mat.set_shader_parameter("fade", k)
	mat.set_shader_parameter("spin", 0.0)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = _toward_cam(p, 0.7)
	m.scale = Vector3.ONE * 0.35
	h.add_child(m)
	var tw := h.create_tween()
	tw.tween_property(m, "scale", Vector3.ONE, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mat, "shader_parameter/spin", 0.7, life)
	tw.parallel().tween_property(mat, "shader_parameter/fade", 0.0, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _toward_cam(p: Vector3, d: float) -> Vector3:
	var vp := get_viewport()
	var cam: Camera3D = vp.get_camera_3d() if vp else null
	if cam == null:
		return p
	return p + (cam.global_position - p).normalized() * d


## 순간 이동의 검은 연기.
func _smoke(at: Vector3, k: float) -> void:
	var p := _emitter({"c": at, "round": true, "inner": 0.0, "outer": 0.6}, roundi(30 * k), 0.85)
	if p == null:
		return
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.6
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 3.0
	p.damping_min = 2.0
	p.damping_max = 3.0
	p.gravity = Vector3(0.0, 0.5, 0.0)
	_grow(p, 0.7, 2.6)
	_ramp(p, [Color(0.07, 0.07, 0.08, 0.0), Color(0.07, 0.07, 0.08, 0.2 * k), Color(0.09, 0.09, 0.1, 0.0)], [0.0, 0.12, 1.0])
	p.mesh = _dot_quad(0.8, false)


## 흙먼지 모양(PullFx._dust와 같은 색): 고리 자리에서 일어 퍼진다.
func _dust_look(p: CPUParticles3D, speed: float) -> void:
	p.direction = Vector3.UP
	p.spread = 50.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.damping_min = speed * 0.8
	p.damping_max = speed * 1.2
	p.gravity = Vector3(0.0, 0.15, 0.0)
	_grow(p, 0.5, 1.6)
	_ramp(p, [Color(0.32, 0.27, 0.22, 0.45), Color(0.3, 0.26, 0.22, 0.0)], [0.0, 1.0])
	p.mesh = _dot_quad(0.7, false)


# ---------------------------------------------------------------- 알갱이

## 알갱이를 더 만들어도 되는지(동시에 MAX_PARTICLES개까지, PullFx에 맡긴 것도 센다).
func _room() -> bool:
	return _parts.get_child_count() + _pull_fx.get_child_count() < MAX_PARTICLES


## 한 번 터지는 알갱이. ar(_area의 모양)에서 나온다. 너무 많으면 null.
func _emitter(ar: Dictionary, amount: int, life: float) -> CPUParticles3D:
	if not _room() or amount <= 0:
		return null
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 0.85
	p.local_coords = false
	if bool(ar["round"]):
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		p.emission_ring_axis = Vector3.UP
		p.emission_ring_height = 0.1
		p.emission_ring_radius = maxf(0.05, float(ar["outer"]))
		p.emission_ring_inner_radius = clampf(float(ar["inner"]), 0.0, float(ar["outer"]))
	else:
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(float(ar["across"]) * 0.5, 0.1, float(ar["along"]) * 0.5)
		p.rotation.y = float(ar["rot"])
	p.position = ar["c"]
	_parts.add_child(p)
	p.emitting = true
	var tw := p.create_tween()
	tw.tween_interval(life + 0.2)
	tw.tween_callback(p.queue_free)
	return p


## ar 안의 아무 점(땅 위 y m).
func _area_point(ar: Dictionary, y: float) -> Vector3:
	var c: Vector3 = ar["c"]
	if bool(ar["round"]):
		var a: float = _rng.randf() * TAU
		var r: float = _rng.randf_range(float(ar["inner"]), float(ar["outer"]))
		return Vector3(c.x + cos(a) * r, c.y - 0.1 + y, c.z + sin(a) * r)
	var local := Vector3(_rng.randf_range(-0.5, 0.5) * float(ar["across"]), 0.0, _rng.randf_range(-0.5, 0.5) * float(ar["along"]))
	return Vector3(c.x, c.y - 0.1 + y, c.z) + Basis(Vector3.UP, float(ar["rot"])) * local


func _ramp(p: CPUParticles3D, cols: Array, offs: Array) -> void:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offs)
	g.colors = PackedColorArray(cols)
	p.color_ramp = g


func _grow(p: CPUParticles3D, a: float, b: float) -> void:
	var c := Curve.new()
	c.max_value = maxf(a, b)
	c.add_point(Vector2(0.0, a))
	c.add_point(Vector2(1.0, b))
	p.scale_amount_curve = c


func _dot_quad(size: float, add: bool) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = _soft_add if add else _soft_mix
	return q


func _soft(add: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if add:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = HitFx._soft_dot()
	return m


# ---------------------------------------------------------------- 날아가는 것

## 던진 칼: 쥔 칼이 있으면 그 모양, 없으면 칼 번호(p.id)로 정한 녹슨 장검.
func _thrown_sword(p: Projectile) -> SwordModel:
	if rules != null and rules.current() != null:
		return SwordModel.for_sword(rules.current(), rules.data.grades)
	return SwordModel.make(null, 0, p.id, Color.WHITE)


func _place(v: Dictionary, alpha: float) -> void:
	var p: Projectile = v["p"]
	var root: Node3D = v["root"]
	if not is_instance_valid(root):
		return
	var cells: Vector2 = p.prev_pos.lerp(p.pos, alpha)
	root.position = _ground(cells, projectile_height)
	var d: Vector2 = p.dir if p.dir.length_squared() > 1e-6 else p.pos - p.prev_pos
	if d.length_squared() > 1e-6:
		root.rotation.y = -atan2(d.y, d.x) - PI / 2.0
	if v["trail"] != null:
		var tr: MeshInstance3D = v["trail"]
		var length: float = clampf(Grid.cells_to_meters(cells.distance_to(v["start"])), 0.05, 4.0)
		tr.position = Vector3(0.0, 0.0, length)
		tr.scale = Vector3(1.0, 1.0, length)
	if bool(v["returning"]) != p.returning:
		v["returning"] = p.returning
		var ring: MeshInstance3D = v["ring"]
		if ring != null:
			ring.scale.z = -1.0 if p.returning else 1.0
	var e: CPUParticles3D = v["emit"]
	if e != null and is_instance_valid(e):
		e.position = root.position
