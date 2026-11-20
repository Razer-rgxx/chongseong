class_name MoveMotion
extends RefCounted
## 좌클릭 동작 20가지에서 영주의 몸이 어떻게 움직이는지(모션팀, docs/attacks.md 1·4절).
## 장면에 기대지 않는 정적 함수뿐이다. 있는 Mixamo 동작(베기 둘, 구르기, 서기)의 구간을 골라 틀고,
## 그 위에 코드로 돌기·뜨기·기울기·웅크리기·내밀기를 얹는다. LordView는 이렇게 쓴다:
##   1) Rules.move_started(move, info)가 오면 p = plan(move, info, character). character는 기사 모델이 없으면 null.
##   2) p.anim이 ""가 아니면 character.play(p.anim, p.speed, p.from)으로 튼다. p.hold초 동안은 서기·달리기로 바꾸지 않는다.
##   3) p.face_lock이면 그 순간 몸을 info.face로 바로 돌려(_yaw_now = _yaw(info.face)) hold 동안 그대로 둔다.
##   4) p.pause_at(0 이상)초에 동작을 멈추고(set_frozen) p.resume_after초 뒤에 푼다. hold가 끝나면 멈춤도 반드시 푼다.
##      히트스톱도 set_frozen을 쓰므로 character.set_frozen(rules.freeze > 0 or 멈춤 중)으로 함께 준다.
##   5) p.then이 비어 있지 않으면 then.at초에 then.anim을 같은 방식(speed, from, hold, side, trail)으로 이어 튼다.
##   6) 매 프레임 _turn과 _draw_hook이 돌기(_yaw_now)와 높이(_air)를 정한 뒤
##      apply(_model, pose(p, t, p.time), _yaw_now, _air)를 부른다. 동작이 없을 때는 apply(_model, pose({}, 0, 0), …)로 되돌린다.
## 위치가 바뀌는 동작(돌진, 물러남, 도약, 순간, 갈고리)은 규칙이 lord.pos를 옮기므로 여기서는 옆으로 옮기지 않는다.

## 칼이 맞기 조금 전부터 튼다(LordView.slash_lead와 같은 값, 동작의 초).
const LEAD: float = 0.06
## LordCharacter가 동작을 바꿀 때 섞는 시간(그 blend의 기본값). 멈추면 섞기도 멈추므로 멈추기 전에 섞기가 끝나야 한다.
const BLEND: float = 0.12
## 베기 기본 빠르기(LordView.slash_speed와 같다).
const SLASH_SPEED: float = 1.1
## 지금 넣어 둔 Mixamo 베기 두 개의 길이(초). 길이가 맞을 때만 아래 구간을 쓴다. 파일이 바뀌면 그냥 "slash"·"big"으로 돌아간다.
const PACK: Dictionary = {"slash1": 1.667, "slash2": 3.533}
## 베기 구간: [동작, 칼이 맞는 때, 끝(초), 쓸어 가는 쪽]. 쪽은 +1 = 오른쪽에서 왼쪽(SlashFx.arc의 sweep_dir와 같은 뜻).
const CUTS: Dictionary = {
	"fore": ["slash2", 0.70, 1.00, 1.0],   # Sword And Shield Slash2 첫 베기: 오른쪽 위에서 왼쪽 아래로 비스듬히
	"back": ["slash2", 1.27, 1.50, -1.0],  # Slash2 둘째: 왼쪽에서 오른쪽으로 허리높이 되베기
	"rise": ["slash1", 0.85, 1.10, -1.0],  # Sword And Shield Slash: 왼 어깨에서 오른쪽 위로 올려 베기
	"slam": ["slash2", 2.55, 3.25, 1.0],   # Slash2 끝: 뛰어올라 머리 위에서 땅까지 내려찍기(맞는 때 = 칼이 땅에 닿음)
}
## 멈춰 세우는 자세: [동작, 초].
const POSES: Dictionary = {
	"guard": ["slash1", 0.20],  # 다리를 벌리고 칼을 세워 몸 앞에 든다
	"coil": ["slash1", 0.58],   # 칼을 왼 어깨 뒤로 감아 둔다
	"lunge": ["slash2", 0.75],  # 앞무릎을 굽혀 낮게 뻗음, 칼끝이 곧게 앞
	"wide": ["slash2", 1.47],   # 칼을 오른쪽 옆으로 수평으로 뻗음
	"low": ["slash2", 2.66],    # 웅크려 칼을 땅에 댄다
}
## 받으면 쓰는 동작(LordCharacter.KEYWORDS의 열쇠)과 칼이 맞는 때(동작 길이에 대한 비율). 받은 파일을 보고 고친다.
## 이 동작들은 LordCharacter.contact()가 찾아 주지 않아서 여기 비율로 맞춘다. block은 멈춰 세울 때.
const EXTRA: Dictionary = {
	"stab": 0.35, "spin": 0.45, "leap": 0.55, "draw": 0.5, "block": 0.3, "throw": 0.45, "slam": 0.5, "dodge": 0.0,
}
## 규칙이 info.time을 주지 않을 때의 동작 길이(초). 설계서 1절의 첫 값.
const TIME: Dictionary = {
	&"sweep": 0.2, &"thrust": 0.2, &"rising": 0.2, &"flurry": 0.3, &"crescent": 0.2, &"retreat": 0.3,
	&"pull": 0.2, &"smash": 0.2, &"spin": 0.2, &"lunge": 0.15, &"wave": 0.2, &"boomerang": 0.2,
	&"leap": 0.35, &"iaido": 0.25, &"cross": 0.2, &"quake": 0.6, &"whirl": 0.6, &"blink": 0.2,
	&"hook": 0.4, &"parry": 0.35, &"parry_counter": 0.2,
}
## 판정이 늦게 터지는 동작의 기본 지연(초). info.delay가 있으면 그것을 쓴다.
const DELAY: Dictionary = {&"smash": 0.12, &"iaido": 0.25}
## 물러나 베기에서 뒤로 뛰는 시간(초). 동작 끝(info.time)에 맞춰 끝난다.
const RETREAT_HOP: float = 0.15
## 갈고리 포물선(LordView.hook_arc_max와 같은 방식): 거리(m)의 이만큼, 최대 HOOK_ARC_MAX m.
const HOOK_ARC: float = 0.16
const HOOK_ARC_MAX: float = 2.6


