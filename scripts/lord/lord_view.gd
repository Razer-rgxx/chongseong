extends Node3D
## 영주 그리기. 규칙의 LordState를 틱 사이로 이어 그리고, 쥔 검, 칼 궤적, 돌진 잔상을 보여 준다.
## 좌클릭 동작(Rules.move_started)마다 MoveMotion.plan으로 동작을 고르고, 매 화면 MoveMotion.pose로 돌기·뜨기·숙이기를 얹는다.
## 판정 모양(부채꼴, 띠, 원 …)은 MoveFx(main)가 그린다.
## 모델은 자식 "Model" 씬(scenes/lord/lord_model.tscn)이다. 모델을 바꿔 끼울 때 칼은 "Model/Hand/Blade"에 두면 된다.
## 쥔 검의 형태에 따라 칼날 길이와 두께가, 등급에 따라 코등이 색이 바뀐다.
## assets/characters/lord/paladin.fbx가 있으면 기본 도형 대신 그 기사(LordCharacter)를 세우고 동작을 고른다.
## 걸어 다니는 점프(30단계): 규칙의 공중 시간(LordState.air)으로 몸을 포물선으로 띄우고, MoveMotion.hop_pose로 웅크림 → 다리 접기 →
## 내려앉으며 무릎 굽힘을 얹는다. 기사 모델은 hop 동작 파일이 있으면 그것을, 없으면 다리를 코드로 굽힌다(LegFold). 기본 도형은 눌린다.
## 말(39단계): 탔으면(LordState.riding) 들판이 넣어 준 HorseView의 안장 높이에 앉힌다. 기사 모델은 서 있기 동작 위에 다리를 벌려 굽히고(LegFold.ride),
## 기본 도형은 낮고 좁게 줄여 올라앉고 다리 둘(넓적다리·정강이·장화)을 말 양옆에 단다. 말이 앞뒤로 기울면 같이 기운다. 탄 채 공중은 말 도약의 높이.

@export var ghost_color: Color = Color(0.5, 0.7, 1.0, 0.35)
@export var ghost_life: float = 0.2
## 칼을 들고 있을 때 몸 앞에서 벌어진 각도(라디안).
@export var idle_blade_angle: float = 0.9
## 기사 모델의 베기·구르기·맞기 동작을 트는 빠르기(1 = 원래 빠르기).
@export var slash_speed: float = 1.1
@export var roll_speed: float = 1.3
## 구르기 동작을 몇 초에 끝낼지. 동작의 실제로 구르는 구간만 이 시간에 맞춰 튼다(규칙의 돌진은 0.16초).
@export var roll_time: float = 0.45
## 몸을 돌리는 빠르기(클수록 빨리). 휘두르거나 구를 때는 turn_fast로 거의 바로 돌린다.
@export var turn_speed: float = 12.0
@export var turn_fast: float = 40.0
@export_group("칼 궤적과 베기 빛")
## 메아리 계곡 같은 두 번째 베기 빛을 사선으로 기울이는 각(라디안).
@export var arc_tilt: float = 0.35
@export_group("")
@export var hit_speed: float = 1.0
## 달리기 동작 빠르기. 영주가 Mixamo 달리기보다 빨라서 올리면 발이 덜 미끄러지지만, 사용자가 빠르다고 해서 1.1로 뒀다.
@export var run_speed: float = 1.1
## 규칙은 누르는 순간 벤다. 화면은 베기 동작을 칼이 맞는 때보다 이만큼(초) 앞에서부터 틀어
## 숫자·피·히트스톱이 칼이 지나가는 순간과 겹치게 한다. 늘리면 휘두르는 모습이 길게 보이지만 맞는 것이 늦어 보인다.
@export var slash_lead: float = 0.06
## 한 번 트는 동작을 길어도 이만큼(초)만 보고 서기·달리기로 돌아간다.
@export var slash_hold: float = 0.8
@export var roll_hold: float = 0.9

