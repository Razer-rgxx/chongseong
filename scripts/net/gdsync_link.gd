class_name GdSyncLink
extends NetLink
## GD-Sync(addons/GD-Sync) 전송(22단계, docs/duel.md). 접속 → 공개 방 찾기(꼬리표 game·mode·ver) → 있으면 들어가고 없으면 만들고 기다림.
## 방을 만든 쪽이 방장(자리 0). 플러그인은 autoload로 두지 않고 처음 쓸 때 /root/GDSync로 올린다(키 없이 시끄럽게 실패하지 않게, 테스트도 조용히).
## 키는 git에 올리지 않고 user://gdsync_keys.cfg([keys] public, private)에서 읽는다. 없으면 NO_KEYS 상태로 멈추고 접속하지 않는다.
## 플러그인 API는 GDSync 노드에 call로만 닿는다(플러그인이 없어도 이 파일은 열린다).

const PLUGIN_SCRIPT: String = "res://addons/GD-Sync/MultiplayerClient.gd"
const RELAY_SCRIPT: String = "res://scripts/net/gdsync_relay.gd"
const RELAY_NAME: String = "GdSyncRelay"
const NODE_NAME: String = "GDSync"
const PLAYER_LIMIT: int = 2
const NAME_CHARS: String = "abcdefghjkmnpqrstuvwxyz23456789"

## 키 파일 자리(시험은 다른 경로를 넣는다).
static var keys_path: String = "user://gdsync_keys.cfg"

var game: GameData
var lobby_name: String = ""
var created: bool = false
var peer_id: int = -1
var _gd: Variant = null
var _relay: Node = null
var _hooked: bool = false
var _phase_t: float = 0.0
var _search_t: float = 0.0
var _peer_t: float = 0.5
var _retry_t: float = -1.0
var _retries: int = 0
var _starting: bool = false
var _rng := RandomNumberGenerator.new()
var _closed: bool = false


## 랭크 결투 방(꼬리표 mode가 달라 보통 결투와 섞이지 않는다, docs/duel_league.md). find_match 전에 정한다.
var ranked: bool = false


func _init(p_game: GameData = null) -> void:
	game = p_game if p_game != null else GameData.load_default()
	_rng.randomize()


# ---------------------------------------------------------------- 키

## 키 파일을 읽는다: {public, private}. 없으면 빈 글. user:// 파일 → 환경변수(GDSYNC_PUBLIC_KEY, GDSYNC_PRIVATE_KEY) → 플러그인 자리(addons/GD-Sync/keys.cfg) 순서.
static func load_keys() -> Dictionary:
	var out: Dictionary = {"public": "", "private": ""}
	var cfg := ConfigFile.new()
	if cfg.load(keys_path) == OK:
		out.public = str(cfg.get_value("keys", "public", "")).strip_edges()
		out.private = str(cfg.get_value("keys", "private", "")).strip_edges()
	if out.public == "" or out.private == "":
		var pub: String = OS.get_environment("GDSYNC_PUBLIC_KEY").strip_edges()
		var pri: String = OS.get_environment("GDSYNC_PRIVATE_KEY").strip_edges()
		if pub != "" and pri != "":
			out.public = pub
			out.private = pri
	if (out.public == "" or out.private == "") and keys_path == "user://gdsync_keys.cfg":
		var plug := ConfigFile.new()
		if plug.load("res://addons/GD-Sync/keys.cfg") == OK:
			var a: String = str(plug.get_value("keys", "publicKey", "")).strip_edges()
			var b: String = str(plug.get_value("keys", "privateKey", "")).strip_edges()
			if a != "" and b != "":
				out.public = a
				out.private = b
	return out


static func has_keys() -> bool:
	var k: Dictionary = load_keys()
	return k.public != "" and k.private != ""


static func plugin_present() -> bool:
	return ResourceLoader.exists(PLUGIN_SCRIPT)


## 키 파일이 있어야 할 실제 컴퓨터 경로(창 안내용).
static func keys_os_path() -> String:
	return ProjectSettings.globalize_path(keys_path)


# ---------------------------------------------------------------- 찾기

func find_match() -> void:
	if _starting or _closed:
		return
	if not plugin_present():
		set_status(Status.FAILED, "GD-Sync 플러그인이 없습니다(addons/GD-Sync).")
		return
	if not has_keys():
		set_status(Status.NO_KEYS, "GD-Sync 키가 없습니다")
		return
	_starting = true
	_phase_t = 0.0
	set_status(Status.CONNECTING, "서버에 접속하는 중")
	_boot()


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


