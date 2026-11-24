class_name SlowMo
extends RefCounted
## 마무리 슬로모션(2026-11-24, docs/dopamine.md): 밤을 끝낸 처치, 보스, 무리·방을 다 쓰러뜨린 순간에 시간을 잠깐 늦춘다.
## 규칙도 같이 느려질 뿐 틱은 그대로라 결과는 같다(Rules는 틱 수로만 돈다). 끝날 때는 한 번에 돌아오지 않고 짧게 풀린다.
## 다른 것이 이미 시간을 바꿔 두었으면(뽑기 연출 등) 건드리지 않는다.

static var _token: int = 0


## scale: 시간 배수(0.25 = 네 배 느리게), secs: 실제 초.
static func hit(tree: SceneTree, scale: float, secs: float) -> void:
	if tree == null or Engine.time_scale < 0.999 and _token == 0:
		return
	_token += 1
	var mine: int = _token
	Engine.time_scale = clampf(scale, 0.05, 1.0)
	tree.create_timer(secs, true, false, true).timeout.connect(func() -> void:
		if mine != _token:
			return
		# 0.18초(실제)에 걸쳐 1로 푼다
		var steps: int = 6
		for i in steps:
			await tree.create_timer(0.03, true, false, true).timeout
			if mine != _token:
				return
			Engine.time_scale = lerpf(scale, 1.0, float(i + 1) / steps)
		Engine.time_scale = 1.0
		_token = 0)
