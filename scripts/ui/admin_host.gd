class_name AdminHost
extends Node
## 관리자 계정일 때 루트에 서서, 검 콘솔(` / F6)이 없는 장면(들판·무덤·마을)에서도 같은 콘솔을 연다(docs/account.md).
## 언덕(main)은 자기 콘솔이 있어 건드리지 않는다. 장면의 `rules`(Rules)가 있으면 그것으로 검·조각·날씨를 돌린다.
## 열려 있는 동안 트리를 멈춘다.

const NAME: String = "AdminHost"

var _layer: CanvasLayer
var _console: SwordConsole
var _was_paused: bool = false
var _was_mouse: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


static func ensure() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root.get_node_or_null(NAME) != null:
		return
	var h := AdminHost.new()
	h.name = NAME
	tree.root.add_child.call_deferred(h)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or not Account.admin:
		return
	if k.physical_keycode != KEY_QUOTELEFT and k.physical_keycode != KEY_F6:
		return
	var scene: Node = get_tree().current_scene
	if scene == null or scene.get("_console") != null:
		return   # 언덕은 자기 콘솔이 있다
	if _console != null and _console.visible:
		return
	_open(scene)
	get_viewport().set_input_as_handled()


func _open(scene: Node) -> void:
	if _console == null:
		_layer = CanvasLayer.new()
		_layer.layer = 100
		add_child(_layer)
		_console = SwordConsole.new()
		_console.process_mode = Node.PROCESS_MODE_ALWAYS
		_console.setup(GameData.load_default())
		_layer.add_child(_console)
		_console.closed.connect(_on_closed)
		_console.picked.connect(_on_pick)
		_console.shards_given.connect(_on_shards)
		_console.command.connect(_on_command)
	_was_paused = get_tree().paused
	_was_mouse = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_console.open()


func _on_closed() -> void:
	get_tree().paused = _was_paused
	Input.mouse_mode = _was_mouse


func _rules() -> Rules:
	var s: Node = get_tree().current_scene
	return s.get("rules") as Rules if s != null else null


func _meta() -> Meta:
	var s: Node = get_tree().current_scene
	var m: Variant = s.get("meta") if s != null else null
	return m as Meta if m is Meta else Meta.load_or_new()


func _on_pick(d: SwordData, slot: int) -> void:
	var r := _rules()
	if r == null:
		return
	var k: int = slot if slot >= 0 else r.active
	r.give(d, k)
	if r.active != k:
		r.swap(k)


func _on_shards(n: int) -> void:
	var m := _meta()
	m.shards = maxi(0, m.shards + n)
	m.save()


func _on_command(cmd: Dictionary) -> void:
	AdminCmd.apply(cmd, _rules(), _meta())
