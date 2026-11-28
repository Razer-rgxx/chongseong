class_name DuelSeat
extends RefCounted
## 결투(21단계)에서 영주 한 사람의 자리. Rules가 영주마다 따로 쥐는 것(영주 상태, 검 칸, 좌클릭 동작, 날아가는 것)을
## 한데 묶는다. Rules는 한 영주의 틱을 돌릴 때 자기 lord·slots·moves·powers·projectiles·enemies를 이 자리의 것으로 바꿔 끼운다.

var lord: LordState
var slots: Array[Sword] = [null, null]
var active: int = 0
var moves: Moves
## 결투에서는 꺼 둔다(Powers.off).
var powers: Powers
var projectiles: Array[Projectile] = []
## 이 영주가 맞힐 수 있는 것: 상대 영주의 그림자 적 하나(Enemy.seat >= 0).
var foes: Array[Enemy] = []