@export_group("갈고리")
## 날아가는 포물선의 가장 높은 곳(m). 먼 적일수록 높게, 이 값까지.
@export var hook_arc_max: float = 2.6
## 줄이 적에게 닿을 때까지의 시간(초).
@export var hook_rope_shoot: float = 0.07
@export var rope_color: Color = Color(0.5, 0.48, 0.45)
@export_group("점프")
## 기본 도형 영주가 무릎 굽힘(bend)·다리 접기(tuck)에서 눌리는 정도(scale_y에서 뺀다).
@export var hop_squash_bend: float = 0.17
@export var hop_squash_tuck: float = 0.09
@export_group("말")
## 기본 도형이 말 위에 앉을 때 위아래·옆으로 줄이는 배수, 안장에 묻히는 깊이(m), 타고 내리는 데 걸리는 시간(초).
@export var ride_squash: float = 0.56
@export var ride_slim: float = 0.62
@export var ride_sink: float = 0.06
@export var ride_blend: float = 0.18
@export_group("뽑기")
## 뽑는 동안 영주의 몸(화면만)을 손잡이에서 이만큼(m)까지 당겨 세운다. 규칙의 뽑기 거리는 1.1칸(2.2m)까지라 팔이 닿게.
@export var pull_stand: float = 1.6
@export_group("")

var rules: Rules
## 결투(21단계)에서 이 몸이 규칙의 몇 번째 영주인지. -1이면 rules.lord(그 밖의 장면).
var seat: int = -1

@onready var _model: Node3D = $Model
@onready var _hand: Node3D = get_node_or_null("Model/Hand") as Node3D
@onready var _blade: MeshInstance3D = get_node_or_null("Model/Hand/Blade") as MeshInstance3D
var _guard := MeshInstance3D.new()
var _guard_mat := StandardMaterial3D.new()
## 밤에 영주 둘레만 밝히는 횃불.
var torch := OmniLight3D.new()
var _ghost_mesh := CapsuleMesh.new()
var _ghosts: Array[MeshInstance3D] = []
## 기사 모델(없으면 null, 기본 도형을 쓴다).
var character: LordCharacter = null
var _busy: float = 0.0
var _last_dash: float = 0.0
## 맞았다(lord_hurt). 다음 화면에 맞는 동작을 튼다.
var _hurt: bool = false
var _rope := MeshInstance3D.new()
var _rope_head := MeshInstance3D.new()
var _air: float = 0.0
var _hook_t: float = -1.0
var _hook_total: float = 1.0
var _rope_out: float = 0.0
var _rope_to := Vector3.ZERO
var _state: String = ""
var _yaw_now: float = 0.0
var _yaw_ready: bool = false
var _fx: SlashFx = null
var _sweep: float = 1.0
## 지금 트는 좌클릭 동작(MoveMotion.plan의 결과)과 시작한 뒤 지난 시간. 비어 있으면 동작이 없다.
var _plan: Dictionary = {}
var _plan_t: float = 0.0
var _then_done: bool = true
## 칼 궤적을 그릴 때(동작 시작부터 초, x < 0이면 안 그림)와 face_lock으로 고정한 몸의 돌기.
var _trail_window := Vector2(-1.0, -1.0)
var _lock_yaw: float = 0.0
var _hide_done: bool = false
## 뽑는 동안의 몸(PullMotion, 14단계)과 손잡이 자리(세계 좌표), 쥔 칼을 숨겼는지.
var _pull := PullMotion.rest()
var _pull_at := Vector3.ZERO
var _pull_has_at: bool = false
var _pull_hid: bool = false
## 점프: 이번 화면의 높이(m), 몸 자세(MoveMotion.hop_pose), 지난 화면에 공중이었는지, 내려앉은 뒤 지난 초(-1이면 아님), hop 동작을 트는 중인지.
var _jump_y: float = 0.0
var _hop: Dictionary = {"bend": 0.0, "tuck": 0.0, "pitch": 0.0}
var _was_air: bool = false
var _land_t: float = -1.0
var _hop_anim: bool = false
## 39단계 말: 들판이 넣는다(없으면 탈 일이 없다). 탄 정도(0~1, 타고 내릴 때 부드럽게), 기본 도형의 말 탄 다리.
var horse_view: HorseView = null
var _ride_k: float = 0.0
var _ride_legs: Node3D = null


func setup(r: Rules) -> void:
	rules = r
	r.move_started.connect(_on_move_started)
	r.move_area.connect(_on_move_area)
	r.projectile_ended.connect(func(_p: Projectile) -> void:
		if _mine():
			_show_sword(true))
	r.lord_hurt.connect(func(_d: float) -> void: _hurt = true)
	r.duelist_hurt.connect(func(s: int, _d: float, _b: bool) -> void:
		if s == seat:
			_hurt = true)
	r.pull_good.connect(func(_h: Hilt, k: int) -> void: PullMotion.good(_pull, k))
	r.pull_perfect.connect(func(_h: Hilt) -> void: PullMotion.perfect(_pull))