# ---------------------------------------------------------------- 계획

## move_started가 왔을 때 할 일. info는 설계서 4절의 열쇠(time, delay, step, big, face, from, to, echo …).
## 돌려주는 열쇠:
##   anim: String       LordCharacter.play에 줄 이름("" = 바꾸지 않음). speed, from(음수 = 칼이 맞는 때보다 그만큼 앞)
##   hold: float        바꾸지 않을 시간(초). then이 있으면 then까지 포함
##   pause_at: float    이때 멈춘다(-1 = 안 멈춤). resume_after: 멈춰 있는 시간(초)
##   face_lock: bool    시작할 때 info.face로 바로 돌리고 hold 동안 고정
##   side: float        칼이 쓸어 가는 쪽(+1 오른쪽→왼쪽, -1 왼쪽→오른쪽, 0 곧게 찌름). 베기 빛·궤적에 쓴다
##   trail: Vector2     칼 궤적을 그릴 때(시작부터 초, x~y). x < 0이면 그리지 않는다
##   hide_sword: float  이때 손의 칼을 숨긴다(-1 = 안 숨김). 칼 던지기: 던진 칼이 돌아오면(projectile_ended) 다시 보인다
##   time: float        pose에 넘길 길이(초). 규칙의 동작 길이보다 길 수 있다(착지 뒤 가라앉기 등)
##   yaw, y, pitch, crouch, push, squash: PackedFloat32Array  pose가 읽는 곡선(초, 값, 초, 값 …)
##   then: Dictionary   이어 틀 동작 {at, anim, speed, from, hold, side, trail}. 없으면 {}
##   move: StringName, big: bool
static func plan(move: StringName, info: Dictionary, character: LordCharacter) -> Dictionary:
	var c: LordCharacter = character
	var p: Dictionary = _blank(move, info)
	if bool(info.get("echo", false)):
		return p   # 메아리는 효과만 다시 울린다. 몸은 그대로
	var T: float = float(info.get("time", TIME.get(move, 0.2)))
	var side: float = combo_side(int(info.get("step", 1)))
	var big: bool = bool(p["big"])
	var moved: bool = info.has("to")
	match move:
		&"thrust":
			# 찌르기: 앞무릎을 굽혀 낮게 파고들며 팔을 곧게 뻗고, 몸을 앞으로 내밀었다가 돌아온다.
			if not _extra(p, c, "stab", 0.0, 1.2):
				if not _freeze(p, c, "lunge", 1.5, 0.32):
					_cut(p, c, "fore", 0.0, SLASH_SPEED, big)
			p["side"] = 0.0
			p["trail"] = Vector2(0.0, 0.14)
			p["pitch"] = _k([0, 0, 0.07, 0.2, 0.18, 0.17, 0.42, 0])
			p["crouch"] = _k([0, 0, 0.07, 0.05, 0.42, 0])
			if not moved:
				p["push"] = _k([0, 0, 0.07, 0.3, 0.18, 0.28, 0.42, 0])
			p["face_lock"] = true
			p["time"] = 0.45
		&"rising":
			# 올려베기: 왼 어깨에서 오른쪽 위로 쳐올리며 발끝으로 조금 솟고 상체를 젖힌다.
			_cut(p, c, "rise", 0.0, SLASH_SPEED, big)
			p["y"] = _k([0, 0, 0.1, 0.09, 0.4, 0])
			p["pitch"] = _k([0, 0, 0.05, 0.06, 0.14, -0.12, 0.42, 0])
			p["time"] = 0.45
			_twist_if_box(p, c, 0.0)
		&"flurry":
			# 연속 찌르기: 찌르기와 같은 낮은 자세로 멈춰 몸을 네 번 내밀었다 당긴다. 찌를 때마다 칼끝이 좌우로 조금 비낀다.
			if not _extra(p, c, "stab", 0.0, 2.0):
				if not _freeze(p, c, "lunge", 1.6, T + 0.15):
					_cut(p, c, "fore", 0.0, SLASH_SPEED, big)
			var gap: float = T / 3.0
			var push: Array = [0, 0]
			var yaw: Array = [0, 0]
			for i in 4:
				var at: float = gap * i
				if i > 0:
					push.append_array([at, 0.05])
				push.append_array([at + 0.04, 0.22])
				yaw.append_array([at + 0.04, 0.08 if i % 2 == 0 else -0.08])
			push.append_array([T + 0.2, 0])
			yaw.append_array([T + 0.2, 0])
			p["push"] = _k(push)
			p["yaw"] = _k(yaw)
			p["pitch"] = _k([0, 0, 0.04, 0.14, T + 0.04, 0.14, T + 0.2, 0])
			p["side"] = 0.0
			p["trail"] = Vector2(0.0, T + 0.1)
			p["face_lock"] = true
			p["time"] = T + 0.22
		&"crescent":
			# 반월: 몸을 한쪽으로 감았다가 크게 풀며 220°를 쓸어 벤다.
			_cut(p, c, "fore" if side > 0.0 else "back", 0.0, 1.0, big)
			var s: float = float(p["side"])
			p["yaw"] = _k([0, 0, 0.04, -0.5 * s, 0.22, 0.6 * s, 0.48, 0])
			p["pitch"] = _k([0, 0, 0.1, 0.08, 0.45, 0])
			p["trail"] = Vector2(0.0, 0.3)
			p["time"] = 0.5
		&"retreat":
			# 물러나 베기: 베고 나서 앞을 본 채 뒤로 뛰어 물러난다(몸을 젖히고 낮게 떴다가 내려앉는다).
			_cut(p, c, "fore" if side > 0.0 else "back", 0.0, 1.2, big)
			var hb: float = maxf(0.05, T - RETREAT_HOP)
			p["y"] = _k([hb, 0, hb + 0.07, 0.28, T, 0])
			p["pitch"] = _k([0, 0, 0.05, 0.06, hb, 0, hb + 0.06, -0.2, T, -0.1, T + 0.22, 0])
			p["squash"] = _k([T, 0, T + 0.04, 0.07, T + 0.2, 0])
			p["crouch"] = _k([T, 0, T + 0.05, 0.06, T + 0.25, 0])
			p["face_lock"] = true
			p["time"] = T + 0.26
			if c != null and c.has("dodge"):
				var d: Dictionary = {}
				_extra(d, c, "dodge", 0.0, c.length("dodge") / maxf(RETREAT_HOP + 0.15, 0.1))
				d["at"] = hb
				d["side"] = p["side"]
				d["trail"] = Vector2(-1.0, -1.0)
				p["then"] = d
				p["hold"] = maxf(float(p["hold"]), hb + float(d["hold"]))
			_twist_if_box(p, c, 0.0)
		&"pull":
			# 끌어당기기: 앞으로 손을 뻗었다가 되베며 몸 쪽으로 홱 당긴다.
			_cut(p, c, "back", 0.0, SLASH_SPEED, big)
			p["pitch"] = _k([0, 0, 0.05, 0.18, 0.15, -0.14, 0.42, 0])
			p["push"] = _k([0, 0, 0.05, 0.15, 0.15, -0.15, 0.42, 0])
			p["time"] = 0.45
			_twist_if_box(p, c, 0.0)
		&"smash":
			# 내려찍기: 살짝 뛰어 칼을 머리 위로 들었다가 땅까지 내려찍고 무릎을 꺾는다.
			var D: float = float(info.get("delay", DELAY[move]))
			if not _extra(p, c, "slam", D, 1.4):
				_cut(p, c, "slam", D, 2.6, true)
			p["y"] = _k([0, 0, D * 0.45, 0.16, D, 0])
			p["pitch"] = _k([0, 0, D * 0.5, -0.08, D, 0.2, D + 0.3, 0])
			p["squash"] = _k([D, 0, D + 0.04, 0.09, D + 0.25, 0])
			p["time"] = D + 0.35
		&"spin":
			# 회전베기: 칼을 뻗은 채 제자리에서 한 바퀴. 돌기 동작을 받았으면 그 동작이 돌고 코드는 돌지 않는다.
			if _extra(p, c, "spin", 0.0, 1.2):
				p["side"] = side
				p["trail"] = Vector2(0.0, 0.4)
			else:
				_cut(p, c, "fore" if side > 0.0 else "back", 0.0, 1.0, true)
				p["yaw"] = _k([0, 0, 0.34, TAU * float(p["side"])])
				p["trail"] = Vector2(0.0, 0.36)
			p["crouch"] = _k([0, 0, 0.1, 0.06, 0.4, 0])
			p["face_lock"] = true
			p["time"] = 0.42
		&"lunge":
			# 돌진베기: 낮게 숙여 미끄러지듯 달려 나가며 지나가는 길에 베고, 멈추며 몸을 세운다.
			_cut(p, c, "fore" if side > 0.0 else "back", T * 0.6, 1.3, true)
			p["pitch"] = _k([0, 0, 0.04, 0.3, T, 0.26, T + 0.12, -0.06, T + 0.32, 0])
			p["crouch"] = _k([0, 0, 0.04, 0.08, T, 0.08, T + 0.3, 0])
			p["face_lock"] = true
			p["time"] = T + 0.35
		&"wave":
			# 검기: 크게 휘두르며 몸을 앞으로 실어 초승달을 날려 보낸다.
			_cut(p, c, "fore" if side > 0.0 else "back", 0.0, 1.2, true)
			p["pitch"] = _k([0, 0, 0.06, 0.15, 0.4, 0])
			if not moved:
				p["push"] = _k([0, 0, 0.06, 0.12, 0.4, 0])
			p["time"] = 0.45
			_twist_if_box(p, c, 0.0)
		&"boomerang":
			# 칼 던지기: 원반 던지듯 왼쪽에서 오른쪽으로 팔을 휘둘러 놓는다. 놓는 순간 손의 칼을 숨긴다.
			if not _extra(p, c, "throw", 0.0, 1.2):
				_cut(p, c, "back", 0.0, SLASH_SPEED, true)
			p["pitch"] = _k([0, 0, 0.05, 0.12, 0.4, 0])
			p["hide_sword"] = (p["trail"] as Vector2).x + 0.06
			p["time"] = 0.45
			_twist_if_box(p, c, 0.0)
		&"leap":
			# 도약 내려찍기: 칼을 머리 위로 들고 높이 뛰어 겨눈 곳에 내려찍는다. 내리면 무릎을 꺾고 가라앉는다.
			var dist: float = 6.0
			if info.has("from") and moved:
				dist = Grid.cells_to_meters((info["from"] as Vector2).distance_to(info["to"] as Vector2))
			var peak: float = clampf(dist * 0.17, 0.8, 2.2)
			if not _extra(p, c, "leap", T, 1.0):
				_cut(p, c, "slam", T, 2.0, true)
			p["y"] = _k([0, 0, T * 0.45, peak, T * 0.8, peak * 0.5, T, 0])
			p["pitch"] = _k([0, 0, T * 0.3, -0.12, T * 0.75, 0.2, T, 0.12, T + 0.25, 0])
			p["squash"] = _k([T, 0, T + 0.04, 0.1, T + 0.25, 0])
			p["crouch"] = _k([T, 0, T + 0.05, 0.06, T + 0.35, 0])
			p["face_lock"] = true
			p["time"] = T + 0.4
		&"iaido":
			# 발도: 낮게 웅크려 칼을 감아 멈췄다가, 판정 순간 눈에 안 보이게 빠르게 베어 나가며 앞으로 숙인다.
			var D: float = float(info.get("delay", DELAY[move]))
			if not _extra(p, c, "draw", D, 1.6):
				if not _iai(p, c, D):
					_cut(p, c, "rise", D, SLASH_SPEED, true)
			p["crouch"] = _k([0, 0, 0.1, 0.1, D, 0.1, D + 0.05, 0.04, D + 0.4, 0])
			p["pitch"] = _k([0, 0, 0.1, 0.15, D, 0.18, D + 0.05, 0.32, D + 0.45, 0])
			p["yaw"] = _k([0, 0, 0.1, 0.2, D, 0.2, D + 0.06, -0.15, D + 0.4, 0])
			p["face_lock"] = true
			p["time"] = D + 0.5
		&"cross":
			# 십자 베기: 비스듬히 내려 베고 곧바로 되베어 X를 긋는다.
			if _pack(c):
				p["anim"] = "slash2"
				p["speed"] = 2.4
				p["from"] = float(CUTS["fore"][1]) - LEAD
				p["hold"] = (float(CUTS["back"][2]) - float(p["from"])) / 2.4
				p["side"] = 1.0
				p["trail"] = Vector2(0.0, (float(CUTS["back"][1]) - float(p["from"])) / 2.4 + 0.14)
			else:
				_cut(p, c, "fore" if side > 0.0 else "back", 0.0, SLASH_SPEED, true)
				p["trail"] = Vector2(0.0, 0.3)
			var s: float = float(p["side"])
			p["yaw"] = _k([0, 0, 0.06, 0.15 * s, 0.26, -0.15 * s, 0.45, 0])
			p["pitch"] = _k([0, 0, 0.05, 0.1, 0.45, 0])
			p["time"] = 0.48
		&"quake":
			# 지진: 칼을 땅에 내려꽂고 웅크린 채 버틴다. 고리가 퍼질 때마다(0.2·0.4·0.6초) 한 번씩 더 누른다.
			# 판정은 누르는 순간이지만 내려치는 모습이 보이게 칼이 0.1초에 땅에 닿게 한다.
			if not _extra(p, c, "slam", 0.1, 1.4):
				_cut(p, c, "slam", 0.1, 2.0, true)
				if _pack(c):
					var low: float = float(POSES["low"][1])
					p["pause_at"] = (low - float(p["from"])) / 2.0
					p["resume_after"] = maxf(0.0, T + 0.05 - float(p["pause_at"]))
					p["hold"] = T + 0.05 + (float(CUTS["slam"][2]) - low) / 2.0
			var cr: Array = [0, 0, 0.1, 0.06]
			for r in [0.2, 0.4, 0.6]:
				var at: float = float(r)
				if at <= T:
					cr.append_array([at - 0.02, 0.045, at + 0.02, 0.09])
			cr.append_array([T + 0.3, 0])
			p["crouch"] = _k(cr)
			p["squash"] = _k([0.08, 0, 0.11, 0.08, 0.28, 0])
			p["pitch"] = _k([0, 0, 0.1, 0.15, T, 0.12, T + 0.3, 0])
			p["face_lock"] = true
			p["time"] = T + 0.35
		&"whirl":
			# 소용돌이: 칼을 옆으로 수평으로 뻗은 채 멈춰 팽이처럼 돈다(0.3초에 한 바퀴). 도는 동안 걸을 수 있다.
			var dir: float = side
			if _pack(c):
				_cut(p, c, "back", 0.0, 1.5, true)
				var wide: float = float(POSES["wide"][1])
				p["pause_at"] = (wide - float(p["from"])) / 1.5
				p["resume_after"] = maxf(0.0, T - float(p["pause_at"]))
				p["hold"] = T + 0.1
				dir = -1.0
			else:
				_cut(p, c, "fore" if side > 0.0 else "back", 0.0, SLASH_SPEED, true)
			var total: float = dir * TAU * maxf(1.0, roundf(T / 0.3))
			var ramp: float = minf(0.1, T * 0.25)
			p["yaw"] = _k([0, 0, ramp, total * 0.08, T - ramp, total * 0.92, T, total])
			p["pitch"] = _k([0, 0, 0.1, 0.06, T, 0.06, T + 0.12, 0])
			p["side"] = dir
			p["trail"] = Vector2(0.0, T)
			p["face_lock"] = true
			p["time"] = T + 0.12
		&"blink":
			# 순간 베기: 적 뒤에 나타나 아직 지나온 쪽을 보던 몸을 홱 돌려 벤다. 낮게 내려앉아 나타난다.
			_cut(p, c, "fore" if side > 0.0 else "back", 0.0, 1.2, true)
			if info.has("from") and moved:
				var go: Vector2 = (info["to"] as Vector2) - (info["from"] as Vector2)
				if go.length() > 0.2:
					var face: float = float(info.get("face", go.angle()))
					var off: float = wrapf(face - go.angle(), -PI, PI)
					p["yaw"] = _k([0, off, 0.05, off * 0.25, 0.14, 0])
			p["pitch"] = _k([0, 0, 0.05, 0.14, 0.4, 0])
			p["crouch"] = _k([0, 0.08, 0.2, 0])
			p["face_lock"] = true
			p["time"] = 0.42
			if (p["yaw"] as PackedFloat32Array).is_empty():
				_twist_if_box(p, c, 0.0)
		&"hook":
			# 갈고리 베기: 줄을 걸고 공중제비로 포물선을 그리며 날아가(구르기 동작), 닿으면 크게 벤다.
			# 포물선(y)은 LordView._draw_hook의 _air와 같은 모양이다. 이 동작을 L.hook으로 돌려 _draw_hook이 이미 띄우면 둘 중 하나만 쓴다.
			if not (info.has("from") and moved):
				_cut(p, c, "fore" if side > 0.0 else "back", 0.0, SLASH_SPEED, true)   # 적이 없으면 횡베기
				p["time"] = 0.35
				_twist_if_box(p, c, 0.0)
			else:
				var dm: float = Grid.cells_to_meters((info["from"] as Vector2).distance_to(info["to"] as Vector2))
				p["anim"] = "roll"
				p["speed"] = 1.3
				p["from"] = 0.0
				p["hold"] = T
				if c != null and c.roll_window.x >= 0.0:
					p["speed"] = (c.roll_window.y - c.roll_window.x) / maxf(T, 0.05)
					p["from"] = c.roll_window.x
				var d: Dictionary = {}
				_cut(d, c, "fore" if side > 0.0 else "back", 0.0, SLASH_SPEED, true)
				d["at"] = T
				p["then"] = d
				p["side"] = d["side"]
				p["hold"] = T + float(d["hold"])
				p["y"] = _k([0, 0, T * 0.5, minf(HOOK_ARC_MAX, dm * HOOK_ARC), T, 0])
				p["pitch"] = _k([0, 0, 0.08, 0.15, T, 0.1, T + 0.25, 0])
				p["face_lock"] = true
				p["time"] = T + 0.3
		&"parry":
			# 반격 자세: 다리를 벌리고 칼을 세워 몸 앞에 든 채 낮게 멈춘다. 안 맞으면 끝에 가볍게 벤다(then).
			# 맞아서 반격하면 LordView가 plan(&"parry_counter", …)로 바꿔 튼다.
			if not _extra(p, c, "block", 0.0, 1.0, true, T):
				if not _freeze(p, c, "guard", 1.0, T):
					p["anim"] = "idle"
					p["pause_at"] = _blend(c)
					p["resume_after"] = maxf(0.0, T - _blend(c))
					p["hold"] = T
			p["crouch"] = _k([0, 0, 0.08, 0.08, T, 0.08, T + 0.2, 0])
			p["pitch"] = _k([0, 0, 0.08, -0.05, T, -0.05, T + 0.2, 0])
			var d: Dictionary = {}
			_cut(d, c, "fore" if side > 0.0 else "back", 0.0, SLASH_SPEED, false)
			d["at"] = T
			p["then"] = d
			p["side"] = d["side"]
			p["hold"] = T + float(d["hold"])
			p["face_lock"] = true
			p["time"] = T + 0.3
		&"parry_counter":
			# 반격(반격 자세에서 맞았을 때, move_area의 반격): 튀어 오르듯 한 바퀴 돌며 둘레를 벤다.
			_cut(p, c, "fore" if side > 0.0 else "back", 0.0, 1.3, true)
			p["yaw"] = _k([0, 0, 0.28, TAU * float(p["side"])])
			p["y"] = _k([0, 0, 0.08, 0.1, 0.3, 0])
			p["trail"] = Vector2(0.0, 0.3)
			p["face_lock"] = true
			p["time"] = 0.36
		_:
			# 횡베기(&"sweep", 모르는 id도): 연타마다 번갈아 오른쪽→왼쪽, 왼쪽→오른쪽으로 벤다.
			_cut(p, c, "fore" if side > 0.0 else "back", 0.0, SLASH_SPEED, big)
			p["pitch"] = _k([0, 0, 0.08, 0.07, 0.35, 0])
			p["time"] = 0.4
			_twist_if_box(p, c, 0.0)
	return p