## 플러그인 노드와 전달 노드를 루트에 올리고 접속한다(노드가 서는 데 한두 프레임).
func _boot() -> void:
	var tree := _tree()
	if tree == null:
		set_status(Status.FAILED, "장면 트리가 없습니다.")
		return
	_gd = tree.root.get_node_or_null(NODE_NAME)
	if _gd == null:
		var scr := load(PLUGIN_SCRIPT) as GDScript
		_gd = scr.new()
		(_gd as Node).name = NODE_NAME
		tree.root.add_child.call_deferred(_gd)
		await tree.process_frame
		await tree.process_frame
	if _closed:
		return
	var keys: Dictionary = load_keys()
	var cc: Variant = _gd.get("_connection_controller")
	if cc != null and (str(cc.get("_PUBLIC_KEY")) == "" or str(cc.get("_PRIVATE_KEY")) == ""):
		cc.set("_PUBLIC_KEY", keys.public)
		cc.set("_PRIVATE_KEY", keys.private)
		var lg: Variant = _gd.get("_logger")
		if lg != null:
			lg.call("register_redacted_value", keys.public)
			lg.call("register_redacted_value", keys.private)
	_relay = tree.root.get_node_or_null(RELAY_NAME)
	if _relay == null:
		_relay = (load(RELAY_SCRIPT) as GDScript).new() as Node
		_relay.name = RELAY_NAME
		tree.root.add_child.call_deferred(_relay)
		await tree.process_frame
	_relay.set("link", self)
	_gd.call("expose_func", Callable(_relay, "receive"))
	_hook()
	if bool(_gd.call("is_active")) and int(_gd.call("get_client_id")) >= 0:
		_on_connected()
	else:
		_gd.call("start_multiplayer")


func _hook() -> void:
	if _hooked:
		return
	_hooked = true
	for pair in [["connected", _on_connected], ["connection_failed", _on_connection_failed], ["disconnected", _on_disconnected],
			["lobbies_received", _on_lobbies], ["lobby_created", _on_lobby_created], ["lobby_creation_failed", _on_create_failed],
			["lobby_joined", _on_lobby_joined], ["lobby_join_failed", _on_join_failed], ["client_joined", _on_client_joined],
			["client_left", _on_client_left]]:
		(_gd as Object).connect(pair[0], pair[1])


func _unhook() -> void:
	if not _hooked or _gd == null or not is_instance_valid(_gd):
		return
	_hooked = false
	for pair in [["connected", _on_connected], ["connection_failed", _on_connection_failed], ["disconnected", _on_disconnected],
			["lobbies_received", _on_lobbies], ["lobby_created", _on_lobby_created], ["lobby_creation_failed", _on_create_failed],
			["lobby_joined", _on_lobby_joined], ["lobby_join_failed", _on_join_failed], ["client_joined", _on_client_joined],
			["client_left", _on_client_left]]:
		if (_gd as Object).is_connected(pair[0], pair[1]):
			(_gd as Object).disconnect(pair[0], pair[1])


func _on_connected() -> void:
	if _closed:
		return
	_search()


func _on_connection_failed(error: int) -> void:
	if _closed:
		return
	_starting = false
	set_status(Status.FAILED, "키가 틀렸습니다. 공개 키와 비밀 키를 확인하세요." if error == 0 else "서버에 닿지 않습니다.")


func _on_disconnected() -> void:
	if _closed:
		return
	var was: int = status
	_starting = false
	set_status(Status.FAILED, "서버와의 연결이 끊겼습니다.")
	if was == Status.MATCHED or was == Status.WAITING:
		peer_left.emit()


func _search() -> void:
	_phase_t = 0.0
	set_status(Status.SEARCHING, "상대를 찾는 중")
	_gd.call("get_public_lobbies")


func _tags() -> Dictionary:
	return {"game": game.duel.net_tag_game, "mode": game.duel.net_tag_ranked if ranked else game.duel.net_tag_mode, "ver": game.duel.net_version}


func _is_ours(lobby: Dictionary) -> bool:
	var t: Variant = lobby.get("Tags", {})
	if not (t is Dictionary):
		return false
	var want: Dictionary = _tags()
	for k in want:
		if (t as Dictionary).get(k) != want[k]:
			return false
	return lobby.get("Open", true) == true and int(lobby.get("PlayerCount", 0)) < int(lobby.get("PlayerLimit", PLAYER_LIMIT))


func _on_lobbies(lobbies: Array) -> void:
	if _closed or status == Status.MATCHED:
		return
	var names: Array[String] = []
	for l in lobbies:
		if l is Dictionary and _is_ours(l) and str(l.get("Name", "")) != lobby_name:
			names.append(str(l.get("Name", "")))
	names.sort()
	if status == Status.WAITING:
		if not created:
			return
		# 둘이 동시에 방을 만들었을 때: 이름이 더 앞선 방으로 모인다(뒤선 쪽이 옮겨 간다).
		if not names.is_empty() and names[0] < lobby_name:
			_leave_lobby()
			_join(names[0])
		return
	if names.is_empty():
		_create()
	else:
		_join(names[0])


func _new_name() -> String:
	var s: String = game.duel.net_lobby_prefix + "_"
	for i in 10:
		s += NAME_CHARS[_rng.randi_range(0, NAME_CHARS.length() - 1)]
	return s