func _ready() -> void:
	_ghost_mesh.radius = 0.42
	_ghost_mesh.height = 1.6
	if LordCharacter.available():
		for c in _model.get_children():
			c.queue_free()
		_hand = null
		_blade = null
		character = LordCharacter.new()
		_model.add_child(character)
		_fx = SlashFx.new()
		add_child(_fx)
	if _hand:
		var gm := BoxMesh.new()
		gm.size = Vector3(0.34, 0.07, 0.07)
		_guard.mesh = gm
		_guard_mat.emission_enabled = true
		_guard_mat.emission_energy_multiplier = 0.6
		_guard.material_override = _guard_mat
		_guard.position = Vector3(0, 0, -0.3)
		_hand.add_child(_guard)
	if _blade:
		_blade.mesh = (_blade.mesh as BoxMesh).duplicate()
	_build_rope()
	torch.position = Vector3(0.4, 2.2, 0.3)
	torch.light_color = Color(1.0, 0.72, 0.45)
	torch.omni_range = 9.0
	torch.light_energy = 0.0
	torch.shadow_enabled = true
	add_child(torch)


## 이 몸의 영주 상태와 쥔 검, 날아가는 것(결투에서는 seat 번째 영주의 것).
func _lord_state() -> LordState:
	return rules.lords[seat] if seat >= 0 else rules.lord


func _sword() -> Sword:
	return rules.seat_sword(seat) if seat >= 0 else rules.current()


func _projs() -> Array[Projectile]:
	return rules.seat_projectiles(seat) if seat >= 0 else rules.projectiles


## 지금 신호를 낸 영주가 이 몸인가(결투에서 영주마다 신호가 섞이지 않게).
func _mine() -> bool:
	return seat < 0 or rules.cur_seat == seat


## 쥔 검이 바뀌면 부른다. null이면 맨손.
func set_sword(s: Sword, grades: GradeTable) -> void:
	if character:
		character.set_sword(s, grades)
		if s:
			_fx.color = Color(0.9, 0.92, 1.0) if s.grade == 0 else (grades.colors[s.grade] as Color).lightened(0.25)
		return
	if not _blade:
		return
	_blade.visible = s != null
	_guard.visible = s != null
	if s == null:
		return
	var m := _blade.mesh as BoxMesh
	m.size = Vector3(s.form.blade_width, 0.05, s.form.blade_length)
	_blade.position = Vector3(0, 0, -(0.32 + s.form.blade_length / 2.0))
	var c: Color = grades.colors[s.grade]
	_guard_mat.albedo_color = c
	_guard_mat.emission = c


