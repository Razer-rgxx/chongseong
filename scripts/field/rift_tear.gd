class_name RiftTear
extends Node3D
## 시대 균열의 찢어진 틈(docs/rift_raid.md): 엇갈린 두 장의 판에 셰이더(rift_tear.gdshader). 푸른 정전기, 금빛 먼지, 재.
## 싸고(빛 하나, 입자 없음) 웹판에서도 돈다. 소리는 낮은 울림만 장면(field.gd)이 낸다. 글자 없음.

const SHADER: Shader = preload("res://assets/field/rift_tear.gdshader")
const HEIGHT: float = 6.0
const WIDTH: float = 4.4

var _mats: Array[ShaderMaterial] = []
var _light: OmniLight3D
var _t: float = 0.0
## 싸움 중이면 더 세게 일렁인다.
var power: float = 1.0


static func make(parent: Node3D, at: Vector3) -> RiftTear:
	var r := RiftTear.new()
	parent.add_child(r)
	r.position = at
	r._build()
	return r


func _build() -> void:
	for i in 2:
		var q := QuadMesh.new()
		q.size = Vector2(WIDTH, HEIGHT)
		var m := ShaderMaterial.new()
		m.shader = SHADER
		_mats.append(m)
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = m
		mi.position.y = HEIGHT / 2.0 - 0.2
		mi.rotation.y = PI / 2.0 * i + 0.35
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.5, 0.7, 1.0)
	_light.omni_range = 9.0
	_light.light_energy = 1.6
	_light.position.y = 2.6
	_light.shadow_enabled = false
	add_child(_light)


func _process(delta: float) -> void:
	_t += delta
	for m in _mats:
		m.set_shader_parameter("power", power)
	# 푸른빛과 금빛이 번갈아 비친다(꾸밈)
	var k: float = 0.5 + 0.5 * sin(_t * 2.3)
	_light.light_color = Color(0.5, 0.7, 1.0).lerp(Color(1.0, 0.78, 0.38), k * 0.5)
	_light.light_energy = (1.2 + 0.5 * absf(sin(_t * 17.0))) * power
