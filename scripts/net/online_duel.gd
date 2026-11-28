class_name OnlineDuel
extends RefCounted
## 온라인 결투를 마을에서 시작해 결투 장면까지 잇는다(22단계, docs/duel.md). 화면 코드와 락스텝 사이의 얇은 흐름.
## 마을 창: 검을 고르고 → start → 접속·방 찾기(상태 글이 바뀐다, 취소 가능) → 둘이 모이면 HELLO·START → ready.
## 결투 장면은 `OnlineDuel.current`를 가져다 쓴다(장면을 넘어 이어지는 값이라 static, 저장하지 않는다).

## 한 줄 상태 글(창이 갈아 끼운다). failed는 더 못 가는 경우(키 없음 포함)의 한 줄.
signal status_text(text: String)
signal ready()
signal failed(text: String)

static var current: OnlineDuel = null

var game: GameData
var meta: Meta
var link: NetLink
var lockstep: Lockstep
var pick_id: int = 0
var done: bool = false
## 랭크 결투인가(docs/duel_league.md). start 전에 정하고, 결투 장면이 읽는다.
var ranked: bool = false


func _init(p_game: GameData, p_meta: Meta) -> void:
	game = p_game
	meta = p_meta


## 검(SwordData.id, 0은 맨손)을 정하고 상대를 찾기 시작한다. 링크를 따로 주면(시험) 그것을 쓴다.
func start(id: int, p_link: NetLink = null) -> void:
	pick_id = id
	if p_link != null:
		link = p_link
	else:
		var gl := GdSyncLink.new(game)
		gl.ranked = ranked
		link = gl
	link.status_changed.connect(_on_status)
	lockstep = Lockstep.new(game, link)
	lockstep.setup_ready.connect(_on_setup)
	lockstep.peer_lost.connect(_on_lost)
	link.find_match()


func _on_status(s: int) -> void:
	match s:
		NetLink.Status.NO_KEYS:
			failed.emit(key_help())
		NetLink.Status.FAILED:
			failed.emit(link.error_text)
		NetLink.Status.CONNECTING, NetLink.Status.SEARCHING, NetLink.Status.WAITING:
			status_text.emit(link.error_text)
		NetLink.Status.MATCHED:
			status_text.emit("상대를 찾았다. 준비하는 중")
			lockstep.begin(DuelSetup.spec_of(meta, pick_id))


func _on_setup(_setup: DuelSetup) -> void:
	if done:
		return
	done = true
	current = self
	ready.emit()


func _on_lost(reason: String) -> void:
	if not done:
		failed.emit("버전이 달라 겨룰 수 없다." if reason == "version" else "상대가 나갔다.")


## 찾기를 그만둔다(방을 나간다).
func cancel() -> void:
	if link != null:
		link.close()
	if current == self:
		current = null


## 한 줄: 키 파일이 없을 때 안내. 창 글에 쓴다.
static func key_help() -> String:
	return "GD-Sync 키가 없습니다. 이 파일을 만드세요:\n%s\n[keys] 아래에 public=\"공개키\"와 private=\"비밀키\"를 적습니다." % GdSyncLink.keys_os_path()
