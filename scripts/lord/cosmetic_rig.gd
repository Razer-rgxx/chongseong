class_name CosmeticRig
extends RefCounted
## 영주 꾸미기를 몸에 입히는 한 곳(docs/cosmetics.md). LordView가 모든 장면(마을·언덕·들판·무덤·미래·과거·결투)에서,
## 꾸미기 창의 미리보기도 같은 함수를 쓴다.
## 기사 모델(LordCharacter)이면 머리·등 뼈에 붙이고, 없으면 기본 도형 몸(Model 노드)에 직접 얹는다.
## worn: 자리(cape·head·slash) → 항목 id. 없는 자리는 기본 모습.
## 우두머리 머리(오브젝트 헤드, Heads)를 쓰는 동안은 머리 꾸미기를 얹지 않는다(그 머리가 몸의 머리다). 망토와 베기 빛은 그대로.

const NODE_PREFIX: String = "Cos"
## 기본 도형 몸(캡슐, 머리 꼭대기 1.6m)의 머리 가운데와 크기, 망토를 다는 자리.
const PRIM_HEAD_AT: Vector3 = Vector3(0, 1.42, 0)
const PRIM_HEAD_SCALE: float = 0.4
const PRIM_CAPE_AT: Vector3 = Vector3(0, 1.38, 0.44)
const PRIM_CAPE_SCALE: Vector3 = Vector3(1.25, 1.0, 1.0)
## 기사 모델: 머리 뼈 원점에서 머리 가운데까지, 머리 반지름, 등 뼈에서 망토를 다는 자리.
const CHAR_HEAD_BONE: String = "mixamorig_Head"
const CHAR_HEAD_AT: Vector3 = Vector3(0, 0.11, 0.0)
const CHAR_HEAD_SCALE: float = 0.105
const CHAR_BACK_BONE: String = "mixamorig_Spine2"
const CHAR_CAPE_AT: Vector3 = Vector3(0, 0.15, 0.13)
## Blender 망토는 이 받침 좌표(영주 몸 단면, scripts/debug/dump_body_profile.gd)에 맞춰 짓는다: 크기 1.
const CHAR_CAPE_SCALE: Vector3 = Vector3.ONE


## 입힌다. 이미 입힌 것은 걷어 내고 다시 입힌다. 돌려주는 값: {slash: 베기 빛 색(알파 0이면 검 본래 빛), cape: 흔들 망토 축 노드 또는 null}.
static func apply(model: Node3D, character: LordCharacter, worn: Dictionary, under_object_head: bool = true) -> Dictionary:
	_clear(model)
	var t: CosmeticTable = Cosmetics.table()
	var out: Dictionary = {"slash": Color(0, 0, 0, 0), "cape": null}
	var cape_it: CosmeticItem = t.item(StringName(worn.get("cape", t.default_of(&"cape"))))
	var head_it: CosmeticItem = t.item(StringName(worn.get("head", t.default_of(&"head"))))
	out.slash = Cosmetics.slash_color(worn)
	var is_cape: bool = cape_it != null and cape_it.slot == &"cape" and cape_it.id != t.default_of(&"cape")
	var is_head: bool = head_it != null and head_it.slot == &"head" and head_it.style != &"none"
	# 우두머리의 오브젝트 머리(Heads, 능력 칸)를 쓰고 있으면 그 머리가 먼저다: 투구는 얹지 않는다(꾸미기 창 미리보기는 사람 머리라 얹는다).
	if is_head and under_object_head and character != null and not ObjectHead.lord_info.is_empty():
		is_head = false
	# 기본 도형의 처음 모습(붉은 상자 망토, 금관)은 꾸밈이 있을 때만 가린다.
	var orig_cape := model.get_node_or_null("Cape") as Node3D
	var orig_crown := model.get_node_or_null("Crown") as Node3D
	if orig_cape != null:
		orig_cape.visible = not is_cape
	if orig_crown != null:
		orig_crown.visible = not is_head
	if is_cape:
		var pivot: Node3D = CosmeticArt.cape(cape_it)
		if character == null:
			pivot.name = NODE_PREFIX + "Cape"
			pivot.position = PRIM_CAPE_AT
			pivot.scale = PRIM_CAPE_SCALE
			model.add_child(pivot)
		else:
			var holder: Node3D = _holder(character, CHAR_BACK_BONE, CHAR_CAPE_AT, NODE_PREFIX + "CapeHolder")
			if holder != null:
				pivot.scale = CHAR_CAPE_SCALE
				holder.add_child(pivot)
			else:
				pivot.name = NODE_PREFIX + "Cape"
				pivot.position = Vector3(0, 1.45, 0.16)
				pivot.scale = CHAR_CAPE_SCALE
				model.add_child(pivot)
		out.cape = pivot
	if is_head:
		var art: Node3D = CosmeticArt.head(head_it)
		if character == null:
			art.name = NODE_PREFIX + "Head"
			art.position = PRIM_HEAD_AT
			art.scale = Vector3.ONE * PRIM_HEAD_SCALE
			model.add_child(art)
		else:
			var holder: Node3D = _holder(character, CHAR_HEAD_BONE, CHAR_HEAD_AT, NODE_PREFIX + "HeadHolder")
			art.scale = Vector3.ONE * CHAR_HEAD_SCALE
			if holder != null:
				holder.add_child(art)
			else:
				art.name = NODE_PREFIX + "Head"
				art.position = Vector3(0, 1.62, 0)
				model.add_child(art)
	return out


## 뼈에 붙는 받침 하나. 받침의 자식은 영주 모델 좌표(앞 -Z)로 짓는다: 쉬는 자세에서 모델 좌표와 같은 방향이 되게
## (뼈대 좌표는 +Z가 앞이라 Y로 반 바퀴 돌려 놓는다) 뼈의 쉬는 자세를 거꾸로 곱한다(EnemyArt의 방패·눈과 같은 방법).
static func _holder(character: LordCharacter, bone: String, offset: Vector3, node_name: String) -> Node3D:
	if not character.has_bone(bone):
		return null
	var rest: Transform3D = character.bone_rest(bone)
	var flip := Basis(Vector3.UP, PI)
	var holder := Node3D.new()
	holder.name = node_name
	character.attach(bone, holder)
	holder.transform = rest.affine_inverse() * Transform3D(flip, rest.origin + flip * offset)
	return holder


## 입혀 둔 것을 모두 걷는다(기본 도형 노드와 뼈에 붙인 받침).
static func _clear(model: Node3D) -> void:
	for n in model.find_children(NODE_PREFIX + "*", "", true, false):
		var holder: Node = n
		if n.name.ends_with("Holder") and n.get_parent() is BoneAttachment3D:
			holder = n.get_parent()   # 붙임 노드째로 지운다
		if holder.get_parent() != null:
			holder.get_parent().remove_child(holder)
		holder.queue_free()