## main이 매 프레임 부른다. alpha는 지난 틱과 이번 틱 사이의 위치(0~1).
func draw(alpha: float, delta: float) -> void:
	var L := _lord_state()
	position = Grid.cells_to_world(L.prev_pos.lerp(L.pos, alpha))
	_draw_pull_stand()
	_draw_hook(L, delta)
	if not _plan.is_empty():
		_plan_t += delta
		if _plan_t >= maxf(float(_plan.hold), float(_plan.time)):
			_plan = {}
			if character:
				character.set_frozen(rules.freeze > 0)
	# 기본 도형: 손을 휘두르는 쪽으로 돌린다(칼 궤적 대신)
	var rel: float = idle_blade_angle
	if L.swing > 0.0:
		var k: float = 1.0 - L.swing / rules.data.lord.swing_time
		var dir: float = float(_plan.get("side", 1.0)) if not _plan.is_empty() else 1.0
		rel = -dir * L.swing_arc / 2.0 + dir * L.swing_arc * minf(1.0, k * 1.6)
	if _hand:
		_hand.rotation.y = -rel
	_step_jump(L, alpha, delta)
	var riding: bool = L.riding and horse_view != null
	_ride_k = move_toward(_ride_k, 1.0 if riding else 0.0, delta / maxf(ride_blend, 0.01))
	if character:
		character.set_frozen(rules.freeze > 0 or _paused() or _air_frozen(L))
		_step_then()
		_animate(L, delta)
		_turn(L, delta)
		_draw_trail(delta)
		_step_hide()
	else:
		_yaw_now = _yaw(L.face)
	# 동작의 돌기·뜨기·숙이기를 얹는다(갈고리는 _draw_hook이 이미 띄우니 한 번만)
	var pose: Dictionary = MoveMotion.pose(_plan, _plan_t, float(_plan.get("time", 0.0))) if not _plan.is_empty() else MoveMotion.pose({}, 0.0, 0.0)
	if _plan.get("move", &"") == &"hook":
		pose["y"] = 0.0
	# 뽑는 동안: 손잡이를 보고, 뒤로 버티며 떨고, 제대로 당김에 젖힌다(끝난 뒤에도 마지막 젖힘이 끝날 때까지)
	var pulling: bool = rules.pull_hilt != null
	if pulling and _pull_has_at:
		var want: float = PullMotion.face_yaw(position, _pull_at)
		_yaw_now = lerp_angle(_yaw_now, want, 1.0 - exp(-turn_fast * delta)) if character else want
	_pull_sword(pulling)
	pose = PullMotion.add(pose, PullMotion.pose(_pull, {"pulling": pulling, "steps": rules.pull_steps}, delta, character))
	pose = PullMotion.add(pose, _jump_pose())
	var seat: float = _ride_pose(pose)
	MoveMotion.apply(_model, pose, _yaw_now, _air + _jump_y + seat)
	for i in range(_ghosts.size() - 1, -1, -1):
		var g := _ghosts[i]
		var m := g.material_override as StandardMaterial3D
		m.albedo_color.a -= ghost_color.a * delta / ghost_life
		if m.albedo_color.a <= 0.0:
			g.queue_free()
			_ghosts.remove_at(i)
	if L.dash > 0.0 and character == null:   # 기사 모델은 구르기 동작이 있어서 잔상을 남기지 않는다
		_spawn_ghost()


## 뽑는 동안 몸을 손잡이 쪽으로 pull_stand(m)까지 당겨 세운다(버티기 세기만큼 부드럽게). 규칙의 자리는 그대로.
func _draw_pull_stand() -> void:
	if rules.pull_hilt != null:
		_pull_at = Grid.cells_to_world(rules.pull_hilt.pos)
		_pull_has_at = true
	var k: float = float(_pull.strain)
	if not _pull_has_at or k <= 0.0:
		if rules.pull_hilt == null:
			_pull_has_at = k > 0.0 and _pull_has_at
		return
	var to: Vector3 = _pull_at - position
	to.y = 0.0
	var d: float = to.length()
	if d > pull_stand:
		position += to / d * (d - pull_stand) * k


## 두 손으로 손잡이를 잡는 자세라 뽑는 동안 쥔 칼을 숨긴다. 끝나면(던진 칼이 날아가는 중이 아니면) 다시 보인다.
func _pull_sword(pulling: bool) -> void:
	if pulling and not _pull_hid:
		_pull_hid = true
		_show_sword(false)
	elif not pulling and _pull_hid:
		_pull_hid = false
		if not _projs().any(func(p: Projectile) -> bool: return p.kind == &"boomerang"):
			_show_sword(true)


## 메아리 계곡 같은 두 번째 베기: 그 자리에 베기 빛만 다시 그린다.
func echo_arc(at: Vector2, face: float, arc: float, reach: float) -> void:
	if _fx:
		_fx.arc(Grid.cells_to_world(at, _fx.arc_height), face, arc, Grid.cells_to_meters(minf(reach, 12.0)), -_sweep, 0.0, false)


# ---------------------------------------------------------------- 좌클릭 동작(MoveMotion)

## 좌클릭 동작 하나가 시작됐다. 메아리(효과만 다시 울림)는 몸을 움직이지 않는다.
func _on_move_started(move: StringName, info: Dictionary) -> void:
	if not _mine() or bool(info.get("echo", false)):
		return
	_start_plan(MoveMotion.plan(move, info, character), info)


## 반격 자세에서 맞아 반격이 나가면 반격 동작으로 바꿔 튼다.
func _on_move_area(move: StringName, info: Dictionary) -> void:
	if not _mine():
		return
	if move == &"parry" and info.get("shape", &"") == &"circle" and not bool(info.get("echo", false)):
		_start_plan(MoveMotion.plan(&"parry_counter", info, character), info)


