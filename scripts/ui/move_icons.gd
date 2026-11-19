class_name MoveIcons
extends RefCounted
## 동작 20가지와 속성 4가지의 아이콘(아트팀). assets/ui/moves/<id>.svg, el_<속성>.svg.
## 손으로 쓴 SVG(64 × 64, 투명 바탕, 놋쇠빛 #A88F61 선)라 32~64px로 띄우면 깨끗하다.
## 한 번 읽은 것은 기억해 둔다. 파일이 없으면 null을 돌려준다.

const DIR := "res://assets/ui/moves/"

static var _cache: Dictionary[String, Texture2D] = {}


## 동작 아이콘(id는 docs/attacks.md 1절: sweep, thrust, … parry).
static func icon(id: StringName) -> Texture2D:
	return _load_icon(String(id))


## 속성 아이콘(fire, ice, bolt, blood). 속성이 없으면(&"") null.
static func element(el: StringName) -> Texture2D:
	if el == &"":
		return null
	return _load_icon("el_" + String(el))


static func _load_icon(name: String) -> Texture2D:
	if name.is_empty():
		return null
	if _cache.has(name):
		return _cache[name]
	var path: String = DIR + name + ".svg"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_cache[name] = tex
	return tex
