extends RefCounted
## 영주 꾸미기 테스트(docs/cosmetics.md). run_all.gd가 부른다: run(데이터, check). 실제 저장 파일은 쓰지 않는다.

const TMP: String = "user://테스트_cosmetics.json"
const UNLOCKS: Array[StringName] = [&"free", &"shards", &"league", &"boss", &"story", &"rune"]
const STYLES: Array[StringName] = [&"plain", &"trim", &"stripe", &"check", &"emblem", &"ragged", &"rune", &"none", &"band", &"hood", &"kettle", &"helm", &"circlet", &"horn", &"plume", &"spikes", &"visor", &"runeband", &"slash"]

var check: Callable
var d: GameData


static func run(game: GameData, chk: Callable) -> void:
	var t: Object = (load("res://tests/cosmetic_tests.gd") as GDScript).new()
	t.set("check", chk)
	t.set("d", game)
	t.call("_all")


func _all() -> void:
	_table()
	_conditions()
	_shop()
	_wear()
	_fresh_and_hidden()
	_save()
	_clean_and_duel()
	_art()
	_admin()
	_guide()


func _table() -> void:
	var t: CosmeticTable = Cosmetics.table()
	var ids: Dictionary = {}
	var ok: bool = true
	var per: Dictionary = {}
	for it in t.items:
		ids[it.id] = 1
		per[it.slot] = int(per.get(it.slot, 0)) + 1
		if not CosmeticTable.SLOTS.has(it.slot) or not UNLOCKS.has(it.unlock) or not STYLES.has(it.style) or it.title == "":
			ok = false
		if it.unlock == &"shards" and it.need <= 0:
			ok = false
		if it.unlock == &"league" and (it.need < 0 or it.need > 7):
			ok = false
		if it.unlock in [&"boss", &"story"] and it.key == &"":
			ok = false
	check.call(ids.size() == t.items.size() and t.items.size() >= 30 and ok, "꾸미기: 표의 항목 id가 겹치지 않고 자리·해금·모양이 모두 알려진 값(%d개)" % t.items.size())
	var firsts: bool = true
	for s in CosmeticTable.SLOTS:
		var first: CosmeticItem = t.item(t.default_of(s))
		firsts = firsts and first != null and first.unlock == &"free" and int(per.get(s, 0)) >= 8
	check.call(firsts, "꾸미기: 세 자리 모두 항목이 8개 넘고 첫 항목(기본)은 처음부터")
	var kinds: Dictionary = {}
	for it in t.items:
		kinds[it.unlock] = 1
	check.call(kinds.size() == UNLOCKS.size(), "꾸미기: 해금 종류(처음부터·조각·리그·우두머리·이야기·룬 자리)가 다 쓰인다")


