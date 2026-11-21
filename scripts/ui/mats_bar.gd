class_name MatsBar
extends HBoxContainer
## 재료 수(2026-11-21 마을 키우기 1단계): 나무·돌·쇠를 그림 하나와 숫자로. 이름 글자는 쓰지 않는다(그림이 곧 그 말).
## 얻으면 그 숫자 위에 "+N"이 잠깐 떴다 사라진다. 마을·들판·무덤 오른쪽 아래(lobby_hud), 조각 옆.

const ICON: float = 18.0
const COLORS: Dictionary = {
	&"wood": Color(0.55, 0.36, 0.2),
	&"stone": Color(0.58, 0.57, 0.54),
	&"iron": Color(0.62, 0.66, 0.72),
}

var _nums: Dictionary = {}
var _boxes: Dictionary = {}


func _init() -> void:
	add_theme_constant_override("separation", 16)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for id in Meta.MAT_IDS:
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := Control.new()
		icon.custom_minimum_size = Vector2(ICON, ICON)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.tooltip_text = Meta.MAT_NAMES[id]
		var kind: StringName = id
		icon.draw.connect(func() -> void: draw_icon(icon, kind))
		box.add_child(icon)
		var n := UiKit.label("0", 18, UiKit.TEXT)
		box.add_child(n)
		add_child(box)
		_nums[id] = n
		_boxes[id] = box


func refresh(m: Meta) -> void:
	for id in Meta.MAT_IDS:
		(_nums[id] as Label).text = str(m.mat(id))


## 얻은 몫을 숫자 위에 잠깐 띄운다.
func pop(id: StringName, n: int) -> void:
	if not _boxes.has(id) or n == 0:
		return
	var l := UiKit.label(("+%d" if n > 0 else "%d") % n, 16, UiKit.TITLE)
	UiKit.soft_shadow(l, 0.8)
	l.top_level = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	var at: Vector2 = (_boxes[id] as Control).global_position + Vector2(ICON + 4.0, -22.0)
	l.global_position = at
	var t := l.create_tween()
	t.set_parallel(true)
	t.tween_property(l, "global_position:y", at.y - 18.0, 1.1)
	t.tween_property(l, "modulate:a", 0.0, 1.1).set_delay(0.4)
	t.chain().tween_callback(l.queue_free)


## 재료 그림: 나무는 나이테 진 통나무 끝, 돌은 모난 덩이, 쇠는 덩이쇠(사다리꼴).
static func draw_icon(c: Control, id: StringName) -> void:
	var s: float = ICON
	var col: Color = COLORS.get(id, Color.WHITE)
	match id:
		&"wood":
			c.draw_circle(Vector2(s / 2.0, s / 2.0), s * 0.46, col.darkened(0.35))
			c.draw_circle(Vector2(s / 2.0, s / 2.0), s * 0.38, col)
			c.draw_arc(Vector2(s / 2.0, s / 2.0), s * 0.24, 0.0, TAU, 16, col.darkened(0.3), 1.2)
			c.draw_circle(Vector2(s / 2.0, s / 2.0), s * 0.07, col.darkened(0.4))
		&"stone":
			var p := PackedVector2Array([Vector2(0.12, 0.62), Vector2(0.3, 0.2), Vector2(0.66, 0.12), Vector2(0.92, 0.45), Vector2(0.78, 0.88), Vector2(0.28, 0.9)])
			for i in p.size():
				p[i] *= s
			c.draw_colored_polygon(p, col)
			c.draw_polyline(p + PackedVector2Array([p[0]]), col.darkened(0.4), 1.2)
			c.draw_line(Vector2(0.42, 0.3) * s, Vector2(0.55, 0.62) * s, col.darkened(0.3), 1.0)
		&"iron":
			var p := PackedVector2Array([Vector2(0.05, 0.78), Vector2(0.22, 0.3), Vector2(0.78, 0.3), Vector2(0.95, 0.78)])
			for i in p.size():
				p[i] *= s
			c.draw_colored_polygon(p, col.darkened(0.2))
			c.draw_colored_polygon(PackedVector2Array([p[1], p[2], Vector2(0.72, 0.44) * s, Vector2(0.28, 0.44) * s]), col.lightened(0.25))
			c.draw_polyline(p + PackedVector2Array([p[0]]), col.darkened(0.5), 1.2)
