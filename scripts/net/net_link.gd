class_name NetLink
extends RefCounted
## 전송 인터페이스(22단계, docs/duel.md). Lockstep은 이것만 알고 GD-Sync는 모른다.
## 구현: LoopLink(테스트, 지연·뒤섞임·빠짐을 흉내), GdSyncLink(GD-Sync). 노드 없음.

## 접속·방 찾기 상태. NO_KEYS는 키 파일이 없다는 뜻(접속하지 않는다).
enum Status { IDLE, NO_KEYS, CONNECTING, SEARCHING, WAITING, MATCHED, FAILED, CLOSED }

## 상대가 보낸 바이트가 왔다.
signal received(data: PackedByteArray)
## 상대가 방에 들어왔다 / 나갔다(연결이 끊긴 것도 나감으로 알린다).
signal peer_joined()
signal peer_left()
## 상태가 바뀌었다(창이 글을 갈아 끼운다).
signal status_changed(status: int)
## 시간이 흘렀다(초). 시간으로 도는 일(HELLO 다시 보내기)에 쓴다.
signal polled(delta: float)

var status: int = Status.IDLE
## 마지막 실패 이유(사람이 읽는 한 줄).
var error_text: String = ""
## 내가 방장이다(방을 만든 쪽). 락스텝에서 0번 자리이고 시작 시드를 정한다.
var is_host: bool = false


## 바이트를 상대에게 보낸다. reliable이 false면 빠질 수 있다(입력 묶음은 겹쳐 보내서 메운다).
func send(_data: PackedByteArray, _reliable: bool = false) -> void:
	pass


## 상대가 방에 있다.
func peer_present() -> bool:
	return false


## 접속과 방 찾기를 시작한다(상대를 찾는다).
func find_match() -> void:
	pass


## 찾기를 그만두거나 방을 나간다.
func close() -> void:
	pass


## 시간을 흘린다. 노드가 없는 구현은 이것으로 돈다(GdSyncLink는 자기 노드가 부른다).
func poll(delta: float) -> void:
	polled.emit(delta)


func set_status(s: int, text: String = "") -> void:
	error_text = text
	if s == status:
		return
	status = s
	status_changed.emit(s)
