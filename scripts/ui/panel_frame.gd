class_name PanelFrame
extends Control
## 창 테두리 장식(2026-11-23, 대화·상호작용 UI 다시 그림): 네 귀퉁이의 놋쇠 꺾쇠와 마름모 징, 안쪽 가는 둘째 테,
## 위 테를 천천히 훑는 빛 한 점. UiKit.center_panel이 판 위에 덮는다(누르기는 통과).

var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_t = randf() * 5.0   # 꾸밈: 창마다 빛이 다른 때에 지나간다


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var c := Color(UiKit.LINE, 0.9)
	var k: float = 18.0
	draw_rect(Rect2(Vector2(5, 5), size - Vector2(10, 10)), Color(UiKit.LINE, 0.14), false, 1.0)
	for corner in [Vector2(0, 0), Vector2(w, 0), Vector2(0, h), Vector2(w, h)]:
		var sx: float = 1.0 if corner.x == 0.0 else -1.0
		var sy: float = 1.0 if corner.y == 0.0 else -1.0
		draw_line(corner, corner + Vector2(sx * k, 0), c, 2.0)
		draw_line(corner, corner + Vector2(0, sy * k), c, 2.0)
		var d: Vector2 = corner + Vector2(sx * 6.0, sy * 6.0)
		draw_colored_polygon(PackedVector2Array([d + Vector2(0, -3), d + Vector2(3, 0), d + Vector2(0, 3), d + Vector2(-3, 0)]), c)
	# 위 가운데 장식: 마름모 하나와 양쪽으로 사라지는 짧은 줄
	var m := Vector2(w / 2.0, 0.0)
	draw_colored_polygon(PackedVector2Array([m + Vector2(0, -5), m + Vector2(5, 0), m + Vector2(0, 5), m + Vector2(-5, 0)]), Color(0.07, 0.06, 0.05))
	draw_polyline(PackedVector2Array([m + Vector2(0, -5), m + Vector2(5, 0), m + Vector2(0, 5), m + Vector2(-5, 0), m + Vector2(0, -5)]), c, 1.2, true)
	# 위 테를 훑는 빛
	var g: float = fmod(_t * 0.18, 1.8)
	if g < 1.0:
		var gx: float = lerpf(k, w - k, g)
		for i in range(-10, 11):
			var a: float = 1.0 - absf(float(i)) / 10.0
			draw_line(Vector2(gx + i * 4.0, 0.5), Vector2(gx + i * 4.0 + 4.0, 0.5), Color(1.0, 0.86, 0.58, a * a * 0.9), 2.0)
