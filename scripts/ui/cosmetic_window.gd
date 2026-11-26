class_name CosmeticWindow
extends ColorRect
## 거울(꾸미기) 창(docs/cosmetics.md). 글보다 그림: 왼쪽에 돌아가는 영주 미리보기, 오른쪽에 자리별 항목 타일.
## 타일을 누르면 잠겨 있어도 입혀 볼 수 있고(미리보기만), 가진 것이면 입고, 조각으로 사는 것은 살 수 있다.
## 잠긴 항목은 어둡게 + 조건 한 줄. 마을 거울에서 연다. 닫으면 스스로 지운다.

signal closed()
## 입은 것이 바뀌었다(장면이 영주 모습을 다시 입힌다).
signal changed()

const TILE: Vector2 = Vector2(104, 104)
const COLS: int = 4
const PREVIEW: Vector2i = Vector2i(300, 420)

var _meta: Meta
var _data: GameData
var _slot: StringName = &"cape"
var _picked: StringName = &""
var _fresh: Array[String] = []
var _tabs: HBoxContainer
var _grid: GridContainer
var _info: VBoxContainer
var _shards: Label
var _pv_root: Node3D
var _pv_model: Node3D
var _pv_char: LordCharacter = null
var _pv_slash: TextureRect
var _spin: float = 0.4
var _dragging: bool = false


static func open(parent: Node, meta: Meta, data: GameData = null) -> CosmeticWindow:
	var w := CosmeticWindow.new()
	w._meta = meta
	w._data = data
	parent.add_child(w)
	return w


func _ready() -> void:
	color = Color(0.0, 0.0, 0.0, 0.72)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	name = "UiCosmetics"
	_meta.cos_sync()
	_fresh = _meta.cos_fresh()
	var box: VBoxContainer = UiKit.center_panel(self)
	UiKit.header(box, "거울", close)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	box.add_child(body)
	body.add_child(_build_preview())
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.custom_minimum_size = Vector2(COLS * (TILE.x + 8) + 8, 0)
	body.add_child(right)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	right.add_child(_tabs)
	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	right.add_child(_grid)
	right.add_child(UiKit.rule())
	_info = VBoxContainer.new()
	_info.add_theme_constant_override("separation", 6)
	_info.custom_minimum_size = Vector2(0, 92)
	right.add_child(_info)
	_shards = UiKit.label("", 14, UiKit.MUTED)
	right.add_child(_shards)
	_picked = _meta.cos_worn_id(_slot)
	_render()
	_meta.cos_mark_seen()   # 이번에 열어 본 것으로 친다(새 표시는 이번 한 번)
	_meta.save()


func _process(delta: float) -> void:
	if _pv_model != null and not _dragging:
		_pv_model.rotation.y += delta * _spin


## 닫는다. 입은 것은 눌러 바꿀 때 이미 저장했다.
func close() -> void:
	_meta.save()
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()


# ---------------------------------------------------------------- 미리보기

