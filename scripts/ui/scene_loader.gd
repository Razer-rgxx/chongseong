class_name SceneLoader
extends CanvasLayer
## 장면을 바꿀 때의 불러오기 화면(2026-11-24 사용자: "처음에 시작할 때 계속 기다려야 하는데 로딩 화면 만들자").
## `SceneLoader.go(get_tree(), 경로)`가 루트에 이 판을 얹고(장면이 바뀌어도 남는다), 장면을 따로 읽으며(load_threaded_request)
## 진행 줄을 채우고, 다 읽으면 장면을 바꾸고, 새 장면이 몇 화면 그려진 뒤(_ready의 무거운 짓기까지) 걷힌다.
## 모양: 게임을 찍은 그림(BACKDROP, 웹판 첫 화면과 같은 것)을 어둡게 깔고 천천히 다가가며, 가운데 아래 가는 놋쇠 줄이 차고,
## 그 위에 가는 곳 이름, 아래에 도움말 한 줄, 바닥에서 불씨가 오른다.
## 웹판(스레드 없음)은 읽는 동안 화면이 멈출 수 있지만 이 판은 먼저 그려 두고 읽는다.
## 도움말 TIPS는 웹판 첫 불러오기 화면(docs/web_build.py)도 같이 쓴다(그 파일이 여기서 글줄을 읽는다).

const TIPS: Array[String] = [
	"땅에 붉은 표시가 차오르면 곧 그 자리에 공격이 온다.",
	"구르는 동안에는 보스의 충격파와 떨어지는 칼을 지나칠 수 있다.",
	"화살은 칼로 쳐서 부러뜨릴 수 있다.",
	"손잡이가 버팀을 끝내기 직전에 E나 좌클릭을 맞추면 제대로 당긴다. 모두 맞히면 그 검의 최대 내구가 오른다.",
	"검집 강화는 검이 아니라 검집에 남는다. 넣는 검을 바꿔도 단계는 그대로다.",
	"검집 +5부터는 망치질에 실패하면 한 단계 내려간다.",
	"우두머리를 쓰러뜨리면 가끔 그 머리를 얻는다. 성소에서 쓸 수 있다.",
	"들판은 낮과 밤이 바뀐다. 밤에는 적이 더 멀리서 알아채고 더 세다.",
	"들판에서 쓰러지면 북문 앞에서 깨어난다.",
	"새벽에는 갈림길에서 다음 밤과 보상을 고른다.",
	"점쟁이는 손잡이의 참된 조짐을 보여 준다.",
	"무덤 기사는 체력이 절반 아래로 떨어지면 빨라진다.",
	"언덕지기에게서 멀리 달아나면 하늘에서 칼이 떨어진다.",
	"V로 3인칭과 쿼터뷰를 바꾸고, F10으로 설정 창을 연다.",
]

## 경로 → 가는 곳 이름.
const NAMES: Dictionary = {
	"res://scenes/title/title.tscn": "검의 언덕",
	"res://scenes/lobby/lobby.tscn": "언덕 아래 마을",
	"res://scenes/world/main.tscn": "언덕",
	"res://scenes/field/field.tscn": "들판",
	"res://scenes/crypt/crypt.tscn": "지하 무덤",
	"res://scenes/duel/duel.tscn": "결투",
}
const FADE_IN: float = 0.25
const FADE_OUT: float = 0.45
## 새 장면이 이만큼 그려진 뒤에 걷는다(첫 화면의 짓기·셰이더 굽기가 끝나게).
const SETTLE_FRAMES: int = 4
const BAR_W: float = 420.0
const BACKDROP: String = "res://assets/ui/loading/hill.jpg"

var path: String = ""
var _root: Control
var _bar: ColorRect
var _bar_back: ColorRect
var _name: Label
var _tip: Label
var _state: int = 0   # 0 판 띄우는 중, 1 읽는 중, 2 바꾼 뒤 기다림, 3 걷는 중
var _shown: float = 0.0
var _frames: int = 0
var _progress: float = 0.0
var _shown_p: float = 0.0
var _tip_t: float = 0.0
var _tip_i: int = 0
var _rng := RandomNumberGenerator.new()
var _pic: TextureRect


