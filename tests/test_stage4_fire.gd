extends "res://tests/test_helper.gd"
## ステージ4 の火矢。向いた方へ飛び、燭に当たると火が移る。
##
## ステージ3 の矢は真上だけだったが、こちらは hero.facing の方へ飛ぶ。
## そこが遊びの中身なので、向きが効いていることを確かめる。

func run_tests() -> void:
	print("ステージ4 の火矢")
	var g := game()
	g.debug = true
	g.stage_no = 4

	var s := await load_scene("res://scenes/stage4.tscn")
	if s == null:
		check(false, "ステージ4 が読み込める")
		return

	## 弓を持たせる（宝箱の作法は test_stage4_chest.gd で見ている）。
	var p: Vector2 = s.chest.scratch_pos()
	s.hero.set_scratch_pos(p.x, p.y)
	await wait_ms(300)
	await press_accept()
	check(g.got_bow, "弓が手に入る")
	await wait_ms(300)

	## 燭のすぐ下に立ち、上を向いて射る。
	var lamp: Node = s._lamps[0]
	var lp: Vector2 = lamp.scratch_pos()
	s.hero.set_scratch_pos(lp.x, lp.y - 60.0)
	s.hero.facing = Vector2.UP
	await wait_ms(300)
	check(lamp.visible, "近くの燭は見えている")
	check_eq(lamp.text, "燭", "射る前は「燭」のまま")

	## 満タンで放つ。当たれば「灯」に変わる。
	var struck = await s._fly_arrow([lamp], Vector2.UP, 1.0)
	check(struck == lamp, "上を向いて射ると、真上の燭に当たる")

	await s._light_lamp(lamp)
	await wait_ms(200)
	check_eq(lamp.text, "灯", "当たった燭は「灯」になる")
	check(lamp.position in _positions(s._lit), "点いた灯として数えられる")

	## 明かりが広がる。
	check(s._light_at(lamp.position) > 0.9, "灯のある所は明るい")

	## 見えていない燭には当たらない。
	## 「見えている所しか射てない」がこのステージの肝。
	var far: Node = s._lamps[3]
	s.hero.set_scratch_pos(-190, -130)
	await wait_ms(300)
	check(not far.visible, "遠くの燭は見えない")
	var missed = await s._fly_arrow([far], Vector2.UP, 1.0)
	check(missed == null, "見えていない燭には当たらない")

	## 引きが浅いと遠くまで届かない。
	## ためる意味が無くなると、遊びが平板になる。
	var lamp2: Node = s._lamps[1]
	var l2: Vector2 = lamp2.scratch_pos()
	s.hero.set_scratch_pos(l2.x, l2.y - 150.0)
	s.hero.facing = Vector2.UP
	await wait_ms(300)
	var weak = await s._fly_arrow([lamp2], Vector2.UP, 0.2)
	check(weak == null, "浅い引きでは遠くの燭に届かない")

	g.debug = false
	g.stage_no = 1

func _positions(arr: Array) -> Array:
	var out: Array = []
	for a in arr:
		if is_instance_valid(a):
			out.append(a.position)
	return out
