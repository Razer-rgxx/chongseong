class_name RunData
extends Resource
## 한 판의 규칙 수치. 거리는 칸(1칸 = 2m), 시간은 초.

@export_group("판")
@export var days: int = 7
@export var day_length: float = 80.0
@export var map_size: int = 33
@export var tick_rate: int = 30

@export_group("시작")
@export var start_wood: int = 40
@export var start_stone: int = 40
@export var start_gold: int = 0
## 영주관을 두르는 첫 성벽 고리의 거리(체비쇼프).
@export var start_wall_ring: int = 3

@export_group("맵")
@export var tree_chance: float = 0.10
@export var rock_chance: float = 0.04
## 영주관에서 이 거리 안에는 나무와 바위를 두지 않는다.
@export var clear_radius: int = 6
## 가장자리 몇 줄에는 나무와 바위를 두지 않는다.
@export var clear_border: int = 2
@export var tree_hits: int = 4
@export var rock_hits: int = 5
@export var wood_per_hit: int = 3
@export var stone_per_hit: int = 2
@export var big_hit_bonus: int = 2

@export_group("설계함")
@export var boxes_per_day: int = 3
@export var box_gold: int = 2
@export var blueprint_slots: int = 6
## 거르거나 칸이 넘쳐 자원으로 바꿀 때 짓는 값에 곱하는 비율.
@export var sell_ratio: float = 0.5

@export_group("성벽과 영주관")
@export var wall_stone: int = 3
@export var wall_hp: float = 260.0
@export var wall_refund: int = 1
@export var hall_hp: float = 1600.0
## 아침에 영주관 최대 체력의 이만큼이 찬다.
@export var hall_dawn_heal: float = 0.4
@export var building_hp_base: float = 140.0
@export var building_hp_growth: float = 1.6
## 방어 건물 세기는 defense_growth^등급배.
@export var defense_growth: float = 2.0
## 폐허를 고칠 때 짓는 값에 곱하는 비율.
@export var repair_ratio: float = 0.5

@export_group("사람")
@export var visitors_per_building: int = 3
@export var talks_base: int = 3
@export var talks_bonus_max: int = 5
@export var pop_base: int = 5
@export var pop_per_recruit: int = 2
## 레벨 하나마다 힘이 이만큼 오른다.
@export var level_power: float = 0.2
@export var skill_cooldown: float = 9.0
## 성벽이 무너져 다치면 쉬는 날.
@export var injury_days: int = 2
@export var guard_range: float = 3.5
## 충신이 막아서면 영주 체력이 최대의 이만큼 남는다.
@export var guard_hp: float = 0.25
@export var guard_invuln: float = 1.5

@export_group("명성")
## 설계함과 손님 운 배수 = 1 + fame_luck × 명성.
@export var fame_luck: float = 0.15
## 적 체력 배수 = fame_enemy_hp^명성. 적 수 + 올림(명성 / 2).
@export var fame_enemy_hp: float = 1.06

@export_group("습격")
@export var wave_base: int = 8
@export var wave_per_day: int = 5
@export var enemy_hp_growth: float = 1.28
@export var enemy_damage_growth: float = 1.15
@export var boss_hp_mult: float = 2.2
@export var boss_damage_mult: float = 1.6
@export var spawn_interval: float = 0.5
## 3일째부터 순번 % 3 == 1은 늑대, 5일째부터 순번 % 7 == 6은 공성추, 4일째부터 공성추 하나 추가.
@export var wolf_from_day: int = 3
@export var ram_from_day: int = 5
@export var extra_ram_from_day: int = 4
## 날짜별 습격 방향 수(1일째부터).
@export var sides_by_day: PackedInt32Array = PackedInt32Array([1, 1, 1, 2, 2, 3, 3])
## 밤을 당기면 남은 낮 시간 / 이 값만큼 금화.
@export var call_night_gold_div: float = 4.0

@export_group("길찾기 비용")
@export var cost_empty: float = 1.0
@export var cost_ruin: float = 1.5
@export var cost_hall: float = 1.0
@export var cost_building: float = 6.0
@export var cost_wall: float = 10.0
## 적이 칸 중심에서 이 거리 안이면 도착한 것으로 친다.
@export var arrive_radius: float = 0.22
