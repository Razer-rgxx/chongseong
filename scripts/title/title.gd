extends Node3D
## 시작 화면(27단계, 2026-11-19 꾸밈). 해 질 녘 언덕 꼭대기: 언덕(HillBuilder)과 꽂힌 검들, 가운데 한 자루가
## 등급 빛을 머금고 서 있고, 불씨가 오르고 재가 바람에 날린다. 카메라는 그 검 둘레를 아주 천천히 돈다.
## 영주 기사 모델(Mixamo, PC에만 있음)이 있으면 그 검 앞에 서 있다.
## 글자는 엘든 링식: 검은 데서 밝아지며 가운데 제목, 아래 "아무 키나 누르세요" → 누르면 메뉴(시작·설정·끝내기).
## 세계(3D)에 글자를 띄우지 않는다. 소리는 내지 않는다(종소리·올라가는 소리 없음). 꾸밈용 랜덤은 이 노드의 것.

const LOBBY: String = "res://scenes/lobby/lobby.tscn"
## 가운데 검이 서는 자리(m): 싸움터 북쪽 끝 바로 밖, 꽂힌 검들이 비탈 아래로 펼쳐지기 시작하는 곳.
## 카메라는 그 검의 남쪽(싸움터 안)에서 북쪽(지는 해 쪽)을 보며 좌우로 아주 천천히 흔들린다.
const HERO_AT := Vector3(34.0, 0.0, -2.5)
const CAM_R: float = 3.6
const CAM_H: float = 1.05
const CAM_SIDE: float = -1.3   ## 검이 화면 오른쪽 1/3에 오게 카메라를 왼쪽으로
const SWAY: float = 0.22       ## 좌우 흔들림(라디안)
const SWAY_SPEED: float = 0.05
## 가운데 검의 등급(2 = 전설, 금빛)과 칼 번호(모양이 정해진다).
const HERO_GRADE: int = 2
const HERO_SEED: int = 4242
const FADE_IN: float = 2.6

@onready var _env: WorldEnvironment = $Environment
@onready var _sun: DirectionalLight3D = $Sun
@onready var _camera: Camera3D = $Camera

var _t: float = 0.0
var _glow: OmniLight3D
var _ui: CanvasLayer
var _fade: ColorRect
var _title: Control
var _prompt: Label
var _menu: VBoxContainer
var _menu_on: bool = false
var _leaving: bool = false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	GameSettings.ensure()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_rng.seed = 19
	var data := GameData.load_default()
	Grid.size = Vector2i(34, 22)
	HillBuilder.build(self, _env.environment, data.forms)
	_dusk()
	_hero(data)
	_embers()
	_ash()
	_knight()
	_build_ui()
	_place_camera(0.0)
	WebQuality.apply(self, _env.environment, _sun, _camera)   # 웹판에서만 가볍게


# ---------------------------------------------------------------- 세계

## 해 질 녘: 낮은 붉은 해, 저녁 하늘(낮과 밤 하늘을 반쯤 섞고 따뜻하게), 따뜻한 안개.
func _dusk() -> void:
	var env: Environment = _env.environment
	if HillBuilder.sky_material:
		HillBuilder.sky_material.set_shader_parameter("night", 0.42)
		HillBuilder.sky_material.set_shader_parameter("tint", Color(1.0, 0.6, 0.42))
		HillBuilder.sky_material.set_shader_parameter("day_energy", 0.62)
	_sun.rotation_degrees = Vector3(-7.0, 172.0, 0.0)   # 카메라 앞(북쪽) 낮은 해: 검과 기사가 역광으로 테가 진다
	_sun.light_color = Color(1.0, 0.52, 0.3)
	_sun.light_energy = 1.25
	env.ambient_light_energy = 0.38
	# 먼 산은 짙고 어두운 노을 안개에 묻혀 그림자처럼(모난 산 모양이 드러나지 않게)
	env.fog_light_color = Color(0.2, 0.13, 0.11)
	env.fog_density = 0.011
	env.fog_aerial_perspective = 0.45
	env.adjustment_saturation = 0.82


