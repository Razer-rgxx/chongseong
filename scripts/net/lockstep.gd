class_name Lockstep
extends RefCounted
## 입력만 주고받는 락스텝(22단계, docs/duel.md). 노드가 없고 NetLink만 안다.
## 둘 다 같은 Rules를 돌리고, 틱마다 내 LordInput(18바이트)만 보낸다. 내 입력은 tick + 입력 지연(D)에 먹고, 두 입력이 다 있는 틱만
## Rules.step_duel로 넘긴다. 상대 입력이 없으면 기다린다(멈춤). 몇 틱마다 state_hash를 주고받아 어긋나면 desync를 알린다.
##
## 묶음(입력): [1][가장 늦은 틱 s32][내가 받은 상대 입력의 연속 끝 틱 s32][개수 u8][입력 18바이트 × 개수].
## 빠진 것은 상대가 알려 준 받은 끝 틱(ack) 다음부터 다시 담아 메운다(최소 net_resend_min, 최대 net_resend_max개).
## 시작: 양쪽이 HELLO(버전, 내 검)를 보내고, 방장이 시드와 두 검을 정해 START를 보낸다(HELLO가 올 때마다 다시 답한다).

signal setup_ready(setup: DuelSetup)
signal desync(tick: int)
## reason: "left"(상대가 나갔다), "timeout"(입력이 오래 안 온다), "version"(프로토콜이 다르다).
signal peer_lost(reason: String)
signal stalled_changed(stalled: bool)

enum Pkt { INPUT = 1, HASH = 2, HELLO = 3, START = 4 }
const HEADER: int = 10
## 믿지 못할 값 방어: 지금 실행할 틱보다 이만큼 넘게 먼 입력은 버린다.
const MAX_AHEAD: int = 600

var data: GameData
var link: NetLink
var rules: Rules
var setup: DuelSetup
## 내 자리(0 = 방장, 1 = 손님).
var seat: int = 0
var delay: int = 4
var lost: bool = false
var lost_reason: String = ""
var desynced: bool = false
var desync_tick: int = -1
var stalled: bool = false
## 실행한 틱 수(= 다음에 실행할 틱 번호).
var exec_tick: int = 0
## 입력을 낸 수(내 입력은 sched + D 틱에 먹는다).
var sched: int = 0
var stall_ticks: int = 0
var rng := RandomNumberGenerator.new()
## 대역폭 세기.
var sent_bytes: int = 0
var sent_packets: int = 0
var recv_bytes: int = 0
var _my_spec: Dictionary = {}
var _peer_spec: Dictionary = {}
var _have_hello: bool = false
var _hello_t: float = 0.0
var _hello_on: bool = false
var _buf: Array[Dictionary] = [{}, {}]
var _peer_ack: int = -1
var _remote_ack: int = -1
var _mine: Dictionary = {}
var _theirs: Dictionary = {}
var _closed: bool = false


func _init(game: GameData, p_link: NetLink) -> void:
	data = game
	link = p_link
	seat = 0 if link.is_host else 1
	delay = game.duel.net_delay
	link.received.connect(_on_received)
	link.peer_left.connect(_on_peer_left)
	link.peer_joined.connect(_on_peer_joined)
	link.polled.connect(_on_polled)
	rng.randomize()


## 시작 정보를 주고받기 시작한다(내 검을 알린다). 상대가 이미 방에 있으면 바로 보낸다.
func begin(my_spec: Dictionary) -> void:
	_my_spec = my_spec
	seat = 0 if link.is_host else 1
	_hello_on = true
	_hello_t = 0.0
	if link.peer_present():
		_send_hello()


func _on_peer_joined() -> void:
	if _hello_on and setup == null:
		_send_hello()


func _on_polled(delta: float) -> void:
	if not _hello_on or setup != null or _closed:
		return
	_hello_t -= delta
	if _hello_t <= 0.0:
		_send_hello()


func _send_hello() -> void:
	_hello_t = data.duel.net_hello_interval
	if not link.peer_present():
		return
	_send(_pack(Pkt.HELLO, var_to_bytes([data.duel.net_version, _my_spec])), true)


