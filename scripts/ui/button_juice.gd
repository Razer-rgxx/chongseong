class_name ButtonJuice
extends RefCounted
## 단추 손맛(2026-11-24, docs/dopamine.md): 마우스를 올리면 살짝 커지고 밝아지며, 누르면 쑥 들어갔다가 튀어나온다.
## 트리에 붙는 모든 단추(Button)에 저절로 붙는다. GameSettings.ensure()가 처음 한 번 install을 부른다.
## 컨테이너 안의 단추는 컨테이너가 다시 놓을 때 크기 배수가 1로 돌아갈 수 있다(그래도 밝기는 남는다).

const HOVER := 1.035
const PRESS := 0.94
const BRIGHT := Color(1.18, 1.12, 1.02)

static var _installed: bool = false


static func install(tree: SceneTree) -> void:
	if _installed or tree == null:
		return
	_installed = true
	tree.node_added.connect(func(n: Node) -> void:
		if n is Button:
			attach(n as Button))


static func attach(b: Button) -> void:
	if b.has_meta(&"juice"):
		return
	b.set_meta(&"juice", true)
	b.mouse_entered.connect(func() -> void:
		if b.disabled:
			return
		_to(b, Vector2.ONE * HOVER, BRIGHT, 0.08))
	b.mouse_exited.connect(func() -> void: _to(b, Vector2.ONE, Color.WHITE, 0.12))
	b.button_down.connect(func() -> void:
		if b.disabled:
			return
		_to(b, Vector2.ONE * PRESS, BRIGHT, 0.05))
	b.button_up.connect(func() -> void:
		var hover: bool = b.is_hovered()
		b.pivot_offset = b.size * 0.5
		var tw := b.create_tween().set_ignore_time_scale(true)
		tw.tween_property(b, "scale", Vector2.ONE * (HOVER * 1.03 if hover else 1.03), 0.06)
		tw.tween_property(b, "scale", Vector2.ONE * (HOVER if hover else 1.0), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(b, "self_modulate", BRIGHT if hover else Color.WHITE, 0.14))


static func _to(b: Button, s: Vector2, c: Color, t: float) -> void:
	if not b.is_inside_tree():
		return
	b.pivot_offset = b.size * 0.5
	var tw := b.create_tween().set_parallel().set_ignore_time_scale(true)
	tw.tween_property(b, "scale", s, t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(b, "self_modulate", c, t)
