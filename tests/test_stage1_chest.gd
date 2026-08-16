extends "res://tests/test_helper.gd"
## 宝箱は「重なってボタンを押した」ときだけ開く。
## 通りかかっただけ、あるいは他のボタンを押しながら通っただけでは開かない。

func run_tests() -> void:
	print("ステージ1 の宝箱")
	var G := game()
	var s := await load_scene("res://scenes/main.tscn")

	## 1. ボタンを押さずに宝箱へ重なる → 開かない
	s.hero.position = s.chest.position
	await wait_ms(400)
	check(not G.got_axe, "触れただけでは斧を取れない")

	## 2. 決定ボタンを押したまま近づく → 開かない
	##    スマホでは移動ボタンを押しながら通ることがあるので、
	##    「押しっぱなしのまま重なった」だけで取れてはいけない。
	s.hero.set_scratch_pos(0, -100)
	await wait_ms(200)
	key(KEY_SPACE, true)          ## 宝箱から離れた所で押し始める
	await wait_ms(200)
	s.hero.position = s.chest.position   ## 押したまま重なる
	await wait_ms(400)
	check(not G.got_axe, "押しっぱなしのまま重なっても斧を取れない")
	key(KEY_SPACE, false)
	await wait_ms(200)

	## 3. 重なってから押す → 開く
	await press_accept()
	check(G.got_axe, "重なってから押すと斧が手に入る")

	## 4. 木を切るのも同じ。押しっぱなしのまま近づいても切れない。
	##    切れてしまうと、歩いているだけで木が倒れてしまう。
	s.start_scene2()
	await wait_ms(300)
	var before: int = G.cut_count
	key(KEY_SPACE, true)              ## 木から離れた所で押し始める
	await wait_ms(200)
	s.hero.position = s.forest.position   ## 押したまま重なる
	await wait_ms(400)
	check_eq(G.cut_count, before, "押しっぱなしのまま木に重なっても切れない")
	key(KEY_SPACE, false)
	await wait_ms(300)

	## 5. 重なってから押すと切れる。
	await press_accept()
	await wait_ms(300)
	check(G.cut_count > before, "重なってから押すと切れる")