func _build_preview() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	var cont := SubViewportContainer.new()
	cont.custom_minimum_size = Vector2(PREVIEW)
	cont.stretch = true
	cont.mouse_filter = Control.MOUSE_FILTER_STOP
	cont.gui_input.connect(_on_preview_input)
	col.add_child(cont)
	var vp := SubViewport.new()
	vp.size = PREVIEW
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	cont.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.58, 0.54)
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -30, 0)
	sun.light_energy = 1.1
	sun.light_color = Color(1.0, 0.92, 0.82)
	vp.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 150, 0)
	fill.light_energy = 0.45
	fill.light_color = Color(0.7, 0.8, 1.0)
	vp.add_child(fill)
	var cam := Camera3D.new()
	cam.fov = 34.0
	cam.position = Vector3(0, 1.05, 4.1)
	cam.rotation_degrees = Vector3(-4, 0, 0)
	vp.add_child(cam)
	_pv_root = Node3D.new()
	vp.add_child(_pv_root)
	var floor_mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.95
	cyl.bottom_radius = 1.05
	cyl.height = 0.08
	floor_mesh.mesh = cyl
	floor_mesh.position = Vector3(0, -0.04, 0)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.12, 0.1, 0.085)
	fm.roughness = 0.9
	floor_mesh.material_override = fm
	_pv_root.add_child(floor_mesh)
	_pv_model = Node3D.new()
	_pv_root.add_child(_pv_model)
	var model: Node3D = (load("res://scenes/lord/lord_model.tscn") as PackedScene).instantiate()
	_pv_model.add_child(model)
	if LordCharacter.available():
		for c in model.get_children():
			c.queue_free()
		_pv_char = LordCharacter.new()
		_pv_char.object_head = &""   # 미리보기는 늘 사람 머리(꾸미기 머리가 보이게)
		model.add_child(_pv_char)
	_pv_root.set_meta("model", model)
	_pv_slash = TextureRect.new()
	_pv_slash.custom_minimum_size = Vector2(PREVIEW.x, 38)
	_pv_slash.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pv_slash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	col.add_child(_pv_slash)
	col.add_child(UiKit.label("끌어서 돌려 보기", 12, UiKit.MUTED))
	return col


func _on_preview_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		_dragging = mb.pressed
	var mm := event as InputEventMouseMotion
	if mm != null and _dragging and _pv_model != null:
		_pv_model.rotation.y += mm.relative.x * 0.012


## 지금 입은 것 위에 눌러 본 항목 하나를 얹은 모습.
func _preview_worn() -> Dictionary:
	var w: Dictionary = _meta.cos_worn.duplicate()
	var it: CosmeticItem = Cosmetics.table().item(_picked)
	if it != null:
		w[String(it.slot)] = String(it.id)
	return w


func _refresh_preview() -> void:
	if _pv_root == null or not _pv_root.has_meta("model"):
		return
	var model: Node3D = _pv_root.get_meta("model")
	var r: Dictionary = CosmeticRig.apply(model, _pv_char, _preview_worn(), false)
	var c: Color = r.slash
	var icon := CosmeticItem.new()
	icon.color = c
	_pv_slash.texture = ImageTexture.create_from_image(CosmeticArt.slash_icon(icon, Vector2(180, 38)))


# ---------------------------------------------------------------- 목록

func _render() -> void:
	for c in _tabs.get_children():
		c.queue_free()
	for s in CosmeticTable.SLOTS:
		var b := UiKit.button(String(CosmeticTable.SLOT_NAMES[s]), func() -> void:
			_slot = s
			_picked = _meta.cos_worn_id(s)
			_render(), 34.0)
		b.custom_minimum_size.x = 96
		if s == _slot:
			b.add_theme_stylebox_override("normal", UiKit.style(UiKit.TITLE, 2, Color(0.1, 0.085, 0.06, 0.95)))
		_tabs.add_child(b)
	for c in _grid.get_children():
		c.queue_free()
	var worn: StringName = _meta.cos_worn_id(_slot)
	for it in Cosmetics.table().of_slot(_slot):
		if not Cosmetics.shown(it, _meta):
			continue
		_grid.add_child(_tile(it, worn))
	_render_info()
	_refresh_preview()
	_shards.text = "조각 %d" % _meta.shards