## 방장이 시드를 정하고 START를 보낸다(HELLO를 받은 뒤).
func _host_start() -> void:
	if setup == null:
		var s := DuelSetup.new()
		s.version = data.duel.net_version
		s.seed_value = rng.randi_range(1, 2147483646)
		s.picks = [DuelSetup.clean(_my_spec, data), DuelSetup.clean(_peer_spec, data)]
		setup = s
		_hello_on = false
		_send(_pack(Pkt.START, setup.to_bytes()), true)
		setup_ready.emit(setup)
		return
	_send(_pack(Pkt.START, setup.to_bytes()), true)


## 규칙을 이어 붙이고 입력 칸을 비운다. 처음 D틱은 둘 다 빈 입력이다(내 입력이 D틱 뒤에 먹으니까).
func bind(r: Rules) -> void:
	rules = r
	exec_tick = 0
	sched = 0
	seat = 0 if link.is_host else 1
	# 규칙이 붙기 전에 먼저 온 상대 입력은 그대로 둔다(상대가 먼저 장면을 열 수 있다).
	for t in delay:
		_buf[0][t] = LordInput.new()
		_buf[1][t] = LordInput.new()
	_peer_ack = maxi(_peer_ack, delay - 1)
	_remote_ack = delay - 1
	while _buf[1 - seat].has(_remote_ack + 1):
		_remote_ack += 1


## 한 틱 분량의 일: 내 입력을 정해 보내고, 두 입력이 다 있으면 규칙을 한 틱 돌린다. 돌렸으면 1.
## 상대 입력이 없으면 0(멈춤). 시간(dt)은 끊김 판정에만 쓴다(몇 번째 멈춤인지 세어 net_timeout 초를 넘기면 peer_lost).
func update(local: LordInput) -> int:
	if rules == null or lost or desynced or _closed:
		return 0
	if sched <= exec_tick:
		_buf[seat][sched + delay] = local
		sched += 1
	_send_inputs()
	var a: Variant = _buf[0].get(exec_tick)
	var b: Variant = _buf[1].get(exec_tick)
	if a == null or b == null:
		stall_ticks += 1
		if not stalled:
			stalled = true
			stalled_changed.emit(true)
		if float(stall_ticks) * rules.dt >= data.duel.net_timeout:
			_lose("timeout")
		return 0
	stall_ticks = 0
	if stalled:
		stalled = false
		stalled_changed.emit(false)
	rules.step_duel(a, b)
	exec_tick += 1
	_prune()
	var every: int = data.duel.net_hash_every
	if every > 0 and exec_tick % every == 0:
		_hash_now()
	return 1


## 내 입력이 상대에게 모자라지 않게 최근 것을 겹쳐 담아 보낸다.
func _send_inputs() -> void:
	var latest: int = sched + delay - 1
	var first: int = maxi(delay, _peer_ack + 1)
	first = mini(first, latest - data.duel.net_resend_min + 1)
	first = maxi(first, latest - data.duel.net_resend_max + 1)
	first = maxi(first, delay)
	var count: int = maxi(0, latest - first + 1)
	var p := PackedByteArray()
	p.resize(HEADER)
	p[0] = Pkt.INPUT
	p.encode_s32(1, latest)
	p.encode_s32(5, _remote_ack)
	p[9] = count
	for t in range(first, first + count):
		var inp: LordInput = _buf[seat].get(t)
		p.append_array(inp.to_bytes() if inp != null else LordInput.new().to_bytes())
	_send(p, false)


func _prune() -> void:
	# 내 입력은 상대가 받았고 나도 실행한 것만 지운다. 상대 입력은 실행한 것을 이미 지웠다.
	var gone: int = mini(exec_tick, _peer_ack + 1)
	for t in _buf[seat].keys():
		if t < gone:
			_buf[seat].erase(t)
	for t in _buf[1 - seat].keys():
		if t < exec_tick:
			_buf[1 - seat].erase(t)


