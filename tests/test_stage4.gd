extends "res://tests/test_helper.gd"
## 作りかけのステージ4。歩いて通しでクリアできること。
##
## 座標を書き込むだけのテストでは「そもそもそこへ行けるのか」が分からない
## （CLAUDE.md の「座標を書き込むテストだけでは足りない」）ので、
## キーで歩いて宝箱と目標に届くところまで確かめる。

func run_tests() -> void:
	print("ステージ4（作りかけ）")
	var g := game()
	g.debug = true
	g.stage_no = 4

	var s := await load_scene("res://scenes/stage4.tscn")
	check(s != null and s.name == "Stage4", "ステージ4 が読み込める")
	var hero: Node = s.get_node("Hero")
	var chest: Node = s.get_node("Chest")
	var goal: Node = s.get_node("Goal")

	check(not goal.visible, "はじめは目標が出ていない")

	## 宝箱まで歩いて開ける。
	var p: Vector2 = chest.scratch_pos()
	check(await walk_to(hero, p.x, p.y), "宝箱まで歩いていける")
	await press_accept()
	check_eq(chest.text, "空箱", "宝箱を開けられる")
	check(goal.visible, "開けると目標が出る")

	## 目標まで歩いてクリアする。
	var q: Vector2 = goal.scratch_pos()
	check(await walk_to(hero, q.x, q.y), "目標まで歩いていける")
	await wait_ms(300)
	check(s._finished, "目標に触れるとクリアになる")

	g.debug = false
	g.stage_no = 1