func _start_plan(p: Dictionary, info: Dictionary) -> void:
	_plan = p
	_plan_t = 0.0
	_then_done = (p.then as Dictionary).is_empty()
	_hide_done = false
	_trail_window = p.trail
	_lock_yaw = _yaw(float(info.get("face", rules.lord.face)))
	if bool(p.face_lock):
		_yaw_now = _lock_yaw
	if character == null:
		return
	character.set_frozen(false)
	_fx.clear_trail()
	if String(p.anim) != "":
		character.play(String(p.anim), float(p.speed), float(p.from))
		_state = "move"
		_busy = float(p.hold)


## 멈춰 세우는 동작(발도, 반격 자세, 지진 …): pause_at초부터 resume_after초 동안. hold가 끝나면 반드시 푼다.
func _paused() -> bool:
	if _plan.is_empty() or _plan_t >= float(_plan.hold):
		return false
	var at: float = float(_plan.pause_at)
	return at >= 0.0 and _plan_t >= at and _plan_t < at + float(_plan.resume_after)


## then.at초에 이어 튼다(물러나 베기의 뒤로 뛰기, 갈고리의 닿아서 베기, 반격 자세의 약한 베기).
func _step_then() -> void:
	if _then_done or _plan.is_empty():
		return
	var t: Dictionary = _plan.then
	if _plan_t < float(t.at):
		return
	_then_done = true
	character.set_frozen(rules.freeze > 0)
	if String(t.get("anim", "")) != "":
		character.play(String(t.anim), float(t.get("speed", 1.0)), float(t.get("from", 0.0)))
		_state = "move"
	var tr: Vector2 = t.get("trail", Vector2(-1.0, -1.0))
	if tr.x >= 0.0:
		_trail_window = tr + Vector2(float(t.at), float(t.at))
		_fx.clear_trail()


## 칼 던지기: 놓는 순간 손의 칼을 숨긴다. 던진 칼이 돌아오면(projectile_ended) 다시 보인다.
func _step_hide() -> void:
	if _plan.is_empty() or _hide_done:
		return
	var at: float = float(_plan.get("hide_sword", -1.0))
	if at < 0.0 or _plan_t < at:
		return
	_hide_done = true
	for p in _projs():
		if p.kind == &"boomerang":
			_show_sword(false)
			return


func _show_sword(on: bool) -> void:
	if character:
		character.set_sword_visible(on)
	elif _blade:
		_blade.visible = on and _sword() != null
		_guard.visible = _blade.visible


## 기사 모델의 동작을 고른다. 좌클릭 동작(_start_plan)·구르기·맞기는 끝날 때까지 두고, 그 밖에는 달리기와 서 있기.
## 규칙의 값이 새로 커지는 순간(돌진)이나 신호(맞음)를 보고 한 번만 튼다.
func _animate(L: LordState, delta: float) -> void:
	_busy = maxf(0.0, _busy - delta)
	if L.hp <= 0.0:
		if _state != "death":
			_one_shot("death", 1.0)
			_busy = 999.0
	elif L.dash > _last_dash:
		_plan = {}
		var w: Vector2 = character.roll_window
		if w.x >= 0.0:
			_one_shot("roll", (w.y - w.x) / roll_time, roll_time, w.x)
		else:
			_one_shot("roll", roll_speed, roll_hold)
	elif _hurt and _plan.is_empty() and L.dash <= 0.0 and not L.riding:
		_one_shot("hit", hit_speed)
	elif _busy <= 0.0 and L.riding:   # 39단계: 말 위에서는 서 있기 동작(다리는 LegFold.ride가 굽힌다)
		_loop("idle")
	elif _busy <= 0.0 and not L.airborne():   # 공중에서는 뛰기 전 동작을 그대로 둔다(hop이 없으면 멈춰 두고 다리를 접는다)
		if rules.pull_hilt != null:
			_loop("pull")
		elif L.moving:
			_loop("run", run_speed)
		else:
			_loop("idle")
	_hurt = false
	_last_dash = L.dash


