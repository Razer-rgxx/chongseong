class_name Account
extends RefCounted
## 이메일 계정(GD-Sync 계정 API 감싸기, docs/account.md). 시작 화면의 로그인 창(AccountWindow)이 쓴다.
## 키·연결이 없어도 열리고, 그때는 짧은 한국어 오류를 돌려주며 "게스트로 하기"로 계속할 수 있다.
## 비밀번호는 어디에도 저장하지 않는다(메모리에서 요청 한 번에만 쓰고 버린다). 로그인 세션 토큰은 GD-Sync 플러그인이
## 제 키로 암호화해 `user://GD-Sync/`에 두므로(자동 로그인), 여기서는 이메일·닉네임·게스트 여부만 `user://account.cfg`에 적는다.
## 결과는 {ok, msg, verify}: ok = 성공, msg = 화면에 띄울 한국어 글, verify = 인증 코드가 필요함.

const GD_NAME: String = "GDSync"
## 안에서 쓰는 오류 번호(GD-Sync 응답 번호는 0 이상).
const ERR_NO_PLUGIN: int = -1
const ERR_NO_KEYS: int = -2
const ERR_EMPTY: int = -3
const ERR_NO_ENGINE: int = -4

## 저장 자리(시험은 다른 경로를 넣는다).
static var path: String = "user://account.cfg"
static var email: String = ""
static var nickname: String = ""
static var guest: bool = false
static var logged_in: bool = false
## 관리자: 로그인 세션이 실제로 인증한 이메일의 해시(소문자·앞뒤 공백 뺀 글의 SHA-256)가 ADMIN_HASHES에 있을 때만 켜진다.
## 저장하지 않고(파일에서 읽지 않는다) 로그인·로그아웃 때마다 다시 정한다. 이메일 글자는 저장소 어디에도 없다.
static var admin: bool = false
static var ADMIN_HASHES: Array[String] = ["3d93a7674a3d0b9d5a7cff8782db7764c4a777acd275f594786f3867476d78eb"]

## 응답 번호의 이름(GD-Sync ENUMS) → 한국어. 종류마다 같은 이름이면 같은 글.
const COMMON: Dictionary = {
	"NO_RESPONSE_FROM_SERVER": "서버가 응답하지 않습니다. 연결을 확인하세요.",
	"DATA_CAP_REACHED": "서버 사용량이 가득 찼습니다. 나중에 다시 해 주세요.",
	"RATE_LIMIT_EXCEEDED": "너무 자주 눌렀습니다. 잠시 뒤에 다시 해 주세요.",
	"NO_DATABASE": "계정 저장소가 아직 켜져 있지 않습니다.",
	"BANNED": "이 계정은 이용이 막혀 있습니다.",
	"STORAGE_FULL": "계정 저장소가 가득 찼습니다.",
	"INVALID_EMAIL": "이메일 모양이 맞지 않습니다.",
	"INVALID_USERNAME": "닉네임에 쓸 수 없는 글자가 있습니다.",
	"EMAIL_ALREADY_EXISTS": "이미 가입된 이메일입니다.",
	"USERNAME_ALREADY_EXISTS": "이미 쓰는 닉네임입니다.",
	"USERNAME_TOO_SHORT": "닉네임은 3글자 이상이어야 합니다.",
	"USERNAME_TOO_LONG": "닉네임은 20글자 이하여야 합니다.",
	"PASSWORD_TOO_SHORT": "비밀번호는 3글자 이상이어야 합니다.",
	"PASSWORD_TOO_LONG": "비밀번호는 20글자 이하여야 합니다.",
	"EMAIL_OR_PASSWORD_INCORRECT": "이메일이나 비밀번호가 맞지 않습니다.",
	"NOT_VERIFIED": "이메일 인증이 아직입니다. 메일로 간 코드를 넣어 주세요.",
	"EXPIRED_SESSION": "로그인이 만료되었습니다. 다시 로그인하세요.",
	"INCORRECT_CODE": "인증 코드가 맞지 않습니다.",
	"CODE_EXPIRED": "인증 코드가 만료되었습니다. 코드 다시 받기를 누르세요.",
	"ALREADY_VERIFIED": "이미 인증된 계정입니다.",
	"VERIFICATION_DISABLED": "이 서버는 이메일 인증을 쓰지 않습니다.",
	"ON_COOLDOWN": "코드를 방금 보냈습니다. 잠시 뒤에 다시 받으세요.",
	"NOT_LOGGED_IN": "로그인되어 있지 않습니다.",
}
const OWN: Dictionary = {
	ERR_NO_PLUGIN: "GD-Sync 플러그인이 없습니다.",
	ERR_NO_KEYS: "GD-Sync 키가 없습니다. 게스트로 하거나 키를 넣어 주세요.",
	ERR_EMPTY: "이메일과 비밀번호를 적어 주세요.",
	ERR_NO_ENGINE: "지금은 계정을 쓸 수 없습니다.",
}