## 연타 순서마다 쓸어 가는 쪽. step은 info.step처럼 1부터 센다: 1, 3, 5…번째 = +1(오른쪽→왼쪽), 2, 4…번째 = -1.
static func combo_side(step: int) -> float:
	return 1.0 if posmod(step, 2) == 1 else -1.0


# ---------------------------------------------------------------- 순간의 자세

## 시작 뒤 t초의 몸 자세. time은 보통 p.time이다(다른 값을 주면 곡선을 그 길이로 늘이거나 줄인다).
## 돌려주는 열쇠(모두 0이면 원래 자세):
##   yaw: float     모델의 돌기에 더한다(라디안, + = 위에서 봐서 반시계 = 왼쪽으로). 여러 바퀴일 수 있으니 섞지 말고 그대로 더한다
##   y: float       뜨기(m)
##   pitch: float   앞으로 숙이기(라디안, + = 앞, - = 뒤로 젖힘). 발을 축으로
##   crouch: float  낮추기(m, + = 아래)
##   push: float    보는 쪽으로 내밀기(m, - = 뒤로). 제자리 동작만 쓰고 끝나면 0으로 돌아온다
##   scale_y: float 세로 비율(1 = 그대로, 내려앉을 때 조금 작아진다)
## t >= time이거나 계획이 비어 있으면 모두 0(scale_y = 1)이다.
static func pose(p: Dictionary, t: float, time: float) -> Dictionary:
	var out: Dictionary = {"yaw": 0.0, "y": 0.0, "pitch": 0.0, "crouch": 0.0, "push": 0.0, "scale_y": 1.0}
	var total: float = float(p.get("time", 0.0))
	if total <= 0.0 or time <= 0.0 or t < 0.0 or t >= time:
		return out
	var u: float = t * total / time
	out["yaw"] = _curve(p.get("yaw", PackedFloat32Array()), u)
	out["y"] = _curve(p.get("y", PackedFloat32Array()), u)
	out["pitch"] = _curve(p.get("pitch", PackedFloat32Array()), u)
	out["crouch"] = _curve(p.get("crouch", PackedFloat32Array()), u)
	out["push"] = _curve(p.get("push", PackedFloat32Array()), u)
	out["scale_y"] = 1.0 - _curve(p.get("squash", PackedFloat32Array()), u)
	return out