## 모델이 보는 쪽: 구를 때는 구르는 쪽, 좌클릭 동작이 face_lock이면 그 방향에 고정, 휘두를 때는 겨눈 쪽(규칙의 face),
## 걸을 때는 걷는 쪽. 서 있으면 그대로 둔다. 확 돌리지 않고 부드럽게 돌려 걸음이 촐랑대지 않게 한다.
func _turn(L: LordState, delta: float) -> void:
	if not _yaw_ready:
		_yaw_now = _yaw(L.face)
		_yaw_ready = true
	var target: float = _yaw_now
	var fast: bool = false
	var planned: bool = not _plan.is_empty() and _plan_t < float(_plan.hold)
	if L.hook > 0.0:
		target = _yaw(L.face)
		fast = true
	elif (_state == "roll" and _busy > 0.0) or L.dash > 0.0:
		target = _yaw(L.dash_dir.angle())
		fast = true
	elif planned and bool(_plan.face_lock):
		_yaw_now = _lock_yaw
		return
	elif L.swing > 0.0 or (planned and _plan_t < minf(float(_plan.hold), slash_hold) * 0.5):
		target = _yaw(L.face)
		fast = true
	elif L.moving:
		target = _yaw(L.move_dir.angle())
	var k: float = 1.0 - exp(-(turn_fast if fast else turn_speed) * delta)
	_yaw_now = lerp_angle(_yaw_now, target, k)


# ---------------------------------------------------------------- 걸어 다니는 점프(30단계)

## 규칙의 공중 시간을 틱 사이로 이어 높이와 자세를 정한다. 뛰는 순간(hop 동작이 있으면 튼다)과 내려앉는 순간을 알아챈다.
func _step_jump(L: LordState, alpha: float, delta: float) -> void:
	var D: LordData = rules.data.lord
	var aloft: bool = L.airborne()
	if L.riding:   # 39단계: 말 도약(HorseData.leap_*)은 몸을 웅크리지 않고 말과 같이 뜬다
		var Hd: HorseData = rules.data.horse
		_was_air = aloft
		_land_t = -1.0
		_hop = MoveMotion.hop_pose(-1.0, -1.0)
		_jump_y = lerpf(LordState.arc(L.prev_air, Hd.leap_time, Hd.leap_height), LordState.arc(L.air, Hd.leap_time, Hd.leap_height), alpha)
		return
	if aloft and not _was_air:
		_land_t = -1.0
		_start_hop()
	elif not aloft and _was_air:
		_land_t = 0.0
	_was_air = aloft
	if _hop_anim and (character == null or _state != "hop"):
		_hop_anim = false   # hop 동작이 끝났거나 맞기 같은 다른 동작으로 바뀌었다
	if _land_t >= 0.0:
		_land_t += delta
		if _land_t > MoveMotion.HOP_LAND:
			_land_t = -1.0
	var u: float = -1.0
	if aloft and D.jump_time > 0.0:
		var left: float = lerpf(L.prev_air if L.prev_air > 0.0 else D.jump_time, L.air, alpha)
		u = 1.0 - left / D.jump_time
	if L.hp <= 0.0:   # 공중에서 쓰러지면 내려온다(규칙은 멈춘다)
		_jump_y = move_toward(_jump_y, 0.0, delta * 6.0)
		_hop = MoveMotion.hop_pose(-1.0, -1.0)
		return
	_jump_y = lerpf(LordState.air_height(L.prev_air, D), LordState.air_height(L.air, D), alpha)
	_hop = MoveMotion.hop_pose(u, _land_t)


## 뛰는 순간: 기사 모델에 hop 동작이 있으면 발이 땅을 떠난 구간(hop_window)을 뜬 시간에 맞춰 튼다.
func _start_hop() -> void:
	_hop_anim = false
	if character == null or not character.has("hop") or rules.pull_hilt != null:
		return
	var w: Vector2 = character.hop_window
	var T: float = rules.data.lord.jump_time
	if w.x >= 0.0 and w.y > w.x and T > 0.0:
		_one_shot("hop", (w.y - w.x) / T, -1.0, w.x)
	else:
		_one_shot("hop", 1.0)
	_plan = {}
	_hop_anim = true


## hop 동작이 없는 기사 모델은 공중에서 뛰기 전 동작을 멈춰 두고 다리만 접는다(뛰던 다리가 허공을 젓지 않게).
func _air_frozen(L: LordState) -> bool:
	return L.airborne() and not _hop_anim


