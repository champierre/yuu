extends "res://tests/test_helper.gd"
## ステージ4 の宝箱は「重なってボタンを押した」ときだけ開く。
## 通りかかっただけ、あるいは押しっぱなしで通っただけでは開かない。
##
## スマホでは移動ボタンを押しながら歩くので、押しっぱなしで開いてしまうと
## 宝箱の上を通っただけで勝手に開く。

func run_tests() -> void:
	print("ステージ4 の宝箱")
	var g := game()
	g.debug = true
	g.stage_no = 4

	var s := await load_scene("res://scenes/stage4.tscn")
	if s == null:
		check(false, "ステージ4 が読み込める")
		return

	## 1. ボタンを押さずに宝箱へ重なる → 開かない
	var p: Vector2 = s.chest.scratch_pos()
	s.hero.set_scratch_pos(p.x, p.y)
	await wait_ms(400)
	check(not g.got_bow, "触れただけでは弓を取れない")

	## 2. 決定ボタンを押したまま近づく → 開かない
	s.hero.set_scratch_pos(p.x, p.y - 80.0)
	await wait_ms(200)
	key(KEY_SPACE, true)                 ## 宝箱から離れた所で押し始める
	await wait_ms(200)
	s.hero.set_scratch_pos(p.x, p.y)     ## 押したまま重なる
	await wait_ms(400)
	check(not g.got_bow, "押しっぱなしのまま重なっても弓を取れない")
	key(KEY_SPACE, false)
	await wait_ms(200)

	## 3. 重なってから押す → 開く
	await press_accept()
	check(g.got_bow, "重なってから押すと弓が手に入る")
	check_eq(s.chest.text, "空箱", "開けた宝箱は空箱になる")
	check(s.bow.visible, "弓が見えるようになる")

	## 宝箱を開けた押し下げが、そのまま引き絞りに化けないこと。
	## 化けると、取った瞬間に矢が飛んでしまう。
	## press_accept() は最後にキーを離すので、そこで印は下りている。
	## ここでは「ためが始まっていない」ことで確かめる。
	check_eq(s._charge, 0.0, "取った直後は引き絞っていない")

	## 押しっぱなしのまま取ったときは、離すまで引き絞りが始まらない。
	var s2 := await load_scene("res://scenes/stage4.tscn")
	g.got_bow = false
	var p2: Vector2 = s2.chest.scratch_pos()
	s2.hero.set_scratch_pos(p2.x, p2.y - 80.0)
	await wait_ms(300)
	key(KEY_SPACE, true)        ## 離れた所から押し始める
	await wait_ms(150)
	s2.hero.set_scratch_pos(p2.x, p2.y)
	await wait_ms(150)
	## 重なった状態で押し直す（押した瞬間を作る）。
	key(KEY_SPACE, false)
	await wait_ms(60)
	key(KEY_SPACE, true)
	await wait_ms(400)          ## 押したまま待つ
	check(g.got_bow, "押し直すと弓が手に入る")
	check_eq(s2._charge, 0.0, "押しっぱなしのままでは引き絞りが始まらない")
	key(KEY_SPACE, false)
	await wait_ms(200)

	g.debug = false
	g.stage_no = 1
