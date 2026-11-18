class_name Hilt
extends RefCounted
## 땅에 꽂힌 검 한 자루(아직 무엇인지 모른다).

var id: int
var pos: Vector2
## 기울기(라디안). 화면에서만 쓴다.
var tilt: float
var gone: bool = false
## 저주받은 손잡이(13단계 낮 사건): 체력 없이 뽑고 운 ×2, 대신 이번 밤 적이 늘고 뽑은 검의 최대 내구가 절반.
var cursed: bool = false