## 점프 자세를 모델에 얹을 몫(PullMotion.add 모양). 기사 모델은 다리를 굽히고 무릎 굽힘만큼 몸을 내린다(발이 땅에 붙게), 기본 도형은 눌린다.
func _jump_pose() -> Dictionary:
	var bend: float = float(_hop.bend)
	var tuck: float = float(_hop.tuck)
	var out: Dictionary = {"pitch": float(_hop.pitch)}
	if character:
		character.set_ride(_ride_k)
		if _ride_k > 0.0:
			character.set_legs(0.0, 0.0)
		elif _hop_anim:
			character.set_legs(0.0, 0.0)
			out["pitch"] = 0.0
		else:
			character.set_legs(tuck, bend)
			out["crouch"] = character.bend_drop(bend)
	else:
		out["scale_y"] = 1.0 - hop_squash_bend * bend - hop_squash_tuck * tuck
	return out


# ---------------------------------------------------------------- 말(39단계)

## 말 위 자세: 안장 높이(땅 위 m, 돌려준다)와 말의 기울기를 pose에 얹는다. 기본 도형은 줄여 앉히고 다리 둘을 말 양옆에 단다.
func _ride_pose(pose: Dictionary) -> float:
	if _ride_k <= 0.0 or horse_view == null:
		if _ride_legs:
			_ride_legs.visible = false
		return 0.0
	var k: float = smoothstep(0.0, 1.0, _ride_k)
	var seat: float = horse_view.seat_height()
	pose["pitch"] = float(pose.get("pitch", 0.0)) - horse_view.seat_pitch() * k
	if character:
		return (seat - character.seat_drop()) * k
	pose["scale_y"] = float(pose.get("scale_y", 1.0)) * lerpf(1.0, ride_squash, k)
	pose["scale_xz"] = lerpf(1.0, ride_slim, k)
	if _ride_legs == null:
		_make_ride_legs()
	_ride_legs.visible = _ride_k > 0.5
	_ride_legs.position = Vector3(0.0, seat - ride_sink + _jump_y, 0.0)
	_ride_legs.rotation = Vector3(horse_view.seat_pitch(), horse_view.seat_yaw(), 0.0)
	return (seat - ride_sink) * k


## 기본 도형의 말 탄 다리: 엉덩이에서 앞아래로 넓적다리, 무릎에서 뒤아래로 정강이, 등자에 걸친 장화(말 몸통 양옆).
func _make_ride_legs() -> void:
	_ride_legs = Node3D.new()
	_ride_legs.name = "RideLegs"
	add_child(_ride_legs)
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.12, 0.11, 0.13)
	cloth.roughness = 0.9
	var boot := StandardMaterial3D.new()
	boot.albedo_color = Color(0.07, 0.05, 0.035)
	boot.roughness = 0.6
	for side in [-1.0, 1.0]:
		var hip := Vector3(0.15 * side, 0.12, 0.02)
		var knee := Vector3(0.36 * side, -0.06, -0.3)
		var ankle := Vector3(0.39 * side, -0.52, -0.1)
		_limb(hip, knee, 0.11, cloth)
		_limb(knee, ankle, 0.085, cloth)
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.11, 0.1, 0.26)
		b.mesh = bm
		b.material_override = boot
		b.position = ankle + Vector3(0.0, -0.04, -0.06)
		_ride_legs.add_child(b)


## 반지름 r의 둥근 막대로 a와 b를 잇는다(_ride_legs 기준).
func _limb(a: Vector3, b: Vector3, r: float, m: Material) -> void:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = a.distance_to(b) + 2.0 * r
	c.radial_segments = 10
	c.rings = 3
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = m
	var y: Vector3 = (b - a).normalized()
	var x: Vector3 = y.cross(Vector3.BACK if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	mi.transform = Transform3D(Basis(x, y, x.cross(y).normalized()), (a + b) * 0.5)
	_ride_legs.add_child(mi)


# ---------------------------------------------------------------- 갈고리

func _build_rope() -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = rope_color
	m.metallic = 0.7
	m.roughness = 0.35
	# 밤에도 줄이 보이게 아주 조금 빛난다
	m.emission_enabled = true
	m.emission = rope_color
	m.emission_energy_multiplier = 0.25
	var c := CylinderMesh.new()
	c.top_radius = 0.022
	c.bottom_radius = 0.022
	c.height = 1.0
	c.radial_segments = 6
	c.rings = 1
	_rope.mesh = c
	_rope.material_override = m
	_rope.top_level = true
	_rope.visible = false
	_rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_rope)
	var h := CylinderMesh.new()
	h.top_radius = 0.0
	h.bottom_radius = 0.07
	h.height = 0.22
	h.radial_segments = 6
	_rope_head.mesh = h
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(0.3, 0.29, 0.28)
	hm.metallic = 0.9
	hm.roughness = 0.35
	_rope_head.material_override = hm
	_rope_head.top_level = true
	_rope_head.visible = false
	add_child(_rope_head)