## 응답 번호 → 한국어. kind: create, login, verify, resend, logout(GD-Sync ENUMS 이름과 맞춘다).
static func message(kind: String, code: int) -> String:
	if OWN.has(code):
		return OWN[code]
	var table: Variant = _enum_of(kind)
	if table is Dictionary:
		var key: Variant = (table as Dictionary).find_key(code)
		if key != null and COMMON.has(str(key)):
			return COMMON[str(key)]
	return "처리하지 못했습니다. (번호 %d)" % code


static func _enum_of(kind: String) -> Variant:
	match kind:
		"create": return ENUMS.ACCOUNT_CREATION_RESPONSE_CODE
		"login": return ENUMS.ACCOUNT_LOGIN_RESPONSE_CODE
		"verify": return ENUMS.ACCOUNT_VERIFICATION_RESPONSE_CODE
		"resend": return ENUMS.ACCOUNT_RESEND_VERIFICATION_RESPONSE_CODE
		"logout": return ENUMS.ACCOUNT_LOGOUT_RESPONSE_CODE
	return null


static func _res(ok: bool, msg: String, verify: bool = false) -> Dictionary:
	return {"ok": ok, "msg": msg, "verify": verify}


# ---------------------------------------------------------------- 저장(비밀번호 없음)

static func load_state() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	email = str(cfg.get_value("account", "email", ""))
	nickname = str(cfg.get_value("account", "nickname", ""))
	guest = bool(cfg.get_value("account", "guest", false))


static func save_state() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("account", "email", email)
	cfg.set_value("account", "nickname", nickname)
	cfg.set_value("account", "guest", guest)
	cfg.save(path)


## 게스트로 하기(또는 그만두기)를 적는다.
static func set_guest(on: bool) -> void:
	guest = on
	if on:
		logged_in = false
		admin = false
	save_state()


## 로그인 창을 띄워야 하나: 로그인했거나 게스트를 골랐으면 아니다.
static func needs_window() -> bool:
	return not logged_in and not guest


## 화면에 보일 이름. 로그인했으면 닉네임, 아니면 fallback.
static func display_name(fallback: String = "") -> String:
	if logged_in and nickname != "":
		return nickname
	return fallback


## 지금 계정 줄(설정 창용).
static func status_text() -> String:
	if logged_in:
		return "%s (%s)" % [nickname if nickname != "" else "이름 없음", email]
	if guest:
		return "게스트"
	return "로그인하지 않음"


static func available() -> bool:
	return GdSyncLink.plugin_present() and GdSyncLink.has_keys()


# ---------------------------------------------------------------- GD-Sync 부르기

static func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


## 플러그인 노드를 올리고 돌려준다. 없으면 null과 오류 번호. 키는 플러그인이 노드가 설 때 읽으므로
## user:// 키 파일에만 있으면 그 전에 환경변수로 건네 둔다(그래야 저장된 세션 토큰을 풀 수 있다).
static func _gd() -> Array:
	var tree := _tree()
	if tree == null:
		return [null, ERR_NO_ENGINE]
	var gd: Node = tree.root.get_node_or_null(GD_NAME)
	if gd != null:
		return [gd, 0]
	if not GdSyncLink.plugin_present():
		return [null, ERR_NO_PLUGIN]
	if not GdSyncLink.has_keys():
		return [null, ERR_NO_KEYS]
	var k: Dictionary = GdSyncLink.load_keys()
	if OS.get_environment("GDSYNC_PUBLIC_KEY") == "":
		OS.set_environment("GDSYNC_PUBLIC_KEY", k.public)
		OS.set_environment("GDSYNC_PRIVATE_KEY", k.private)
	gd = (load(GdSyncLink.PLUGIN_SCRIPT) as GDScript).new() as Node
	gd.name = GD_NAME
	tree.root.add_child.call_deferred(gd)
	await tree.process_frame
	await tree.process_frame
	gd.account_logged_in.connect(_on_logged_in)
	gd.account_logged_out.connect(_on_logged_out)
	return [gd, 0]


static func _on_logged_in(username: String) -> void:
	logged_in = true
	if username != "":
		nickname = username
	guest = false
	save_state()


static func _on_logged_out() -> void:
	logged_in = false
	admin = false


## 이메일 글 → 해시(소문자, 앞뒤 공백 제거).
static func hash_email(mail: String) -> String:
	return mail.strip_edges().to_lower().sha256_text()


## 인증된 이메일로 관리자 여부를 정한다.
static func set_admin_from(authed_mail: String) -> void:
	admin = authed_mail.strip_edges() != "" and ADMIN_HASHES.has(hash_email(authed_mail))
	if admin:
		AdminHost.ensure()


