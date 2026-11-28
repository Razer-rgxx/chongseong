extends RefCounted
## 밸런스 테스트(2026-11-21, 사용자: "검이 너무 쎄서 밸런스가 안 맞음"): 기본 피해와 등급 배수를 내렸다.
## 흔한 장검은 1구역 늑대·궁수도 한 번에 못 베고, 가장 높은 등급도 흔한 검의 2.5배를 넘지 않는다. 맞은 잔챙이 머리 위에 체력 막대.
## run_all.gd가 부른다: run(데이터, check).


static func run(d: GameData, check: Callable) -> void:
	var common := d.lord.damage * d.forms[1].damage * d.grades.damage_mult[0]
	check.call(d.lord.damage == 13.0, "기본 피해 13(전에는 20)")
	check.call(common < d.enemies[&"wolf"].hp and common < d.enemies[&"archer"].hp, "흔한 장검(%.0f)은 1구역 늑대(%.0f)·궁수(%.0f)를 한 번에 못 벤다" % [common, d.enemies[&"wolf"].hp, d.enemies[&"archer"].hp])
	var m: PackedFloat32Array = d.grades.damage_mult
	var rising: bool = true
	for i in range(1, m.size()):
		rising = rising and m[i] > m[i - 1]
	check.call(rising and m[0] == 1.0 and m[m.size() - 1] <= 2.5, "등급 피해 배수는 오르되 무한도 2.5배까지 %s" % [m])
	var top := d.lord.damage * d.forms[2].damage * m[m.size() - 1] * d.lord.big_damage_mult
	check.call(top < d.enemies[&"giant"].hp, "무한 대검의 큰 베기(%.0f)도 1구역 거인(%.0f)을 한 번에 못 벤다" % [top, d.enemies[&"giant"].hp])
	# 체력 막대(같은 날): 잔챙이와 정예는 머리 위 막대, 보스·우두머리·허수아비는 없다
	var e := Enemy.new()
	e.data = d.enemies[&"wolf"]
	e.max_hp = e.data.hp
	var ok: bool = EnemyView.wants_bar(e)
	e.chief = &"wolf"
	ok = ok and not EnemyView.wants_bar(e)
	e.chief = &""
	e.data = d.enemies[&"boss"]
	ok = ok and not EnemyView.wants_bar(e)
	e.data = d.enemies[&"dummy"]
	e.max_hp = e.data.hp
	ok = ok and not EnemyView.wants_bar(e)
	check.call(ok, "체력 막대: 잔챙이에는 달고 보스·우두머리·허수아비에는 안 단다")
