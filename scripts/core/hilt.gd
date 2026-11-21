class_name Hilt
extends RefCounted
## 땅에 꽂힌 검 한 자루(아직 무엇인지 모른다).

var id: int
var pos: Vector2
## 기울기(라디안). 화면에서만 쓴다.
var tilt: float
var gone: bool = false
## 꽂아 둔 검(2026-11-21 발검): 밤에 새 검을 뽑으며 쥐고 있던 검을 이 자리에 꽂았다. 무엇인지 알고, 뽑기 값 없이 다시 뽑는다.
var sword: Sword = null
## 주인 있는 검(docs/sword_hill.md 2번): Meta.fallen의 기록 하나. 비어 있지 않으면 굴리지 않고 그 검이 나오고, 뽑으면 주인의 잔영이 나온다.
var owner: Dictionary = {}
## 저주받은 손잡이(13단계 낮 사건): 체력 없이 뽑고 운 ×2, 대신 이번 밤 적이 늘고 뽑은 검의 최대 내구가 절반.
var cursed: bool = false
## 조짐(14단계): 숨은 조짐(0~3, 뽑을 때 운 × RunData.omen_luck[omen])과 겉으로 보이는 조짐(75% 맞음).
## 점쟁이를 쓰면 revealed가 켜지고 보이는 조짐이 숨은 조짐이 된다.
var omen: int = 1
var shown_omen: int = 1
var revealed: bool = false


## 화면에 보일 조짐.
func seen_omen() -> int:
	return omen if revealed else shown_omen
