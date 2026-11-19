class_name LoopLink
extends NetLink
## 테스트용 전송: 두 개를 이어(`pair`) 한 프로세스 안에서 주고받는다. 지연·뒤섞임·빠짐을 흉내 낸다.
## 시간은 poll 한 번 = 1단위(보통 한 틱). 랜덤은 시드가 있는 자체 RNG(전역 randf를 쓰지 않는다).

## 한 번 보낸 것이 도착하기까지 걸리는 poll 수의 범위(둘이 다르면 순서가 뒤섞인다).
var delay_min: int = 0
var delay_max: int = 0
## 믿지 못하는 전송(reliable=false)이 빠질 확률. 믿는 전송(reliable=true)은 빠지지 않고 늦기만 한다.
var loss: float = 0.0
var rng := RandomNumberGenerator.new()
var other: LoopLink
var open: bool = false
## 보낸 바이트 수와 묶음 수(대역폭 어림).
var sent_bytes: int = 0
var sent_packets: int = 0
var _now: int = 0
## [도착 시각, 번호, 바이트]. 번호는 같은 시각의 순서를 정한다.
var _queue: Array = []
var _n: int = 0


## 이어진 두 링크. 0번이 방장이다. 둘 다 상대가 들어온 것으로 시작한다(joined가 true면 신호도 보낸다).
static func pair(seed_value: int = 1, p_delay_min: int = 0, p_delay_max: int = 0, p_loss: float = 0.0) -> Array[LoopLink]:
	var a := LoopLink.new()
	var b := LoopLink.new()
	a.other = b
	b.other = a
	a.is_host = true
	for l in [a, b]:
		l.delay_min = p_delay_min
		l.delay_max = p_delay_max
		l.loss = p_loss
	a.rng.seed = seed_value
	b.rng.seed = seed_value + 7919
	return [a, b]


func find_match() -> void:
	open = true
	if other != null and other.open:
		set_status(Status.MATCHED)
		other.set_status(Status.MATCHED)
		peer_joined.emit()
		other.peer_joined.emit()
	else:
		set_status(Status.WAITING)


func peer_present() -> bool:
	return open and other != null and other.open


func send(data: PackedByteArray, reliable: bool = false) -> void:
	if not peer_present():
		return
	sent_bytes += data.size()
	sent_packets += 1
	if not reliable and loss > 0.0 and rng.randf() < loss:
		return
	var d: int = rng.randi_range(delay_min, delay_max) if delay_max > delay_min else delay_min
	_n += 1
	other._queue.append([other._now + d, _n, data.duplicate()])


## 한 단위 흘리고, 도착할 때가 된 것을 받은 순서가 아니라 (시각, 번호) 순으로 내보낸다.
func poll(delta: float) -> void:
	_now += 1
	polled.emit(delta)
	var due: Array = []
	var rest: Array = []
	for m in _queue:
		if m[0] <= _now:
			due.append(m)
		else:
			rest.append(m)
	_queue = rest
	due.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	for m in due:
		received.emit(m[2])


## 연결을 끊는다: 상대가 나감 신호를 받는다.
func close() -> void:
	if not open:
		return
	open = false
	set_status(Status.CLOSED)
	if other != null:
		other.peer_left.emit()
