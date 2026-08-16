extends "res://tests/test_helper.gd"
## 演出の途中で「戻」を押しても落ちないか（ステージ4）。
##
## 火矢が飛んでいる間や、やられた演出の途中で場面を抜けると、
## 解放されたノードや get_tree() を触りにいって落ちる（落とし穴 9）。
##
## この落ち方はヘッドレスでは走り続けてしまい、テストの中からは見えない。
## run_all.sh が stderr の「Parameter "data.tree" is null」を拾って失敗にする。

func run_tests() -> void:
	print("ステージ4 で演出中に「戻」")
	var g := game()
	g.debug = true
	g.stage_no = 4

	## 1. 火矢が飛んでいる最中に「戻」を押す。
	var s := await load_scene("res://scenes/stage4.tscn")
	if s == null:
		check(false, "ステージ4 が読み込める")
		return
	var pad = load("res://scripts/touch_pad.gd").new()
	s.add_child(pad)
	await wait_ms(200)

	## 弓を持たせて、遠くへ向けて射る（当たらないので長く飛ぶ）。
	var p: Vector2 = s.chest.scratch_pos()
	s.hero.set_scratch_pos(p.x, p.y)
	await wait_ms(300)
	await press_accept()
	check(g.got_bow, "弓が手に入る")

	s.hero.set_scratch_pos(0, -140)
	s.hero.facing = Vector2.UP
	await wait_ms(200)
	## 待たない。飛んでいる最中に抜けたいので。
	##
	## 実時間で待つと行き過ぎる。ヘッドレスの 1 コマは 0.5ms ほどしかなく、
	## 120ms 待つと矢はとうに燃え尽きている。コマ単位で待つこと。
	s._shoot(1.0)
	var flying := false
	for i in 20:
		if s._shooting:
			flying = true
			break
		await process_frame
	check(flying, "火矢が飛んでいる最中である")

	pad._press_at(_btn_pos(pad, "ui_cancel"), 0)
	await wait_ms(1800)
	var now := current_scene
	check(now != null and now.name == "Title", "火矢が飛んでいる途中で「戻」を押しても落ちない")

	## 2. やられた演出の最中に「戻」を押す。
	g.debug = true
	g.stage_no = 4
	var s2 := await load_scene("res://scenes/stage4.tscn")
	if s2 == null:
		check(false, "ステージ4 をもう一度読み込める")
		return
	var pad2 = load("res://scripts/touch_pad.gd").new()
	s2.add_child(pad2)
	await wait_ms(200)

	s2._defeated()             ## 待たない
	await wait_ms(120)
	check(s2._busy, "やられた演出の最中である")

	pad2._press_at(_btn_pos(pad2, "ui_cancel"), 0)
	await wait_ms(1800)
	var now2 := current_scene
	check(now2 != null and now2.name == "Title", "やられた演出の途中で「戻」を押しても落ちない")

	g.debug = false
	g.stage_no = 1

func _btn_pos(pad, action: String) -> Vector2:
	for b in pad.BUTTONS:
		if b["action"] == action:
			return Vector2(b["x"], pad.PAD_TOP + b["y"])
	return Vector2.ZERO