func _hash_now() -> void:
	var h: int = rules.state_hash()
	_mine[exec_tick] = h
	var p := _pack(Pkt.HASH, PackedByteArray())
	p.resize(1 + 4 + 8)
	p.encode_s32(1, exec_tick)
	p.encode_s64(5, h)
	_send(p, true)
	_check_hash(exec_tick)
	var old: int = exec_tick - data.duel.net_hash_every * 6
	for k in _mine.keys():
		if k < old:
			_mine.erase(k)
	for k in _theirs.keys():
		if k < old:
			_theirs.erase(k)


func _check_hash(tick: int) -> void:
	if not _mine.has(tick) or not _theirs.has(tick) or desynced:
		return
	if _mine[tick] != _theirs[tick]:
		desynced = true
		desync_tick = tick
		desync.emit(tick)


func _on_received(b: PackedByteArray) -> void:
	if b.is_empty() or _closed:
		return
	recv_bytes += b.size()
	match int(b[0]):
		Pkt.INPUT:
			_recv_inputs(b)
		Pkt.HASH:
			if b.size() >= 13:
				var tick: int = b.decode_s32(1)
				_theirs[tick] = b.decode_s64(5)
				_check_hash(tick)
		Pkt.HELLO:
			_recv_hello(b)
		Pkt.START:
			_recv_start(b)


func _recv_inputs(b: PackedByteArray) -> void:
	if b.size() < HEADER:
		return
	var latest: int = b.decode_s32(1)
	var ack: int = b.decode_s32(5)
	var count: int = b[9]
	if b.size() != HEADER + count * LordInput.BYTES:
		return
	_peer_ack = maxi(_peer_ack, ack)
	var other: int = 1 - seat
	var first: int = latest - count + 1
	for i in count:
		var t: int = first + i
		if t < exec_tick or t > exec_tick + MAX_AHEAD or _buf[other].has(t):
			continue
		_buf[other][t] = LordInput.from_bytes(b.slice(HEADER + i * LordInput.BYTES, HEADER + (i + 1) * LordInput.BYTES))
	while _buf[other].has(_remote_ack + 1):
		_remote_ack += 1


func _recv_hello(b: PackedByteArray) -> void:
	if b.size() < 5:
		return
	var v: Variant = bytes_to_var(b.slice(1))
	if not (v is Array) or (v as Array).size() != 2 or not ((v as Array)[0] is int):
		return
	if int((v as Array)[0]) != data.duel.net_version:
		_lose("version")
		return
	_peer_spec = DuelSetup.clean((v as Array)[1], data)
	_have_hello = true
	if link.is_host and not _my_spec.is_empty():
		_host_start()


func _recv_start(b: PackedByteArray) -> void:
	if link.is_host or setup != null:
		return
	var s := DuelSetup.from_bytes(b.slice(1), data)
	if s == null:
		return
	if s.version != data.duel.net_version:
		_lose("version")
		return
	setup = s
	_hello_on = false
	setup_ready.emit(s)


func _on_peer_left() -> void:
	if not _closed:
		_lose("left")


func _lose(reason: String) -> void:
	if lost:
		return
	lost = true
	lost_reason = reason
	peer_lost.emit(reason)


## 내 자리(링크가 방장이면 0).
func link_seat() -> int:
	return 0 if link.is_host else 1


## 끝났다: 더 안 받고 링크를 닫는다(방을 나간다).
func close() -> void:
	if _closed:
		return
	_closed = true
	link.close()


func _pack(type: int, body: PackedByteArray) -> PackedByteArray:
	var p := PackedByteArray([type])
	p.append_array(body)
	return p


func _send(p: PackedByteArray, reliable: bool) -> void:
	sent_bytes += p.size()
	sent_packets += 1
	link.send(p, reliable)


## 한 판(초)에 한 쪽이 보내는 바이트 어림: 평균 묶음 크기 × 초당 틱 수 × 초.
func bytes_per_second() -> float:
	if sent_packets == 0 or exec_tick == 0:
		return 0.0
	return float(sent_bytes) / (float(exec_tick) * (rules.dt if rules != null else 1.0 / 30.0))
