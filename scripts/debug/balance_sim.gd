extends SceneTree
## 밸런스 시험(2026-11-26): 봇이 검 하나를 쥐고 들판 모드에서 무리를 차례로 상대한다. 검마다 "무리 하나를 치우는 데 걸린 초"와
## "잃은 체력"을 재서 일반 검과 사이버 검을 등급별로 견준다. 봇은 가장 가까운 적에게 걸어가 베고, 체력이 적으면 물러서지 않는다(단순하게).
## 돌리기: godot --headless --path . -s scripts/debug/balance_sim.gd [-- 시대(now|future|past) 구역 무리수]
## 결과는 표로 찍는다(파일은 안 남긴다). 규칙 난수는 시드를 고정해 같은 검은 같은 결과.

const PACK := {"foes": [[&"wolf", 3], [&"charger", 2], [&"shield", 1]], "wander": 2.0}
var data: GameData


func _init() -> void:
	data = GameData.load_default()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var era: StringName = StringName(args[0]) if args.size() > 0 else &""
	var zone: int = int(args[1]) if args.size() > 1 else 4
	var packs: int = int(args[2]) if args.size() > 2 else 3
	if era == &"now":
		era = &""
	print("시대 %s · 구역 %d · 무리 %d" % [era if era != &"" else "현재", zone, packs])
	print("등급\t종류\t자루\t무리당초\t잃은체력\t다 치움")
	for g in 6:
		for cyber in [false, true]:
			var ids: Array[int] = []
			for sw in data.swords:
				if sw.grade == g and sw.cyber == cyber and not sw.field_only and sw.id != CyberSwords.KATANA:
					ids.append(sw.id)
			if ids.is_empty():
				continue
			ids.shuffle()
			ids = ids.slice(0, 10)
			var t_sum: float = 0.0
			var hp_sum: float = 0.0
			var cleared: int = 0
			for id in ids:
				var r: Dictionary = _run(id, era, zone, packs)
				t_sum += r.t
				hp_sum += r.hp
				cleared += 1 if r.ok else 0
			print("%s\t%s\t%d\t%.1f\t%.0f\t%d/%d" % [data.grades.names[g], "사이버" if cyber else "일반", ids.size(), t_sum / ids.size() / packs, hp_sum / ids.size(), cleared, ids.size()])
	quit()


func _run(id: int, era: StringName, zone: int, packs: int) -> Dictionary:
	Grid.size = Vector2i(34, 22)
	var r := Rules.new(data, 1234 + id)
	r.era = era
	r.start_field()
	r.debug_god = false
	var s := Sword.new(data.sword_by_id(id), data)
	s.durability = 1e9
	s.max_durability = 1e9
	r.slots[0] = s
	r.active = 0
	r.lord.pos = Vector2(17, 11)
	var hp0: float = r.lord.hp
	var t: int = 0
	var limit: int = roundi(90.0 * packs / r.dt)
	var done: int = 0
	var def: Dictionary = PACK.duplicate(true)
	if era == &"future":
		def = FutureLayout.NEON_PACKS["plaza"].duplicate(true)
	elif era == &"past":
		def = PastLayout.PACKS[PastLayout.PACKS.keys()[2]].duplicate(true)
	def["zone"] = zone
	def["at"] = Vector2(17, 4)
	r.spawn_pack(&"p0", def)
	while t < limit and r.lord.hp > 0.0:
		var i := LordInput.new()
		var best: Enemy = null
		var bd: float = 1e9
		for e in r.enemies:
			if e.dead:
				continue
			var d: float = e.pos.distance_to(r.lord.pos)
			if d < bd:
				bd = d
				best = e
		if best == null:
			done += 1
			if done >= packs:
				break
			def["at"] = Vector2(17, 4) if done % 2 == 0 else Vector2(17, 18)
			r.spawn_pack(StringName("p%d" % done), def)
		else:
			var dir: Vector2 = best.pos - r.lord.pos
			i.aim_valid = true
			i.aim = best.pos
			if dir.length() > 1.3 + best.radius:
				i.move = dir.normalized()
			i.attack = dir.length() < 2.6 + best.radius
		r.step(i)
		t += 1
	return {"t": t * r.dt, "hp": hp0 - maxf(r.lord.hp, 0.0), "ok": done >= packs}