## pose를 모델 노드(LordView._model)에 얹는다. yaw와 y는 이번 프레임 LordView가 정한 돌기(_yaw_now)와 높이(_air)다.
## 돌기 → 숙이기 순서(Node3D의 YXZ)라서 숙이기는 돌아간 몸의 옆축으로 돈다. 모델의 앞은 -Z라 앞으로 숙이기는 -X 회전이다.
static func apply(model: Node3D, pose_now: Dictionary, yaw: float, y: float) -> void:
	var push: float = float(pose_now.get("push", 0.0))
	model.rotation = Vector3(-float(pose_now.get("pitch", 0.0)), yaw + float(pose_now.get("yaw", 0.0)), 0.0)
	model.position = Vector3(-sin(yaw) * push, y + float(pose_now.get("y", 0.0)) - float(pose_now.get("crouch", 0.0)), -cos(yaw) * push)
	var sxz: float = float(pose_now.get("scale_xz", 1.0))
	model.scale = Vector3(sxz, float(pose_now.get("scale_y", 1.0)), sxz)


# ---------------------------------------------------------------- 걸어 다니는 점프(30단계)

## 점프하는 몸(화면만, 규칙은 높이 LordState.air_height만 정한다). 웅크렸다 펴며 솟고 → 공중에서 다리를 접고 → 펴서 내려앉으며 무릎을 굽혔다 편다.
## 솟을 때 펴는 구간(뜬 시간의 비율), 다리 접기(시작, 다 접음, 펴기 시작, 다 폄: 비율), 내려앉은 뒤 무릎을 굽혔다 펴는 시간(초).
const HOP_PUSH: float = 0.18
const HOP_TUCK: Vector4 = Vector4(0.16, 0.4, 0.62, 0.92)
const HOP_LAND: float = 0.26
## 솟기 전 웅크림(bend), 내려앉을 때 굽힘의 가장 깊은 때(HOP_LAND의 비율), 공중과 내려앉을 때 앞으로 숙이는 정도(라디안).
const HOP_CROUCH: float = 0.6
const HOP_LAND_PEAK: float = 0.22
const HOP_PITCH: float = 0.12
const HOP_LAND_PITCH: float = 0.16


