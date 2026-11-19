class_name CryptRun
extends RefCounted
## 지하 무덤의 규칙 쪽(19단계): 방에 들어서면 그 방의 무리를 세우고, 다 쓰러뜨렸는지 보고 Meta에 적는다.
## 문이 닫혔는지는 규칙 상태(Rules.packs의 cleared, 마지막 방은 무덤 주인 BOSS_DOWN)와 Meta.crypt_cleared에서 읽는다.
## 화면(CryptBuilder, crypt.gd)은 이 클래스를 읽기만 한다. Rules.step 다음에 틱마다 step()을 부른다.

signal room_entered(id: StringName)
signal room_cleared(id: StringName)

var rules: Rules
var meta: Meta
## 영주가 지금 들어서 있는 방(복도면 &"").
var room: StringName = &""
## 무리나 무덤 주인을 이미 세운 방.
var spawned: Dictionary = {}


func _init(r: Rules, m: Meta) -> void:
	rules = r
	meta = m


## 그 방을 쓰러뜨렸는가: 저장된 것이거나, 이번에 무리를 다 쓰러뜨렸거나, 무덤 주인이 쓰러졌다.
func cleared(id: StringName) -> bool:
	if meta.crypt_cleared.has(String(id)):
		return true
	if CryptLayout.ROOMS[id].has("boss"):
		return rules.field_boss != null and rules.field_boss_state == Rules.BOSS_DOWN
	return rules.packs.has(id) and bool(rules.packs[id].cleared)


func cleared_set() -> Dictionary:
	var out := {}
	for id in CryptLayout.ROOM_ORDER:
		if cleared(id):
			out[id] = 1
	return out


## 문이 닫혀 있는가(영주가 들어선 방이 아직 안 쓰러뜨려졌으면 그 방의 문이 모두 닫힌다).
func door_closed(door: StringName) -> bool:
	return CryptLayout.door_closed(door, room, cleared_set())


func open_doors() -> Dictionary:
	var out := {}
	var cs: Dictionary = cleared_set()
	for d in CryptLayout.DOORS:
		if not CryptLayout.door_closed(d, room, cs):
			out[d] = 1
	return out


## 관을 지금 열 수 있는가(그 방을 쓰러뜨렸고 아직 안 열었다).
func coffin_ready(id: StringName) -> bool:
	return cleared(id) and not meta.crypt_opened.has(String(id))


## 규칙 한 틱 뒤에 부른다: 들어섬을 알아채 무리를 세우고, 쓰러뜨린 방을 Meta에 적는다.
func step() -> void:
	var now: StringName = CryptLayout.room_at(rules.lord.pos)
	if now != &"" and now != room:
		room = now
		_enter(now)
	elif now == &"" and room != &"":
		# 방 가장자리(들어선 곳 밖)에 나서면 그 방을 벗어난 것이다. 문은 쓰러뜨린 방에서만 열려 있으니 닫힌 방에서는 일어나지 않는다.
		room = &""
	for id in CryptLayout.ROOM_ORDER:
		if spawned.has(id) and not meta.crypt_cleared.has(String(id)) and cleared(id):
			meta.crypt_clear(String(id))
			room_cleared.emit(id)


func _enter(id: StringName) -> void:
	if not meta.crypt_cleared.has(String(id)) and not spawned.has(id):
		spawned[id] = true
		var R: Dictionary = CryptLayout.ROOMS[id]
		if R.has("boss"):
			rules.spawn_field_boss(R.boss.at, R.boss.kind, int(R.boss.zone))
		else:
			rules.spawn_pack(id, R.pack)
	room_entered.emit(id)


## 걷는 판 안으로 밀어 넣는다(닫힌 문 안과 벽 밖으로 못 나간다). 장면이 틱마다 영주의 자리에 건다.
## 무덤의 벽(1.5m)·관은 높은 막힘이라 공중(airborne)이어도 막는다(30단계).
func push(p: Vector2, airborne: bool = false) -> Vector2:
	return CryptLayout.push_in(p, open_doors(), airborne)
