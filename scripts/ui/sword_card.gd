class_name SwordCard
extends RefCounted
## 검 카드의 글(BBCode). 언덕의 두 칸, 고르기 창, 마을의 대장간이 같이 쓴다.


## slot이 0 이상이면 [1] 같은 칸 번호를 붙인다. held: 비었을 때 "맨손"으로 쓸지.
static func bbcode(s: Sword, data: GameData, slot: int = -1, held: bool = false) -> String:
	var key: String = "" if slot < 0 else "  [color=#8b96b3][%d][/color]" % (slot + 1)
	if s == null:
		return "[b][color=#8b96b3]%s[/color][/b]%s\n[color=#8b96b3]낮에 검을 뽑아 채워[/color]" % ["맨손" if held else "빈 칸", key]
	var col: String = data.grades.colors[s.grade].to_html(false)
	var dmg: int = roundi(s.damage(data))
	var dur: String = "∞" if not s.breakable() else "%d/%d" % [ceili(s.durability), s.max_durability]
	var t: String = "[b][color=#%s]%s[/color][/b]%s\n[color=#aab4c8]%s %s · 피해 %d · 내구 %s[/color]" % [col, s.label(), key, data.grades.names[s.grade], s.form.display_name, dmg, dur]
	for k in s.ins:
		var ins: InscriptionData = data.inscriptions.get(k)
		if ins:
			t += "\n[b]%s[/b]  %s%s" % [k, ins.describe(s.grade), " [color=#8b96b3](덧붙임)[/color]" if s.extra_ins.has(k) else ""]
	if s.data.unique_text != "":
		t += "\n[color=#ffe2a0]%s[/color]" % s.data.unique_text
		if not s.data.unique_ready:
			t += " [color=#c0566a](아직 작동 안 함)[/color]"
	return t
