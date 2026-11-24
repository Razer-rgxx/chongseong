extends RefCounted
## 이메일 계정 테스트(docs/account.md): 오류 번호 → 한국어, 게스트 표시, 비밀번호가 디스크에 안 남음. 네트워크는 쓰지 않는다.

static func run(_game: GameData, check: Callable) -> void:
	# 오류 번호 → 짧은 한국어(GD-Sync ENUMS 이름으로 찾는다)
	check.call(Account.message("login", ENUMS.ACCOUNT_LOGIN_RESPONSE_CODE.EMAIL_OR_PASSWORD_INCORRECT).contains("비밀번호"), "계정: 로그인 틀림 글")
	check.call(Account.message("login", ENUMS.ACCOUNT_LOGIN_RESPONSE_CODE.NOT_VERIFIED).contains("인증"), "계정: 인증 전 글")
	check.call(Account.message("create", ENUMS.ACCOUNT_CREATION_RESPONSE_CODE.EMAIL_ALREADY_EXISTS).contains("이미"), "계정: 이메일 중복 글")
	check.call(Account.message("verify", ENUMS.ACCOUNT_VERIFICATION_RESPONSE_CODE.INCORRECT_CODE).contains("코드"), "계정: 코드 틀림 글")
	check.call(Account.message("login", Account.ERR_NO_KEYS).contains("키가 없습니다"), "계정: 키 없음 글")
	check.call(Account.message("login", 999).contains("999"), "계정: 모르는 번호도 글이 나옴")
	for kind in ["create", "login", "verify", "resend", "logout"]:
		var tbl: Dictionary = Account._enum_of(kind)
		var all_ok: bool = true
		for name in tbl:
			if int(tbl[name]) != 0 and Account.message(kind, int(tbl[name])).begins_with("처리하지 못했습니다"):
				all_ok = false
				push_warning("계정 글 없음: %s %s" % [kind, name])
		check.call(all_ok, "계정: %s 응답 번호마다 한국어 글이 있다" % kind)
	# 게스트 흐름과 저장
	var keep_path: String = Account.path
	Account.path = "user://테스트_account.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Account.path))
	Account.email = ""
	Account.nickname = ""
	Account.guest = false
	Account.logged_in = false
	check.call(Account.needs_window(), "계정: 처음에는 로그인 창이 뜬다")
	Account.set_guest(true)
	check.call(not Account.needs_window(), "계정: 게스트를 고르면 창이 안 뜬다")
	Account.guest = false
	Account.load_state()
	check.call(Account.guest, "계정: 게스트 선택이 저장된다")
	check.call(Account.display_name("나") == "나", "계정: 게스트는 기본 이름")
	Account.logged_in = true
	Account.email = "a@b.c"
	Account.nickname = "검객"
	Account.save_state()
	check.call(Account.display_name("나") == "검객", "계정: 로그인하면 닉네임이 이름")
	var text: String = FileAccess.get_file_as_string(Account.path)
	check.call(text.contains("a@b.c") and not text.to_lower().contains("pass"), "계정: 파일에 이메일만 있고 비밀번호 칸이 없다")
	# 키 없이 로그인하면 오류 글만 돌려준다(저장된 비밀번호 없음)
	Account.logged_in = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Account.path))
	Account.path = keep_path
	Account.email = ""
	Account.nickname = ""
	Account.guest = false
	# 관리자: 인증된 이메일의 해시가 목록에 있을 때만 켜지고, 켜지면 순위 올리기가 막힌다(가짜 해시로 본다)
	var keep_hashes: Array[String] = Account.ADMIN_HASHES.duplicate()
	Account.ADMIN_HASHES = [Account.hash_email("fake.admin@example.com")]
	Account.set_admin_from("someone@example.com")
	check.call(not Account.admin and FallenShare.may_submit(), "계정: 다른 이메일은 관리자가 아니고 순위에 올린다")
	Account.set_admin_from("  Fake.Admin@Example.com ")
	check.call(Account.admin, "계정: 가짜 관리자 이메일(대소문자·공백 무시)이 관리자")
	check.call(not FallenShare.may_submit(), "계정: 관리자는 순위표에 올리지 않는다")
	Account.path = "user://테스트_account.cfg"
	Account.set_guest(true)
	Account.path = keep_path
	check.call(not Account.admin, "계정: 게스트로 바꾸면 관리자가 풀린다")
	check.call(Account.ADMIN_HASHES.size() == 1 and Account.hash_email("x").length() == 64, "계정: 해시는 SHA-256 16진 64자")
	var src: String = FileAccess.get_file_as_string("res://scripts/net/account.gd")
	check.call(not src.contains("@gmail") and not src.contains("razer"), "계정: 소스에 관리자 이메일 글이 없다")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://테스트_account.cfg"))
	Account.ADMIN_HASHES = keep_hashes
	Account.admin = false
	Account.guest = false
