extends SceneTree
## 좌클릭 동작 20가지와 속성 4가지의 효과(MoveFx)를 가짜 신호로 하나씩 틀어 PNG로 찍는 도구(이펙트팀).
## 언덕(main.tscn)을 그대로 띄워 빛과 땅이 게임과 같다. 영주는 싸움터 가운데 남쪽에 서서 북쪽(-Z)을 보고, 카메라는 3인칭 뒤.
##   DISPLAY=:99 godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility --resolution 1280x720 \
##     --fixed-fps 30 -s scripts/debug/move_gallery.gd -- /home/claude/hill/team/fx/
## 첫 사용자 인자가 저장할 폴더(기본 /home/claude/hill/team/fx/). 장면마다 <번호>_<이름>_<때>.png, 끝에 sheet_<n>.png(모아 보기).
## 둘째 인자를 주면 이름에 그 낱말(쉼표로 여럿)이 든 장면만 찍는다(예: smash,quake). 소프트웨어 렌더러에서는 장면 하나에 20초쯤 걸린다.
## 규칙은 건드리지 않는다: MoveFx.on_* 함수를 바로 부르고, 날아가는 것(Projectile)은 여기서 옮긴다.

const MAIN: String = "res://scenes/world/main.tscn"
## 장검의 칼 길이와 폭(칸, 라디안). 설계서 1절의 배수를 여기에 곱한다.
const B: float = 1.55
const A: float = 1.9
const P := Vector2(17.0, 14.0)
const F: float = -PI / 2.0
const FWD := Vector2(0.0, -1.0)

var out: String = "/home/claude/hill/team/fx/"
var main: Node3D
var fx: MoveFx
var cam: Camera3D
var label: Label
var saved: Array[String] = []
var sims: Array[Dictionary] = []
var _scene: int = 0
var _night: bool = false
var _only: PackedStringArray = []
## 이 시각(밀리초, 실제 시간)이 지나면 멈춘 것으로 보고 끝낸다.
var _deadline: int = 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	if not out.ends_with("/"):
		out += "/"
	if args.size() > 1:
		_only = args[1].split(",", false)
	DirAccess.make_dir_recursive_absolute(out)
	# 스크립트 오류로 멈추면 끝낸다(실제 시간 40분)
	_deadline = Time.get_ticks_msec() + 40 * 60 * 1000
	process_frame.connect(func() -> void:
		if Time.get_ticks_msec() > _deadline:
			push_error("갤러리: 시간 초과")
			quit(1))
	_run()


