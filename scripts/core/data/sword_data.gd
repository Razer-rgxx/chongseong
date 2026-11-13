class_name SwordData
extends Resource
## 검 한 종류. data/swords/에 300개가 있다. 시험판 표(prototype/game_reference.js의 SW)에서 옮겼다.

@export var id: int = 0
@export var display_name: String = ""
## 0 흔함 … 5 무한. GradeTable의 순서와 같다.
@export_range(0, 5) var grade: int = 0
## 0 단검, 1 장검, 2 대검, 3 세검. data/forms/의 파일 순서와 같다.
@export_range(0, 3) var form: int = 0
## 각인 이름. 수치는 InscriptionData에서 등급으로 찾는다.
@export var inscriptions: PackedStringArray = PackedStringArray()
## 유물(초월) 이상만 있다. 비어 있으면 없다.
@export_multiline var unique_text: String = ""
## 고유 능력이 규칙에 들어갔는지. false면 카드에 "아직 작동 안 함"이 붙는다.
@export var unique_ready: bool = false
## 부러지지 않는 검(내구가 없다).
@export var unbreakable: bool = false
@export_multiline var story: String = ""
