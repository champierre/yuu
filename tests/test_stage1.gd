extends "res://tests/test_helper.gd"
## ステージ1「斧」を、実際にキーで歩いて最後まで遊べるか。

func run_tests() -> void:
	print("ステージ1「斧」")
	var G := game()
	var s := await load_scene("res://scenes/stage1.tscn")

	check_eq(G.scene_no, 1, "シーン1 から始まる")
	check(not G.got_axe, "斧はまだ持っていない")

	## 宝箱まで歩いて斧を取る。
	await walk_to(s.hero, 200, -150)
	await press_accept()
	check(G.got_axe, "宝箱を開けて斧が手に入る")

	## 木に触れるとシーン2 へ。
	await walk_to(s.hero, 0, -20)
	check_eq(G.scene_no, 2, "木に触れてシーン2 へ移る")

	## 木木木 を 3 回切る。
	for n in 5:
		if G.scene_no == 3:
			break
		for i in 300:
			if s._touching_tree() or G.scene_no == 3:
				break
			await step(KEY_LEFT)
		if G.scene_no == 3:
			break
		await press_accept()
		await wait_ms(2500)
	await wait_ms(2000)
	check_eq(G.scene_no, 3, "3 回切ると木が倒れてシーン3 へ")

	## 倒木の橋を渡って目標へ。
	for i in 500:
		if s._finished:
			break
		await step(KEY_UP)
	await wait_ms(500)
	check(s._finished, "目標に着いてクリアになる")
