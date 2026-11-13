class_name VillageMaterials
extends RefCounted
## 마을과 언덕의 질감. assets/village/<이름>/ 에 <이름>_diff.jpg, <이름>_nor_gl.jpg, <이름>_rough.jpg가 있으면 쓰고,
## 없으면 받은 색 하나로 칠한다. 질감 파일을 넣기만 하면 코드를 고치지 않아도 바뀐다.
## 상자 크기가 제각각이라 월드 좌표 트라이플래너로 붙인다(늘어나지 않는다).

const DIR: String = "res://assets/village/"

static var _cache: Dictionary = {}


## tile: 질감 한 장이 덮는 길이(m).
static func get_mat(name: String, fallback: Color, tile: float = 2.5, tint: Color = Color.WHITE) -> StandardMaterial3D:
	var key: String = "%s|%s|%s|%s" % [name, fallback, tile, tint]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	var base: String = DIR + name + "/" + name
	if ResourceLoader.exists(base + "_diff.jpg"):
		m.albedo_texture = load(base + "_diff.jpg")
		m.albedo_color = tint
		if ResourceLoader.exists(base + "_nor_gl.jpg"):
			m.normal_enabled = true
			m.normal_texture = load(base + "_nor_gl.jpg")
		if ResourceLoader.exists(base + "_rough.jpg"):
			m.roughness_texture = load(base + "_rough.jpg")
			m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE / tile
	else:
		m.albedo_color = fallback
		m.roughness = 0.9
	_cache[key] = m
	return m


static func has(name: String) -> bool:
	return ResourceLoader.exists(DIR + name + "/" + name + "_diff.jpg")