func _run() -> void:
	main = (load(MAIN) as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	(main.get_node("UI") as CanvasLayer).visible = false
	var r: Rules = main.get("rules")
	if r == null:
		push_error("갤러리: main의 rules가 없다")
		quit(1)
		return
	r.debug_god = true
	r.lord.pos = P
	r.lord.prev_pos = P
	r.lord.face = F
	cam = main.get_node("Camera")
	fx = MoveFx.new()
	main.add_child(fx)
	fx.setup(r)   # 신호가 아직 없어도 죽지 않는지 함께 본다
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	label = Label.new()
	label.position = Vector2(18, 12)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	layer.add_child(label)
	_view(32.0, 1.0)
	await _wait(1.0)

	# ---- 동작 20가지(낮)
	await _scene_play("sweep", [[0.0, _start.bind(&"sweep", {"shape": &"arc", "reach": B, "arc": A})]], [0.07, 0.17])
	await _scene_play("thrust", [[0.0, _start.bind(&"thrust", {"shape": &"line", "reach": B * 1.5, "width": 0.5})]], [0.07, 0.2])
	await _scene_play("rising", [[0.0, _start.bind(&"rising", {"shape": &"arc", "reach": B, "arc": A * 0.8, "step": 2})]], [0.07])
	await _scene_play("flurry", [
		[0.0, _start.bind(&"flurry", {"shape": &"line", "reach": B * 1.2, "width": 0.4})],
		[0.1, _area.bind(&"flurry", {"shape": &"line", "reach": B * 1.2, "width": 0.4})],
		[0.2, _area.bind(&"flurry", {"shape": &"line", "reach": B * 1.2, "width": 0.4})],
		[0.3, _area.bind(&"flurry", {"shape": &"line", "reach": B * 1.2, "width": 0.4})],
	], [0.13, 0.33])
	await _scene_play("crescent", [[0.0, _start.bind(&"crescent", {"shape": &"arc", "reach": B * 0.9, "arc": deg_to_rad(220.0)})]], [0.1])
	await _scene_play("retreat", [[0.0, _start.bind(&"retreat", {"shape": &"arc", "reach": B, "arc": A, "from": P, "to": P - FWD * 2.0, "time": 0.3})]], [0.07, 0.27])
	await _scene_play("pull", [[0.0, _start.bind(&"pull", {"shape": &"arc", "reach": B * 2.5, "arc": deg_to_rad(60.0)})]], [0.1])
	var smash_at: Vector2 = P + FWD * B * 0.8
	await _scene_play("smash", [
		[0.0, _start.bind(&"smash", {"shape": &"circle", "radius": 1.6, "at": smash_at, "delay": 0.12, "big": true})],
		[0.12, _area.bind(&"smash", {"shape": &"circle", "radius": 1.6, "at": smash_at, "big": true, "hits": 2})],
	], [0.07, 0.2, 0.5])
	await _scene_play("spin", [[0.0, _start.bind(&"spin", {"shape": &"circle", "radius": B, "big": true})]], [0.1, 0.2])
	_view(40.0, 0.75)
	await _scene_play("lunge", [[0.0, _start.bind(&"lunge", {"shape": &"line", "width": 1.6, "from": P, "to": P + FWD * 3.5, "time": 0.15, "big": true})]], [0.1, 0.2])
	_view(32.0, 1.0)
	await _scene_play("wave", [
		[0.0, _start.bind(&"wave", {"big": true})],
		[0.03, _launch.bind(&"wave", &"", 16.0, 8.0)],
	], [0.17, 0.37])
	await _scene_play("boomerang", [
		[0.0, _start.bind(&"boomerang", {"big": true})],
		[0.03, _launch.bind(&"boomerang", &"", 14.0, 6.0)],
	], [0.2, 0.6])
	_view(40.0, 0.75)
	var leap_to: Vector2 = P + FWD * 5.0
	await _scene_play("leap", [
		[0.0, _start.bind(&"leap", {"shape": &"circle", "radius": 2.0, "from": P, "to": leap_to, "time": 0.35, "big": true})],
		[0.35, _area.bind(&"leap", {"shape": &"circle", "radius": 2.0, "at": leap_to, "big": true})],
	], [0.2, 0.43])
	await _scene_play("iaido", [
		[0.0, _start.bind(&"iaido", {"shape": &"line", "reach": B * 3.0, "width": 0.6, "delay": 0.25, "big": true})],
		[0.25, _area.bind(&"iaido", {"shape": &"line", "reach": B * 3.0, "width": 0.6, "big": true})],
	], [0.17, 0.3])
	_view(32.0, 1.0)
	await _scene_play("cross", [[0.0, _start.bind(&"cross", {"shape": &"plus", "reach": B * 1.3, "width": 0.6, "big": true})]], [0.13])
	_view(48.0, 0.55)
	await _scene_play("quake", [
		[0.0, _start.bind(&"quake", {"shape": &"circle", "radius": 1.5, "time": 0.6, "big": true})],
		[0.2, _area.bind(&"quake", {"shape": &"ring", "radius": 2.5, "thick": 1.0, "big": true})],
		[0.4, _area.bind(&"quake", {"shape": &"ring", "radius": 3.5, "thick": 1.0, "big": true})],
		[0.6, _area.bind(&"quake", {"shape": &"ring", "radius": 4.5, "thick": 1.0, "big": true})],
	], [0.1, 0.47, 0.67])
	_view(32.0, 1.0)
	var whirl: Dictionary = {"shape": &"circle", "radius": B * 0.9, "time": 0.6, "big": true}
	await _scene_play("whirl", [
		[0.0, _start.bind(&"whirl", whirl)],
		[0.15, _area.bind(&"whirl", whirl)],
		[0.3, _area.bind(&"whirl", whirl)],
		[0.45, _area.bind(&"whirl", whirl)],
	], [0.2, 0.5])
	_view(36.0, 0.8)
	var blink_to: Vector2 = P + FWD * 4.0
	await _scene_play("blink", [[0.0, _start.bind(&"blink", {"shape": &"arc", "reach": B, "arc": A, "from": P, "to": blink_to, "at": blink_to, "face": F + PI, "big": true})]], [0.07, 0.17])
	var hook_to: Vector2 = P + FWD * 6.0
	await _scene_play("hook", [
		[0.0, _start.bind(&"hook", {"from": P, "to": hook_to, "time": 0.4, "big": true})],
		[0.4, _area.bind(&"hook", {"shape": &"arc", "reach": B, "arc": A, "at": hook_to, "big": true})],
	], [0.2, 0.47])
	_view(32.0, 1.0)
	await _scene_play("parry_counter", [
		[0.0, _start.bind(&"parry", {"time": 0.35})],
		[0.2, _area.bind(&"parry", {"shape": &"circle", "radius": B * 1.2, "big": true})],
	], [0.13, 0.27])
	await _scene_play("parry_weak", [
		[0.0, _start.bind(&"parry", {"time": 0.35})],
		[0.35, _area.bind(&"parry", {"shape": &"arc", "reach": B, "arc": A, "step": 1})],
	], [0.2, 0.42])

	# ---- 속성 4가지와 메아리
	await _scene_play("fire_thrust", [[0.0, _start.bind(&"thrust", {"shape": &"line", "reach": B * 1.5, "width": 0.5, "element": &"fire"})]], [0.1, 0.3])
	await _scene_play("ice_cross", [[0.0, _start.bind(&"cross", {"shape": &"plus", "reach": B * 1.3, "width": 0.6, "big": true, "element": &"ice"})]], [0.15])
	await _scene_play("bolt_spin", [[0.0, _start.bind(&"spin", {"shape": &"circle", "radius": B, "big": true, "element": &"bolt"})]], [0.05, 0.13])
	await _scene_play("blood_sweep", [[0.0, _start.bind(&"sweep", {"shape": &"arc", "reach": B, "arc": A, "element": &"blood"})]], [0.1, 0.3])
	await _scene_play("echo_smash", [
		[0.0, _area.bind(&"smash", {"shape": &"circle", "radius": 1.6, "at": smash_at, "big": true})],
		[0.3, _area.bind(&"smash", {"shape": &"circle", "radius": 1.6, "at": smash_at, "big": true, "echo": true})],
	], [0.37])

	# ---- 밤
	_set_night(true)
	_view(28.0, 0.95, 0.0)   # 밤은 게임 카메라 그대로(영주 바로 뒤)
	await _wait(0.5)
	await _scene_play("night_sweep", [[0.0, _start.bind(&"sweep", {"shape": &"arc", "reach": B, "arc": A, "big": true})]], [0.08])
	await _scene_play("night_thrust", [[0.0, _start.bind(&"thrust", {"shape": &"line", "reach": B * 1.5, "width": 0.5})]], [0.1])
	await _scene_play("night_fire_smash", [
		[0.0, _start.bind(&"smash", {"shape": &"circle", "radius": 1.6, "at": smash_at, "delay": 0.12, "big": true, "element": &"fire"})],
		[0.12, _area.bind(&"smash", {"shape": &"circle", "radius": 1.6, "at": smash_at, "big": true, "element": &"fire"})],
	], [0.07, 0.25])
	await _scene_play("night_ice_spin", [[0.0, _start.bind(&"spin", {"shape": &"circle", "radius": B, "big": true, "element": &"ice"})]], [0.12])
	await _scene_play("night_bolt_sweep", [[0.0, _start.bind(&"sweep", {"shape": &"arc", "reach": B, "arc": A, "element": &"bolt", "big": true})]], [0.05])
	await _scene_play("night_blood_cross", [[0.0, _start.bind(&"cross", {"shape": &"plus", "reach": B * 1.3, "width": 0.6, "big": true, "element": &"blood"})]], [0.15])
	await _scene_play("night_fire_wave", [
		[0.0, _start.bind(&"wave", {"big": true, "element": &"fire"})],
		[0.03, _launch.bind(&"wave", &"fire", 16.0, 8.0)],
	], [0.27])
	await _scene_play("night_ice_boomerang", [
		[0.0, _start.bind(&"boomerang", {"big": true, "element": &"ice"})],
		[0.03, _launch.bind(&"boomerang", &"ice", 14.0, 6.0)],
	], [0.3])
	_view(48.0, 0.55, 0.0)
	await _scene_play("night_quake", [
		[0.0, _start.bind(&"quake", {"shape": &"circle", "radius": 1.5, "time": 0.6, "big": true})],
		[0.2, _area.bind(&"quake", {"shape": &"ring", "radius": 2.5, "thick": 1.0, "big": true})],
		[0.4, _area.bind(&"quake", {"shape": &"ring", "radius": 3.5, "thick": 1.0, "big": true})],
	], [0.47])
	_view(40.0, 0.7, 0.0)
	await _scene_play("night_iaido", [
		[0.0, _start.bind(&"iaido", {"shape": &"line", "reach": B * 3.0, "width": 0.6, "delay": 0.25, "big": true})],
		[0.25, _area.bind(&"iaido", {"shape": &"line", "reach": B * 3.0, "width": 0.6, "big": true})],
	], [0.3])

	_sheets()
	print("갤러리: %d장 → %s" % [saved.size(), out])
	quit()


# ---------------------------------------------------------------- 장면

## 한 장면: events = [[초, Callable], …]를 때맞춰 부르고 captures(초)마다 찍는다. 끝나면 효과를 지운다.
func _scene_play(name: String, events: Array, captures: Array) -> void:
	_scene += 1
	if not _only.is_empty() and not Array(_only).any(func(w: String) -> bool: return name.contains(w)):
		return
	fx.clear()
	sims.clear()
	await _wait(0.25)
	var t: float = 0.0
	var ev: Array = events.duplicate()
	var caps: Array = captures.duplicate()
	var end: float = float(caps.back()) + 0.05
	while t <= end:
		while not ev.is_empty() and float(ev[0][0]) <= t + 0.001:
			(ev.pop_front()[1] as Callable).call()
		_step_sims(1.0 / 30.0)
		fx.draw(1.0)
		var shoot: bool = not caps.is_empty() and float(caps[0]) <= t + 0.001
		label.text = "%02d  %s   t = %.2fs   %s" % [_scene, name, t, "night" if _night else "day"]
		await process_frame
		if shoot:
			caps.pop_front()
			await RenderingServer.frame_post_draw
			var path: String = "%s%02d_%s_%03d.png" % [out, _scene, name, roundi(t * 100.0)]
			root.get_texture().get_image().save_png(path)
			saved.append(path)
		t += main.get_process_delta_time()
	await _wait(0.05)


func _info(move: StringName, extra: Dictionary) -> Dictionary:
	var big: bool = move in [&"smash", &"spin", &"lunge", &"wave", &"boomerang", &"leap", &"iaido", &"cross", &"quake", &"whirl", &"blink"]
	var d: Dictionary = {"at": P, "face": F, "big": big, "element": &"", "step": 1, "steps": 3, "time": float(MoveMotion.TIME.get(move, 0.2))}
	d.merge(extra, true)
	return d


func _start(move: StringName, extra: Dictionary) -> void:
	fx.on_move_started(move, _info(move, extra))


func _area(move: StringName, extra: Dictionary) -> void:
	fx.on_move_area(move, _info(move, extra))


## 날아가는 것 하나(규칙 대신 여기서 옮긴다). 칼 던지기는 dist만큼 갔다가 영주에게 돌아온다.
func _launch(kind: StringName, el: StringName, speed: float, dist: float) -> void:
	var p := Projectile.new()
	p.kind = kind
	p.pos = P + FWD * 0.6
	p.prev_pos = p.pos
	p.dir = FWD
	p.element = el
	p.width = 1.2
	p.id = 42 + sims.size()
	fx.on_projectile_spawned(p)
	sims.append({"p": p, "speed": speed, "dist": dist, "gone": 0.0})


func _step_sims(dt: float) -> void:
	for i in range(sims.size() - 1, -1, -1):
		var s: Dictionary = sims[i]
		var p: Projectile = s["p"]
		var step: float = float(s["speed"]) * dt
		p.prev_pos = p.pos
		var done: bool = false
		if p.kind == &"boomerang" and p.returning:
			var back: Vector2 = P - p.pos
			if back.length() <= step:
				done = true
			else:
				p.dir = back.normalized()
				p.pos += p.dir * step
		else:
			p.pos += p.dir * step
			s["gone"] = float(s["gone"]) + step
			if float(s["gone"]) >= float(s["dist"]):
				if p.kind == &"boomerang":
					p.returning = true
				else:
					done = true
		if done:
			fx.on_projectile_ended(p)
			sims.remove_at(i)


# ---------------------------------------------------------------- 카메라와 빛

## 3인칭: pitch(도), zoom(작을수록 멀다), yaw(라디안, 0 = 영주 바로 뒤, + = 오른쪽 뒤에서 비스듬히).
## 바로 뒤에서는 앞으로 뻗는 띠가 몸에 가려서 갤러리는 대개 비스듬히 본다.
func _view(pitch_deg: float, zoom: float, yaw: float = 0.6) -> void:
	cam.set("yaw", yaw)
	cam.set("pitch", deg_to_rad(pitch_deg))
	cam.set("zoom", zoom)
	cam.call("snap")


func _set_night(on: bool) -> void:
	_night = on
	main.call("_set_light", on, true)
	var hilts: Dictionary = main.get("_hilts")
	for v: Node3D in hilts.values():
		v.visible = not on


func _wait(sec: float) -> void:
	var t: float = 0.0
	while t < sec:
		_step_sims(1.0 / 30.0)
		fx.draw(1.0)
		await process_frame
		t += main.get_process_delta_time()


# ---------------------------------------------------------------- 모아 보기

## 찍은 것을 1/3 크기로 4열씩 16장마다 한 장(sheet_1.png, sheet_2.png …)으로 모은다.
func _sheets() -> void:
	var tw: int = 426
	var th: int = 240
	var per: int = 16
	var page: int = 0
	var i: int = 0
	while i < saved.size():
		var n: int = mini(per, saved.size() - i)
		var rows: int = ceili(n / 4.0)
		var sheet := Image.create(tw * 4, th * rows, false, Image.FORMAT_RGB8)
		sheet.fill(Color(0.05, 0.05, 0.06))
		for k in n:
			var img := Image.load_from_file(saved[i + k])
			img.convert(Image.FORMAT_RGB8)
			img.resize(tw, th, Image.INTERPOLATE_BILINEAR)
			sheet.blit_rect(img, Rect2i(0, 0, tw, th), Vector2i((k % 4) * tw, (k / 4) * th))
		page += 1
		sheet.save_png("%ssheet_%d.png" % [out, page])
		i += n
