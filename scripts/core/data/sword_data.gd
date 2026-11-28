class_name SwordData
extends Resource
## 검 한 종류. data/swords/에 511개가 있다. 001~300은 시험판 표(prototype/game_reference.js의 SW)에서 옮겼고,
## 301~310은 오픈월드 한정 검(33단계, docs/field_life.md)이다.

@export var id: int = 0
@export var display_name: String = ""
## 0 흔함 … 5 무한. GradeTable의 순서와 같다.
@export_range(0, 5) var grade: int = 0
## 0 단검, 1 장검, 2 대검, 3 세검. data/forms/의 파일 순서와 같다.
@export_range(0, 3) var form: int = 0
## 좌클릭 공격 방식 번호(data/attacks/patterns/<번호>.tres, 1~150). scripts/debug/build_attacks.gd가 채운다.
@export var attack: int = 0
## 각인 이름. 수치는 InscriptionData에서 등급으로 찾는다.
@export var inscriptions: PackedStringArray = PackedStringArray()
## 유물(초월) 이상만 있다. 비어 있으면 없다.
@export_multiline var unique_text: String = ""
## 고유 능력이 규칙에 들어갔는지. false면 카드에 "아직 작동 안 함"이 붙는다.
@export var unique_ready: bool = false
## 부러지지 않는 검(내구가 없다).
@export var unbreakable: bool = false
@export_multiline var story: String = ""
## 오픈월드 한정 검(33단계): 언덕의 뽑기·대장장이·상인 어디서도 나오지 않고, 들판의 우두머리·무덤 큰 관·몰락한 기사에게서만 얻는다.
## attack은 손으로 정한다(scripts/debug/build_attacks.gd가 건드리지 않는다).
@export var field_only: bool = false

## 사이버 검(docs/cyber_swords.md): 312~511 + 사이버 카타나(311). 총검 느낌의 새 능력(cyber_powers)을 가진다.
## 311은 field_only이고 나머지는 언덕 뽑기에 따로 섞인다(GameData.cyber_by_grade, Meta.rift_open 뒤에만).
@export var cyber: bool = false
## 사이버 검의 종류: 단검, 카타나, 오니마루, 환도, 중장도, 대검. 모양(SwordModel)과 이름이 이걸 따른다.
@export var sub_type: String = ""
## 사이버 능력 이름(CyberPowers가 읽는다, 수치는 PowerTable.cyber). 1~2개.
@export var cyber_powers: PackedStringArray = PackedStringArray()