## u = 뜬 뒤 지난 비율(0~1, 땅이면 음수), land = 내려앉은 뒤 지난 초(아니면 음수).
## 돌려주는 것: bend(0~1, 선 채로 무릎 굽힘: 솟기 직전과 내려앉은 뒤), tuck(0~1, 공중에서 다리 접기), pitch(앞으로 숙이기, 라디안).
## LordView가 기사 모델이면 다리(LordCharacter.set_legs)와 몸 내리기(bend_drop)로, 기본 도형이면 눌림(scale_y)으로 바꾼다.
static func hop_pose(u: float, land: float) -> Dictionary:
	var bend: float = 0.0
	var tuck: float = 0.0
	var pitch: float = 0.0
	if u >= 0.0:
		var k: float = clampf(u, 0.0, 1.0)
		bend = HOP_CROUCH * (1.0 - smoothstep(0.0, HOP_PUSH, k))
		tuck = smoothstep(HOP_TUCK.x, HOP_TUCK.y, k) * (1.0 - 0.8 * smoothstep(HOP_TUCK.z, HOP_TUCK.w, k))
		pitch = HOP_PITCH * sin(k * PI)
	if land >= 0.0 and land < HOP_LAND:
		var t: float = land / HOP_LAND
		var g: float = smoothstep(0.0, HOP_LAND_PEAK, t) * (1.0 - smoothstep(HOP_LAND_PEAK + 0.08, 1.0, t))
		bend = maxf(bend, g)
		pitch += HOP_LAND_PITCH * g
	return {"bend": bend, "tuck": tuck, "pitch": pitch}


