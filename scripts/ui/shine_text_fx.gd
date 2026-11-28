class_name ShineTextFx
extends RichTextEffect
## 대사 속 이름(「…」)에 놋쇠빛이 천천히 훑고 지나간다(2026-11-23). [shine]…[/shine].

var bbcode := "shine"

const GOLD := Color(0.93, 0.78, 0.46)
const GLINT := Color(1.0, 0.95, 0.82)


func _process_custom_fx(c: CharFXTransform) -> bool:
	var now: float = Time.get_ticks_msec() / 1000.0
	var p: float = fmod(now * 0.9 - float(c.relative_index) * 0.08, 2.4)
	var g: float = clampf(1.0 - absf(p - 0.4) / 0.35, 0.0, 1.0)
	var a: float = c.color.a
	c.color = GOLD.lerp(GLINT, g)
	c.color.a = a
	return true
