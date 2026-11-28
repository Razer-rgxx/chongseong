class_name ForgeTextFx
extends RichTextEffect
## 대사 글자가 하나씩 "벼려져" 나온다(2026-11-23): 아래에서 살짝 떠오르며 나타나고, 처음엔 달군 쇠처럼 붉게 빛나다 식는다.
## [forge t0=시각]…[/forge]. t0은 Time.get_ticks_msec()/1000(줄을 띄운 순간). 시간을 따로 재므로 줄마다 처음부터 다시 돈다.

var bbcode := "forge"

const STEP: float = 0.024      ## 글자 사이(초)
const APPEAR: float = 0.16
const RISE: float = 9.0
const COOL: float = 0.55
const HOT := Color(1.0, 0.62, 0.28)


func _process_custom_fx(c: CharFXTransform) -> bool:
	var now: float = Time.get_ticks_msec() / 1000.0
	var local: float = now - float(c.env.get("t0", 0.0)) - float(c.relative_index) * STEP
	if local <= 0.0:
		c.color.a = 0.0
		return true
	var a: float = clampf(local / APPEAR, 0.0, 1.0)
	var e: float = 1.0 - pow(1.0 - clampf(local / 0.3, 0.0, 1.0), 3.0)
	c.offset = Vector2(0.0, (1.0 - e) * RISE)
	var heat: float = clampf(1.0 - local / COOL, 0.0, 1.0)
	var base: Color = c.color
	c.color = base.lerp(HOT, heat * 0.85)
	c.color.a = base.a * a
	return true
