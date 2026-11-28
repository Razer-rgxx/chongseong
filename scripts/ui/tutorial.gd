class_name Tutorial
extends CanvasLayer
## 튜토리얼(2026-11-23): 첫 판에만, 화면 아래 가운데에 한 줄씩. 해낸 줄은 사라지고 다음 줄이 뜬다.
## 규칙(Rules)을 읽기만 한다. 걸음 → 베기 → 검 뽑기 → 사건 이기기 → 깨어난 검 → 정산 순서.

var rules: Rules
var _label: Label
var _step: int = 0
var _start: Vector2
var _swings: int = 0
var _fade: float = 0.0

const LINES: Array[String] = [
	"WASD로 걷는다",
	"클릭으로 벤다. 손에 쥔 것은 초보자의 검",
	"땅에 꽂힌 손잡이에 다가가 E를 누르고 있으면 검을 뽑는다",
	"뽑으면 그 검의 주인이 깨어난다. 이겨야 검을 얻는다",
	"붉게 빛나는 검은 깨어난 검. 등급이 올랐지만 주인이 다가온다. 땅의 점선이 다음에 깨어날 검이다",
	"준비되면 N. 깨어난 검의 주인이 한꺼번에 온다(정산)",
]


func setup(r: Rules) -> void:
	rules = r
	_start = r.lord.pos
	layer = 6
	_label = Label.new()
	_label.anchor_left = 0.5
	_label.anchor_right = 0.5
	_label.anchor_top = 0.84
	_label.offset_left = -420
	_label.offset_right = 420
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_color", Color(0.93, 0.88, 0.76))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("outline_size", 6)
	add_child(_label)


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_swings += 1
	elif ev is InputEventKey and ev.pressed and (ev as InputEventKey).physical_keycode == KEY_J:
		_swings += 1


func _done(i: int) -> bool:
	match i:
		0: return rules.lord.pos.distance_to(_start) > 3.0
		1: return _swings >= 3
		2: return rules.pull_hilt != null or rules.hz != null and rules.hz.blades.any(func(b): return b.state != HillZone.State.SLEEP)
		3: return rules.hz == null or rules.hz.blades.any(func(b): return b.state == HillZone.State.DONE)
		4: return rules.hz == null or rules.hz.awake_count() == 0 and rules.hz.blades.any(func(b): return b.state == HillZone.State.DONE) or _fade > 9.0
		5: return rules.phase != Rules.Phase.DAY
	return true


func _process(delta: float) -> void:
	if rules == null or _step >= LINES.size() or rules.phase == Rules.Phase.OVER:
		visible = false
		return
	_fade += delta
	if _done(_step):
		_step += 1
		_fade = 0.0
		if _step >= LINES.size():
			queue_free()
			return
	_label.text = LINES[_step]
	_label.modulate.a = clampf(_fade * 2.0, 0.0, 1.0)
