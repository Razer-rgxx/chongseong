extends SceneTree
## data/cosmetics.tres를 만든다(영주 꾸미기 표, docs/cosmetics.md): godot --headless --path . -s scripts/debug/build_cosmetics.gd
## 손으로 .tres를 고치지 않고 이 표를 고쳐 다시 만든다. 자리마다 첫 줄이 기본이다.
## 줄: [id, 자리, 이름, 해금, 값(조각·티어·룬 자리), 열쇠(우두머리·막), 모양, 색, 색2]

const ROWS: Array = [
	# 망토: 기본은 처음의 붉은 망토. 색·무늬는 CosmeticArt.cape_texture가 그린다.
	["cape_red", "cape", "붉은 망토", "free", 0, "", "plain", Color(0.54, 0.11, 0.17), Color(0.54, 0.11, 0.17)],
	["cape_grey", "cape", "회색 모직 망토", "free", 0, "", "plain", Color(0.3, 0.3, 0.31), Color(0.3, 0.3, 0.31)],
	["cape_moss", "cape", "이끼빛 망토", "shards", 40, "", "plain", Color(0.17, 0.26, 0.17), Color(0.17, 0.26, 0.17)],
	["cape_night", "cape", "밤빛 가장자리 망토", "shards", 60, "", "trim", Color(0.08, 0.11, 0.2), Color(0.66, 0.56, 0.38)],
	["cape_stripe", "cape", "줄무늬 망토", "shards", 120, "", "stripe", Color(0.45, 0.12, 0.12), Color(0.14, 0.13, 0.12)],
	["cape_check", "cape", "체크 망토", "shards", 150, "", "check", Color(0.2, 0.25, 0.3), Color(0.1, 0.12, 0.15)],
	["cape_emblem", "cape", "검 문장 망토", "shards", 250, "", "emblem", Color(0.12, 0.12, 0.14), Color(0.8, 0.7, 0.4)],
	["cape_knight", "cape", "무덤 기사의 낡은 망토", "boss", 0, "grave_knight", "ragged", Color(0.2, 0.22, 0.26), Color(0.09, 0.1, 0.12)],
	["cape_shroud", "cape", "무덤 주인의 수의", "boss", 0, "crypt_lord", "ragged", Color(0.72, 0.7, 0.62), Color(0.18, 0.16, 0.15)],
	["cape_runes", "cape", "룬 자수 망토", "rune", 1, "", "rune", Color(0.14, 0.12, 0.1), Color(0.35, 0.62, 0.85)],
	["cape_platinum", "cape", "백금 외투", "league", 4, "", "trim", Color(0.66, 0.68, 0.72), Color(0.3, 0.33, 0.4)],
	["cape_immortal", "cape", "불멸의 망토", "league", 7, "", "emblem", Color(0.05, 0.04, 0.06), Color(0.9, 0.75, 0.35)],
	["cape_coat", "cape", "시간 건너는 코트", "story", 0, "act1", "trim", Color(0.07, 0.09, 0.11), Color(0.2, 0.8, 0.9)],
	["cape_anchor", "cape", "닻의 푸른 망토", "story", 0, "act3", "emblem", Color(0.1, 0.2, 0.3), Color(0.8, 0.85, 0.9)],
	# 머리: 기본은 맨머리(기본 도형 영주는 처음의 금관).
	["head_none", "head", "맨머리", "free", 0, "", "none", Color.WHITE, Color.WHITE],
	["head_band", "head", "검은 머리띠", "free", 0, "", "band", Color(0.08, 0.07, 0.07), Color(0.08, 0.07, 0.07)],
	["head_hood", "head", "두건", "shards", 30, "", "hood", Color(0.2, 0.18, 0.15), Color(0.12, 0.11, 0.1)],
	["head_kettle", "head", "챙 넓은 쇠모자", "shards", 80, "", "kettle", Color(0.35, 0.3, 0.24), Color(0.2, 0.17, 0.14)],
	["head_helm", "head", "철 투구", "shards", 100, "", "helm", Color(0.42, 0.43, 0.46), Color(0.2, 0.2, 0.22)],
	["head_circlet", "head", "철관", "shards", 140, "", "circlet", Color(0.62, 0.52, 0.3), Color(0.5, 0.12, 0.14)],
	["head_horn", "head", "뿔 투구", "shards", 220, "", "horn", Color(0.38, 0.38, 0.4), Color(0.85, 0.8, 0.7)],
	["head_knight", "head", "무덤 기사의 투구", "boss", 0, "grave_knight", "plume", Color(0.22, 0.24, 0.28), Color(0.5, 0.1, 0.1)],
	["head_bone", "head", "뼈관", "boss", 0, "crypt_lord", "spikes", Color(0.8, 0.78, 0.7), Color(0.3, 0.28, 0.25)],
	["head_runeband", "head", "룬 이마띠", "rune", 2, "", "runeband", Color(0.12, 0.1, 0.1), Color(0.35, 0.62, 0.85)],
	["head_ascend", "head", "승천의 투구", "league", 6, "", "plume", Color(0.7, 0.72, 0.76), Color(0.85, 0.7, 0.3)],
	["head_visor", "head", "시간의 바이저", "story", 0, "act1", "visor", Color(0.1, 0.1, 0.12), Color(0.2, 0.85, 0.95)],
	["head_anchor", "head", "닻의 관", "story", 0, "act3", "circlet", Color(0.55, 0.65, 0.75), Color(0.75, 0.88, 1.0)],
	# 베기 빛: 알파 0이면 쥔 검의 등급 색 그대로.
	["slash_grade", "slash", "검 본래의 빛", "free", 0, "", "slash", Color(0, 0, 0, 0), Color.WHITE],
	["slash_white", "slash", "흰빛", "free", 0, "", "slash", Color(0.95, 0.95, 1.0), Color.WHITE],
	["slash_ember", "slash", "불씨빛", "shards", 60, "", "slash", Color(1.0, 0.5, 0.15), Color.WHITE],
	["slash_frost", "slash", "서리빛", "shards", 60, "", "slash", Color(0.6, 0.85, 1.0), Color.WHITE],
	["slash_jade", "slash", "비취빛", "shards", 80, "", "slash", Color(0.3, 0.9, 0.6), Color.WHITE],
	["slash_violet", "slash", "보랏빛", "shards", 100, "", "slash", Color(0.65, 0.4, 1.0), Color.WHITE],
	["slash_blood", "slash", "핏빛", "shards", 150, "", "slash", Color(0.9, 0.12, 0.15), Color.WHITE],
	["slash_gold", "slash", "금빛", "league", 3, "", "slash", Color(1.0, 0.82, 0.35), Color.WHITE],
	["slash_void", "slash", "허무의 빛", "league", 7, "", "slash", Color(0.9, 0.25, 0.75), Color.WHITE],
	["slash_grave", "slash", "무덤빛", "boss", 0, "grave_knight", "slash", Color(0.45, 0.85, 0.8), Color.WHITE],
	["slash_bone", "slash", "뼈빛", "boss", 0, "crypt_lord", "slash", Color(0.95, 0.92, 0.78), Color.WHITE],
	["slash_rune", "slash", "룬빛", "rune", 3, "", "slash", Color(0.35, 0.62, 1.0), Color.WHITE],
	["slash_neon", "slash", "디지털 푸른빛", "story", 0, "act1", "slash", Color(0.2, 0.9, 1.0), Color.WHITE],
	["slash_anchor", "slash", "닻빛", "story", 0, "act3", "slash", Color(0.7, 0.85, 1.0), Color.WHITE],
]


func _init() -> void:
	var t := CosmeticTable.new()
	for r in ROWS:
		var it := CosmeticItem.new()
		it.id = StringName(r[0])
		it.slot = StringName(r[1])
		it.title = r[2]
		it.unlock = StringName(r[3])
		it.need = int(r[4])
		it.key = StringName(r[5])
		it.style = StringName(r[6])
		it.color = r[7]
		it.color2 = r[8]
		t.items.append(it)
	var err: int = ResourceSaver.save(t, "res://data/cosmetics.tres")
	print("cosmetics.tres ", t.items.size(), " 줄, 저장 ", err)
	quit(0 if err == OK else 1)
