class_name HzView
extends Node3D
## 언덕 재설계 3단계(docs/hill_events.md)의 화면: 첫 구역 검 지도.
## - 가까운 손잡이를 뽑으면 깨어날 이웃까지 땅에 희미한 줄(뽑기 전에 보인다).
## - 깨어난 검은 붉게 숨 쉬는 빛, 그 주인은 어두운 형체로 일어나 천천히 다가온다(규칙의 owner_at).
## - 거래가 걸리면 아래 가운데 창(요구 한 줄, E 받기 / Q 거절). 글자는 창 안에만.
## 규칙(Rules.hz)을 읽기만 하고, 거래 답만 rules.hz_answer로 보낸다.

var rules: Rules
var _lines: MeshInstance3D
var _glows: Dictionary = {}    # zi -> OmniLight3D
var _owners: Dictionary = {}   # zi -> Node3D
var _panel: PanelContainer
var _label: Label
var _t: float = 0.0

const ASKS: Dictionary = {
	&"sword": "쥔 검을 내려놓아라. 그러면 이 검에 각인을 새겨 주마.",
	&"max_hp": "네 피를 조금 다오(최대 체력 -20). 그러면 이 검에 각인을 새겨 주마.",
	&"durability": "네 검들의 날을 반쯤 무뎌지게 하라. 그러면 이 검에 각인을 새겨 주마.",
}


func setup(r: Rules) -> void:
	rules = r
	_lines = MeshInstance3D.new()
	_lines.mesh = ImmediateMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.85, 0.32, 0.22, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_lines.material_override = m
	add_child(_lines)
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.03, 0.88)
	sb.border_color = Color(0.62, 0.5, 0.3, 0.8)
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.72
	_panel.anchor_bottom = 0.72
	_panel.offset_left = -330
	_panel.offset_right = 330
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 20)
	_panel.add_child(_label)
	layer.add_child(_panel)
	_panel.visible = false


func _unhandled_input(ev: InputEvent) -> void:
	if rules == null or rules.hz_offer.is_empty():
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		var k := (ev as InputEventKey).physical_keycode
		if k == KEY_E:
			rules.hz_answer(true)
			get_viewport().set_input_as_handled()
		elif k == KEY_Q:
			rules.hz_answer(false)
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_t += delta
	var on: bool = rules != null and rules.hz != null
	visible = on
	_panel.visible = on and not rules.hz_offer.is_empty()
	if not on:
		_clear()
		return
	if _panel.visible:
		_label.text = "%s\n\nE 받는다    Q 거절한다(주인과 겨룬다)" % ASKS.get(rules.hz_offer.ask, "")
	_draw_preview()
	_draw_awake()


func _clear() -> void:
	(_lines.mesh as ImmediateMesh).clear_surfaces()
	for n in _glows.values():
		n.queue_free()
	for n in _owners.values():
		n.queue_free()
	_glows.clear()
	_owners.clear()


## 가장 가까운 손잡이(뽑을 수 있는 거리의 2배 안)에서 깨어날 이웃으로 줄.
func _draw_preview() -> void:
	var im := _lines.mesh as ImmediateMesh
	im.clear_surfaces()
	if rules.phase != Rules.Phase.DAY or rules.pull_hilt != null:
		return
	var h := rules.nearest_hilt(rules.data.run.pull_reach * 2.0)
	if h == null or h.zi < 0:
		return
	var to := rules.hz_wake_preview(h)
	if to.is_empty():
		return
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var a: Vector3 = Grid.cells_to_world(h.pos, 0.06)
	for o in to:
		var b: Vector3 = Grid.cells_to_world(o.pos, 0.06)
		# 점선: 짧게 끊어 땅 위에 깐다
		var n: int = int(a.distance_to(b) / 0.5)
		for k in n:
			if k % 2 == 0:
				im.surface_add_vertex(a.lerp(b, float(k) / n))
				im.surface_add_vertex(a.lerp(b, float(k + 1) / n))
	im.surface_end()


## 깨어난 검: 붉은 빛과 다가오는 주인.
func _draw_awake() -> void:
	var hz := rules.hz
	for zi in hz.blades.size():
		var b: HillZone.Blade = hz.blades[zi]
		var awake: bool = b.state == HillZone.State.AWAKE
		if awake and not _glows.has(zi):
			var h := rules.hilt_of(zi)
			var l := OmniLight3D.new()
			l.light_color = Color(0.9, 0.22, 0.12)
			l.omni_range = 3.0
			add_child(l)
			l.position = Grid.cells_to_world(h.pos if h else Vector2.ZERO, 0.6)
			_glows[zi] = l
			var o := _make_owner(b)
			_owners[zi] = o
		elif not awake and _glows.has(zi):
			_glows[zi].queue_free()
			_glows.erase(zi)
			_owners[zi].queue_free()
			_owners.erase(zi)
		if awake:
			var l: OmniLight3D = _glows[zi]
			l.light_energy = (1.2 + 0.5 * sin(_t * 3.0 + zi)) * (1.0 + 0.5 * b.woke)
			var o: EnemyView = _owners[zi]
			var e: Enemy = o.enemy
			var p: Vector2 = Grid.middle() + b.owner_at * rules.hz_scale
			e.prev_pos = e.pos
			if p.distance_to(e.pos) > 0.001:
				e.face = (p - e.pos).normalized()
			e.pos = p
			o.draw(1.0, get_process_delta_time())


## 주인: 망령 모양(EnemyView를 규칙 밖의 가짜 적으로 빌린다). 규칙의 적이 아니라 맞지도 때리지도 않는다.
func _make_owner(b: HillZone.Blade) -> EnemyView:
	var e := Enemy.new()
	e.id = -1000 - _owners.size()
	e.data = rules.data.enemies.get(&"wraith")
	e.pos = Grid.middle() + b.owner_at * rules.hz_scale
	e.prev_pos = e.pos
	e.hp = 1.0
	e.max_hp = 1.0
	var v := EnemyView.new()
	v.setup(e)
	add_child(v)
	return v
