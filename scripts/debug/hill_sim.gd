extends SceneTree
## 언덕 판 밸런스 시험(2026-11-26): 단순한 봇이 언덕 판을 끝까지(또는 쓰러질 때까지) 한다.
## 낮: 가장 가까운 손잡이로 가서 뽑고(타이밍 누름은 버팀마다 한 번), 고르기는 등급이 높은 쪽, 거래는 받는다, 갈림길은 첫째.
## 둘레 12칸 안에 적이 있으면 가장 가까운 적을 벤다. 손잡이가 없으면 밤을 연다.
## 돌리기: godot --headless --path . -s scripts/debug/hill_sim.gd [-- 판수 지난판수(runs)]
## 찍는 것: 판마다 닿은 구역·이김·처치·뽑음·조각, 끝에 평균.

var data: GameData
var _died_day: bool = false
var max_pulls: int = 99
var smart: bool = true   ## 휘두른 뒤 물러서고 둘러싸이면 구른다(사람 비슷하게). 인자 6번째가 0이면 끈다


func _init() -> void:
	data = GameData.load_default()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var n: int = int(args[0]) if args.size() > 0 else 8
	var runs: int = int(args[1]) if args.size() > 1 else 10
	max_pulls = int(args[2]) if args.size() > 2 else 99
	var dur: float = float(args[3]) if args.size() > 3 else 1.0   # 시험용: 등급 내구 배수
	for g in data.grades.durability.size():
		data.grades.durability[g] *= dur
	var spawn: float = float(args[4]) if args.size() > 4 else 1.0   # 시험용: 밤 나타남 간격 배수
	data.run.spawn_start *= spawn
	smart = not (args.size() > 5 and args[5] == "0")
	print("내구 ×%.2f · 나타남 간격 ×%.2f · 지난 판 %d · 낮 뽑기 최대 %d" % [dur, spawn, runs, max_pulls])
	var zs: float = 0.0
	var wins: int = 0
	var shards: float = 0.0
	var kills: float = 0.0
	var mins: float = 0.0
	var hist: Dictionary = {}
	for k in n:
		var r: Dictionary = _run(5000 + k, runs)
		print("판 %d: 구역 %d%s · 처치 %d · 뽑음 %d · 조각 %d · %.1f분" % [k, r.zone, " 이김" if r.won else "", r.kills, r.pulls, r.shards, r.min])
		zs += r.zone
		wins += 1 if r.won else 0
		shards += r.shards
		kills += r.kills
		mins += r.min
		hist[r.zone] = int(hist.get(r.zone, 0)) + 1
	print("평균: 구역 %.1f · 이김 %d/%d · 처치 %.0f · 조각 %.0f · %.1f분 · 구역별 %s" % [zs / n, wins, n, kills / n, shards / n, mins / n, hist])
	quit()


func _run(seed: int, runs: int) -> Dictionary:
	var meta := Meta.new()
	meta.runs = runs
	Grid.size = data.run.arena_size
	var r := Rules.new(data, seed, meta)
	var limit: int = roundi(25.0 * 60.0 / r.dt)
	var t: int = 0
	var press_k: int = -1
	var day_zone: int = -1
	var pulls_at_day: int = 0
	while t < limit and r.phase != Rules.Phase.OVER:
		t += 1
		if r.pending != null:
			var worst: int = 0
			for i in r.slots.size():
				if r.slots[i] == null:
					worst = i
					break
				if r.slots[i].grade < r.slots[worst].grade:
					worst = i
			var empty: bool = r.slots[worst] == null
			r.choose(worst if empty or r.pending.grade >= r.slots[worst].grade else -1)
			continue
		if r.path_open:
			r.choose_path(0)
			continue
		if not r.hz_offer.is_empty():
			r.hz_answer(true)
			continue
		var i := LordInput.new()
		var foe: Enemy = null
		var fd: float = 12.0
		for e in r.enemies:
			if e.dead or e.data.still:
				continue
			var d: float = e.pos.distance_to(r.lord.pos)
			if d < fd:
				fd = d
				foe = e
		if foe != null:
			i.aim_valid = true
			i.aim = foe.pos
			var near: int = 0
			for e in r.enemies:
				if not e.dead and not e.data.still and e.pos.distance_to(r.lord.pos) < 2.6:
					near += 1
			if smart and r.lord.cooldown > 0.12 and fd < 1.6 + foe.radius:
				i.move = (r.lord.pos - foe.pos).normalized().rotated(0.6)   # 휘두른 뒤 비껴 물러선다
			elif fd > 1.3 + foe.radius:
				i.move = (foe.pos - r.lord.pos).normalized()
			if smart and near >= 3:
				i.dash = true
				i.move = (r.lord.pos - foe.pos).normalized().rotated(1.2)
			i.attack = fd < 2.6 + foe.radius
		elif r.phase == Rules.Phase.DAY:
			if r.zone != day_zone:
				day_zone = r.zone
				pulls_at_day = r.pulls
			if r.pull_hilt != null:
				i.pull = true
				if r.pull_steps != press_k:   # 버팀마다 한 번 누른다(창 안에 들지는 운)
					press_k = r.pull_steps
					i.pull_press = true
			else:
				var h: Hilt = null
				var hd: float = 1e9
				for x in r.hilts:
					if x.gone:
						continue
					var d: float = x.pos.distance_to(r.lord.pos)
					if d < hd:
						hd = d
						h = x
				if h == null or r.pulls - pulls_at_day >= max_pulls:
					r.start_night()
				elif hd > 1.0:
					i.move = (h.pos - r.lord.pos).normalized()
				else:
					i.pull = true
		var was_day: bool = r.phase == Rules.Phase.DAY
		r.step(i)
		_died_day = was_day and r.phase == Rules.Phase.OVER
	var s: Dictionary = Meta.run_shards(r, data.meta)
	print("   끝: %s · 칸 %s · 체력 %.0f" % ["낮" if r.phase == Rules.Phase.DAY or _died_day else "밤", [r.slots[0].data.grade if r.slots[0] else -1, r.slots[1].data.grade if r.slots[1] else -1], r.lord.hp])
	return {"zone": r.zone + 1, "won": r.won, "kills": r.kills, "pulls": r.pulls, "shards": int(s.total), "min": t * r.dt / 60.0}
