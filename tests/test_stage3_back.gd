extends "res://tests/test_helper.gd"
## 蟲が登場してくる途中で「戻」を押しても落ちないか。
##
## 宝箱を開けると蟲が穴から這い出てくる。その演出は await でコマをまたぐので、
## 途中で場面を抜けると、解放されたノードを触りにいって落ちていた。

func run_tests() -> void:
	print("蟲の登場中に「戻」")

	var st := await load_scene("res://scenes/stage3.tscn")
	check(st != null and st.name == "Stage3", "ステージ3 が開く")

	var pad = load("res://scripts/touch_pad.gd").new()
	st.add_child(pad)
	await wait_ms(200)

	## 宝箱まで歩いて、「押」で開ける。ここから蟲の登場演出が始まる。
	var hero := st.get_node("Hero")
	var chest := st.get_node("Chest")
	var cp: Vector2 = chest.scratch_pos()
	var ok := await walk_to(hero, cp.x, cp.y)
	check(ok, "宝箱まで歩ける")

	pad._press_at(_btn_pos(pad, "ui_accept"), 0)
	await wait_ms(120)
	pad._release(0)
	## 蟲が出てくる途中（出そろう前）まで待つ。
	await wait_ms(500)
	check(st._emerging_now, "蟲が登場してくる途中である")

	## その最中に「戻」を押す。ここで落ちていた。
	##
	## 落ちたことは、この中からは見えない。
	## ヘッドレスの Godot は get_tree() を触って落ちても走り続け、
	## 印は stderr の「SCRIPT ERROR」にしか出ないため。
	## そこは run_all.sh が拾って落とす（エラーを出したら失敗にする）。
	pad._press_at(_btn_pos(pad, "ui_cancel"), 0)
	await wait_ms(1500)

	## 落ちずにタイトルまで帰れていること。
	var now := current_scene
	check(now != null and now.name == "Title", "登場の途中で「戻」を押しても落ちない")

func _btn_pos(pad, action: String) -> Vector2:
	for b in pad.BUTTONS:
		if b["action"] == action:
			return Vector2(b["x"], pad.PAD_TOP + b["y"])
	return Vector2.ZERO