func _conditions() -> void:
	var m := Meta.new()
	var t: CosmeticTable = Cosmetics.table()
	check.call(m.cos_worn_id(&"cape") == &"cape_red" and m.cos_worn_id(&"head") == &"head_none" and m.cos_worn_id(&"slash") == &"slash_grade", "꾸미기: 새 기록은 자리마다 기본을 입고 있다")
	check.call(m.cos_has(&"cape_grey") and m.cos_has(&"head_band") and not m.cos_has(&"cape_moss") and not m.cos_has(&"cape_knight"), "꾸미기: 처음부터인 것만 가졌다")
	check.call(m.cos_sync().is_empty(), "꾸미기: 아무것도 이루지 않았으면 새로 열리는 것이 없다")
	m.boss_first = true
	check.call(m.cos_sync() == ["cape_knight", "head_knight", "slash_grave"], "꾸미기: 무덤 기사를 쓰러뜨리면 그 셋이 열린다")
	check.call(m.cos_sync().is_empty(), "꾸미기: 같은 조건으로 두 번 열리지 않는다")
	m.crypt_cleared["boss"] = 1
	check.call(m.cos_sync() == ["cape_shroud", "head_bone", "slash_bone"], "꾸미기: 무덤 주인을 쓰러뜨리면 그 셋이 열린다")
	m.time_traveller = true
	m.harvest_down = true
	m.anchor_hand = true
	var story: Array[String] = m.cos_sync()
	check.call(story.has("cape_coat") and story.has("head_visor") and story.has("slash_neon") and story.has("cape_anchor") and story.has("head_anchor") and story.has("slash_anchor"), "꾸미기: 이야기 1막·3막을 마치면 그 항목들이 열린다")
	# 룬 자리: 벤 적 100/400/1000 → 1/2/3칸
	m.sword_log["7"] = {"k": 100, "b": 0, "p": 0, "r": 1}
	check.call(m.cos_sync() == ["cape_runes"], "꾸미기: 룬 자리가 하나 열리면 룬 망토")
	m.sword_log["7"]["k"] = 1000
	var rr: Array[String] = m.cos_sync()
	check.call(rr.has("head_runeband") and rr.has("slash_rune") and rr.size() == 2, "꾸미기: 룬 자리 둘·셋에 이마띠와 룬빛")
	# 리그: 배치를 마치기 전에는 안 센다, 마친 뒤 최고 티어, 지난 시즌 칭호도 센다
	var lg := Meta.new()
	var st: Dictionary = League.state(lg)
	st.peak = 20
	check.call(lg.cos_sync().is_empty(), "꾸미기: 배치를 마치기 전의 티어는 세지 않는다")
	st.games = League.data().placement_games
	var got: Array[String] = lg.cos_sync()
	check.call(Cosmetics.league_tier(lg) == 6 and got.has("slash_gold") and got.has("cape_platinum") and got.has("head_ascend") and not got.has("cape_immortal"), "꾸미기: 승천(티어 6)이면 금빛·백금·승천 투구, 불멸 것은 아직")
	lg.league_titles = {"1": 23}
	check.call(lg.cos_sync().has("cape_immortal") and lg.cos_sync().is_empty() and Cosmetics.league_tier(lg) == 7, "꾸미기: 지난 시즌 불멸 칭호로 불멸 항목")
	var all_free: bool = true
	for it in t.items:
		if it.unlock != &"shards" and not Meta.new().cos_has(it.id):
			all_free = all_free and it.unlock != &"free"
	check.call(all_free, "꾸미기: 처음부터가 아닌 항목은 처음엔 없다")


func _shop() -> void:
	var m := Meta.new()
	m.shards = 39
	check.call(not m.cos_buy(&"cape_moss") and m.shards == 39 and not m.cos_has(&"cape_moss"), "꾸미기: 조각이 모자라면 못 산다")
	m.shards = 40
	check.call(m.cos_buy(&"cape_moss") and m.shards == 0 and m.cos_has(&"cape_moss"), "꾸미기: 값만큼 조각을 내고 산다")
	m.shards = 999
	check.call(not m.cos_buy(&"cape_moss") and m.shards == 999, "꾸미기: 이미 가진 것은 또 안 산다")
	check.call(not m.cos_buy(&"cape_knight") and not m.cos_buy(&"cape_grey") and not m.cos_buy(&"없는것") and m.shards == 999, "꾸미기: 조각으로 사는 것이 아닌 항목·없는 항목은 못 산다")
	m.cos_sync()
	check.call(m.cos_has(&"cape_moss") and m.cos_owned.has("cape_moss"), "꾸미기: 동기화가 산 것을 지우지 않는다")