## 플러그인 세션이 실제로 로그인한 이메일(칸에 친 글이 아니라 DataController가 든 것). 못 읽으면 인증에 쓴 글.
static func _session_mail(fallback: String) -> String:
	var gd: Node = _tree().root.get_node_or_null(GD_NAME) if _tree() != null else null
	if gd != null:
		var dc: Variant = gd.get("_data_controller")
		if dc != null and str(dc.get("login_email")) != "":
			return str(dc.get("login_email"))
	return fallback


static func _done(mail: String, nick: String) -> void:
	set_admin_from(_session_mail(mail))
	email = mail
	if nick != "":
		nickname = nick
	logged_in = true
	guest = false
	save_state()


## 가입: 만들고 바로 로그인을 해 본다. 인증이 켜져 있으면 verify = true.
static func register(mail: String, nick: String, password: String) -> Dictionary:
	mail = mail.strip_edges()
	nick = nick.strip_edges()
	if mail == "" or password == "" or nick == "":
		return _res(false, "이메일, 닉네임, 비밀번호를 모두 적어 주세요.")
	var g: Array = await _gd()
	if g[0] == null:
		return _res(false, message("create", g[1]))
	var code: int = await (g[0] as Node).account_create(mail, nick, password)
	if code != 0:
		return _res(false, message("create", code))
	email = mail
	nickname = nick
	var r: Dictionary = await login(mail, password)
	if r.verify:
		return _res(false, "가입했습니다. 메일로 간 인증 코드를 넣어 주세요.", true)
	return r


static func login(mail: String, password: String) -> Dictionary:
	mail = mail.strip_edges()
	if mail == "" or password == "":
		return _res(false, message("login", ERR_EMPTY))
	var g: Array = await _gd()
	if g[0] == null:
		return _res(false, message("login", g[1]))
	var out: Dictionary = await (g[0] as Node).account_login(mail, password)
	var code: int = int(out.get("Code", 1))
	if code == ENUMS.ACCOUNT_LOGIN_RESPONSE_CODE.SUCCESS:
		await _tree().process_frame   # 닉네임 신호가 오도록 한 틱
		_done(mail, "")
		return _res(true, "로그인했습니다.")
	if code == ENUMS.ACCOUNT_LOGIN_RESPONSE_CODE.NOT_VERIFIED:
		email = mail
		return _res(false, message("login", code), true)
	return _res(false, message("login", code))


## 이메일로 온 인증 코드. 맞으면 바로 로그인된다.
static func verify(mail: String, code_text: String) -> Dictionary:
	mail = mail.strip_edges()
	if mail == "" or code_text.strip_edges() == "":
		return _res(false, "이메일과 인증 코드를 적어 주세요.")
	var g: Array = await _gd()
	if g[0] == null:
		return _res(false, message("verify", g[1]))
	var code: int = await (g[0] as Node).account_verify(mail, code_text.strip_edges())
	if code != ENUMS.ACCOUNT_VERIFICATION_RESPONSE_CODE.SUCCESS:
		return _res(false, message("verify", code))
	await _tree().process_frame
	_done(mail, "")
	return _res(true, "인증했습니다. 로그인되었습니다.")


static func resend(mail: String, password: String) -> Dictionary:
	var g: Array = await _gd()
	if g[0] == null:
		return _res(false, message("resend", g[1]))
	var code: int = await (g[0] as Node).account_resend_verification_code(mail.strip_edges(), password)
	if code != 0:
		return _res(false, message("resend", code), code == ENUMS.ACCOUNT_RESEND_VERIFICATION_RESPONSE_CODE.ON_COOLDOWN)
	return _res(false, "인증 코드를 다시 보냈습니다.", true)


## 저장된 세션으로 자동 로그인(이메일이 저장돼 있을 때만 시도). 실패하면 창을 띄운다.
static func auto_login() -> Dictionary:
	if email == "":
		return _res(false, "")
	var g: Array = await _gd()
	if g[0] == null:
		return _res(false, message("login", g[1]))
	var code: int = await (g[0] as Node).account_login_from_session()
	if code == ENUMS.ACCOUNT_LOGIN_RESPONSE_CODE.SUCCESS:
		await _tree().process_frame
		_done(email, "")
		return _res(true, "로그인했습니다.")
	return _res(false, message("login", code))


## 로그아웃: 서버 세션을 끊고 저장한 이메일을 지운다. 연결이 없어도 이 PC에서는 로그아웃된다.
static func logout() -> Dictionary:
	var tree := _tree()
	var gd: Node = tree.root.get_node_or_null(GD_NAME) if tree != null else null
	var msg: String = "로그아웃했습니다."
	if gd != null and bool(gd.account_is_logged_in()):
		var code: int = await gd.account_logout()
		if code != 0:
			msg = "로그아웃했습니다. (서버 응답: %s)" % message("logout", code)
	logged_in = false
	admin = false
	email = ""
	nickname = ""
	save_state()
	return _res(true, msg)
