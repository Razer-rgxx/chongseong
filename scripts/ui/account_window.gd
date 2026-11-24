class_name AccountWindow
extends Control
## 이메일 로그인 창(UiKit 모양, docs/account.md). 시작 화면 메뉴 앞에 뜬다.
## 로그인·가입(닉네임 칸이 생김)·인증 코드(인증이 필요할 때만)·게스트로 하기. 끝나면 done.
## 비밀번호는 이 창의 칸에만 있고 저장하지 않는다(성공하면 칸을 비운다).

signal done

var _mail: LineEdit
var _pass: LineEdit
var _nick: LineEdit
var _code: LineEdit
var _nick_row: Control
var _code_row: Control
var _status: Label
var _buttons: Array[Button] = []
var _register_mode: bool = false
var _busy: bool = false
var _btn_register: Button
var _btn_resend: Button


func _ready() -> void:
	Account.warm()   # 미리 접속(2026-11-24: 로그인이 너무 오래 걸렸다)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var box := UiKit.center_panel(self)
	box.custom_minimum_size = Vector2(460, 0)
	var t := UiKit.label("계정", 26, UiKit.TITLE)
	box.add_child(t)
	box.add_child(UiKit.ornament_rule())
	_mail = _field(box, "이메일", false)
	_pass = _field(box, "비밀번호", true)
	_nick_row = _field_row(box, "닉네임")
	_nick = _nick_row.get_meta("edit")
	_nick_row.visible = false
	_code_row = _field_row(box, "인증 코드")
	_code = _code_row.get_meta("edit")
	_code_row.visible = false
	_status = UiKit.label("", 15, UiKit.MUTED)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(420, 40)
	box.add_child(_status)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	row.add_child(_btn("로그인", _on_login))
	_btn_register = _btn("가입", _on_register)
	row.add_child(_btn_register)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	box.add_child(row2)
	_btn_resend = _btn("코드 다시 받기", _on_resend)
	_btn_resend.visible = false
	row2.add_child(_btn_resend)
	box.add_child(UiKit.rule())
	box.add_child(_btn("게스트로 하기", _on_guest))
	box.add_child(UiKit.label("게스트는 계정 없이 혼자 즐깁니다. 설정 창에서 나중에 로그인할 수 있습니다.", 13, UiKit.MUTED))
	_mail.text = Account.email
	if not Account.available():
		set_status("GD-Sync 키가 없습니다. 게스트로 하거나 키를 넣어 주세요.")


## 글자 줄 하나(이름표 + 입력 칸). 돌려주는 것은 행이고, 칸은 meta "edit".
func _field_row(box: VBoxContainer, label_text: String, secret: bool = false) -> Control:
	var row := HBoxContainer.new()
	var l := UiKit.label(label_text, 16, UiKit.TITLE)
	l.custom_minimum_size = Vector2(90, 0)
	row.add_child(l)
	var e := LineEdit.new()
	e.secret = secret
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.custom_minimum_size = Vector2(300, 34)
	e.text_submitted.connect(func(_s: String) -> void: _on_submit())
	row.add_child(e)
	row.set_meta("edit", e)
	box.add_child(row)
	return row


func _field(box: VBoxContainer, label_text: String, secret: bool) -> LineEdit:
	return _field_row(box, label_text, secret).get_meta("edit")


func _btn(text: String, f: Callable) -> Button:
	var b := UiKit.button(text, f, 38)
	_buttons.append(b)
	return b


func set_status(text: String, bad: bool = true) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", Color(0.9, 0.45, 0.35) if bad else UiKit.TEXT)


func _lock(on: bool) -> void:
	_busy = on
	for b in _buttons:
		b.disabled = on


func _on_submit() -> void:
	if _code_row.visible and _code.text.strip_edges() != "":
		_on_verify()
	elif _register_mode:
		_on_register()
	else:
		_on_login()


func _on_login() -> void:
	if _busy:
		return
	_lock(true)
	set_status("로그인하는 중…", false)
	var r: Dictionary = await Account.login(_mail.text, _pass.text)
	_after(r)


func _on_register() -> void:
	if _busy:
		return
	if not _register_mode:
		_register_mode = true
		_nick_row.visible = true
		_btn_register.text = "가입하기"
		set_status("닉네임(3~20글자)을 적고 가입하기를 누르세요.", false)
		return
	_lock(true)
	set_status("가입하는 중…", false)
	var r: Dictionary = await Account.register(_mail.text, _nick.text, _pass.text)
	_after(r)


func _on_verify() -> void:
	if _busy:
		return
	_lock(true)
	set_status("인증하는 중…", false)
	var r: Dictionary = await Account.verify(_mail.text, _code.text)
	_after(r)


func _on_resend() -> void:
	if _busy:
		return
	_lock(true)
	var r: Dictionary = await Account.resend(_mail.text, _pass.text)
	_after(r)


func _on_guest() -> void:
	if _busy:
		return
	Account.set_guest(true)
	_finish()


func _after(r: Dictionary) -> void:
	_lock(false)
	if not is_inside_tree():
		return
	if r.ok:
		_pass.text = ""
		_finish()
		return
	if r.verify:
		_code_row.visible = true
		_btn_resend.visible = true
		if not _btn_register.text.contains("인증"):
			_btn_register.text = "인증 코드"
			_btn_register.pressed.disconnect(_on_register)
			_btn_register.pressed.connect(_on_verify)
	set_status(r.msg, not r.verify)


func _finish() -> void:
	done.emit()
	queue_free()