func _wear() -> void:
	var m := Meta.new()
	check.call(not m.cos_wear(&"cape_moss") and m.cos_worn.is_empty(), "꾸미기: 안 가진 것은 못 입는다")
	check.call(m.cos_wear(&"cape_grey") and m.cos_worn_id(&"cape") == &"cape_grey" and Meta.cos_look.get("cape") == "cape_grey", "꾸미기: 가진 것을 입으면 화면 거울도 바뀐다")
	check.call(m.cos_wear(&"head_band") and m.cos_worn_id(&"head") == &"head_band" and m.cos_worn_id(&"cape") == &"cape_grey", "꾸미기: 자리마다 따로 입는다")
	check.call(m.cos_wear(&"cape_red") and not m.cos_worn.has("cape") and m.cos_worn_id(&"cape") == &"cape_red", "꾸미기: 기본을 입으면 칸이 지워진다")
	check.call(not m.cos_wear(&"없는것") and m.guide_ev.get("mirror", 0) == 2, "꾸미기: 기본이 아닌 것을 입을 때만 길라잡이에 센다(2번)")
	var before: Array = m.cos_owned.duplicate()
	m.cos_unlock(&"cape_moss")
	check.call(m.cos_unlock_all() > 0 and m.cos_owned.size() == Cosmetics.table().items.size() and before.size() < m.cos_owned.size(), "꾸미기: 전부 열기")
	check.call(m.cos_wear(&"slash_void") and m.cos_wear(&"head_ascend") and m.cos_wear(&"cape_immortal"), "꾸미기: 전부 열면 무엇이든 입는다")


func _fresh_and_hidden() -> void:
	var m := Meta.new()
	m.boss_first = true
	m.cos_sync()
	check.call(m.cos_fresh().size() == 3, "꾸미기: 새로 연 것은 알릴 목록에 든다(처음부터인 것은 빼고)")
	m.cos_mark_seen()
	check.call(m.cos_fresh().is_empty(), "꾸미기: 알리고 나면 목록이 빈다")
	var it: CosmeticItem = Cosmetics.table().item(&"head_visor")
	check.call(not Cosmetics.shown(it, m), "꾸미기: 틈이 열리기 전에는 이야기 항목이 목록에 아예 없다")
	m.stranger_done = true
	check.call(Cosmetics.shown(it, m), "꾸미기: 틈이 열리면 목록에 든다")
	var gold: CosmeticItem = Cosmetics.table().item(&"slash_gold")
	check.call(Cosmetics.condition_text(gold).contains("금") and Cosmetics.condition_text(Cosmetics.table().item(&"cape_moss")) == "조각 40" and Cosmetics.condition_text(Cosmetics.table().item(&"cape_runes")).contains("룬"), "꾸미기: 조건 한 줄이 나온다")


func _save() -> void:
	var m := Meta.new()
	m.boss_first = true
	m.shards = 500
	m.cos_buy(&"cape_stripe")
	m.cos_wear(&"cape_stripe")
	m.cos_wear(&"slash_white")
	m.cos_sync()
	m.cos_mark_seen()
	m.save(TMP)
	var n := Meta.load_or_new(TMP)
	check.call(n.cos_owned == m.cos_owned and n.cos_worn == m.cos_worn and n.cos_seen == m.cos_seen and n.shards == m.shards and Meta.cos_look == n.cos_worn, "꾸미기: 저장하고 읽어도 가진 것·입은 것·알린 것이 그대로")
	var f := FileAccess.open(TMP, FileAccess.WRITE)
	f.store_string(JSON.stringify({"shards": 9, "runs": 2}))
	f.close()
	var old := Meta.load_or_new(TMP)
	check.call(old.cos_worn.is_empty() and old.cos_worn_id(&"cape") == &"cape_red" and old.cos_has(&"cape_grey") and not old.cos_has(&"cape_moss") and old.shards == 9, "꾸미기: 옛 저장은 모두 기본, 처음부터인 것만 가진 채로 읽힌다")
	f = FileAccess.open(TMP, FileAccess.WRITE)
	f.store_string(JSON.stringify({"cos_owned": ["cape_moss", "없는것", 5, "cape_moss"], "cos_worn": {"cape": "head_hood", "head": "head_hood", "slash": "없는것", "x": "y"}}))
	f.close()
	var odd := Meta.load_or_new(TMP)
	check.call(odd.cos_owned.count("cape_moss") == 1 and not odd.cos_owned.has("없는것") and odd.cos_worn == {"head": "head_hood"}, "꾸미기: 잘못된 저장(없는 항목·다른 자리·중복)은 걸러진다")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))


