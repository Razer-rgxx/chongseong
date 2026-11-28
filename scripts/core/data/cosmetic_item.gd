class_name CosmeticItem
extends Resource
## 꾸밀 것 하나(docs/cosmetics.md). 모양만 바꾸고 능력치는 없다. 표(CosmeticTable)의 한 줄.
## 해금 조건은 이미 있는 Meta 값에서 읽는다(Cosmetics.met).

@export var id: StringName = &""
## 자리: cape(망토), head(머리), slash(베기 궤적 색).
@export var slot: StringName = &"cape"
@export var title: String = ""
## 해금 종류: free(처음부터), shards(조각으로 산다), league(랭크 결투 최고 티어), boss(우두머리), story(이야기 막), rune(룬 자리).
@export var unlock: StringName = &"free"
## shards = 값(조각), league = 티어 번호(0 녹쇠 … 7 불멸), rune = 열린 룬 자리 수.
@export var need: int = 0
## boss = grave_knight·crypt_lord, story = act1·act2·act3.
@export var key: StringName = &""
## 모양 이름(CosmeticArt가 읽는다)과 두 색. 베기 색 자리는 color가 곧 빛 색이다.
@export var style: StringName = &"plain"
@export var color: Color = Color(0.5, 0.1, 0.12)
@export var color2: Color = Color(0.8, 0.7, 0.4)
