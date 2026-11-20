class_name PlayLog
extends RefCounted
## 플레이 기록(2026-11-20, 리뷰: "숫자가 전부 첫 값, 사람이 해 본 기록이 없다").
## 판이 끝날 때, 들판·무덤에서 쓰러질 때, 우두머리를 쓰러뜨릴 때 한 줄(JSON)을 user://playlog.jsonl 끝에 붙인다.
## Windows에서는 %APPDATA%\Godot\app_userdata\검의 언덕\playlog.jsonl. 요약은 `python3 docs/playlog_report.py <파일>`.
## 게임 진행에는 아무 영향이 없다(규칙을 읽기만 한다). 웹판에서는 쓰지 않는다.

const PATH: String = "user://playlog.jsonl"


static func write(kind: String, fields: Dictionary) -> void:
	if OS.has_feature("web"):
		return
	var d: Dictionary = {"kind": kind, "at": Time.get_datetime_string_from_system(false, true), "ver": ProjectSettings.get_setting("application/config/version", "")}
	d.merge(fields, true)
	var f: FileAccess = FileAccess.open(PATH, FileAccess.READ_WRITE) if FileAccess.file_exists(PATH) else FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(JSON.stringify(d))
	f.close()


## 언덕 한 판이 끝났다.
static func hill_end(rules: Rules, won: bool, shards: int) -> void:
	write("hill_end", {
		"won": won, "zone": rules.zone + 1, "secs": snappedf(rules.tick * rules.dt, 0.1),
		"pulls": rules.pulls, "kills": rules.kills, "best_grade": rules.best_grade, "shards": shards,
		"pulled_by_grade": rules.run_stats.get("pulled_by_grade", []), "perfect": rules.run_stats.get("perfect", 0),
		"elites": rules.run_stats.get("elites", 0), "killer": String(rules.last_hit_by), "hp_max": rules.max_hp(),
	})


## 들판·무덤에서 쓰러졌다.
static func down(place: String, rules: Rules, held_id: int, area: String) -> void:
	write("down", {
		"place": place, "area": area, "held": held_id, "killer": String(rules.last_hit_by),
		"night": rules.field_night, "secs": snappedf(rules.tick * rules.dt, 0.1), "kills": rules.kills,
	})


## 우두머리(또는 보스)를 쓰러뜨렸다.
static func chief(id: String, rules: Rules, held_id: int) -> void:
	write("chief", {"id": id, "hp_left": snappedf(rules.lord.hp, 0.1), "hp_max": rules.max_hp(), "held": held_id, "night": rules.field_night, "secs": snappedf(rules.tick * rules.dt, 0.1)})