func _clean_and_duel() -> void:
	check.call(Cosmetics.clean("글") == {} and Cosmetics.clean(null) == {} and Cosmetics.clean({"cape": 5, "head": ["x"]}) == {}, "꾸미기: 모양이 틀린 것은 빈 사전")
	check.call(Cosmetics.clean({"cape": "cape_moss", "head": "cape_moss", "slash": "slash_ember", "zzz": "a"}) == {"cape": "cape_moss", "slash": "slash_ember"}, "꾸미기: 자리에 맞는 표의 항목만 남긴다")
	var m := Meta.new()
	m.cos_unlock_all()
	m.cos_wear(&"cape_runes")
	m.cos_wear(&"head_horn")
	var spec: Dictionary = DuelSetup.spec_of(m, 0)
	check.call(spec.cos == {"cape": "cape_runes", "head": "head_horn"}, "꾸미기: 결투 시작 정보에 입은 꾸미기가 실린다")
	var s := DuelSetup.new()
	s.picks = [spec, DuelSetup.bare()]
	var back := DuelSetup.from_bytes(s.to_bytes(), d)
	check.call(back != null and back.picks[0].cos == spec.cos and back.picks[1].cos == {}, "꾸미기: 바이트로 보냈다 받아도 그대로(맨손이어도)")
	var evil := DuelSetup.from_bytes(var_to_bytes([1, 5, {"id": 0, "cos": {"cape": "head_horn", "head": "<b>x</b>", "slash": "slash_void", "q": "w"}}, {"cos": 7}]), d)
	check.call(evil != null and evil.picks[0].cos == {"slash": "slash_void"} and evil.picks[1].cos == {}, "꾸미기: 상대가 보낸 이상한 꾸미기는 걸러진다")
	var plain := DuelSetup.new()
	plain.seed_value = 5
	var s2 := DuelSetup.new()
	s2.seed_value = 5
	s2.picks = [spec, DuelSetup.bare()]
	var r1 := Rules.new(d, 5)
	var r2 := Rules.new(d, 5)
	r1.start_duel(plain.make_swords(d)[0], null)
	r2.start_duel(s2.make_swords(d)[0], null)
	check.call(r1.state_hash() == r2.state_hash(), "꾸미기: 꾸미기가 달라도 규칙의 상태 해시는 같다")


func _art() -> void:
	var t: CosmeticTable = Cosmetics.table()
	var scene: PackedScene = load("res://scenes/lord/lord_model.tscn")
	var built: int = 0
	var bad: int = 0
	for it in t.items:
		if it.slot == &"cape":
			var c: Node3D = CosmeticArt.cape(it)
			var mi := c.get_node_or_null("Cape") as MeshInstance3D
			if mi == null or mi.mesh == null or mi.mesh.get_surface_count() != 1 or (mi.material_override as StandardMaterial3D).albedo_texture == null:
				bad += 1
			c.free()
			built += 1
		elif it.slot == &"head":
			var h: Node3D = CosmeticArt.head(it)
			if (it.style == &"none") != (h.get_child_count() == 0):
				bad += 1
			h.free()
			built += 1
		else:
			var img: Image = CosmeticArt.slash_icon(it, Vector2(64, 64))
			if img.get_width() != 64:
				bad += 1
			built += 1
	check.call(built == t.items.size() and bad == 0, "꾸미기: 모든 항목의 모양(망토 면·머리 도형·베기 그림)이 만들어진다")
	check.call(Cosmetics.slash_color({"slash": "slash_ember"}) == Color(1.0, 0.5, 0.15) and Cosmetics.slash_color({}).a == 0.0 and Cosmetics.slash_color({"slash": "cape_moss"}).a == 0.0, "꾸미기: 베기 빛 색(안 입으면 알파 0 = 검 본래 빛, 다른 자리 항목은 무시)")
	var fx := MoveFx.new()
	Meta.cos_look = {"slash": "slash_blood"}
	check.call(fx._col(&"") == Color(0.9, 0.12, 0.15), "꾸미기: 속성 없는 판정 빛도 입은 베기 색을 따른다")
	fx.use_cosmetic = false
	check.call(fx._col(&"") == fx.tint, "꾸미기: 결투는 판정 빛에 꾸미기를 쓰지 않는다")
	Meta.cos_look = {}
	fx.free()
	var model: Node3D = scene.instantiate()
	var orig_cape: Node3D = model.get_node("Cape")
	var crown: Node3D = model.get_node("Crown")
	var r: Dictionary = CosmeticRig.apply(model, null, {})
	check.call(orig_cape.visible and crown.visible and r.cape == null and r.slash.a == 0.0, "꾸미기: 아무것도 안 입으면 처음 모습 그대로(붉은 망토, 금관)")
	r = CosmeticRig.apply(model, null, {"cape": "cape_stripe", "head": "head_helm", "slash": "slash_ember"})
	check.call(not orig_cape.visible and not crown.visible and r.cape != null and model.get_node_or_null("CosCape") != null and model.get_node_or_null("CosHead") != null and r.slash == Color(1.0, 0.5, 0.15), "꾸미기: 입으면 처음 망토·금관을 가리고 새 망토와 머리가 붙는다")
	r = CosmeticRig.apply(model, null, {"cape": "cape_moss"})
	check.call(model.find_children("CosCape*", "", true, false).size() == 1 and model.get_node_or_null("CosHead") == null and crown.visible, "꾸미기: 다시 입히면 지난 것은 걷힌다")
	r = CosmeticRig.apply(model, null, {"cape": "head_helm", "head": "cape_moss", "slash": "cape_moss"})
	check.call(orig_cape.visible and crown.visible and r.slash.a == 0.0, "꾸미기: 자리가 틀린 항목은 무시한다")
	model.free()


