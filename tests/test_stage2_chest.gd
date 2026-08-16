extends "res://tests/test_helper.gd"
## ステージ2 の宝箱。画面のボタンでも 1 回目で開くか。

func run_tests() -> void:
	print("ステージ2 の宝箱")
	var G := game()
	var s := await load_scene("res://scenes/stage2.tscn")

	## 触れただけでは開かない。
	s.hero.position = s.chest.position
	await wait_ms(400)
	check(not G.got_gold, "触れただけでは金を取れない")

	## 画面のボタンで 1 回押したら開く。
	var pad = load("res://scripts/touch_pad.gd").new()
	s.add_child(pad)
	await wait_ms(300)
	var apos := Vector2.ZERO
	for b in pad.BUTTONS:
		if b["action"] == "ui_accept":
			apos = Vector2(b["x"], pad.PAD_TOP + b["y"])
	pad._press_at(apos, 0)
	await wait_ms(200)
	pad._release(0)
	await wait_ms(200)
	check(G.got_gold, "画面のボタンでも 1 回目で宝箱が開く")
