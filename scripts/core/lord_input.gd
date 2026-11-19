class_name LordInput
extends RefCounted
## 한 틱 동안의 영주 입력. 규칙은 이것만 보고 움직이니, 이것을 틱마다 기록하면 판을 그대로 다시 돌릴 수 있다.

## 길이 1 이하. x는 동쪽, y는 남쪽.
var move: Vector2 = Vector2.ZERO
var aim_valid: bool = false
## 마우스가 가리키는 땅(칸 단위).
var aim: Vector2 = Vector2.ZERO
var attack: bool = false
var dash: bool = false
## 겨눈 쪽의 적에게 갈고리를 걸고 날아가 벤다(밤).
var hook: bool = false
## 가까운 꽂힌 검을 뽑는다(낮).
var pull: bool = false
## 뽑는 동안 이 틱에 E나 좌클릭을 눌렀다(누른 순간만, 버팀 타이밍 판정에 쓴다. 14단계).
var pull_press: bool = false
## 다른 칸의 검으로 바꿔 쥔다. -1은 그대로, 0이나 1은 그 칸으로.
var swap_to: int = -1

## 22단계(온라인)용: 입력을 바이트로 바꾸고 되돌린다. 숫자는 32비트 실수 그대로라 되돌려도 같다(규칙이 같은 값을 본다).
## 배치: [0] 깃발(aim_valid 1, attack 2, dash 4, hook 8, pull 16, pull_press 32), [1] swap_to + 1, [2..9] move x·y, [10..17] aim x·y.
const BYTES: int = 18


func to_bytes() -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(BYTES)
	var f: int = 0
	f |= 1 if aim_valid else 0
	f |= 2 if attack else 0
	f |= 4 if dash else 0
	f |= 8 if hook else 0
	f |= 16 if pull else 0
	f |= 32 if pull_press else 0
	b[0] = f
	b[1] = clampi(swap_to + 1, 0, 255)
	b.encode_float(2, move.x)
	b.encode_float(6, move.y)
	b.encode_float(10, aim.x)
	b.encode_float(14, aim.y)
	return b


## 모자라거나 잘못된 바이트면 빈 입력을 돌려준다.
static func from_bytes(b: PackedByteArray) -> LordInput:
	var i := LordInput.new()
	if b.size() < BYTES:
		return i
	var f: int = b[0]
	i.aim_valid = f & 1 != 0
	i.attack = f & 2 != 0
	i.dash = f & 4 != 0
	i.hook = f & 8 != 0
	i.pull = f & 16 != 0
	i.pull_press = f & 32 != 0
	i.swap_to = int(b[1]) - 1
	i.move = Vector2(b.decode_float(2), b.decode_float(6))
	i.aim = Vector2(b.decode_float(10), b.decode_float(14))
	return i
