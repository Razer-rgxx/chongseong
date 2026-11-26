class_name SecretRun
extends RefCounted
## 한 장면의 꾸미기 비밀을 세우고 치우고 쓴다(docs/cosmetics.md). 장면(field·future·past)은 이것만 부른다.
## refresh(ctx) → 때가 맞는 자리만 모양이 서고, spots()가 E 후보 자리를 주고, use(키)가 찾음을 Meta에 적고 알린다.
## 규칙(Rules)은 건드리지 않는다. 키는 "sec_<id>".

var scene: String
var _parent: Node3D
var _meta: Meta
var _ground: Callable   # (칸 좌표 Vector2) -> 땅 높이 m
var _nodes: Dictionary = {}
var _t: float = 0.0


func _init(scene_name: String, parent: Node3D, meta: Meta, ground: Callable = Callable()) -> void:
	scene = scene_name
	_parent = parent
	_meta = meta
	_ground = ground


## ctx: {weather: String, night: bool}(들판만 채운다).
func refresh(ctx: Dictionary = {}) -> void:
	for s in CosSecrets.in_scene(scene):
		var id: String = String(s.id)
		var on: bool = CosSecrets.active(s, _meta, ctx)
		if on and not _nodes.has(id):
			var p: Vector3 = Grid.cells_to_world(s.at)
			if _ground.is_valid():
				p.y = float(_ground.call(s.at))
			_nodes[id] = SecretProps.make(String(s.look), _parent, p)
		elif not on and _nodes.has(id):
			(_nodes[id] as Node3D).queue_free()
			_nodes.erase(id)


func spots() -> Dictionary:
	var out: Dictionary = {}
	for id in _nodes:
		out["sec_" + String(id)] = CosSecrets.find(String(id)).at
	return out


func prompt(key: String) -> String:
	return String(CosSecrets.find(key.substr(4)).get("prompt", ""))


## 인물은 영주 쪽을 천천히 돌아보고 숨 쉰다(꾸밈).
func animate(delta: float, lord_world: Vector3) -> void:
	_t += delta
	for id in _nodes:
		var n: Node3D = _nodes[id]
		var body: Node3D = n.get_node_or_null("Body")
		if body != null:
			body.position.y = sin(_t * 1.1) * 0.03
			n.rotation.y = lerp_angle(n.rotation.y, atan2(lord_world.x - n.position.x, lord_world.z - n.position.z) + PI, 1.0 - exp(-1.5 * delta))


## 쓴다: 찾았다고 적고 모양을 치우고 알린다. 새로 열린 항목 id들을 돌려준다(저장은 부른 쪽이).
func use(key: String, hud: LobbyHud) -> Array[String]:
	var id: String = key.substr(4)
	var s: Dictionary = CosSecrets.find(id)
	if s.is_empty() or not _nodes.has(id):
		return []
	var got: Array[String] = _meta.cos_discover(id)
	var n: Node3D = _nodes[id]
	_nodes.erase(id)
	announce(hud, s, n.position)
	if s.kind == "talk":
		var tw: Tween = n.create_tween()
		tw.tween_interval(6.0)
		tw.tween_property(n, "scale", Vector3(1, 0.01, 1), 0.8)   # 말을 마치면 안개처럼 가라앉는다
		tw.tween_callback(n.queue_free)
	else:
		n.queue_free()
	return got


static func announce(hud: LobbyHud, s: Dictionary, _at: Vector3) -> void:
	hud.flash(Color(0.8, 0.85, 1.0), 0.18, 0.7)
	if s.get("kind", "touch") == "talk":
		hud.say(String(s.name), String(s.line), true)
		hud.get_tree().create_timer(6.5).timeout.connect(func() -> void:
			if is_instance_valid(hud):
				hud.say_end())
	else:
		hud.toast(String(s.line))