func _create() -> void:
	created = true
	lobby_name = _new_name()
	_gd.call("lobby_create", lobby_name, "", true, PLAYER_LIMIT, _tags())


func _join(n: String) -> void:
	created = false
	is_host = false
	lobby_name = n
	_gd.call("lobby_join", n)


func _on_lobby_created(n: String) -> void:
	if _closed:
		return
	lobby_name = n
	_gd.call("lobby_join", n)


func _on_create_failed(_n: String, _error: int) -> void:
	if _closed:
		return
	_retries += 1
	if _retries > 5:
		set_status(Status.FAILED, "방을 만들지 못했습니다.")
		return
	_retry_t = 3.5   # 방 만들기는 3초에 한 번(플러그인 문서)


func _on_lobby_joined(n: String) -> void:
	if _closed:
		return
	lobby_name = n
	is_host = created
	_phase_t = 0.0
	_search_t = game.duel.net_search_interval
	if created:
		set_status(Status.WAITING, "상대를 기다리는 중")
	_check_peer.call_deferred()


func _on_join_failed(_n: String, _error: int) -> void:
	if _closed:
		return
	_retries += 1
	if _retries > 5:
		set_status(Status.FAILED, "방에 들어가지 못했습니다.")
		return
	_search()   # 그 사이 찼거나 사라졌다: 처음부터 다시 찾는다


func _on_client_joined(id: int) -> void:
	if _closed or status == Status.MATCHED or id == int(_gd.call("get_client_id")):
		return
	if lobby_name != "":
		_matched(id)


func _on_client_left(id: int) -> void:
	if _closed or id == int(_gd.call("get_client_id")):
		return
	if status == Status.MATCHED and id == peer_id:
		set_status(Status.CLOSED, "상대가 나갔습니다.")
		peer_left.emit()


func _check_peer() -> void:
	if _closed or status == Status.MATCHED or _gd == null:
		return
	var me: int = int(_gd.call("get_client_id"))
	for id in _gd.call("lobby_get_all_clients"):
		if int(id) != me:
			_matched(int(id))
			return
	if not created and status != Status.MATCHED:
		set_status(Status.WAITING, "상대를 기다리는 중")


func _matched(id: int) -> void:
	peer_id = id
	set_status(Status.MATCHED, "상대를 찾았습니다")
	if created:
		_gd.call("lobby_set_visibility", false)   # 더는 공개 목록에 안 뜬다
	peer_joined.emit()


func _leave_lobby() -> void:
	if _gd != null and is_instance_valid(_gd) and lobby_name != "":
		_gd.call("lobby_leave")
	lobby_name = ""
	created = false
	is_host = false
	peer_id = -1


# ---------------------------------------------------------------- 주고받기

func peer_present() -> bool:
	return status == Status.MATCHED and _gd != null and is_instance_valid(_gd)


func send(data: PackedByteArray, reliable: bool = false) -> void:
	if not peer_present() or _relay == null:
		return
	_gd.callv("call_func" if reliable else "call_func_unreliable", [Callable(_relay, "receive"), data])


## 릴레이 노드가 받은 바이트를 올려 준다.
func on_remote(data: PackedByteArray) -> void:
	if not _closed:
		received.emit(data)


## 시간으로 도는 일: 접속 한계, 방 만들기 다시 하기, 기다리는 동안 다른 대기 방 다시 찾기.
func poll(delta: float) -> void:
	polled.emit(delta)
	if _closed or _gd == null:
		return
	match status:
		Status.CONNECTING, Status.SEARCHING:
			_phase_t += delta
			if _retry_t >= 0.0:
				_retry_t -= delta
				if _retry_t < 0.0:
					_create()
			elif _phase_t > game.duel.net_connect_timeout:
				_starting = false
				set_status(Status.FAILED, "서버에 닿지 않습니다.")
		Status.WAITING:
			_peer_t -= delta
			if _peer_t <= 0.0:
				_peer_t = 0.5
				_check_peer()   # 신호를 놓쳤을 때를 위해 방 사람을 다시 센다
			_search_t -= delta
			if _search_t <= 0.0:
				_search_t = game.duel.net_search_interval
				_gd.call("get_public_lobbies")


## 방을 나가고 접속을 끊고 전달 노드를 치운다. 여러 번 불러도 된다.
func close() -> void:
	if _closed:
		return
	_closed = true
	_starting = false
	if _gd != null and is_instance_valid(_gd):
		_unhook()
		if lobby_name != "" and bool(_gd.call("is_active")):
			_gd.call("lobby_leave")
		if bool(_gd.call("is_active")):
			_gd.call("stop_multiplayer")
	if _relay != null and is_instance_valid(_relay):
		_relay.set("link", null)
		_relay.queue_free()
	_relay = null
	if status != Status.NO_KEYS and status != Status.FAILED:
		set_status(Status.CLOSED)
