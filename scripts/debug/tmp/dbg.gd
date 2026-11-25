extends SceneTree
func _init() -> void:
	var data := GameData.load_default()
	Grid.size = Vector2i(60, 60)
	var r := Rules.new(data, 5)
	r.start_field()
	var s := Sword.new(data.sword_by_id(50), data)
	r.slots[0] = s
	r.active = 0
	r.lord.pos = Vector2(30, 30)
	var es := r.spawn_pack(&"p0", {"foes": [[&"wolf", 2]], "wander": 2.0, "zone": 4, "at": Vector2(30, 26)})
	print("phase ", r.phase, " field ", r.field, " es ", es.size(), " cur ", r.current())
	for t in 120:
		var i := LordInput.new()
		var e: Enemy = es[0]
		i.aim_valid = true
		i.aim = e.pos
		i.move = (e.pos - r.lord.pos).normalized() if e.pos.distance_to(r.lord.pos) > 1.5 else Vector2.ZERO
		i.attack = true
		r.step(i)
		if t % 20 == 0:
			print(t, " lord ", r.lord.pos, " e ", e.pos, " hp ", e.hp, " dead ", e.dead, " cd ", r.lord.cooldown)
	quit()