## 가운데 검: 칼날이 땅에 박혀 조금 기울었고, 등급 빛이 코등이 둘레를 은은하게 비춘다.
func _hero(data: GameData) -> void:
	var col: Color = data.grades.colors[HERO_GRADE] if data.grades.colors.size() > HERO_GRADE else Color(1.0, 0.75, 0.3)
	var form: FormData = data.forms[1] if data.forms.size() > 1 else null
	var sw := SwordModel.make(form, HERO_GRADE, HERO_SEED, col)
	sw.basis = Basis.from_euler(Vector3(PI + 0.12, 0.6, 0.07))
	sw.position = HERO_AT + Vector3(0.0, 0.55, 0.0)
	add_child(sw)
	_glow = OmniLight3D.new()
	_glow.light_color = col.lerp(Color(1.0, 0.7, 0.4), 0.5)
	_glow.light_energy = 0.9
	_glow.omni_range = 4.5
	_glow.position = HERO_AT + Vector3(0.0, 0.9, 0.0)
	add_child(_glow)
	# 앞쪽에 몇 자루 더(녹슬고 기울어진 보통 검): 화면에 깊이를 준다
	var spots: Array = [Vector3(-2.4, 0.0, -1.2), Vector3(1.8, 0.0, -3.4), Vector3(-0.9, 0.0, -5.6), Vector3(3.6, 0.0, -1.0), Vector3(-4.2, 0.0, -4.4)]
	for i in spots.size():
		var f: FormData = data.forms[i % data.forms.size()] if not data.forms.is_empty() else null
		var o := SwordModel.make(f, 0, 900 + i * 31, Color.WHITE)
		o.basis = Basis.from_euler(Vector3(PI + _rng.randf_range(-0.4, 0.4), _rng.randf() * TAU, _rng.randf_range(-0.4, 0.4)))
		o.position = HERO_AT + spots[i] + Vector3(0.0, _rng.randf_range(0.25, 0.7), 0.0)
		add_child(o)


## 검 둘레에서 오르는 불씨. 대부분 아주 작고 몇 개만 크다. 더해 그리기(빛나 보인다), 바람 쪽으로 기울며
## 맴돌고, 살아 있는 동안 깜빡이다 작아지며 꺼진다. 색은 개마다 검붉은빛~누런빛.
func _embers() -> void:
	var p := CPUParticles3D.new()
	p.amount = 46
	p.lifetime = 6.5
	p.preprocess = 6.5
	p.randomness = 0.7
	p.position = HERO_AT + Vector3(0.0, 0.1, 0.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 3.2
	p.direction = Vector3(0.3, 1.0, 0.0)
	p.spread = 22.0
	p.gravity = Vector3(0.28, 0.2, 0.05)
	p.initial_velocity_min = 0.15
	p.initial_velocity_max = 0.55
	p.tangential_accel_min = -0.5
	p.tangential_accel_max = 0.5
	p.damping_min = 0.02
	p.damping_max = 0.08
	p.scale_amount_min = 0.35
	p.scale_amount_max = 1.7
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.2))
	grow.add_point(Vector2(0.08, 1.0))
	grow.add_point(Vector2(0.65, 0.75))
	grow.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = grow
	var hue := Gradient.new()
	hue.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	hue.colors = PackedColorArray([Color(0.85, 0.22, 0.05), Color(1.0, 0.5, 0.14), Color(1.0, 0.78, 0.42)])
	p.color_initial_ramp = hue
	var life := Gradient.new()   # 흰색에 알파만: 켜졌다가 두어 번 깜빡이고 꺼진다
	life.offsets = PackedFloat32Array([0.0, 0.06, 0.42, 0.5, 0.58, 0.8, 0.86, 1.0])
	life.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0.25), Color(1, 1, 1, 0)])
	p.color_ramp = life
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = _dot(0.18)
	m.albedo_color = Color(1.6, 1.6, 1.6)   # 더해 그릴 때 가운데가 하얗게 타오르게
	q.material = m
	p.mesh = q
	add_child(p)


## 가운데가 진하고 가장자리로 사라지는 둥근 점. core가 작을수록 또렷한 알갱이, 클수록 흐릿한 솜.
static func _dot(core: float = 0.35) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, core, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t


