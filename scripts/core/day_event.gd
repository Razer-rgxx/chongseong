class_name DayEvent
extends RefCounted
## 낮 사건 하나(13단계, docs/content.md): smith 떠돌이 대장장이, cursed 저주받은 손잡이, pilgrim 순례자, seer 점쟁이.
## 2구역부터 낮마다 하나가 선다. 다가가 E로 한 번 쓰면 사라진다. 저주받은 손잡이는 낮의 손잡이(hilt) 하나이고 뽑으면 쓴 것이다.

var id: int
var kind: StringName
## 자리(칸). 저주받은 손잡이면 그 손잡이의 자리.
var pos: Vector2
var used: bool = false
## 저주받은 손잡이면 그 손잡이(Rules.hilts 가운데 하나, cursed가 켜져 있다). 아니면 null.
var hilt: Hilt = null
