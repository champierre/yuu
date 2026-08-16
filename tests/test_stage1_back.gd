extends "res://tests/test_helper.gd"
## 斧を振っている途中で「戻」を押しても落ちないか。
##
## 木を切る演出は await でコマをまたぐ。その途中で場面を抜けると、
## 解放されたノードや get_tree() を触りにいって落ちていた。
##
## この落ち方はヘッドレスでは走り続けてしまうので、
## テストの中からは見えない。run_all.sh が stderr の
## 「SCRIPT ERROR」を拾って失敗にする。

func run_tests() -> void:
	print("斧を振っている途中で「戻」")

	var G := game()
	var s := await load_scene("res://scenes/stage1.tscn")
	check(s != null and s.name == "Stage1", "ステージ1 が開く")

	var pad = load("res://scripts/touch_pad.gd").new()
	s.add_child(pad)
	await wait_ms(200)

	## 宝箱に重なって斧を取る。
	s.hero.position = s.chest.position
	await wait_ms(300)
	await press_accept()
	check(G.got_axe, "斧が手に入る")

	## 木に重なって「押」で振り始める。
	s.start_scene2()
	await wait_ms(300)
	s.hero.position = s.forest.position
	await wait_ms(200)
	await press_accept()
	## 振っている最中まで待つ（振りかぶり〜振り抜き）。
	await wait_ms(250)
	check(s._busy, "斧を振っている最中である")

	## その最中に「戻」を押す。ここで落ちていた。
	pad._press_at(_btn_pos(pad, "ui_cancel"), 0)
	await wait_ms(2000)

	var now := current_scene
	check(now != null and now.name == "Title", "斧を振っている途中で「戻」を押しても落ちない")

func _btn_pos(pad, action: String) -> Vector2:
	for b in pad.BUTTONS:
		if b["action"] == action:
			return Vector2(b["x"], pad.PAD_TOP + b["y"])
	return Vector2.ZERO