# ---------------------------------------------------------------- 안쪽

static func _blank(move: StringName, info: Dictionary) -> Dictionary:
	return {
		"move": move, "big": bool(info.get("big", false)),
		"anim": "", "speed": 1.0, "from": 0.0, "hold": 0.0, "pause_at": -1.0, "resume_after": 0.0,
		"face_lock": false, "side": combo_side(int(info.get("step", 1))), "trail": Vector2(-1.0, -1.0),
		"hide_sword": -1.0, "time": 0.0, "then": {},
		"yaw": PackedFloat32Array(), "y": PackedFloat32Array(), "pitch": PackedFloat32Array(), "crouch": PackedFloat32Array(), "push": PackedFloat32Array(), "squash": PackedFloat32Array(),
	}


## 곡선 키 [초, 값, …]. 동작 길이(time·delay)가 아주 짧아 앞의 키가 뒤의 키보다 늦어지면
## 뒤의 키(규칙의 때에 맞춘 것)를 남기고 앞의 키를 버려 시간이 늘 늘어나게 한다.
static func _k(a: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in range(0, a.size() - 1, 2):
		var t: float = float(a[i])
		while out.size() >= 2 and out[out.size() - 2] >= t:
			out.resize(out.size() - 2)
		out.append(t)
		out.append(float(a[i + 1]))
	return out


static func _blend(c: LordCharacter) -> float:
	return c.blend if c != null else BLEND


## 지금 넣어 둔 베기 두 개(Sword And Shield Slash, Slash2)가 그대로 있는지.
static func _pack(c: LordCharacter) -> bool:
	if c == null:
		return false
	for k in PACK:
		if not c.has(k) or absf(c.length(k) - float(PACK[k])) > 0.05:
			return false
	return true


## 칼이 hit_t초(시작부터)에 맞게 베기를 고른다. 넣어 둔 베기가 있으면 그 구간을, 없으면 LordCharacter가 고르는 베기를 튼다.
static func _cut(p: Dictionary, c: LordCharacter, seg: String, hit_t: float, speed: float, big: bool) -> void:
	var lead: float = maxf(LEAD, hit_t * speed)   # 맞는 때보다 몇 초(동작의 초) 앞에서 시작하는지
	var hit_real: float = lead / speed
	var s: Array = CUTS[seg]
	if _pack(c):
		p["anim"] = s[0]
		p["from"] = maxf(0.0, float(s[1]) - lead)
		hit_real = (float(s[1]) - float(p["from"])) / speed
		p["hold"] = (float(s[2]) - float(p["from"])) / speed
	else:
		p["anim"] = "big" if big else "slash"
		p["from"] = -lead
		p["hold"] = hit_real + 0.45
	p["side"] = float(s[3])   # 넣어 둔 베기가 없으면 실제 쪽은 모르지만 고른 구간의 쪽을 따른다(fore +1, back -1)
	p["speed"] = speed
	p["pause_at"] = -1.0
	p["trail"] = Vector2(maxf(0.0, hit_real - 0.06), hit_real + 0.2)


## 넣어 둔 베기의 한 순간(POSES)에 멈춰 세운다. 섞기가 끝나는 때에 그 순간이 오게 시작점을 잡는다. hold초 뒤에 푼다.
static func _freeze(p: Dictionary, c: LordCharacter, pose_name: String, speed: float, hold: float) -> bool:
	if not _pack(c):
		return false
	var f: Array = POSES[pose_name]
	var b: float = _blend(c)
	p["anim"] = f[0]
	p["speed"] = speed
	p["from"] = maxf(0.0, float(f[1]) - b)
	p["pause_at"] = (float(f[1]) - float(p["from"])) / speed
	p["hold"] = maxf(hold, float(p["pause_at"]))
	p["resume_after"] = float(p["hold"]) - float(p["pause_at"])
	p["trail"] = Vector2(0.0, float(p["pause_at"]) + 0.05)
	return true


## 받은 동작(EXTRA)이 있으면 그것을 튼다. 칼이 hit_t초에 맞게 시작점을 잡는다. freeze면 맞는 때에 멈춰 hold초 둔다.
static func _extra(p: Dictionary, c: LordCharacter, key: String, hit_t: float, speed: float, freeze: bool = false, hold: float = 0.0) -> bool:
	if c == null or not c.has(key):
		return false
	var L: float = c.length(key)
	var at: float = L * float(EXTRA[key])
	p["anim"] = key
	p["speed"] = speed
	if freeze:
		p["from"] = maxf(0.0, at - _blend(c))
		p["pause_at"] = (at - float(p["from"])) / speed
		p["hold"] = maxf(hold, float(p["pause_at"]))
		p["resume_after"] = float(p["hold"]) - float(p["pause_at"])
		return true
	var lead: float = maxf(LEAD, hit_t * speed)
	p["from"] = maxf(0.0, at - lead)
	var hit_real: float = (at - float(p["from"])) / speed
	p["hold"] = minf((L * 0.9 - float(p["from"])) / speed, hit_real + 0.8)
	p["pause_at"] = -1.0
	p["trail"] = Vector2(maxf(0.0, hit_real - 0.06), hit_real + 0.2)
	return true


## 발도: 칼을 감은 순간(coil)에 멈췄다가, 칼이 d초에 맞게 풀어 올려 벤다(rise). 빠르기 2.5.
static func _iai(p: Dictionary, c: LordCharacter, d: float) -> bool:
	if not _pack(c):
		return false
	var speed: float = 2.5
	var coil: float = float(POSES["coil"][1])
	var hit: float = float(CUTS["rise"][1])
	_cut(p, c, "rise", d, speed, true)
	var b: float = _blend(c)
	var start: float = coil - b
	var reach: float = b / speed                      # 감은 자세에 닿는 때
	var resume: float = d - (hit - coil) / speed       # 이때 풀어야 d초에 칼이 맞는다
	if resume > reach:
		p["from"] = start
		p["pause_at"] = reach
		p["resume_after"] = resume - reach
		p["hold"] = resume + (float(CUTS["rise"][2]) - coil) / speed
		p["trail"] = Vector2(maxf(0.0, d - 0.06), d + 0.2)
	return true


## 기사 모델이 없으면(기본 도형) 베기 동작이 없으니 몸통을 비틀어 휘두르는 모습을 대신한다.
static func _twist_if_box(p: Dictionary, c: LordCharacter, hit: float) -> void:
	if c != null:
		return
	var s: float = float(p["side"])
	if s == 0.0:
		return
	p["yaw"] = _k([0, 0, hit + 0.03, -0.35 * s, hit + 0.14, 0.45 * s, hit + 0.4, 0])


## 곡선 값. keys = [초, 값, 초, 값 …]. 처음과 끝은 기울기 0(천천히 떠나 천천히 닿는다),
## 가운데 점은 양쪽 기울기의 평균(Fritsch–Carlson로 넘치지 않게)이라 꼭대기·바닥을 넘어서지 않고 매끄럽게 지난다.
static func _curve(keys: PackedFloat32Array, t: float) -> float:
	var n: int = keys.size() / 2
	if n == 0:
		return 0.0
	if t <= keys[0]:
		return keys[1]
	if t >= keys[(n - 1) * 2]:
		return keys[(n - 1) * 2 + 1]
	var i: int = 0
	while i < n - 2 and t > keys[(i + 1) * 2]:
		i += 1
	var t0: float = keys[i * 2]
	var v0: float = keys[i * 2 + 1]
	var t1: float = keys[i * 2 + 2]
	var v1: float = keys[i * 2 + 3]
	var h: float = t1 - t0
	if h <= 0.0:
		return v1
	var m0: float = _slope(keys, i)
	var m1: float = _slope(keys, i + 1)
	var dk: float = (v1 - v0) / h
	if dk == 0.0:
		m0 = 0.0
		m1 = 0.0
	else:
		var a: float = m0 / dk
		var b: float = m1 / dk
		var r: float = a * a + b * b
		if r > 9.0:
			var k: float = 3.0 / sqrt(r)
			m0 = k * a * dk
			m1 = k * b * dk
	var s: float = (t - t0) / h
	var s2: float = s * s
	var s3: float = s2 * s
	return (2.0 * s3 - 3.0 * s2 + 1.0) * v0 + (s3 - 2.0 * s2 + s) * h * m0 + (-2.0 * s3 + 3.0 * s2) * v1 + (s3 - s2) * h * m1


static func _slope(keys: PackedFloat32Array, i: int) -> float:
	var n: int = keys.size() / 2
	if i <= 0 or i >= n - 1:
		return 0.0
	var dl: float = (keys[i * 2 + 1] - keys[i * 2 - 1]) / maxf(keys[i * 2] - keys[i * 2 - 2], 1e-5)
	var dr: float = (keys[i * 2 + 3] - keys[i * 2 + 1]) / maxf(keys[i * 2 + 2] - keys[i * 2], 1e-5)
	if dl * dr <= 0.0:
		return 0.0
	return (dl + dr) * 0.5
