class_name DuelSetup
extends RefCounted
## 온라인 결투를 시작하는 정보(22단계, docs/duel.md). 방장이 시드를 정하고 두 검(번호·검집 단계·검집 각인)을 담아 보낸다.
## 두 쪽이 이 정보로 같은 Rules.start_duel을 부른다. 바이트로 바꿔 보내고 되돌린다(잘못된 바이트는 null).
## 자리 0은 방장, 1은 손님.

var version: int = 1
var seed_value: int = 1
## 자리마다 {id: SwordData.id(0은 맨손), lv: 검집 단계, ins: 검집 각인 이름들, sheath: 검집에서 온 검인가, cos: 입은 꾸미기(자리 → 항목 id, 보기만)}.
var picks: Array[Dictionary] = [DuelSetup.bare(), DuelSetup.bare()]


static func bare() -> Dictionary:
	return {"id": 0, "lv": 0, "ins": PackedStringArray(), "sheath": false, "cos": {}}


## 내 Meta에서 그 검(SwordData.id)을 다시 만들 수 있는 최소 정보. 검집의 검이면 강화 단계와 각인이 같이 든다.
static func spec_of(meta: Meta, id: int) -> Dictionary:
	var s: Dictionary = DuelSetup.bare()
	s.id = maxi(id, 0)
	s.cos = meta.cos_worn.duplicate()   # 꾸미기는 모양뿐이라 규칙(상태 해시)에 안 든다
	if id > 0 and id == meta.sheath_id:
		s.sheath = true
		s.lv = meta.sheath_lv
		s.ins = meta.sheath_ins.duplicate()
	return s


## 믿지 못하는 값(상대가 보낸 것)을 다듬는다: 모양이 틀리면 맨손.
static func clean(v: Variant, game: GameData) -> Dictionary:
	var s: Dictionary = DuelSetup.bare()
	if not (v is Dictionary):
		return s
	var d: Dictionary = v
	s.cos = Cosmetics.clean(d.get("cos", {}))   # 검이 맨손이어도 모양은 보인다
	var id: int = int(d.get("id", 0)) if d.get("id", 0) is int else 0
	if id <= 0 or game.sword_by_id(id) == null:
		return s
	s.id = id
	s.sheath = d.get("sheath", false) == true
	if s.sheath:
		var lv: int = int(d.get("lv", 0)) if d.get("lv", 0) is int else 0
		s.lv = clampi(lv, 0, game.meta.sheath_max)
		var names := PackedStringArray()
		var raw: Variant = d.get("ins", [])
		if raw is PackedStringArray or raw is Array:
			for k in raw:
				if k is String and game.inscriptions.has(k) and names.size() < 8 and not names.has(k):
					names.append(k)
		s.ins = names
	return s


func to_bytes() -> PackedByteArray:
	return var_to_bytes([version, seed_value, picks[0], picks[1]])


## 되돌린다. 모양이 틀리면 null(검 번호는 game이 아는 것만, 아니면 맨손).
static func from_bytes(b: PackedByteArray, game: GameData) -> DuelSetup:
	if b.size() < 4:
		return null
	var v: Variant = bytes_to_var(b)
	if not (v is Array) or (v as Array).size() != 4:
		return null
	var a: Array = v
	if not (a[0] is int) or not (a[1] is int):
		return null
	var s := DuelSetup.new()
	s.version = a[0]
	s.seed_value = a[1]
	s.picks = [DuelSetup.clean(a[2], game), DuelSetup.clean(a[3], game)]
	return s


## 두 검을 다시 만든다(결투에서는 부러지지 않는다). 맨손이면 null.
func make_swords(game: GameData) -> Array[Sword]:
	var out: Array[Sword] = []
	for p in picks:
		out.append(DuelSetup.make_sword(game, p))
	return out


static func make_sword(game: GameData, spec: Dictionary) -> Sword:
	var id: int = int(spec.get("id", 0))
	if id <= 0:
		return null
	var d := game.sword_by_id(id)
	if d == null:
		return null
	var s := Sword.new(d, game)
	if spec.get("sheath", false) == true:
		s.apply_sheath(int(spec.get("lv", 0)), spec.get("ins", PackedStringArray()), game)
	s.max_durability = -1.0
	s.durability = -1.0
	return s
