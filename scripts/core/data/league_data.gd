class_name LeagueData
extends Resource
## 결투 리그(docs/duel_league.md)의 모든 수치. data/league.tres 한 장.
## 걸음(step) = 티어 × 3 + (단계 - 1): 0 = 녹쇠 1, 23 = 불멸 3. 24는 "언덕의 검"(걸음이 아니라 표).

## 티어 이름(낮은 쪽부터 8개)과 맨 위 이름.
@export var tier_names: PackedStringArray = ["녹쇠", "청동", "은", "금", "백금", "금강", "승천", "불멸"]
@export var top_name: String = "언덕의 검"
@export var divisions: int = 3
## 한 단계의 RR 크기(이 값에 닿으면 오른다).
@export var rr_max: int = 100

## RR 증감: 기본값과 한계. 숨은 MMR이 기준보다 높으면 이기는 몫이 늘고 지는 몫이 준다(mmr_gain_k × 차이).
@export var win_base: int = 23
@export var win_min: int = 18
@export var win_max: int = 28
@export var loss_base: int = 17
@export var loss_min: int = 12
@export var loss_max: int = 22
@export var mmr_gain_k: float = 0.06

## 숨은 MMR(Elo 꼴): 시작값, 걸음 0의 기준값, 걸음 하나의 폭, 판마다 움직이는 크기(K).
@export var mmr_start: float = 1000.0
@export var mmr_base: float = 850.0
@export var mmr_per_step: float = 40.0
@export var k_factor: float = 32.0
@export var k_placement: float = 80.0

## 배치: 처음 이 수만큼의 랭크 결투로 시작 걸음을 정한다(MMR로, 이 걸음을 넘지 않는다: 금 1 = 9).
@export var placement_games: int = 5
@export var placement_cap_step: int = 9

## 시즌: 기준 날(1970-01-01부터 센 날수, 2026-11-23)에서 season_days 일마다 한 시즌. 바뀔 때 soft_drop 단계 내려간다.
@export var season_anchor_day: int = 20780
@export var season_days: int = 42
@export var soft_drop: int = 3

## 순위표: 상위 top_n 명(불멸 3인 사람만 "언덕의 검"). 보드 이름은 board_prefix + 시즌 번호. 창에는 list_rows줄.
@export var top_n: int = 100
@export var board_prefix: String = "league_s"
@export var list_rows: int = 10

## 화면: RR 바가 오르내리는 시간(초)과 승급·강등 번쩍임.
@export var anim_time: float = 1.6
@export var flash_time: float = 0.6