## 날아가는 동안: 줄을 쏘아 적에 걸고, 몸은 포물선으로 뜬다. 끝나면 줄을 거두고 내려온다.
func _draw_hook(L: LordState, delta: float) -> void:
	if L.hook > 0.0 and L.hook_target != null:
		var e: Enemy = L.hook_target
		if _hook_t < 0.0:
			_hook_t = 0.0
			_hook_total = maxf(0.5, L.hook_from.distance_to(e.pos) - e.radius)
		_hook_t += delta
		var g: Vector3 = Grid.cells_to_world(e.pos)
		_rope_to = g + Vector3(0, Grid.cells_to_meters(e.radius) * 1.5 + HillBuilder.height(g.x, g.z), 0)
		var p: float = clampf(L.pos.distance_to(L.hook_from) / _hook_total, 0.0, 1.0)
		var h: float = minf(hook_arc_max, Grid.cells_to_meters(_hook_total) * 0.16)
		_air = sin(p * PI) * h
		_rope_out = minf(1.0, _hook_t / hook_rope_shoot)
	else:
		_hook_t = -1.0
		_air = lerpf(_air, 0.0, 1.0 - exp(-14.0 * delta))
		_rope_out = maxf(0.0, _rope_out - delta / 0.12)
	_model.position.y = _air
	var a: Vector3 = position + Vector3(0, 1.25 + _air, 0)
	var b: Vector3 = a.lerp(_rope_to, _rope_out)
	var len: float = a.distance_to(b)
	var show: bool = _rope_out > 0.01 and len > 0.1
	_rope.visible = show
	_rope_head.visible = show
	if not show:
		return
	var up: Vector3 = (b - a) / len
	var basis := Basis(Quaternion(Vector3.UP, up))
	_rope.global_transform = Transform3D(basis * Basis.from_scale(Vector3(1.0, len, 1.0)), (a + b) * 0.5)
	_rope_head.global_transform = Transform3D(basis, b)


## 동작의 trail 구간(MoveMotion.plan의 trail, then이 있으면 then의 것) 동안 칼날의 두 끝을 SlashFx에 넘긴다.
func _draw_trail(delta: float) -> void:
	var bp: Array[Vector3] = character.blade_points()
	var w: Vector2 = _trail_window
	var active: bool = not _plan.is_empty() and w.x >= 0.0 and _plan_t >= w.x and _plan_t <= w.y and not bp.is_empty()
	if bp.is_empty():
		bp = [Vector3.ZERO, Vector3.ZERO]
	_fx.trail_step(delta, active, bp[0].lerp(bp[1], 0.25), bp[1])


func _loop(state: String, speed: float = 1.0) -> void:
	_state = state
	character.play(state, speed)


## cap: 길어도 이만큼만 본다(0 이하면 끝까지). from: 몇 초째부터.
func _one_shot(state: String, speed: float, cap: float = -1.0, from: float = 0.0) -> void:
	_state = state
	var name: String = character.play(state, speed, from)
	var whole: float = maxf(0.0, character.length(name) - character.last_from) / maxf(speed, 0.01)
	_busy = minf(whole, cap) if cap > 0.0 else whole


## 규칙의 각도(0 = 동쪽 +x, PI/2 = 남쪽 +z)를 모델의 앞(-Z)이 그쪽을 보게 하는 회전으로 바꾼다.
static func _yaw(face: float) -> float:
	return atan2(-cos(face), -sin(face))


func _spawn_ghost() -> void:
	var g := MeshInstance3D.new()
	g.mesh = _ghost_mesh
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = ghost_color
	g.material_override = m
	g.top_level = true
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(g)
	g.global_position = global_position + Vector3(0, 0.8, 0)
	_ghosts.append(g)
