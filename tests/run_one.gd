extends SceneTree
## 테스트 파일 하나만 돌린다(빨리 볼 때): godot --headless --path . -s tests/run_one.gd -- horse_tests
var _pass: int = 0
var _fail: int = 0


func _init() -> void:
	var d := GameData.load_default()
	var name: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "horse_tests"
	(load("res://tests/%s.gd" % name) as GDScript).call("run", d, check)
	print("통과 %d, 실패 %d" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func check(ok: bool, what: String) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
		printerr("실패: " + what)
