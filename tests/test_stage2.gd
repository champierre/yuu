extends "res://tests/test_helper.gd"
## ステージ2「鉄」を、実際にキーで歩いて最後まで遊べるか。
## 謎の筋（金 → 失 → 鉄）が通ることを確かめる。

func run_tests() -> void:
	print("ステージ2「鉄」")
	var G := game()
	var s := await load_scene("res://scenes/stage2.tscn")

	## 門は閉じていて、通れない。
	check(s.gate1.get_parent() == s.wall_root, "門はぶつかる相手に入っている")
	await walk_to(s.hero, 0, 40)
	for i in 60:
		await step(KEY_UP)
	check(s.hero.scratch_pos().y < 90.0, "門が閉じている間は壁を越えられない")

	## 宝箱から金を取る。
	await walk_to(s.hero, 200, 50)
	await press_accept()
	check(G.got_gold, "宝箱から金が手に入る")

	## 盗人にわざと捕まって金を失う。
	for tries in 14:
		if G.lost_gold:
			break
		var tp: Vector2 = s.thief.scratch_pos()
		await walk_to(s.hero, tp.x, tp.y, 200)
		await wait_ms(400)
	check(G.lost_gold, "盗人に金を奪われて「失」になる")
	await wait_ms(2500)

	## もう一度宝箱を開けると、金と失が合わさって鉄になる。
	await walk_to(s.hero, 200, 50)
	await press_accept()
	await wait_ms(4500)
	check(G.got_iron, "金＋失で鉄になる")

	## 門番に鉄を見せると門が開く。
	await walk_to(s.hero, 40, 40)
	await wait_ms(4500)
	check(G.gate_open, "鉄を見せると門が開く")

	## 門を抜けて目標へ。
	await walk_to(s.hero, -10, 60, 300)
	for i in 300:
		if s._finished:
			break
		await step(KEY_UP)
	await wait_ms(500)
	check(s._finished, "門を抜けて目標に着ける")
