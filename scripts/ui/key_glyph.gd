class_name KeyGlyph
extends Control
## 누를 키(2026-11-23): 놋쇠 테를 두른 마름모 안에 글자, 바깥에 천천히 도는 끊긴 고리, 숨 쉬듯 밝아지는 테.
## Band(다가갔을 때 안내)와 DialogueBox(다음)가 쓴다.

var label: Label
var _t: float = 0.0


static func make(size_px: float, font_size: int) -> KeyGlyph:
	var k := KeyGlyph.new()
	k.custom_minimum_size = Vector2(size_px, size_px)
	k.mouse_filter = Control.MOUSE_FILTER_IGNORE
	k.label = UiKit.label("", font_size, UiKit.TITLE)
	k.label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	k.label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	k.label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	k.add_child(k.label)
	return k


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var c: Vector2 = size / 2.0
	var r: float = minf(size.x, size.y) * 0.4
	var dia := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	draw_colored_polygon(dia, Color(0.05, 0.04, 0.03, 0.92))
	var pulse: float = 0.55 + 0.45 * (0.5 + 0.5 * sin(_t * 3.0))
	var line := Color(UiKit.LINE, pulse)
	dia.append(dia[0])
	draw_polyline(dia, line, 1.5, true)
	var inner := PackedVector2Array()
	for p in dia:
		inner.append(c + (p - c) * 0.78)
	draw_polyline(inner, Color(UiKit.LINE, 0.25), 1.0, true)
	# 바깥 고리: 세 토막이 천천히 돈다
	var rr: float = r * 1.32
	for k in 3:
		var a0: float = _t * 0.9 + k * TAU / 3.0
		draw_arc(c, rr, a0, a0 + 1.1, 16, Color(UiKit.LINE, 0.45), 1.2, true)