## 바람에 천천히 떠가는 재. 네모 알갱이가 빠르게 지나가면 화면 잡음처럼 보여서,
## 흐릿한 둥근 송이를 적게, 느리게, 맴돌며 가라앉게 한다. 카메라 가까이 큰 송이 몇 개는 초점이 나간 듯 크게 흐리다.
func _ash() -> void:
	_ash_layer(HERO_AT + Vector3(-8.0, 3.0, -2.0), Vector3(6.0, 3.5, 12.0), 55, 0.06, 0.32, 0.45)
	_ash_layer(HERO_AT + Vector3(CAM_SIDE - 4.0, CAM_H, CAM_R - 3.0), Vector3(3.0, 1.5, 1.5), 7, 0.22, 0.12, 0.85)


func _ash_layer(at: Vector3, box: Vector3, amount: int, size: float, alpha: float, core: float) -> void:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 14.0
	p.preprocess = 14.0
	p.randomness = 0.8
	p.position = at
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = box
	p.direction = Vector3(1.0, -0.2, 0.12)
	p.spread = 18.0
	p.gravity = Vector3(0.05, -0.07, 0.0)
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.75
	p.tangential_accel_min = -0.15
	p.tangential_accel_max = 0.15
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.6
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.2, 0.75, 1.0])
	fade.colors = PackedColorArray([Color(0.3, 0.28, 0.26, 0), Color(0.3, 0.28, 0.26, alpha), Color(0.24, 0.22, 0.21, alpha * 0.8), Color(0.24, 0.22, 0.21, 0)])
	p.color_ramp = fade
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = _dot(core)
	q.material = m
	p.mesh = q
	add_child(p)


## 영주 기사 모델이 있으면 검 앞에 서서 검을 내려다본다(동작은 서 있기).
func _knight() -> void:
	if not LordCharacter.available():
		return
	var k := LordCharacter.new()
	var at: Vector3 = HERO_AT + Vector3(-0.9, 0.0, 0.7)   # 검 왼쪽 앞: 화면 가운데와 검 사이에 역광으로 선다
	k.position = at
	add_child(k)
	k.look_at(Vector3(HERO_AT.x, at.y, HERO_AT.z), Vector3.UP)
	k.play("idle", 0.6)


# ---------------------------------------------------------------- 카메라

## 검의 남쪽에서 북쪽을 본다. 좌우로 아주 천천히 흔들리고 숨 쉬듯 조금 오르내린다. 하늘이 위 절반을 차지한다.
func _place_camera(_delta: float) -> void:
	var a: float = sin(_t * SWAY_SPEED * TAU) * SWAY
	var bob: float = sin(_t * 0.35) * 0.06
	var pos := HERO_AT + Vector3(CAM_SIDE + sin(a) * CAM_R, CAM_H + bob, cos(a) * CAM_R)
	_camera.position = pos
	_camera.look_at(HERO_AT + Vector3(CAM_SIDE * 1.4, 1.35, -6.0), Vector3.UP)


func _process(delta: float) -> void:
	_t += delta
	_place_camera(delta)
	if _glow:
		_glow.light_energy = 0.8 + 0.18 * sin(_t * 1.7) + 0.08 * sin(_t * 4.3 + 1.0)   # 숨 쉬는 듯 흔들리는 등급 빛
	if _prompt and not _menu_on:
		_prompt.modulate.a = 0.35 + 0.45 * (0.5 + 0.5 * sin(_t * 2.0))