## 장면을 바꾼다(이미 바꾸는 중이면 무시). 지금 장면은 판이 덮은 뒤에 사라진다.
static func go(tree: SceneTree, to: String) -> void:
	if tree.root.get_node_or_null("SceneLoader") != null:
		return
	var l := SceneLoader.new()
	l.name = "SceneLoader"
	l.path = to
	tree.root.add_child(l)


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()   # 꾸밈용(도움말 고르기): 규칙의 rng와 무관
	_tip_i = _rng.randi() % TIPS.size()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.modulate.a = 0.0
	var th: Theme = load("res://assets/ui/theme.tres") as Theme
	if th:
		_root.theme = th
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.025, 0.02)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	var tex := load(BACKDROP) as Texture2D
	if tex:
		_pic = TextureRect.new()
		_pic.texture = tex
		_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_pic.set_anchors_preset(Control.PRESET_FULL_RECT)
		_pic.modulate = Color(0.42, 0.4, 0.38)
		_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(_pic)
		_root.resized.connect(func() -> void: _pic.pivot_offset = _root.size / 2.0)
		_pic.pivot_offset = get_viewport().get_visible_rect().size / 2.0
		UiKit.vignette(_root)
		# 아래쪽을 어둡게: 이름·도움말이 땅 위에서도 읽히게
		var g := Gradient.new()
		g.set_color(0, Color(0.02, 0.015, 0.01, 0.0))
		g.set_color(1, Color(0.02, 0.015, 0.01, 0.92))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill_from = Vector2(0.5, 0.0)
		gt.fill_to = Vector2(0.5, 1.0)
		gt.width = 4
		gt.height = 128
		var low := TextureRect.new()
		low.texture = gt
		low.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		low.stretch_mode = TextureRect.STRETCH_SCALE
		low.mouse_filter = Control.MOUSE_FILTER_IGNORE
		low.anchor_left = 0.0
		low.anchor_right = 1.0
		low.anchor_top = 0.5
		low.anchor_bottom = 1.0
		_root.add_child(low)
	_root.add_child(_embers())
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.grow_vertical = Control.GROW_DIRECTION_BEGIN
	col.offset_bottom = -110.0
	col.custom_minimum_size = Vector2(760, 0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	_root.add_child(col)
	_name = UiKit.label(NAMES.get(path, ""), 30, UiKit.TITLE)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiKit.soft_shadow(_name, 0.8)
	col.add_child(_name)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(BAR_W, 9)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(holder)
	_bar_back = ColorRect.new()
	_bar_back.color = Color(UiKit.LINE, 0.18)
	_bar_back.position = Vector2(0, 4)
	_bar_back.size = Vector2(BAR_W, 1)
	holder.add_child(_bar_back)
	_bar = ColorRect.new()
	_bar.color = UiKit.LINE
	_bar.position = Vector2(0, 3)
	_bar.size = Vector2(0, 3)
	holder.add_child(_bar)
	_tip = UiKit.label(TIPS[_tip_i], 16, UiKit.MUTED)
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.custom_minimum_size = Vector2(760, 0)
	col.add_child(_tip)


## 바닥에서 오르는 불씨(대사 띠와 같은 모양).
func _embers() -> CPUParticles2D:
	var e := CPUParticles2D.new()
	e.amount = 40
	e.lifetime = 4.0
	e.preprocess = 3.0
	e.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	var vp := get_viewport().get_visible_rect().size if get_viewport() else Vector2(1600, 900)
	e.emission_rect_extents = Vector2(vp.x * 0.5, 4.0)
	e.position = Vector2(vp.x * 0.5, vp.y + 6.0)
	e.direction = Vector2(0, -1)
	e.spread = 20.0
	e.gravity = Vector2(0, -5)
	e.initial_velocity_min = 14.0
	e.initial_velocity_max = 46.0
	e.scale_amount_min = 1.0
	e.scale_amount_max = 2.6
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.62, 0.25, 0.0))
	ramp.add_point(0.15, Color(1.0, 0.6, 0.22, 0.8))
	ramp.add_point(0.7, Color(0.9, 0.35, 0.12, 0.35))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.6, 0.2, 0.08, 0.0))
	e.color_ramp = ramp
	return e


func _process(delta: float) -> void:
	if _pic:
		_pic.scale = _pic.scale.lerp(Vector2.ONE * 1.06, 1.0 - exp(-0.08 * delta))   # 천천히 다가간다
	_tip_t += delta
	if _tip_t > 6.0:
		_tip_t = 0.0
		_tip_i = (_tip_i + 1) % TIPS.size()
		_tip.text = TIPS[_tip_i]
	match _state:
		0:
			_shown += delta
			_root.modulate.a = clampf(_shown / FADE_IN, 0.0, 1.0)
			if _shown >= FADE_IN + 0.05:   # 다 덮은 화면이 한 번 그려진 뒤 읽기 시작
				var err := ResourceLoader.load_threaded_request(path, "", true)
				if err != OK:
					get_tree().change_scene_to_file(path)   # 따로 못 읽으면 예전처럼
					_state = 2
				else:
					_state = 1
		1:
			var p: Array = []
			var st := ResourceLoader.load_threaded_get_status(path, p)
			if not p.is_empty():
				_progress = float(p[0]) * 0.85   # 남은 15%는 새 장면의 짓기
			if st == ResourceLoader.THREAD_LOAD_LOADED:
				var ps := ResourceLoader.load_threaded_get(path) as PackedScene
				get_tree().change_scene_to_packed(ps)
				_state = 2
				_frames = 0
			elif st == ResourceLoader.THREAD_LOAD_FAILED or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				get_tree().change_scene_to_file(path)
				_state = 2
				_frames = 0
		2:
			_frames += 1
			_progress = lerpf(0.85, 1.0, clampf(float(_frames) / SETTLE_FRAMES, 0.0, 1.0))
			if _frames >= SETTLE_FRAMES:
				_state = 3
				_shown = 0.0
		3:
			_shown += delta
			_root.modulate.a = 1.0 - clampf(_shown / FADE_OUT, 0.0, 1.0)
			if _shown >= FADE_OUT:
				queue_free()
	_shown_p = lerpf(_shown_p, _progress, 1.0 - exp(-10.0 * delta))
	_bar.size.x = BAR_W * _shown_p
