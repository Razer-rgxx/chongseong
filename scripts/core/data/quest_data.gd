class_name QuestData
extends Resource
## 의뢰판의 의뢰 한 줄(15단계, docs/village.md 15.1). 판 하나에서 n을 채우면 조각 reward.
## kind: kill(쓰러뜨린 적), kill_kind(target 종류의 적), zones(넘은 구역), elites(정예),
## pull_grade(grade 등급 이상 뽑은 검), perfect(버팀을 모두 제대로 당김), goal(target 밤 목표를 이룸), events(쓴 낮 사건).

@export var kind: StringName = &"kill"
## kill_kind: 적 id(archer …), goal: 밤 목표 id(hunt, defend, siege). 나머지는 비운다.
@export var target: StringName = &""
## pull_grade: 이 등급 이상(0 흔함 … 5 무한).
@export var grade: int = 0
@export var n: int = 10
@export var reward: int = 20
## 가장 높이 오른 구역(Meta.best)이 이만큼은 돼야 판에 붙는다(못 가 본 곳의 적이나 목표는 안 붙는다).
@export var min_best: int = 0
