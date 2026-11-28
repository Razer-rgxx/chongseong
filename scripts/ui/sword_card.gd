class_name SwordCard
extends RefCounted
## 검 카드의 글(BBCode). 언덕의 두 칸, 고르기 창, 마을의 대장간이 같이 쓴다.


## slot이 0 이상이면 [1] 같은 칸 번호를 붙인다. held: 비었을 때 "맨손"으로 쓸지.
static func bbcode(s: Sword, data: GameData, slot: int = -1, held: bool = false) -> String:
	var key: String = "" if slot < 0 else "  [color=#8b96b3][%d][/color]" % (slot + 1)
	if s == null:
		return "[b][color=#8b96b3]%s[/color][/b]%s" % ["맨손" if held else "빈 칸", key]   # 채우는 법은 손잡이 앞 E가 말한다
	var col: String = data.grades.colors[s.grade].to_html(false)
	var dmg: int = roundi(s.damage(data))
	var dur: String = "∞" if not s.breakable() else "%d/%d" % [ceili(s.durability), s.max_durability]
	var t: String = "[b][color=#%s]%s[/color][/b]%s\n[color=#aab4c8]%s %s · 피해 %d · 내구 %s[/color]" % [col, s.label(), key, data.grades.names[s.grade], s.form.display_name, dmg, dur]
	var atk: String = attack_bbcode(s.pattern)
	if atk != "":
		t += "\n" + atk
	for k in s.ins:
		var ins: InscriptionData = data.inscriptions.get(k)
		if ins:
			t += "\n[b]%s[/b]  %s%s" % [k, ins.describe(s.grade), " [color=#8b96b3](덧붙임)[/color]" if s.extra_ins.has(k) else ""]
	if s.data.unique_text != "":
		t += "\n[color=#ffe2a0]%s[/color]" % s.data.unique_text
		if not s.data.unique_ready:
			t += " [color=#c0566a](아직 작동 안 함)[/color]"
	return t


## 좌클릭 공격 방식 두 줄: 방식 이름(메아리가 있으면 "· 메아리"), 그 아래 동작 아이콘을 차례로(이음은 조금 어둡게,
## 마지막 = 마무리는 밝고 크게, 앞에 "›"), 속성 아이콘, 갈고리 검이면 "우클릭 갈고리". 아이콘은 MoveIcons(assets/ui/moves/*.svg).
static func attack_bbcode(p: PatternData, size: int = 28) -> String:
	if p == null or p.steps() == 0:
		return ""
	var t: String = "[color=#e6d3a3]%s[/color]" % p.display_name
	if p.echo:
		t += " [color=#8b96b3]· 메아리[/color]"
	t += "\n"
	var n: int = p.steps()
	for k in n:
		var id: StringName = p.move_at(k + 1)
		var fin: bool = k == n - 1 and n > 1
		if k > 0:
			t += "[color=#d9b46a] › [/color]" if fin else "[color=#6f6450] · [/color]"
		t += _icon(MoveIcons.icon(id), size + 8 if fin else size, "#ffffff" if fin else "#b8b0a0", String(id))
	var el: Texture2D = MoveIcons.element(p.element)
	if el:
		t += "    " + _icon(el, size, "#ffffff", String(p.element))
	if p.has_hook():
		t += "    [color=#d9b46a]우클릭 갈고리[/color]"
	return t


## [img]는 width=·height=·color=만 쓴다([img=center,…]처럼 앞에 값을 붙이면 크기가 먹지 않는다). color는 곱해져 어두워지기만 한다.
static func _icon(tex: Texture2D, size: int, color: String, fallback: String) -> String:
	if tex == null or tex.resource_path == "":
		return "[color=%s]%s[/color]" % [color, fallback]
	return "[img width=%d height=%d color=%s]%s[/img]" % [size, size, color, tex.resource_path]