func _tile(it: CosmeticItem, worn: StringName) -> Control:
	var owned: bool = _meta.cos_has(it.id)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = TILE
	b.clip_contents = true
	var edge: Color = Color(UiKit.LINE, 0.3)
	var width: int = 1
	if it.id == worn:
		edge = UiKit.TITLE
		width = 2
	if it.id == _picked:
		edge = Color(0.95, 0.9, 0.78)
		width = 2
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb: StyleBoxFlat = UiKit.style(edge, width, Color(0.045, 0.04, 0.034, 0.95))
		sb.set_content_margin_all(2)
		if st == "hover":
			sb.bg_color = Color(0.09, 0.075, 0.055, 0.95)
		b.add_theme_stylebox_override(st, sb)
	var thumb: Control = _thumb(it)
	thumb.set_anchors_preset(Control.PRESET_FULL_RECT)
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(thumb)
	if not owned:
		thumb.modulate = Color(0.28, 0.28, 0.3, 0.95)   # 잠긴 것은 어둡게
		var lock := ColorRect.new()
		lock.color = Color(0, 0, 0, 0.25)
		lock.set_anchors_preset(Control.PRESET_FULL_RECT)
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(lock)
	if it.id == worn:
		b.add_child(_corner("입음", Control.PRESET_BOTTOM_RIGHT, UiKit.TITLE))
	elif _fresh.has(String(it.id)):
		b.add_child(_corner("새것", Control.PRESET_TOP_RIGHT, Color(0.95, 0.8, 0.4)))
	elif not owned:
		b.add_child(_corner("조각 %d" % it.need if it.unlock == &"shards" else "잠김", Control.PRESET_BOTTOM_RIGHT, UiKit.MUTED))
	b.pressed.connect(func() -> void:
		_picked = it.id
		_render())
	return b


func _corner(t: String, preset: int, col: Color) -> Label:
	var l := UiKit.label(t, 12, col)
	l.set_anchors_preset(preset)
	l.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	l.grow_vertical = Control.GROW_DIRECTION_BEGIN if preset == Control.PRESET_BOTTOM_RIGHT else Control.GROW_DIRECTION_END
	l.offset_right = -5
	l.offset_left = -5
	l.offset_bottom = -3 if preset == Control.PRESET_BOTTOM_RIGHT else 0
	l.offset_top = 0 if preset == Control.PRESET_BOTTOM_RIGHT else 3
	UiKit.soft_shadow(l, 0.9)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## 타일 그림: 베기 빛은 초승달 그림, 망토와 머리는 작은 3D 그림(항목만 어두운 마네킹 위에).
func _thumb(it: CosmeticItem) -> Control:
	if it.slot == &"slash":
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(CosmeticArt.slash_icon(it, Vector2(TILE.x, TILE.y)))
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		return tr
	return CosmeticThumb.make(it, Vector2i(int(TILE.x) - 4, int(TILE.y) - 4))


func _render_info() -> void:
	for c in _info.get_children():
		c.queue_free()
	var it: CosmeticItem = Cosmetics.table().item(_picked)
	if it == null:
		return
	var owned: bool = _meta.cos_has(it.id)
	var worn: StringName = _meta.cos_worn_id(_slot)
	_info.add_child(UiKit.label(it.title, 20, UiKit.TITLE))
	if not owned:
		var cond := UiKit.label("잠김  ·  " + Cosmetics.condition_text(it), 14, Color(0.78, 0.6, 0.4))
		_info.add_child(cond)
	var def: StringName = Cosmetics.table().default_of(_slot)
	if owned and it.id != worn:
		_info.add_child(UiKit.button("입기", func() -> void:
			_meta.cos_wear(it.id)
			_after_change(), 36.0))
	elif owned and it.id == worn and it.id != def:
		_info.add_child(UiKit.button("벗기 (기본 모습으로)", func() -> void:
			_meta.cos_wear(def)
			_picked = def
			_after_change(), 36.0))
	elif owned:
		_info.add_child(UiKit.label("기본 모습", 14, UiKit.MUTED))
	elif it.unlock == &"shards":
		var can: bool = _meta.shards >= it.need
		var b := UiKit.button("조각 %d으로 얻기" % it.need if can else "조각이 모자란다 (%d)" % it.need, func() -> void:
			if _meta.cos_buy(it.id):
				_meta.cos_wear(it.id)
				_after_change(), 36.0)
		b.disabled = not can
		_info.add_child(b)


func _after_change() -> void:
	_meta.save()
	changed.emit()
	_render()