func _admin() -> void:
	var m := Meta.new()
	var cmd: Dictionary = AdminCmd.parse("꾸미기 전부")
	check.call(cmd.get("name", "") == "꾸미기" and AdminCmd.describe(cmd) != "", "꾸미기: 관리 명령 `꾸미기 전부`를 알아본다")
	m.cos_wear(&"cape_grey")
	var msg: String = AdminCmd.apply(cmd, null, m)
	check.call(m.cos_owned.size() == Cosmetics.table().items.size() and msg.contains("꾸미기") and m.cos_fresh().is_empty(), "꾸미기: 관리 명령이 표의 모든 항목을 연다")
	m.save(TMP)
	AdminCmd.apply(AdminCmd.parse("꾸미기 처음"), null, m)
	check.call(m.cos_worn.is_empty() and not m.cos_has(&"cape_moss") and AdminCmd.apply(AdminCmd.parse("꾸미기 뭐"), null, m).contains("전부"), "꾸미기: `꾸미기 처음`은 처음으로, 모르는 낱말은 안내")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	Meta.load_or_new("user://없는_파일.json")   # 화면 거울을 빈 기록으로 되돌린다


func _guide() -> void:
	var i: int = Guide.index_of("mirror")
	check.call(i >= 0 and bool(Guide.STEPS[i].hint.has("lobby")) and Guide.reward_text(i) != "", "꾸미기: 길라잡이에 거울 단계가 있고 방향·보상이 있다")
	var m := Meta.new()
	check.call(Guide.count(i, m) == 0 and not Guide.legacy_ok(i, m), "꾸미기: 안 입었으면 거울 단계는 0")
	check.call(Guide.sync(m).is_empty() and m.guide_init, "꾸미기: 처음 정리에서는 거울 단계가 끝나지 않는다")
	m.cos_wear(&"cape_grey")
	var got: Array[int] = Guide.sync(m)
	check.call(got.has(i) and Guide.is_done(i, m) and m.shards == 5, "꾸미기: 하나 입으면 거울 단계가 끝나고 조각 5")
	var old := Meta.new()
	old.cos_worn = {"head": "head_band"}
	check.call(Guide.legacy_ok(i, old), "꾸미기: 이미 꾸민 저장은 거울 단계가 끝난 것으로 본다")