# ---------------------------------------------------------------- 글자

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(root)
	UiKit.vignette(root)
	# 위아래를 조금 더 어둡게(글자가 하늘과 땅에서 잘 읽히게)
	for top in [true, false]:
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(0, 0, 0, 0.55 if top else 0.72), Color(0, 0, 0, 0.0)])
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill_from = Vector2(0.5, 0.0 if top else 1.0)
		tex.fill_to = Vector2(0.5, 1.0 if top else 0.0)
		var band := TextureRect.new()
		band.texture = tex
		band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		band.stretch_mode = TextureRect.STRETCH_SCALE
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		var h: float = 260.0 if top else 380.0
		band.custom_minimum_size = Vector2(0, h)
		if top:
			band.offset_bottom = h
		else:
			band.offset_top = -h
		root.add_child(band)
	# 제목: 화면 위쪽 1/4, 글자 사이를 띄우고 아래에 가는 줄
	var head := VBoxContainer.new()
	head.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	head.anchor_top = 0.16
	head.anchor_bottom = 0.16
	head.grow_horizontal = Control.GROW_DIRECTION_BOTH
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 10)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(head)
	var t := UiKit.label("검 의   언 덕", 76, UiKit.TITLE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiKit.soft_shadow(t, 0.6)
	head.add_child(t)
	var rule := UiKit.rule(520, UiKit.LINE, 0.8)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	head.add_child(rule)
	_title = head
	# "아무 키나 누르세요"(깜빡임) → 누르면 메뉴
	_prompt = UiKit.label("아무 키나 누르세요", 22, UiKit.TEXT)
	UiKit.soft_shadow(_prompt)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.anchor_top = 0.86
	_prompt.anchor_bottom = 0.86
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(_prompt)
	_menu = VBoxContainer.new()
	_menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_menu.anchor_top = 0.7
	_menu.anchor_bottom = 0.7
	_menu.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_menu.add_theme_constant_override("separation", 4)
	_menu.modulate.a = 0.0
	_menu.visible = false
	root.add_child(_menu)
	var items: Array = [["시작", _start], ["설정", _settings]]
	if not OS.has_feature("web"):
		items.append(["끝내기", _quit])   # 웹판에는 끝내기가 없다
	for item in items:
		_menu.add_child(_menu_button(item[0], item[1]))
	# 검은 데서 밝아진다
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, FADE_IN).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_title.modulate.a = 0.0
	_prompt.modulate.a = 0.0
	var tw2 := create_tween()
	tw2.tween_interval(FADE_IN * 0.6)
	tw2.tween_property(_title, "modulate:a", 1.0, 1.6)


## 메뉴 한 줄: 평소엔 글자만, 마우스를 올리면 뒤에 가운데가 진한 가로 띠(엘든 링식).
func _menu_button(text: String, f: Callable) -> Button:
	var b := UiKit.button(text, f, 44)
	b.custom_minimum_size = Vector2(360, 44)
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_color_override("font_color", UiKit.TEXT)
	b.add_theme_color_override("font_hover_color", UiKit.TITLE)
	b.add_theme_color_override("font_pressed_color", UiKit.TITLE)
	UiKit.soft_shadow(b, 0.7)   # 테두리 없이: 아래쪽 어두운 띠가 글자를 받쳐 준다
	var empty := StyleBoxEmpty.new()
	var bar := StyleBoxTexture.new()
	bar.texture = UiKit.fade_texture(Color(0.0, 0.0, 0.0), 0.7, 0.3)
	var lit := StyleBoxTexture.new()
	lit.texture = UiKit.fade_texture(UiKit.LINE, 0.22, 0.3)
	b.add_theme_stylebox_override("normal", empty)
	b.add_theme_stylebox_override("hover", lit)
	b.add_theme_stylebox_override("pressed", lit)
	b.add_theme_stylebox_override("focus", empty)
	return b


func _show_menu() -> void:
	if _menu_on:
		return
	_menu_on = true
	var tw := create_tween()
	tw.tween_property(_prompt, "modulate:a", 0.0, 0.3)
	_menu.visible = true
	tw.tween_property(_menu, "modulate:a", 1.0, 0.5)


func _unhandled_input(event: InputEvent) -> void:
	if _leaving or get_node_or_null("UiSettings"):
		return
	var k := event as InputEventKey
	var mb := event as InputEventMouseButton
	var pressed: bool = (k and k.pressed and not k.echo) or (mb and mb.pressed) or (event is InputEventJoypadButton and event.pressed)
	if not pressed:
		return
	if not _menu_on:
		if _fade.color.a > 0.6:
			return   # 아직 밝아지는 중
		_show_menu()
		get_viewport().set_input_as_handled()
		return
	if k and (k.physical_keycode == KEY_ENTER or k.physical_keycode == KEY_KP_ENTER):
		_start()


# ---------------------------------------------------------------- 메뉴

func _start() -> void:
	if _leaving:
		return
	_leaving = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.7)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file(LOBBY))


func _settings() -> void:
	var p := SettingsPanel.new()
	p.name = "UiSettings"
	p.pause_game = false
	_ui.add_child(p)
	_menu.modulate.a = 0.0
	_title.modulate.a = 0.25
	p.closed.connect(func() -> void:
		_menu.modulate.a = 1.0
		_title.modulate.a = 1.0)
	p.open()


func _quit() -> void:
	get_tree().quit()
